CREATE VIEW IF NOT EXISTS kpi_monthly AS
WITH pay AS (
  SELECT order_id, SUM(payment_value) AS value FROM order_payments GROUP BY order_id
)
SELECT strftime('%Y-%m', o.order_purchase_timestamp)            AS month,
       COUNT(*)                                                 AS orders,
       ROUND(SUM(pay.value), 2)                                 AS revenue,
       ROUND(AVG(pay.value), 2)                                 AS aov,
       ROUND(AVG(o.order_delivered_customer_date
                 <= o.order_estimated_delivery_date), 3)        AS on_time_rate
FROM orders o JOIN pay USING (order_id)
WHERE o.order_status = 'delivered'
GROUP BY month;
