CREATE DATABASE amazon_sales_db;
USE amazon_sales_db;

CREATE TABLE amazon_sales (
    order_id VARCHAR(255),
    product_name VARCHAR(255),
    category VARCHAR(100),
    sub_category VARCHAR(100),
    order_date DATE,
    ship_date DATE,
    customer_id VARCHAR(255),
    customer_name VARCHAR(255),
    region VARCHAR(100),
    country VARCHAR(100),
    sales FLOAT,
    quantity INT,
    discount FLOAT,
    profit FLOAT,
    shipping_cost FLOAT,
    payment_method VARCHAR(100),
    review_score INT
);
DROP TABLE amazon_sales;

select* from amazon_sales;

-- Standardize Country Names
UPDATE amazon_sales 
SET country = 'United States' 
WHERE country IN ('USA', 'U.S.', 'US');

-- Exploratory Data Analysis (EDA) --

-- ** Sales Performance Analysis **
-- Total Sales and Profit Summary
SELECT 
	CONCAT('$', ROUND(SUM(sales) / 1000), 'K') AS total_revenue,
	CONCAT(IF(SUM(profit) < 0, '$', '$'), ROUND(ABS(SUM(profit)) / 1000), 'K') AS total_profit,
	CONCAT(ROUND(100 * SUM(profit) / SUM(sales), 2), '%') AS profit_margin
FROM amazon_sales;
-- Provides a high level summary of revenue, profit and margin.

-- Monthly Revenue Breakdown
SELECT 
DATE_FORMAT(order_date, '%Y-%m') AS month, 
	CONCAT('$', ROUND(SUM(sales) / 1000, 2), 'K') AS total_revenue
FROM amazon_sales
GROUP BY month
ORDER BY month ASC;
-- Shows revenue trends over time

-- Top 5 Best-Selling Categories
SELECT 
category, 
CONCAT('$',ROUND(SUM(sales) / IF(SUM(sales) >= 1000000, 1000000, 1000), 2), 
IF(SUM(sales) >= 1000000, 'M', 'K')) AS total_sales
FROM amazon_sales
GROUP BY category
ORDER BY SUM(sales) DESC
LIMIT 5;
-- Identifies the most profitable categories.

-- Most Sold Product in Each Category
SELECT category, product_ID, total_units_sold
FROM (
    SELECT category, product_ID, SUM(quantity) AS total_units_sold,
           RANK() OVER (PARTITION BY category ORDER BY SUM(quantity) DESC) AS rnk
    FROM amazon_sales
    GROUP BY category, product_ID
) ranked
WHERE rnk = 1;
-- Finds the highest-selling product per category.


-- ** Customer Behavior Analysis **
-- Top 10 Customers by Total Spending
SELECT 
    customer_name, 
    CONCAT('$',ROUND(SUM(sales) / 
           IF(SUM(sales) >= 1000000, 1000000, 
              IF(SUM(sales) >= 1000, 1000, 1))), 
           IF(SUM(sales) >= 1000000, 'M', 
              IF(SUM(sales) >= 1000, 'K', ''))) AS total_spent,
    COUNT(order_id) AS total_orders
FROM amazon_sales
GROUP BY customer_name
ORDER BY SUM(sales) DESC
LIMIT 10;
-- Identifies most valuable customers.

-- Finds Customers with More Than 2 Orders
SELECT customer_name, COUNT(order_id) AS total_orders
FROM amazon_sales
GROUP BY customer_name
HAVING total_orders > 2
ORDER BY total_orders DESC;
-- Finds customers who purchase frequently

-- Customers Who Prefer High-Discount Purchases
SELECT customer_name, 
       CONCAT(ROUND(AVG(discount) * 100), '%') AS avg_discount
FROM amazon_sales
GROUP BY customer_name
ORDER BY AVG(discount) DESC
LIMIT 10;
-- Finds discount sensitive customers

-- ** Profitability & Discount Impact **
-- Average Profit Per Category
SELECT category, CONCAT('$',ROUND(AVG(profit), 2)) AS avg_profit
FROM amazon_sales
GROUP BY category
ORDER BY avg_profit DESC;
-- Identifies which categories generate the most profit.

-- Impact of Discounts on Profitability
SELECT discount, CONCAT('$',ROUND(AVG(profit),2)) AS avg_profit, COUNT(order_id) AS num_orders
FROM amazon_sales
GROUP BY discount
ORDER BY discount ASC;
-- Shows how discounts affect profitability.

-- Orders with High Discounts but Low Profit
SELECT * FROM amazon_sales 
WHERE discount > 0.20 AND profit < 5
ORDER BY discount DESC;
-- Finds transactions where discounts led to low profitability.

-- Inventory & Order Management
-- Low-Selling Products
SELECT product_ID, SUM(quantity) AS total_units_sold
FROM amazon_sales
GROUP BY product_ID
HAVING total_units_sold < 10
ORDER BY total_units_sold ASC;
-- Finds slow-moving products.

-- Fastest & Slowest Shipping Products
SELECT product_ID, 
       ROUND(AVG(DATEDIFF(ship_date, order_date))) AS avg_shipping_days
FROM amazon_sales
GROUP BY product_ID
ORDER BY avg_shipping_days ASC;
-- Analyzes shipping performance by product.

-- Peak Sales Days of the Week
SELECT DAYNAME(order_date) AS weekday, COUNT(order_id) AS total_orders
FROM amazon_sales
GROUP BY weekday
ORDER BY total_orders DESC;
-- Identifies the best days for sales

-- ** Customer Feedback & Payment Analysis **
-- Most Common Review Score
SELECT review_score, COUNT(*) AS num_reviews
FROM amazon_sales
GROUP BY review_score
ORDER BY num_reviews DESC;
-- Analyzes customer satisfaction trends.

-- Most Preferred Payment Method
SELECT payment_method, COUNT(*) AS total_transactions
FROM amazon_sales
GROUP BY payment_method
ORDER BY total_transactions DESC;
-- Finds the most used payment method.

-- ** Trend Analysis & Forecasting **
-- Year-over-Year Sales Growth
SELECT 
    YEAR(order_date) AS sales_year, 
    CONCAT('$', FORMAT(SUM(sales) / 1000000, 1), 'M') AS total_sales, 
    CONCAT('$', FORMAT(COALESCE(LAG(SUM(sales)) OVER (ORDER BY YEAR(order_date)), 0) / 1000000, 1), 'M') AS previous_year_sales, 
    CONCAT(ROUND(((SUM(sales) - LAG(SUM(sales)) OVER (ORDER BY YEAR(order_date))) 
                 / NULLIF(LAG(SUM(sales)) OVER (ORDER BY YEAR(order_date)), 0)) * 100, 2), '%') AS growth_rate 
FROM amazon_sales 
GROUP BY sales_year 
ORDER BY sales_year;
-- Shows annual growth trends.

-- Top 3 Best-Selling Products Each Month
WITH MonthlyProductSales AS (
    SELECT DATE_FORMAT(order_date, '%Y-%m') AS month, product_ID, 
           SUM(sales) AS total_sales,
           RANK() OVER (PARTITION BY DATE_FORMAT(order_date, '%Y-%m') ORDER BY SUM(sales) DESC) rnk
    FROM amazon_sales
    GROUP BY 1, 2
)
SELECT month, product_ID, 
CONCAT('$', FORMAT(total_sales, 2)) AS total_sales
FROM MonthlyProductSales
WHERE rnk <= 3
ORDER BY 1, rnk;
-- Finds the most popular products each month.

-- Most Profitable Day of the Week
SELECT DAYNAME(order_date) AS weekday, 
       CONCAT('$', FORMAT(SUM(profit) / 1000, 2), 'K') AS total_profit
FROM amazon_sales
GROUP BY 1
ORDER BY SUM(profit) DESC;
-- Finds the most profitable day for sales.

-- ** Predict Next Month’s Sales Using Moving Averages **
WITH MonthlySales AS (
    SELECT DATE_FORMAT(order_date, '%Y-%m') AS month, SUM(sales) AS total_sales
    FROM amazon_sales
    GROUP BY 1
)
SELECT month, 
       CONCAT('$', FORMAT(total_sales / 1000, 1), 'K') AS total_sales, 
       CONCAT('$', FORMAT(AVG(total_sales) 
              OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) / 1000, 1), 'K') 
              AS moving_avg_3months
FROM MonthlySales;
-- Uses a moving average to estimate future sales.

-- Detect Unusual Sales Spikes
SELECT order_date, 
       CONCAT('$', FORMAT(SUM(sales) / 1000, 1), 'K') AS total_sales
FROM amazon_sales
GROUP BY 1
ORDER BY SUM(sales) DESC
LIMIT 5;
-- Finds unexpected sales surges.