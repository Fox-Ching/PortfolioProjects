# PortfolioProjects

This project walks through the full process of cleaning messy retail transaction data using SQL, followed by some basic exploratory data analysis (EDA). The data is stored in a SQL Server database under the PortfolioProject database.

All cleaning is wrapped in a single transaction so it's safe to run without leaving partial changes.

Key cleaning steps:
1.  Converted transaction dates to proper DATE format.
2.  Filled missing total_spent by calculating price_per_unit * quantity.
3.  Populated missing price_per_unit by dividing total_spent / quantity.
4.  Imputed missing item names using a window function (based on category & price).
5.  Handled null/empty discount_applied values by labeling them as 'Unknown'.
6.  Dropped meaningless rows where both quantity and total_spent were NULL.
7.  Removed duplicate rows using ROW_NUMBER() and DELETE.
8.  Dropped the old transaction_date column once replaced.


The project also includes several analysis queries:
1.  Total revenue, average spend per customer
2.  Monthly & yearly sales trends
3.  Top products, categories, payment methods, and locations
4.  One-time vs repeat customers
5.  Revenue impact of discounts
