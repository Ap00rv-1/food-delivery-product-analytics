-- ============================================================
-- A/B test, done properly: ONE row per USER (because users were randomised, not sessions)
-- Metric: of users who reached the cart, what % started checkout in their FIRST cart session?
-- ============================================================

-- Query 1: the primary metric (copy these 4 numbers into ab_test.py)
WITH cart_sessions AS (
    SELECT user_id, session_id, MIN(event_time) AS cart_time
    FROM events
    WHERE event_name = 'add_to_cart'
    GROUP BY user_id, session_id
),
ranked AS (
    SELECT user_id, session_id,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY cart_time) AS cart_number
    FROM cart_sessions
),
first_cart AS (
    SELECT user_id, session_id FROM ranked WHERE cart_number = 1
)
SELECT a.variant,
       COUNT(*) AS users,
       COUNT(*) FILTER (
           WHERE EXISTS (SELECT 1 FROM events e
                         WHERE e.session_id = f.session_id AND e.event_name = 'checkout_start')
       ) AS converted
FROM first_cart f
JOIN experiment_assignments a USING (user_id)
GROUP BY a.variant
ORDER BY a.variant;

-- Query 2: guardrail metrics (things the feature must NOT hurt)
SELECT a.variant,
       COUNT(*)                                                        AS orders,
       ROUND(AVG(o.order_value), 2)                                    AS avg_order_value,
       COUNT(*) FILTER (WHERE o.status = 'cancelled')                  AS cancelled,
       ROUND(100.0 * COUNT(*) FILTER (WHERE o.status = 'cancelled') / COUNT(*), 2) AS cancel_pct,
       ROUND(AVG(o.delivery_minutes), 1)                               AS avg_delivery_min
FROM orders o
JOIN experiment_assignments a USING (user_id)
GROUP BY a.variant
ORDER BY a.variant;
