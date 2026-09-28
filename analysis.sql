-- ================================================
-- 1. EXECUTIVE SUMMARY: CORE KPIs
-- ================================================
SELECT
COUNT(DISTINCT order_id) AS total_orders,
COUNT(DISTINCT user_id) AS total_customers,
ROUND(SUM(total_amount)::numeric, 2) AS total_revenue,
ROUND(AVG(total_amount)::numeric, 2) AS average_order_value
FROM orders; 



-- ================================================
-- 2. CONVERSION FUNNEL ANALYSIS (سلوك المستخدم)
-- ================================================


WITH funnel AS (
SELECT
COUNT(DISTINCT CASE WHEN event_type = 'view' THEN user_id END) AS view_users,
COUNT(DISTINCT CASE WHEN event_type = 'cart' THEN user_id END) AS cart_users,
COUNT(DISTINCT CASE WHEN event_type = 'wishlist' THEN user_id END) AS wishlist_users,
COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS purchase_users
FROM events
)

SELECT
view_users,
cart_users,
wishlist_users,
purchase_users,
ROUND(100.0 * cart_users / NULLIF(view_users, 0), 2) AS view_to_cart_pct,
ROUND(100.0 * purchase_users / NULLIF(cart_users, 0), 2) AS cart_to_purchase_pct,
ROUND(100.0 * purchase_users / NULLIF(view_users, 0), 2) AS overall_conversion_pct
FROM funnel;


-- ================================================
-- 3. ORDER STATUS BREAKDOWN
-- ================================================

SELECT
order_status,
COUNT(order_id) AS order_count,
ROUND(100.0 * COUNT(order_id) / (SELECT COUNT(*) FROM orders), 2) AS status_percentage
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;



-- ================================================
-- 4. ROOT CAUSE: TOP PRODUCTS WITH HIGH RETURN/CANCEL RATES
-- ================================================

SELECT
p.product_name,
COUNT(o.order_id) AS total_orders,
SUM(CASE WHEN o.order_status IN ('returned', 'cancelled') THEN 1 ELSE 0 END) AS failed_orders,
ROUND(100.0 * SUM(CASE WHEN o.order_status IN ('returned', 'cancelled') THEN 1 ELSE 0 END) / COUNT(o.order_id), 2) AS failure_rate
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_name
HAVING COUNT(o.order_id) >= 20
ORDER BY failure_rate DESC
LIMIT 10;




-- ================================================
-- 5. REVIEWS ANALYSIS FOR FAILED PRODUCTS
-- ================================================

SELECT
p.product_name,  
ROUND(AVG(r.rating)::numeric, 2) AS avg_rating,
COUNT(r.review_id) AS total_reviews
FROM products p
JOIN reviews r ON p.product_id = r.product_id
WHERE p.product_name IN ('Willow Woman', 'Pulse Race', 'Astra Hundred', 'NeoTech Society')
GROUP BY p.product_name
ORDER BY avg_rating ASC;

-- ================================================
-- 5. REVIEWS ANALYSIS FOR HIGH-FAILURE PRODUCTS
-- ================================================

WITH failed_products AS (
SELECT
p.product_id,
p.product_name,
COUNT(o.order_id) AS total_orders,
SUM(
CASE
WHEN o.order_status IN ('returned', 'cancelled')
THEN 1 ELSE 0
END
) AS failed_orders,
ROUND(
100.0 * SUM(
CASE
WHEN o.order_status IN ('returned', 'cancelled')
THEN 1 ELSE 0
END
) / COUNT(o.order_id),
2
) AS failure_rate
FROM orders o
JOIN order_items oi
ON o.order_id = oi.order_id
JOIN products p
ON oi.product_id = p.product_id
GROUP BY p.product_id, p.product_name
HAVING COUNT(o.order_id) >= 20
)
SELECT
fp.product_name,
fp.total_orders,
fp.failed_orders,
fp.failure_rate,
ROUND(AVG(r.rating)::numeric, 2) AS avg_rating,
COUNT(r.review_id) AS total_reviews
FROM failed_products fp
JOIN reviews r
ON fp.product_id = r.product_id
GROUP BY
fp.product_id,
fp.product_name,
fp.total_orders,
fp.failed_orders,
fp.failure_rate
ORDER BY fp.failure_rate DESC
LIMIT 10;




-- ================================================
-- 6. CUSTOMER VALUE SEGMENTS
-- ================================================

WITH customer_value AS (
SELECT
u.user_id,
COUNT(DISTINCT o.order_id) AS total_orders,
SUM(o.total_amount) AS total_spend,
AVG(o.total_amount) AS average_order_value
FROM users u
JOIN orders o
ON u.user_id = o.user_id
WHERE o.order_status NOT IN ('cancelled', 'returned')
GROUP BY u.user_id
HAVING COUNT(DISTINCT o.order_id) >= 2
)

SELECT
CASE
WHEN total_spend >= 1000 THEN 'High Value'
WHEN total_spend >= 500 THEN 'Medium Value'
ELSE 'Low Value'
END AS customer_segment,
COUNT(*) AS customers,
ROUND(AVG(total_spend)::numeric, 2) AS avg_customer_spend,
ROUND(AVG(total_orders)::numeric, 2) AS avg_orders
FROM customer_value
GROUP BY customer_segment
ORDER BY avg_customer_spend DESC;