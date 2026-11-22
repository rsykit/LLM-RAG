-- =====================================================================
-- KPI views (SQLite)
-- load_db.py runs this whole file after loading the CSVs.
-- These views feed both the Tableau CSV exports and the text-to-SQL LLM.
--
-- Recipe for every view:
--   1. Decide the GRAIN: what is one row? (a month, a category, a state...)
--   2. Pre-aggregate any table that has MANY rows per order (payments,
--      items, reviews) in a CTE, so joins don't duplicate rows.
--   3. Join, filter (WHERE), group by the grain, then compute the KPIs.
--   4. Test the SELECT on its own first, then wrap it in CREATE VIEW.
-- =====================================================================


-- ---------------------------------------------------------------------
-- kpi_monthly: one row per month of purchases
-- Columns: month, orders, revenue, aov, on_time_rate
-- ---------------------------------------------------------------------

-- DROP first so that editing this file and rerunning load_db.py replaces
-- the old view. (CREATE VIEW IF NOT EXISTS alone would keep the old one.)
DROP VIEW IF EXISTS kpi_monthly;

CREATE VIEW kpi_monthly AS

-- CTE ("WITH ... AS"): a temporary named result used only in this query.
-- An order can have several payment rows (e.g. voucher + credit card),
-- so we first sum payments per order -> exactly ONE row per order_id.
-- Joining order_payments directly would duplicate orders and inflate
-- COUNT(*) and AVG().
WITH pay AS (
  SELECT order_id,
         SUM(payment_value) AS value       -- total paid for this order
  FROM order_payments
  GROUP BY order_id
)

SELECT
       -- Timestamps are stored as text like '2017-03-15 10:22:01'.
       -- strftime('%Y-%m', ...) cuts that down to '2017-03' = the grain.
       strftime('%Y-%m', o.order_purchase_timestamp)            AS month,

       -- Thanks to the CTE, each row is one order, so COUNT(*) = orders.
       COUNT(*)                                                 AS orders,

       -- Total revenue in the month, rounded to cents.
       ROUND(SUM(pay.value), 2)                                 AS revenue,

       -- AOV (average order value) = revenue / orders.
       ROUND(AVG(pay.value), 2)                                 AS aov,

       -- Rate trick: a comparison returns 1 (true) or 0 (false) in SQLite,
       -- so AVG(condition) = share of rows where it's true.
       -- The dates compare correctly as text because they're in
       -- 'YYYY-MM-DD HH:MM:SS' format. Rows with a missing date give NULL,
       -- and AVG ignores NULLs.
       ROUND(AVG(o.order_delivered_customer_date
                 <= o.order_estimated_delivery_date), 3)        AS on_time_rate

-- "o" is an alias, so we can write o.column instead of orders.column.
-- USING (order_id) = ON o.order_id = pay.order_id, when both sides
-- have a column with the same name.
FROM orders o
JOIN pay USING (order_id)

-- Only completed orders: cancelled/unavailable orders aren't revenue,
-- and undelivered orders have no delivery date for on_time_rate.
WHERE o.order_status = 'delivered'

-- One output row per month. SQLite lets you use the alias "month" here.
GROUP BY month;


-- ---------------------------------------------------------------------
-- kpi_category: one row per product category
-- Columns: category, orders, revenue, avg_review_score
--
-- Tables: order_items -> products -> product_category_name_translation,
--         plus order_reviews
-- Watch out:
--   * order_items has one row per ITEM: count orders with
--     COUNT(DISTINCT order_id), and revenue = SUM(price).
--   * An order can have several reviews: average them per order in a
--     CTE first (same idea as "pay" above).
--   * Use product_category_name_english for English names. Some products
--     have no category, so consider a LEFT JOIN + COALESCE(..., 'unknown').
--
-- Uncomment and fill in when ready (an unfinished CREATE VIEW will make
-- load_db.py fail):
-- ---------------------------------------------------------------------

-- DROP VIEW IF EXISTS kpi_category;
--
-- CREATE VIEW kpi_category AS
-- WITH rev AS (
--   SELECT order_id, AVG(review_score) AS score
--   FROM order_reviews
--   GROUP BY order_id
-- )
-- SELECT ...
-- FROM order_items i
-- JOIN products p USING (product_id)
-- ...
-- GROUP BY category;
