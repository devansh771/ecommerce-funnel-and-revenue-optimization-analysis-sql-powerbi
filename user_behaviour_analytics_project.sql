CREATE DATABASE user_behaviour_analytics;
USE user_behaviour_analytics;

CREATE TABLE user_events (
    event_id INT,
    user_id INT,
    event_type VARCHAR(50),
    event_date VARCHAR(50),
    product_id INT,
    amount DECIMAL(10,2),
    traffic_source VARCHAR(50)
);

SELECT * FROM user_events
LIMIT 10;

SELECT COUNT(*) FROM user_events;

SELECT count(*) FROM user_events WHERE amount IS NULL;


# Checking column type

DESCRIBE user_events; 

# Standardize mixing values like fake blanks e.g- '' (empty string), ' ' (Space)

UPDATE user_events 
SET amount = null
WHERE TRIM(amount) = ''; #TRIM() = removes spaces from both ends

SET SQL_SAFE_UPDATES = 0;

SELECT * FROM user_events WHERE amount IS NULL;
SELECT * FROM user_events;

# Convert it to correct Data type bcz text is bad design

ALTER TABLE user_events
MODIFY amount DECIMAL(10,2);

SELECT * FROM user_events;

ALTER TABLE user_events
MODIFY event_date TIMESTAMP;

DESCRIBE user_events;


-- Define Sales funnel and the different stages

WITH funnel_stages AS (

SELECT 
	COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS stage_1_views, 
    COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart' THEN user_id END) AS stage_2_cart,
    COUNT(DISTINCT CASE WHEN event_type = 'checkout_start' THEN user_id END) AS stage_3_checkout,
    COUNT(DISTINCT CASE WHEN event_type = 'payment_info' THEN user_id END) AS stage_4_payment,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS stage_5_purchase
    
FROM user_events
WHERE event_date >= TIMESTAMP(DATE_SUB((SELECT MAX(event_date) FROM user_events), INTERVAL 30 DAY))
)

SELECT * FROM funnel_stages

-- Conversion rates through the funnel

WITH funnel_stages AS (

SELECT 
	COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS stage_1_views, 
    COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart' THEN user_id END) AS stage_2_cart,
    COUNT(DISTINCT CASE WHEN event_type = 'checkout_start' THEN user_id END) AS stage_3_checkout,
    COUNT(DISTINCT CASE WHEN event_type = 'payment_info' THEN user_id END) AS stage_4_payment,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS stage_5_purchase
    
FROM user_events
WHERE event_date >= TIMESTAMP(DATE_SUB((SELECT MAX(event_date) FROM user_events), INTERVAL 30 DAY))
)

SELECT 
	stage_1_views,
    
    stage_2_cart,
    ROUND(stage_2_cart * 100 / stage_1_views) AS view_to_cart_rate,
    
    stage_3_checkout,
    ROUND(stage_3_checkout * 100 / stage_2_cart) AS cart_to_checkout_rate,
    
    stage_4_payment,
    ROUND(stage_4_payment * 100 / stage_3_checkout) AS checkout_to_payment_rate,
    
    stage_5_purchase,
    ROUND(stage_5_purchase * 100 / stage_4_payment) AS payment_to_purchase_rate,
    
    ROUND(stage_5_purchase * 100 / stage_1_views) AS overall_conversion_rate
    
FROM funnel_stages

-- Funnel by Source

WITH source_funnel AS (
SELECT traffic_source, 
	COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS views, 
    COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart' THEN user_id END) AS cart,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS purchases
    
FROM user_events
WHERE event_date >= TIMESTAMP(DATE_SUB((SELECT MAX(event_date) FROM user_events), INTERVAL 30 DAY))
GROUP BY traffic_source
)

SELECT
	traffic_source,
	views,
	cart,
    purchases,
    ROUND(cart * 100 / views) AS cart_conversion_rate,
    ROUND(purchases * 100 / views) AS purchase_conversion_rate,
    ROUND(purchases * 100 / cart) AS cart_to_purchase_conversion_rate
FROM source_funnel
ORDER BY purchases DESC;

-- time to funnel analysis

WITH user_journey AS (
SELECT user_id, 
	MIN(CASE WHEN event_type = 'page_view' THEN event_date END) AS view_time, 
    MIN(CASE WHEN event_type = 'add_to_cart' THEN event_date END) AS cart_time,
    MIN(CASE WHEN event_type = 'purchase' THEN event_date END) AS purchase_time
FROM user_events
WHERE event_date >= TIMESTAMP(DATE_SUB((SELECT MAX(event_date) FROM user_events), INTERVAL 30 DAY))
GROUP BY user_id
HAVING MIN(CASE WHEN event_type = 'purchase' THEN event_date END) IS NOT NULL
)

SELECT 
	COUNT(*) AS converted_users,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, view_time, cart_time)), 2) AS avg_view_to_cart_minutes,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, cart_time, purchase_time)),2) AS avg_cart_to_purchase_minutes,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, view_time, purchase_time)),2) AS avg_total_journey_minutes
FROM user_journey

-- Revenue funnel analysis

WITH funnel_revenue AS (
SELECT 
	COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS total_visitors, 
    COUNT(CASE WHEN event_type = 'add_to_cart' THEN user_id END) AS total_buyers,
    SUM(CASE WHEN event_type = 'purchase' THEN amount END) AS total_revenue,
    COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) AS total_orders
FROM user_events
WHERE event_date >= TIMESTAMP(DATE_SUB((SELECT MAX(event_date) FROM user_events), INTERVAL 30 DAY))
)
SELECT 
	total_visitors,
    total_buyers,
    total_revenue,
    total_orders,
    ROUND(total_revenue/total_orders) AS avg_order_value,
    ROUND(total_revenue/total_buyers) AS revenue_per_buyer,
    ROUND(total_revenue/total_visitors) AS revenue_per_visitor
FROM funnel_revenue