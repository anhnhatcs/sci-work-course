
-- Find the orders that have items details but total_price and total_price_without_tax is 0
WITH t_orders_zero_price AS (
SELECT *,
	   CASE WHEN t.total_price = 0 OR t.total_price_without_tax = 0 THEN 'Cancelled' ELSE 'Completed' END AS Order_status
FROm cust.orders_toy_data t
WHERE 1=1 
)
, t_aggr_data AS (
SELECT li.*, 
	  tz.*,
	  ctd.*,
	  SUM(li.orders_line_items_price* li.orders_line_items_quantity) OVER(PARTITION BY li._airbyte_orders_hashid) AS revenue_by_order_details,
	  total_price AS revenue_by_order_summary,
	  SUM(ctd.netto_cost* li.orders_line_items_quantity) OVER(PARTITION BY li._airbyte_orders_hashid) AS total_netto_cost

FROM cust."orders-line-items_toy_data" li
LEFT JOIN t_orders_zero_price tz
ON tz._airbyte_orders_hashid = li._airbyte_orders_hashid
LEFT JOIN cust.cost_toy_data ctd
ON li.sku = ctd.sku

WHERE 1=1 
--AND li._airbyte_orders_hashid = 'd91c03b7d92daf46d3e55b20e032b81b'

)
, t_finaL_data AS (
SELECT t.revenue_by_order_details,
	   t.revenue_by_order_summary, 
	   t.total_netto_cost, 
	   CASE WHEN t.order_status = 'Completed' THEN t.revenue_by_order_details - total_netto_cost ELSE 0 END AS margin_by_order_details,
	   CASE WHEN t.order_status = 'Completed' THEN t.revenue_by_order_summary - total_netto_cost ELSE 0 END AS margin_by_order_summary,

	   t.*
FROM t_aggr_data t
WHERE 1=1
--AND orders_line_items_price = total_price
)
--
SELECT created_at
	  ,SUM(ROUND(margin_by_order_details::numeric,1)) total_margin_by_order_details
	  ,SUM(ROUND(margin_by_order_summary::numeric,1)) total_margin_by_order_summary
FROM t_final_data
GROUP BY created_at
ORDER BY created_at DESC