"""
Synthetic data generator for the product analytics case study.

All data is SIMULATED. The story we plant in it (so the analysis has something to find):
  * Funnel: users drop off at each step; the biggest leak is cart -> checkout.
  * Experiment: showing the delivery ETA on the cart screen (treatment) lifts
    cart -> checkout conversion by ~2 percentage points. Guardrails (order value,
    delivery time) are unchanged; cancellations move only slightly.
  * Retention: referral users return more than paid users, and everyone decays over time.

Usage:
  python generate_data.py                 # writes CSVs into ./data
  python generate_data.py --load          # also loads them into Postgres (docker-compose db)
"""
import argparse
import os
import numpy as np
import pandas as pd

# ---------------- Knobs you can change (and defend in an interview) ----------------
SEED = 42
N_USERS = 50_000
WINDOW_DAYS = 60            # we observe the app for 60 days
SIGNUP_DAYS = 45            # users sign up during the first 45 days
START_DATE = pd.Timestamp("2026-08-01")

CHANNELS = {"organic": 0.40, "paid": 0.35, "referral": 0.15, "influencer": 0.10}
# average sessions per week by channel (referral users are most engaged)
CHANNEL_WEEKLY_SESSIONS = {"organic": 1.8, "paid": 1.2, "referral": 2.2, "influencer": 1.0}
CITIES = {"Delhi NCR": 0.35, "Bengaluru": 0.25, "Mumbai": 0.20, "Hyderabad": 0.10, "Pune": 0.10}
DEVICES = {"android": 0.70, "ios": 0.30}

# Funnel step probabilities (per session)
P_VIEW = 0.85               # open -> view restaurant
P_CART = 0.55               # view -> add to cart
P_CHECKOUT_CONTROL = 0.62   # cart -> checkout start (control)
P_CHECKOUT_TREATMENT = 0.64 # cart -> checkout start (ETA shown)  <- the planted effect (+2 pp)
P_PLACED = 0.80             # checkout -> order placed (payment failures happen)
P_CANCEL_CONTROL = 0.050
P_CANCEL_TREATMENT = 0.052  # tiny change: a guardrail we should check, not a real effect
# -----------------------------------------------------------------------------------


def pick(rng, probs, n):
    return rng.choice(list(probs.keys()), size=n, p=list(probs.values()))


def generate():
    rng = np.random.default_rng(SEED)

    # ---- users ----
    users = pd.DataFrame({"user_id": np.arange(1, N_USERS + 1)})
    users["signup_day"] = rng.integers(0, SIGNUP_DAYS, N_USERS)
    users["signup_date"] = START_DATE + pd.to_timedelta(users["signup_day"], unit="D")
    users["city"] = pick(rng, CITIES, N_USERS)
    users["channel"] = pick(rng, CHANNELS, N_USERS)
    users["device"] = pick(rng, DEVICES, N_USERS)

    # ---- experiment assignment: random 50/50 at USER level ----
    # (Randomising by user, not by session, is why we must analyse at user level later.)
    assign = pd.DataFrame({
        "user_id": users["user_id"],
        "variant": rng.choice(["control", "treatment"], size=N_USERS),
    })
    variant = dict(zip(assign.user_id, assign.variant))

    # each user has their own engagement level (some people just order more)
    engagement = rng.gamma(shape=2.0, scale=0.5, size=N_USERS)   # mean ~1.0

    events, orders = [], []
    event_id, session_id, order_id = 0, 0, 0

    for i, u in enumerate(users.itertuples(index=False)):
        weekly = CHANNEL_WEEKLY_SESSIONS[u.channel] * engagement[i]
        for day in range(u.signup_day, WINDOW_DAYS):
            days_since = day - u.signup_day
            # chance of a session today: starts high, decays as the user gets less excited
            p_session = min(0.9, (weekly / 7) * (0.4 + 0.6 * np.exp(-days_since / 20)))
            if days_since == 0:
                p_session = 1.0          # signup day always has a session
            if rng.random() > p_session:
                continue

            session_id += 1
            # lunch (12-14h) and dinner (19-22h) peaks
            hour = rng.choice([12, 13, 14, 19, 20, 21, 22, 11, 18, 15], p=[.15, .13, .08, .17, .17, .12, .06, .04, .05, .03])
            t = START_DATE + pd.Timedelta(days=day, hours=int(hour), minutes=int(rng.integers(0, 60)))

            def emit(name):
                nonlocal event_id, t
                event_id += 1
                events.append((event_id, session_id, u.user_id, name, t))
                t = t + pd.Timedelta(seconds=int(rng.integers(5, 90)))

            emit("app_open")
            if rng.random() > P_VIEW:
                continue
            emit("view_restaurant")
            if rng.random() > P_CART:
                continue
            emit("add_to_cart")
            p_checkout = P_CHECKOUT_TREATMENT if variant[u.user_id] == "treatment" else P_CHECKOUT_CONTROL
            if rng.random() > p_checkout:
                continue
            emit("checkout_start")
            if rng.random() > P_PLACED:
                continue
            emit("order_placed")

            order_id += 1
            value = float(np.clip(rng.lognormal(mean=5.8, sigma=0.45), 80, 2500))  # ~INR 330 median
            p_cancel = P_CANCEL_TREATMENT if variant[u.user_id] == "treatment" else P_CANCEL_CONTROL
            if rng.random() < p_cancel:
                orders.append((order_id, session_id, u.user_id, t, round(value, 2), None, "cancelled"))
            else:
                minutes = int(np.clip(rng.normal(32, 7), 12, 75))
                orders.append((order_id, session_id, u.user_id, t, round(value, 2), minutes, "delivered"))
                t = t + pd.Timedelta(minutes=minutes)
                emit("order_delivered")

    events_df = pd.DataFrame(events, columns=["event_id", "session_id", "user_id", "event_name", "event_time"])
    orders_df = pd.DataFrame(orders, columns=["order_id", "session_id", "user_id", "order_time",
                                              "order_value", "delivery_minutes", "status"])
    users_out = users[["user_id", "signup_date", "city", "channel", "device"]]
    return users_out, assign, events_df, orders_df


def load_to_postgres(out_dir):
    import psycopg2
    conn = psycopg2.connect(
        host=os.getenv("PGHOST", "localhost"), port=os.getenv("PGPORT", "5433"),
        dbname=os.getenv("PGDATABASE", "analytics"), user=os.getenv("PGUSER", "analyst"),
        password=os.getenv("ANALYTICS_DB_PASSWORD", "change_me"),
    )
    cur = conn.cursor()
    cur.execute("TRUNCATE orders, events, experiment_assignments, users CASCADE")
    for table in ["users", "experiment_assignments", "events", "orders"]:   # parents first
        with open(os.path.join(out_dir, f"{table}.csv")) as f:
            cur.copy_expert(f"COPY {table} FROM STDIN WITH CSV HEADER", f)
        print("loaded", table)
    conn.commit()
    conn.close()


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--load", action="store_true", help="load CSVs into Postgres after generating")
    ap.add_argument("--out", default="data")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    users, assign, events, orders = generate()
    users.to_csv(f"{args.out}/users.csv", index=False)
    assign.to_csv(f"{args.out}/experiment_assignments.csv", index=False)
    events.to_csv(f"{args.out}/events.csv", index=False)
    orders.to_csv(f"{args.out}/orders.csv", index=False)
    print(f"users={len(users):,} events={len(events):,} orders={len(orders):,}")
    if args.load:
        load_to_postgres(args.out)
