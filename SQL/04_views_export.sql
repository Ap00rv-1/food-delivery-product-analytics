-- ============================================================
-- Turns every analysis into a VIEW (a saved query), then exports each view to CSV
-- so Power BI can load plain files (no database driver needed).
-- Run once; safe to re-run.
-- ============================================================

CREATE OR REPLACE VIEW v_funnel AS
WITH steps(step_order, event_name) AS (
    VALUES (1,'app_open'), (2,'view_restaurant'), (3,'add_to_cart'),
           (4,'checkout_start'), (5,'order_placed'), (6,'order_delivered')
),
counts AS (
    SELECT s.step_order, s.event_name, COUNT(DISTINCT e.session_id) AS sessions
    FROM steps s LEFT JOIN events e ON e.event_name = s.event_name
    GROUP BY s.step_order, s.event_name
)
SELECT step_order, event_name, sessions,
       ROUND(100.0 * sessions / FIRST_VALUE(sessions) OVER (ORDER BY step_order), 1) AS pct_of_opens,
       ROUND(100.0 * sessions / LAG(sessions) OVER (ORDER BY step_order), 1)          AS pct_of_previous_step
FROM counts;

CREATE OR REPLACE VIEW v_retention AS
WITH cohort_users AS (
    SELECT user_id, signup_date, DATE_TRUNC('week', signup_date)::date AS cohort_week
    FROM users WHERE signup_date <= DATE '2026-08-25'
),
cohort_size AS (
    SELECT cohort_week, COUNT(*) AS cohort_users FROM cohort_users GROUP BY cohort_week
),
activity AS (
    SELECT DISTINCT c.cohort_week, o.user_id,
           (o.order_time::date - c.signup_date) / 7 AS week_number
    FROM orders o JOIN cohort_users c USING (user_id)
)
SELECT a.cohort_week, a.week_number, s.cohort_users,
       COUNT(*) AS active_users,
       ROUND(100.0 * COUNT(*) / s.cohort_users, 1) AS retention_pct
FROM activity a JOIN cohort_size s USING (cohort_week)
WHERE a.week_number BETWEEN 0 AND 4
GROUP BY a.cohort_week, a.week_number, s.cohort_users;

CREATE OR REPLACE VIEW v_channel_repeat AS
WITH numbered AS (
    SELECT user_id, order_time,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY order_time) AS n
    FROM orders
),
first_two AS (
    SELECT user_id,
           MAX(order_time) FILTER (WHERE n = 1) AS first_order,
           MAX(order_time) FILTER (WHERE n = 2) AS second_order
    FROM numbered WHERE n <= 2 GROUP BY user_id
)
SELECT u.channel,
       COUNT(*) AS users,
       COUNT(f.second_order) AS repeat_users,
       ROUND(100.0 * COUNT(f.second_order) / COUNT(*), 1) AS pct_repeat,
       ROUND(AVG(EXTRACT(EPOCH FROM (f.second_order - f.first_order)) / 86400)::numeric, 1) AS avg_days_to_second_order
FROM users u LEFT JOIN first_two f USING (user_id)
GROUP BY u.channel;

CREATE OR REPLACE VIEW v_ab_primary AS
WITH cart_sessions AS (
    SELECT user_id, session_id, MIN(event_time) AS cart_time
    FROM events WHERE event_name = 'add_to_cart' GROUP BY user_id, session_id
),
ranked AS (
    SELECT user_id, session_id,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY cart_time) AS cart_number
    FROM cart_sessions
),
first_cart AS (SELECT user_id, session_id FROM ranked WHERE cart_number = 1)
SELECT a.variant,
       COUNT(*) AS users,
       COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM events e
                         WHERE e.session_id = f.session_id AND e.event_name = 'checkout_start')) AS converted,
       ROUND(100.0 * COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM events e
                         WHERE e.session_id = f.session_id AND e.event_name = 'checkout_start')) / COUNT(*), 2) AS conversion_pct
FROM first_cart f JOIN experiment_assignments a USING (user_id)
GROUP BY a.variant;

CREATE OR REPLACE VIEW v_guardrails AS
SELECT a.variant,
       COUNT(*) AS orders,
       ROUND(AVG(o.order_value), 2) AS avg_order_value,
       COUNT(*) FILTER (WHERE o.status = 'cancelled') AS cancelled,
       ROUND(100.0 * COUNT(*) FILTER (WHERE o.status = 'cancelled') / COUNT(*), 2) AS cancel_pct,
       ROUND(AVG(o.delivery_minutes), 1) AS avg_delivery_min
FROM orders o JOIN experiment_assignments a USING (user_id)
GROUP BY a.variant;

-- Export each view to a CSV inside the container (docker cp copies them out afterwards)
\copy (SELECT * FROM v_funnel ORDER BY step_order) TO '/tmp/funnel.csv' CSV HEADER
\copy (SELECT * FROM v_retention ORDER BY cohort_week, week_number) TO '/tmp/retention.csv' CSV HEADER
\copy (SELECT * FROM v_channel_repeat ORDER BY pct_repeat DESC) TO '/tmp/channel_repeat.csv' CSV HEADER
\copy (SELECT * FROM v_ab_primary ORDER BY variant) TO '/tmp/ab_primary.csv' CSV HEADER
\copy (SELECT * FROM v_guardrails ORDER BY variant) TO '/tmp/guardrails.csv' CSV HEADER
