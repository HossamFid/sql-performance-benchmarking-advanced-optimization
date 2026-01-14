
--Scenario 1############################################

--Full Table Scan OR Avoid select * trap 

select count(*) from orders 

--check the query plan 
EXPLAIN ANALYZE
select * from orders where user_id = 16161

--QUERY PLAN
--"Planning Time: 0.233 ms"
--"Execution Time: 0.171 ms"


--#check indexes on the table 
SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'orders'

--optimization: create index on user_id col and select only needed cols 

create index idx_orders_customer on orders(user_id)

EXPLAIN ANALYZE
select user_id, total_amount from orders 
where user_id = 16161

--New QUERY PLAN
--"Planning Time: 0.118 ms"
--"Execution Time: 0.125 ms"



--Scenario 2############################################

--Implicit Casting 

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'events'

ALTER TABLE events  
ALTER COLUMN id TYPE VARCHAR(10)

-- 'id' is VARCHAR, but we compare with INT
EXPLAIN ANALYZE
SELECT id, event_type FROM events WHERE id = 4024959


--optimization:  Match data types
SELECT id, event_type FROM events WHERE id = '4024959'

ALTER TABLE events
ALTER COLUMN id TYPE BIGINT
USING id::BIGINT

--Scenario 3############################################

--early filtering 

explain analyze 
select user_id, sum(total_amount)as total_sales 
from orders 
where order_date > CAST('2025-01-15 08:48:18' AS DATE)
group by user_id 
HAVING SUM(total_amount) > 10000

--QUERY PLAN
--"Planning Time: 0.405 ms"
--"Execution Time: 452.299 ms"

select * from orders 
limit 10 
--optimization: filter rows before aggregation step 
--1- CTE
explain analyze 
with filter_rows_first as (
	select * 
	from orders 
	where order_date > CAST('2025-01-15 08:48:18' AS DATE)
	
)select user_id, sum(total_amount)as total_sales 
from 
filter_rows_first
group by user_id 
HAVING SUM(total_amount) > 10000

--New QUERY PLAN
--"Planning Time: 0.274 ms"
--"Execution Time: 514.377 ms"

--NOTE: PostgreSQL materializes the CTE first (creates a temporary result) then doing aggregation, so i will try subquery instead 
--2- Subquery 

create index idx_orders_order_date on orders(order_date)


explain analyze
select user_id, sum(total_amount) as total_sales
from (
    select user_id, total_amount
    from orders
    where order_date > CAST('2025-01-15 08:48:18' AS DATE)
) as filtered_orders
group by user_id
having sum(total_amount) > 10000

-- NOTE: aggregation still expensive, maybe we need to index more cols like total_amount 
--Scenario 4############################################














#Slow Join 

select distinct(country) from users 

EXPLAIN ANALYZE

select u.name, o.order_date 
from orders o 
left join users u 
on o.user_id= u.id where u.country = 'UK'

"Planning Time: 4.859 ms"
"Execution Time: 454.854 ms"