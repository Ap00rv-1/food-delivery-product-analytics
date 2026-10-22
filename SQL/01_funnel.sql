-- Query 1: overall session funnel
-- Window functions used here: FIRST_VALUE and LAG (your first two!)
WITH steps(step_order, event_name) AS (
    VALUES (1,'app_open'), (2,'view_restaurant'), (3,'add_to_cart'),
           (4,'checkout_start'), (5,'order_placed'), (6,'order_delivered')
),
counts AS (
    SELECT s.step_order, s.event_name, COUNT(DISTINCT e.session_id) AS sessions
    FROM steps s
    LEFT JOIN events e ON e.event_name = s.event_name
    GROUP BY s.step_order, s.event_name
)
SELECT step_order, event_name, sessions,
       ROUND(100.0 * sessions / FIRST_VALUE(sessions) OVER (ORDER BY step_order), 1) AS pct_of_opens,
       ROUND(100.0 * sessions / LAG(sessions) OVER (ORDER BY step_order), 1)          AS pct_of_previous_step
FROM counts
ORDER BY step_order;

-- Query 2: cart -> checkout conversion by experiment variant (session level, quick look only)
SELECT a.variant,
       COUNT(DISTINCT e.session_id) FILTER (WHERE e.event_name = 'add_to_cart')     AS cart_sessions,
       COUNT(DISTINCT e.session_id) FILTER (WHERE e.event_name = 'checkout_start')  AS checkout_sessions,
       ROUND(100.0 * COUNT(DISTINCT e.session_id) FILTER (WHERE e.event_name = 'checkout_start')
             / NULLIF(COUNT(DISTINCT e.session_id) FILTER (WHERE e.event_name = 'add_to_cart'), 0), 2) AS cart_to_checkout_pct
FROM events e
JOIN experiment_assignments a USING (user_id)
GROUP BY a.variant;
