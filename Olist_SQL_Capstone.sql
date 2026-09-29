/*
=========================================================
OLIST SQL CAPSTONE PROJECT
Business Analysis using Microsoft SQL Server
=========================================================
*/

/* =========================================================
01. DATA VALIDATION
========================================================= */

-- Row-count validation
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM dbo.customers
UNION ALL SELECT 'orders', COUNT(*) FROM dbo.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM dbo.order_items
UNION ALL SELECT 'payments', COUNT(*) FROM dbo.payments
UNION ALL SELECT 'reviews', COUNT(*) FROM dbo.reviews
UNION ALL SELECT 'products', COUNT(*) FROM dbo.products
UNION ALL SELECT 'sellers', COUNT(*) FROM dbo.sellers
UNION ALL SELECT 'category_translation', COUNT(*) FROM dbo.category_translation
UNION ALL SELECT 'geolocation', COUNT(*) FROM dbo.geolocation;

-- Relationship validation
SELECT COUNT(*) AS unmatched_orders
FROM dbo.orders o LEFT JOIN dbo.customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

SELECT COUNT(*) AS unmatched_order_items
FROM dbo.order_items oi LEFT JOIN dbo.orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

SELECT COUNT(*) AS unmatched_products
FROM dbo.order_items oi LEFT JOIN dbo.products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

SELECT COUNT(*) AS unmatched_sellers
FROM dbo.order_items oi LEFT JOIN dbo.sellers s ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

-- Key validation
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT order_id) AS unique_order_ids
FROM dbo.orders;

SELECT COUNT(*) AS total_rows, COUNT(DISTINCT product_id) AS unique_product_ids
FROM dbo.products;

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT CONCAT(order_id, '-', order_item_id)) AS unique_item_keys
FROM dbo.order_items;

-- review_id alone is not unique; review_id + order_id is the composite key.
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT CONCAT(review_id, '-', order_id)) AS unique_review_keys
FROM dbo.reviews;


/* =========================================================
02. SALES ANALYSIS
========================================================= */

-- Total product sales
SELECT SUM(price) AS total_product_sales
FROM dbo.order_items;

-- Monthly sales trend
SELECT YEAR(o.order_purchase_timestamp) AS order_year,
       MONTH(o.order_purchase_timestamp) AS order_month,
       SUM(oi.price) AS total_sales
FROM dbo.orders o
JOIN dbo.order_items oi ON o.order_id = oi.order_id
GROUP BY YEAR(o.order_purchase_timestamp), MONTH(o.order_purchase_timestamp)
ORDER BY order_year, order_month;

-- Monthly orders vs sales
SELECT YEAR(o.order_purchase_timestamp) AS order_year,
       MONTH(o.order_purchase_timestamp) AS order_month,
       COUNT(DISTINCT o.order_id) AS total_orders,
       SUM(oi.price) AS total_sales
FROM dbo.orders o
JOIN dbo.order_items oi ON o.order_id = oi.order_id
GROUP BY YEAR(o.order_purchase_timestamp), MONTH(o.order_purchase_timestamp)
ORDER BY order_year, order_month;

-- Average Order Value (product value per order; freight excluded)
SELECT AVG(order_total) AS average_order_value
FROM (
    SELECT order_id, SUM(price) AS order_total
    FROM dbo.order_items
    GROUP BY order_id
) order_summary;

-- Sales by product category
SELECT c.product_category_name_english AS category,
       SUM(oi.price) AS total_sales
FROM dbo.order_items oi
JOIN dbo.products p ON oi.product_id = p.product_id
LEFT JOIN dbo.category_translation c
    ON p.product_category_name = c.product_category_name
GROUP BY c.product_category_name_english
ORDER BY total_sales DESC;


/* =========================================================
03. CUSTOMER ANALYSIS
========================================================= */

-- Unique customers with orders
SELECT COUNT(DISTINCT c.customer_unique_id) AS unique_customers
FROM dbo.customers c
JOIN dbo.orders o ON c.customer_id = o.customer_id;

-- Repeat customer rate
WITH customer_orders AS (
    SELECT c.customer_unique_id,
           COUNT(DISTINCT o.order_id) AS order_count
    FROM dbo.customers c
    JOIN dbo.orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT COUNT(*) AS total_customers,
       SUM(CASE WHEN order_count = 1 THEN 1 ELSE 0 END) AS one_time_customers,
       SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_customers,
       CAST(100.0 * SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END)
            / COUNT(*) AS DECIMAL(10,2)) AS repeat_customer_rate
FROM customer_orders;

-- Spending by customer type
WITH customer_summary AS (
    SELECT c.customer_unique_id,
           COUNT(DISTINCT o.order_id) AS order_count,
           SUM(oi.price) AS total_spent
    FROM dbo.customers c
    JOIN dbo.orders o ON c.customer_id = o.customer_id
    JOIN dbo.order_items oi ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
)
SELECT CASE WHEN order_count = 1 THEN 'One-Time' ELSE 'Repeat' END AS customer_type,
       COUNT(*) AS customer_count,
       SUM(total_spent) AS total_sales,
       AVG(total_spent) AS average_customer_spending
FROM customer_summary
GROUP BY CASE WHEN order_count = 1 THEN 'One-Time' ELSE 'Repeat' END;

-- Customer purchase frequency
WITH customer_orders AS (
    SELECT c.customer_unique_id,
           COUNT(DISTINCT o.order_id) AS order_count
    FROM dbo.customers c
    JOIN dbo.orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT order_count, COUNT(*) AS customer_count
FROM customer_orders
GROUP BY order_count
ORDER BY order_count;


/* =========================================================
04. DELIVERY ANALYSIS
========================================================= */

-- Average delivery time
SELECT AVG(CAST(DATEDIFF(DAY, order_purchase_timestamp,
                         order_delivered_customer_date) AS DECIMAL(10,2)))
       AS average_delivery_days
FROM dbo.orders
WHERE order_delivered_customer_date IS NOT NULL;

-- Late delivery rate
SELECT SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date
                THEN 1 ELSE 0 END) AS late_orders,
       SUM(CASE WHEN order_delivered_customer_date <= order_estimated_delivery_date
                THEN 1 ELSE 0 END) AS on_time_or_early_orders,
       COUNT(*) AS total_delivered_orders,
       CAST(100.0 * SUM(CASE WHEN order_delivered_customer_date >
                                  order_estimated_delivery_date
                             THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(10,2))
       AS late_delivery_rate
FROM dbo.orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;

-- Late delivery by customer state
SELECT c.customer_state AS state,
       COUNT(DISTINCT o.order_id) AS delivered_orders,
       SUM(CASE WHEN o.order_delivered_customer_date >
                     o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS late_orders,
       CAST(100.0 * SUM(CASE WHEN o.order_delivered_customer_date >
                                  o.order_estimated_delivery_date THEN 1 ELSE 0 END)
            / COUNT(DISTINCT o.order_id) AS DECIMAL(10,2)) AS late_delivery_rate
FROM dbo.orders o
JOIN dbo.customers c ON o.customer_id = c.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY late_delivery_rate DESC;

-- Delivery vs customer satisfaction
WITH order_reviews AS (
    SELECT order_id,
           AVG(CAST(review_score AS DECIMAL(10,2))) AS avg_review_score
    FROM dbo.reviews
    WHERE review_score IS NOT NULL
    GROUP BY order_id
)
SELECT CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 'Late' ELSE 'On Time/Early' END AS delivery_status,
       COUNT(*) AS reviewed_orders,
       AVG(r.avg_review_score) AS average_review_score
FROM dbo.orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
             THEN 'Late' ELSE 'On Time/Early' END;


/* =========================================================
05. SELLER ANALYSIS
========================================================= */

-- Top sellers by product sales
SELECT s.seller_id,
       COUNT(DISTINCT oi.order_id) AS total_orders,
       SUM(oi.price) AS total_sales
FROM dbo.order_items oi
JOIN dbo.sellers s ON oi.seller_id = s.seller_id
GROUP BY s.seller_id
ORDER BY total_sales DESC;

-- Seller sales per order
SELECT s.seller_id,
       COUNT(DISTINCT oi.order_id) AS total_orders,
       SUM(oi.price) AS total_sales,
       SUM(oi.price) / COUNT(DISTINCT oi.order_id) AS sales_per_order
FROM dbo.order_items oi
JOIN dbo.sellers s ON oi.seller_id = s.seller_id
GROUP BY s.seller_id
ORDER BY sales_per_order DESC;

-- Seller late-delivery performance; minimum 50 delivered orders
SELECT s.seller_id,
       COUNT(DISTINCT o.order_id) AS delivered_orders,
       SUM(CASE WHEN o.order_delivered_customer_date >
                     o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS late_orders,
       CAST(100.0 * SUM(CASE WHEN o.order_delivered_customer_date >
                                  o.order_estimated_delivery_date THEN 1 ELSE 0 END)
            / COUNT(DISTINCT o.order_id) AS DECIMAL(10,2)) AS late_delivery_rate
FROM dbo.order_items oi
JOIN dbo.orders o ON oi.order_id = o.order_id
JOIN dbo.sellers s ON oi.seller_id = s.seller_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY s.seller_id
HAVING COUNT(DISTINCT o.order_id) >= 50
ORDER BY late_delivery_rate DESC;


/* =========================================================
06. PAYMENT ANALYSIS
========================================================= */

-- Payment method usage; counts payment records, not distinct orders
SELECT payment_type,
       COUNT(*) AS payment_count,
       SUM(payment_value) AS total_payment_value
FROM dbo.payments
GROUP BY payment_type
ORDER BY payment_count DESC;

-- Average payment value by method
SELECT payment_type,
       COUNT(*) AS payment_count,
       SUM(payment_value) AS total_payment_value,
       AVG(payment_value) AS average_payment_value
FROM dbo.payments
GROUP BY payment_type
ORDER BY average_payment_value DESC;

-- Installment behavior by payment method
SELECT payment_type,
       AVG(CAST(payment_installments AS DECIMAL(10,2))) AS average_installments,
       AVG(payment_value) AS average_payment_value
FROM dbo.payments
GROUP BY payment_type
ORDER BY average_installments DESC;


/* =========================================================
07. PRODUCT ANALYSIS
========================================================= */

-- Top categories by units sold
SELECT c.product_category_name_english AS category,
       COUNT(*) AS units_sold
FROM dbo.order_items oi
JOIN dbo.products p ON oi.product_id = p.product_id
LEFT JOIN dbo.category_translation c
    ON p.product_category_name = c.product_category_name
GROUP BY c.product_category_name_english
ORDER BY units_sold DESC;

-- Category sales and average price
SELECT c.product_category_name_english AS category,
       COUNT(*) AS units_sold,
       SUM(oi.price) AS total_sales,
       AVG(oi.price) AS average_item_price
FROM dbo.order_items oi
JOIN dbo.products p ON oi.product_id = p.product_id
LEFT JOIN dbo.category_translation c
    ON p.product_category_name = c.product_category_name
GROUP BY c.product_category_name_english
ORDER BY total_sales DESC;

-- Product weight vs freight cost
SELECT CASE
           WHEN p.product_weight_g < 1000 THEN 'Under 1 kg'
           WHEN p.product_weight_g < 3000 THEN '1–3 kg'
           WHEN p.product_weight_g < 5000 THEN '3–5 kg'
           WHEN p.product_weight_g < 10000 THEN '5–10 kg'
           ELSE '10+ kg'
       END AS weight_category,
       COUNT(*) AS units_sold,
       AVG(oi.freight_value) AS average_freight
FROM dbo.order_items oi
JOIN dbo.products p ON oi.product_id = p.product_id
WHERE p.product_weight_g IS NOT NULL
GROUP BY CASE
             WHEN p.product_weight_g < 1000 THEN 'Under 1 kg'
             WHEN p.product_weight_g < 3000 THEN '1–3 kg'
             WHEN p.product_weight_g < 5000 THEN '3–5 kg'
             WHEN p.product_weight_g < 10000 THEN '5–10 kg'
             ELSE '10+ kg'
         END
ORDER BY MIN(p.product_weight_g);

-- Top individual products by sales
SELECT TOP 10
       p.product_id,
       p.product_category_name AS category,
       COUNT(*) AS units_sold,
       SUM(oi.price) AS total_sales
FROM dbo.order_items oi
JOIN dbo.products p ON oi.product_id = p.product_id
GROUP BY p.product_id, p.product_category_name
ORDER BY total_sales DESC;


/* =========================================================
08. EXECUTIVE KPI SUMMARY
========================================================= */

WITH order_summary AS (
    SELECT order_id, SUM(price) AS order_total
    FROM dbo.order_items
    GROUP BY order_id
),
customer_summary AS (
    SELECT COUNT(DISTINCT c.customer_unique_id) AS unique_customers
    FROM dbo.customers c
    JOIN dbo.orders o ON c.customer_id = o.customer_id
),
delivery_summary AS (
    SELECT
        AVG(CAST(DATEDIFF(DAY, order_purchase_timestamp,
                          order_delivered_customer_date) AS DECIMAL(10,2)))
            AS average_delivery_days,
        CAST(100.0 * SUM(CASE WHEN order_delivered_customer_date >
                                   order_estimated_delivery_date
                              THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(10,2))
            AS late_delivery_rate
    FROM dbo.orders
    WHERE order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
),
review_summary AS (
    SELECT AVG(CAST(review_score AS DECIMAL(10,2))) AS average_review_score
    FROM dbo.reviews
    WHERE review_score IS NOT NULL
)
SELECT
    (SELECT COUNT(*) FROM dbo.orders) AS total_orders,
    cs.unique_customers,
    (SELECT SUM(price) FROM dbo.order_items) AS total_product_sales,
    AVG(os.order_total) AS average_order_value,
    ds.average_delivery_days,
    ds.late_delivery_rate,
    rs.average_review_score
FROM order_summary os
CROSS JOIN customer_summary cs
CROSS JOIN delivery_summary ds
CROSS JOIN review_summary rs
GROUP BY cs.unique_customers,
         ds.average_delivery_days,
         ds.late_delivery_rate,
         rs.average_review_score;
