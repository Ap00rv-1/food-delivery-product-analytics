-- Product analytics case study: food-delivery app (SYNTHETIC data)
CREATE TABLE users (
    user_id      INTEGER PRIMARY KEY,
    signup_date  DATE NOT NULL,
    city         TEXT NOT NULL,
    channel      TEXT NOT NULL,      -- organic / paid / referral / influencer
    device       TEXT NOT NULL       -- android / ios
);

-- One row per user: which version of the cart screen they were shown
CREATE TABLE experiment_assignments (
    user_id  INTEGER PRIMARY KEY REFERENCES users(user_id),
    variant  TEXT NOT NULL           -- control / treatment (treatment = ETA shown on cart)
);

-- Funnel events: app_open > view_restaurant > add_to_cart > checkout_start > order_placed > order_delivered
CREATE TABLE events (
    event_id    BIGINT PRIMARY KEY,
    session_id  BIGINT NOT NULL,
    user_id     INTEGER NOT NULL REFERENCES users(user_id),
    event_name  TEXT NOT NULL,
    event_time  TIMESTAMP NOT NULL
);

CREATE TABLE orders (
    order_id          BIGINT PRIMARY KEY,
    session_id        BIGINT NOT NULL,
    user_id           INTEGER NOT NULL REFERENCES users(user_id),
    order_time        TIMESTAMP NOT NULL,
    order_value       NUMERIC(10,2) NOT NULL,
    delivery_minutes  INTEGER,       -- NULL if cancelled
    status            TEXT NOT NULL  -- delivered / cancelled
);

CREATE INDEX idx_events_user    ON events(user_id);
CREATE INDEX idx_events_session ON events(session_id);
CREATE INDEX idx_events_name    ON events(event_name);
CREATE INDEX idx_orders_user    ON orders(user_id, order_time);
