-- Table contained SKU priced (unique), 2 null SKU values
SELECT COUNT(DISTINCT SKU), COUNT(*)
FROm cust.cost_toy_data

-- Order details, one sku can have mulltiple order
SELECT sku, count(*)
FROM cust."orders-line-items_toy_data"
group by sku;

-- Why one order_hash_id have multiple rows?
SELECT _airbyte_orders_hashid, COUNT(*)
FROM cust."orders-line-items_toy_data"
GROUP BY _airbyte_orders_hashid

-- Why one order_hash_id have multiple rows? -> one hashid represent for an order, this table have one rows is one item a order
SELECT sku, count(*)
FROM cust."orders-line-items_toy_data"
WHERE _airbyte_orders_hashid = '415d8195153a3bd6bbde9fec5413ff5c'
--AND sku = 'RH10175'
GROUP BY sku

SELECT *
FROM cust."orders-line-items_toy_data"

--
-- Total orders are 283
SELECT COUNT(DISTINCT _airbyte_orders_hashid)
FROM cust."orders-line-items_toy_data"

-- ? This order likely cancelled orders
SELECT *
FROm cust.orders_toy_data
WHERE 1=1
AND _airbyte_orders_hashid = '415d8195153a3bd6bbde9fec5413ff5c'


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

;
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

