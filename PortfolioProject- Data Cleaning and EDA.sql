---Cleaning Data in SQL Queries---
BEGIN TRANSACTION;

USE PortfolioProject;

SELECT * 
FROM retail_sales;

-------------------------------------------------------------------------------

--Step 1: Convert Transaction Date to DATE Format
--Populate new column by casting the original transaction date string to DATE
ALTER TABLE retail_sales
ADD transaction_date_converted DATE;

UPDATE retail_sales
SET transaction_date_converted = CAST(transaction_date AS DATE);


-------------------------------------------------------------------------------
---Step 2: Populate Missing Total Spent by calculating price_per_unit * quantity

UPDATE retail_sales
SET total_spent = price_per_unit * quantity
WHERE total_spent IS NULL
	AND price_per_unit IS NOT NULL
	AND quantity IS NOT NULL;

--Step 3: Populate Missing Price Per Unit by dividing total_spent by quantity
UPDATE retail_sales
SET price_per_unit = total_spent / quantity
WHERE price_per_unit IS NULL 
	AND total_spent IS NOT NULL 
	AND quantity IS NOT NULL
	AND quantity <>0;

--Step 4: Populate Missing Item using window function 
/*	To fill missing item names, FIRST_VALUE() window function is used
	to assign the most frequent item 
	based on each combination of category and unit price*/

WITH Referencing AS (
    SELECT *,
           FIRST_VALUE(item) OVER (
           PARTITION BY category, price_per_unit
           ORDER BY item
           ) AS refered_item
    FROM retail_sales
)
UPDATE rs
SET item = re.refered_item
FROM retail_sales rs
JOIN Referencing re
  ON rs.transaction_id = re.transaction_id
WHERE rs.item IS NULL AND re.refered_item IS NOT NULL;

-------------------------------------------------------------------------------
--Step 5: Fill Discount Applied as 'Unknown'
--Help Prevent errors and keep categories complete

SELECT COUNT(*) AS null_count
FROM retail_sales
WHERE discount_applied IS NULL;

SELECT COUNT(*) AS empty_count
FROM retail_sales
WHERE discount_applied = '';

UPDATE retail_sales
SET discount_applied = 'Unknown'
WHERE discount_applied = '';

-------------------------------------------------------------------------------
--step 6: Cleanup: drop null rows and remove original date column
--Identify rows with NULL in both 'quantity' and 'total_spent'
--Delete rows with NULL 'quantity' and 'total_spent'
--Drop the original transaction date column

SELECT * 
FROM retail_sales
WHERE quantity IS NULL AND total_spent IS NULL;

DELETE FROM retail_sales
WHERE quantity IS NULL AND total_spent IS NULL;

ALTER TABLE retail_sales
DROP COLUMN transaction_date;
-------------------------------------------------------------------------------
--Step 7: check for duplicates based on key columns
--Assign row numbers partitioned by identifying columns and order by transaction ID
WITH RowNumCTE AS(
	SELECT *,
	ROW_NUMBER() OVER (
	PARTITION BY customer_id,
				 category,
				 item,
				 total_spent,
				 payment_method,
				 location,
				 transaction_date_converted
				 ORDER BY transaction_id) AS row_num
	FROM retail_sales
)
DELETE FROM RowNumCTE
WHERE row_num >1;

COMMIT TRANSACTION;

-------------------------------------------------------------------------------
--Exploratory Data Analysis (EDA)	

--1. Total revenue and average spend per customer

WITH customer_total AS (
	SELECT customer_id, sum(total_spent) AS sum_total_spent
	FROM retail_sales
	GROUP BY customer_id
)
SELECT 
	COUNT(DISTINCT rs.customer_id) AS customers,
	SUM(rs.total_spent) AS total_revenus,
	AVG(rs.total_spent) AS average_transaction_value,
	AVG(ct.sum_total_spent) AS average_spend_per_customer
FROM retail_sales rs
JOIN customer_total ct
ON rs.customer_id = ct.customer_id;



--2. Sales Trends monthly and yearly
--Monthly
SELECT 
	FORMAT(transaction_date_converted,'yyyy-MM') AS month,
	SUM(total_spent) AS monthly_revenue,
	count(*) AS Transactions
FROM retail_sales
GROUP BY FORMAT(transaction_date_converted,'yyyy-MM')
ORDER BY month;

--Yearly
SELECT 
	YEAR(transaction_date_converted) AS YEAR,
	SUM(total_spent) AS yearly_revenue,
	count(*) AS Transactions
FROM retail_sales
GROUP BY YEAR(transaction_date_converted)
ORDER BY YEAR;


--3. Most Popular Product Categories and Items
SELECT 
    category,
    SUM(total_spent) AS Revenue,
    COUNT(*) AS Transactions
FROM retail_sales
GROUP BY Category
ORDER BY Revenue DESC;


SELECT TOP 10
	item,
	sum(quantity) AS total_quantity_sold,
	sum(total_spent) AS revenue
FROM retail_sales
GROUP BY item
ORDER BY total_quantity_sold DESC;

--4. Top Payment Methods
SELECT 
	DISTINCT payment_method,
	COUNT(*) AS transaction_count
FROM retail_sales
GROUP BY payment_method
ORDER BY transaction_count DESC;


--5. Check number of one-Time and repeat customers
WITH customer_check AS (
	SELECT customer_id, COUNT(*) AS purchase_count
	FROM retail_sales
	GROUP BY customer_id
)
SELECT
	CASE
		WHEN purchase_count = 1 THEN 'One-time'
		ELSE 'Repeat'
	End AS customer_type,
	COUNT(*) AS customer_count
FROM customer_check
GROUP BY
	CASE
		WHEN purchase_count = 1 THEN 'One-time'
		ELSE 'Repeat'
	END;

--6. Top Customers by total spend

SELECT TOP 10
	customer_id,
	COUNT(*) AS Transactions,
	SUM(total_spent) AS total_spent_per_customer
FROM retail_sales
GROUP BY customer_id
ORDER BY total_spent_per_customer DESC;

--7. Top Location by Revenue
SELECT 
	location, 
	SUM(total_spent) AS total_revenue
FROM retail_sales
GROUP BY location
ORDER BY total_revenue DESC;

--8. Discount impact on Purchase Quantity
SELECT
	discount_applied,
	ROUND((AVG(quantity)),2) AS avg_qty
FROM retail_sales
GROUP BY discount_applied;

--Create view for clean data
CREATE VIEW cleaned_retail_sales AS
SELECT
	transaction_id, 
	customer_id, 
	category, 
	item,
	transaction_date_converted,
	FORMAT(transaction_date_converted, 'yyyy-MM') AS month,
	YEAR(transaction_date_converted) AS year,
	price_per_unit, 
	quantity, 
	total_spent,
	payment_method, 
	location, 
	discount_applied
FROM retail_sales
WHERE 
	price_per_unit > 0 
	AND quantity > 0 
	AND total_spent IS NOT NULL
	AND item IS NOT NULL;


--Create view for monthly sales summary
CREATE VIEW monthly_sales_summary AS
SELECT
	FORMAT(transaction_date_converted,'yyyy-MM') AS month,
	SUM(total_spent) AS monthly_revenue,
	COUNT(*) AS transaction_count
FROM retail_sales
GROUP BY FORMAT(transaction_date_converted,'yyyy-MM');	