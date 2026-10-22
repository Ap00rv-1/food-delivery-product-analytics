-- ============================================================
-- Query A: weekly cohort retention
-- A "cohort" = users who signed up in the same week.
-- week_N = % of the cohort who placed an order N weeks after THEIR signup date.
-- (week_0 is really "activation": did they order in their first 7 days?)
-- ============================================================
WITH cohort_users AS (
    SELECT user_id, signup_date, DATE_TRUNC('week', signup_date)::date AS cohort_week
    FROM users
    -- Only keep cohorts that had time to be observed for 5 full weeks.
    -- Data ends 29 Sep, so users who signed up later haven't had a chance to show week_4.
    WHERE signup_date <= DATE '2026-08-25'
),
cohort_size AS (
    SELECT cohort_week, COUNT(*) AS cohort_users
    FROM cohort_users
    GROUP BY cohort_week
),
activity AS (
    -- one row per user per week-since-signup in which they ordered
    SELECT DISTINCT c.cohort_week, o.user_id,
           (o.order_time::date - c.signup_date) / 7 AS week_number
    FROM orders o
    JOIN cohort_users c USING (user_id)
)
SELECT a.cohort_week,
       s.cohort_users,
       ROUND(100.0 * COUNT(*) FILTER (WHERE a.week_number = 0) / s.cohort_users, 1) AS week_0,
       ROUND(100.0 * COUNT(*) FILTER (WHERE a.week_number = 1) / s.cohort_users, 1) AS week_1,
       ROUND(100.0 * COUNT(*) FILTER (WHERE a.week_number = 2) / s.cohort_users, 1) AS week_2,
       ROUND(100.0 * COUNT(*) FILTER (WHERE a.week_number = 3) / s.cohort_users, 1) AS week_3,
       ROUND(100.0 * COUNT(*) FILTER (WHERE a.week_number = 4) / s.cohort_users, 1) AS week_4
FROM activity a
JOIN cohort_size s USING (cohort_week)
GROUP BY a.cohort_week, s.cohort_users
ORDER BY a.cohort_week;

-- ============================================================
-- Query B: do users place a second order, and how fast? By acquisition channel.
-- Window function used: ROW_NUMBER() with PARTITION BY (numbers each user's orders 1, 2, 3...)
-- ============================================================
WITH numbered AS (
    SELECT user_id, order_time,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY order_time) AS n
    FROM orders
),
first_two AS (
    SELECT user_id,
           MAX(order_time) FILTER (WHERE n = 1) AS first_order,
           MAX(order_time) FILTER (WHERE n = 2) AS second_order
    FROM numbered
    WHERE n <= 2
    GROUP BY user_id
)
SELECT u.channel,
       COUNT(*)                                   AS users,
       COUNT(f.second_order)                      AS repeat_users,
       ROUND(100.0 * COUNT(f.second_order) / COUNT(*), 1) AS pct_repeat,
       ROUND(AVG(EXTRACT(EPOCH FROM (f.second_order - f.first_order)) / 86400)::numeric, 1) AS avg_days_to_second_order
FROM users u
LEFT JOIN first_two f USING (user_id)
GROUP BY u.channel
ORDER BY pct_repeat DESC;
