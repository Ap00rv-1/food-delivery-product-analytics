"""
A/B test maths, written by hand with only the standard library (no scipy needed).

Step 1: run 03_ab_test_counts.sql, copy the numbers into the section below.
Step 2: python ab_test.py

The numbers below are an example from one run of the data generator (seed 42).
Replace them with YOUR numbers from the SQL output.
"""
import math

# ---- PASTE FROM 03_ab_test_counts.sql, Query 1 (primary metric) ----
CONTROL_USERS, CONTROL_CONVERTED = 22316, 13851
TREATMENT_USERS, TREATMENT_CONVERTED = 21987, 14221

# ---- PASTE FROM Query 2 (guardrail: cancellations, counted per order) ----
CONTROL_ORDERS, CONTROL_CANCELLED = 37811, 1802
TREATMENT_ORDERS, TREATMENT_CANCELLED = 38707, 2007
# --------------------------------------------------------------------


def two_proportion_test(x1, n1, x2, n2):
    """Compare two rates. Returns (rate1, rate2, difference, z, p_value, 95% confidence interval)."""
    p1, p2 = x1 / n1, x2 / n2
    pooled = (x1 + x2) / (n1 + n2)
    # "If there were NO real difference, how much would the gap wobble by luck alone?"
    se_null = math.sqrt(pooled * (1 - pooled) * (1 / n1 + 1 / n2))
    z = (p2 - p1) / se_null                      # how many 'wobbles' away from zero is our gap?
    p_value = math.erfc(abs(z) / math.sqrt(2))   # chance of a gap this big from luck alone
    se_diff = math.sqrt(p1 * (1 - p1) / n1 + p2 * (1 - p2) / n2)
    ci = (p2 - p1 - 1.96 * se_diff, p2 - p1 + 1.96 * se_diff)
    return p1, p2, p2 - p1, z, p_value, ci


def sample_size_per_group(base_rate, min_lift, alpha_z=1.96, power_z=0.8416):
    """Users needed in EACH group to detect an absolute lift of `min_lift` (95% confidence, 80% power)."""
    p_bar = base_rate + min_lift / 2
    return math.ceil(2 * p_bar * (1 - p_bar) * (alpha_z + power_z) ** 2 / min_lift ** 2)


def report(title, x1, n1, x2, n2):
    p1, p2, diff, z, pv, ci = two_proportion_test(x1, n1, x2, n2)
    print(f"\n=== {title} ===")
    print(f"control   : {p1:.2%}  ({x1:,} of {n1:,})")
    print(f"treatment : {p2:.2%}  ({x2:,} of {n2:,})")
    print(f"difference: {diff * 100:+.2f} percentage points  (relative: {diff / p1:+.1%})")
    print(f"95% confidence interval for the difference: {ci[0] * 100:+.2f} to {ci[1] * 100:+.2f} points")
    print(f"z = {z:.2f},  p-value = {pv:.2g}")
    return diff, pv


if __name__ == "__main__":
    need = sample_size_per_group(0.62, 0.02)
    print(f"Planning check: to detect a +2 point lift from a 62% baseline we needed ~{need:,} users per group.")
    print(f"We had {CONTROL_USERS:,} and {TREATMENT_USERS:,}, so the test was big enough.")

    report("PRIMARY: first-cart checkout rate", CONTROL_CONVERTED, CONTROL_USERS,
           TREATMENT_CONVERTED, TREATMENT_USERS)
    report("GUARDRAIL: cancellation rate (lower is better)", CONTROL_CANCELLED, CONTROL_ORDERS,
           TREATMENT_CANCELLED, TREATMENT_ORDERS)