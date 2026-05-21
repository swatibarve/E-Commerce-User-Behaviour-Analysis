

CREATE TABLE customers (
    customer_key   INTEGER PRIMARY KEY,
    gender         VARCHAR(10),
    name           VARCHAR(100),
    city           VARCHAR(100),
    state_code     VARCHAR(10),
    state          VARCHAR(100),
    zip_code       VARCHAR(20),
    country        VARCHAR(50),
    continent      VARCHAR(50),
    birthday       VARCHAR(20)  
);

CREATE TABLE products (
    product_key    INTEGER PRIMARY KEY,
    product_name   VARCHAR(200),
    brand          VARCHAR(100),
    color          VARCHAR(50),
    unit_cost_usd  VARCHAR(20),   
    unit_price_usd VARCHAR(20),  
    subcategory_key INTEGER,
    subcategory    VARCHAR(100),
    category_key   INTEGER,
    category       VARCHAR(100)
);

CREATE TABLE stores (
    store_key      INTEGER PRIMARY KEY,  -- 0 = Online store
    country        VARCHAR(50),
    state          VARCHAR(100),
    square_meters  INTEGER,
    open_date      VARCHAR(20)
);

CREATE TABLE exchange_rates (
    rate_date      VARCHAR(20),
    currency       VARCHAR(10),
    exchange       NUMERIC(10,4), -- units of currency per 1 USD
    PRIMARY KEY (rate_date, currency)
);

CREATE TABLE sales (
    order_number   INTEGER,
    line_item      INTEGER,
    order_date     VARCHAR(20),
    delivery_date  VARCHAR(20),
    customer_key   INTEGER  REFERENCES customers(customer_key),
    store_key      INTEGER  REFERENCES stores(store_key),
    product_key    INTEGER  REFERENCES products(product_key),
    quantity       INTEGER,
    currency_code  VARCHAR(10),
    PRIMARY KEY (order_number, line_item)
);


-- SECTION 1 : REVENUE & SALES PERFORMANCE


-- Q1: Which countries generate the most revenue for the business?
-- ---------------------------------------------------------------
SELECT
    st.country,
    COUNT(DISTINCT s.order_number) AS total_orders,
    SUM(s.quantity) AS units_sold,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2) AS revenue_usd,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_cost_usd,'$',''))  AS NUMERIC)), 2)       AS cost_usd,
    ROUND(SUM(s.quantity
        * (CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)
         - CAST(TRIM(REPLACE(p.unit_cost_usd,'$',''))  AS NUMERIC))), 2)     AS gross_profit_usd
FROM sales        s
JOIN products     p  ON s.product_key   = p.product_key
JOIN stores       st ON s.store_key     = st.store_key
GROUP BY st.country
ORDER BY revenue_usd DESC;


-- ---------------------------------------------------------------
-- Q2: Yearly Revenue Trend
-- Business Question:
--   Is the business growing year over year?
--   Which year was the peak revenue year?
-- ---------------------------------------------------------------
-- PostgreSQL version (dates stored as TEXT in M/D/YYYY):
SELECT
    EXTRACT(YEAR FROM TO_DATE(s.order_date, 'FMMM/FMDD/YYYY'))              AS order_year,
    COUNT(DISTINCT s.order_number)                                            AS total_orders,
    SUM(s.quantity)                                                           AS units_sold,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)       AS revenue_usd,
    ROUND(SUM(s.quantity
        * (CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)
         - CAST(TRIM(REPLACE(p.unit_cost_usd,'$',''))  AS NUMERIC))), 2)     AS gross_profit_usd
FROM sales    s
JOIN products p  ON s.product_key = p.product_key
GROUP BY order_year
ORDER BY order_year;

-- SQLite alternative (dates in M/D/YYYY — use substr-based year extraction):
-- CAST(SUBSTR(s.order_date, LENGTH(s.order_date)-3, 4) AS INTEGER) AS order_year


-- ---------------------------------------------------------------
-- Q3: Monthly Revenue Trend (all years combined)
-- Business Question:
--   Which months consistently drive the highest sales?
--   Are there seasonal peaks or troughs?
-- ---------------------------------------------------------------
SELECT
    EXTRACT(MONTH FROM TO_DATE(s.order_date, 'FMMM/FMDD/YYYY'))             AS order_month,
    TO_CHAR(TO_DATE(s.order_date, 'FMMM/FMDD/YYYY'), 'Mon')                 AS month_name,
    COUNT(DISTINCT s.order_number)                                            AS total_orders,
    SUM(s.quantity)                                                           AS units_sold,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)       AS revenue_usd
FROM sales    s
JOIN products p  ON s.product_key = p.product_key
GROUP BY order_month, month_name
ORDER BY order_month;


-- ---------------------------------------------------------------
-- Q4: Revenue in Local Currency (using Exchange Rates)
-- Business Question:
--   What is the revenue in each customer's local currency?
--   This helps regional teams report in their own currency.
-- ---------------------------------------------------------------
SELECT
    s.currency_code,
    COUNT(DISTINCT s.order_number)                                             AS total_orders,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)        AS revenue_usd,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)
        * er.exchange), 2)                                                     AS revenue_local_currency
FROM sales           s
JOIN products        p  ON s.product_key   = p.product_key
JOIN exchange_rates  er ON s.currency_code = er.currency
                       AND s.order_date    = er.rate_date
GROUP BY s.currency_code
ORDER BY revenue_usd DESC;


-- ---------------------------------------------------------------
-- Q5: Top 10 Highest Revenue-Generating Products
-- Business Question:
--   Which individual products are the top revenue drivers?
--   Which ones should get priority in inventory and marketing?
-- ---------------------------------------------------------------
SELECT
    p.product_key,
    p.product_name,
    p.brand,
    p.category,
    p.subcategory,
    SUM(s.quantity)                                                            AS units_sold,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)        AS revenue_usd,
    ROUND(SUM(s.quantity
        * (CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)
         - CAST(TRIM(REPLACE(p.unit_cost_usd,'$',''))  AS NUMERIC))), 2)      AS gross_profit_usd,
    ROUND(
        SUM(s.quantity
            * (CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)
             - CAST(TRIM(REPLACE(p.unit_cost_usd,'$',''))  AS NUMERIC)))
      / NULLIF(SUM(s.quantity
            * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 0)
      * 100, 2)                                                                AS profit_margin_pct
FROM sales    s
JOIN products p  ON s.product_key = p.product_key
GROUP BY p.product_key, p.product_name, p.brand, p.category, p.subcategory
ORDER BY revenue_usd DESC
LIMIT 10;


-- ================================================================
-- SECTION 2 : CUSTOMER ANALYTICS
-- ================================================================

-- ---------------------------------------------------------------
-- Q6: Customer Count and Revenue by Country and Continent
-- Business Question:
--   Where is our customer base concentrated?
--   Which continents are most valuable to the business?
-- ---------------------------------------------------------------
SELECT
    c.continent,
    c.country,
    COUNT(DISTINCT c.customer_key)                                             AS total_customers,
    COUNT(DISTINCT s.order_number)                                             AS total_orders,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)        AS revenue_usd,
    ROUND(AVG(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)        AS avg_order_value_usd
FROM customers c
JOIN sales     s  ON c.customer_key = s.customer_key
JOIN products  p  ON s.product_key  = p.product_key
GROUP BY c.continent, c.country
ORDER BY c.continent, revenue_usd DESC;


-- ---------------------------------------------------------------
-- Q7: Top 10 Customers by Lifetime Revenue
-- Business Question:
--   Who are our highest-value customers?
--   These are VIP customers who deserve loyalty rewards.
-- ---------------------------------------------------------------
SELECT
    c.customer_key,
    c.name                                                                     AS customer_name,
    c.gender,
    c.city,
    c.country,
    COUNT(DISTINCT s.order_number)                                             AS total_orders,
    SUM(s.quantity)                                                            AS total_units,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)        AS lifetime_revenue_usd,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC))
      / NULLIF(COUNT(DISTINCT s.order_number), 0), 2)                         AS avg_order_value_usd
FROM customers c
JOIN sales     s  ON c.customer_key = s.customer_key
JOIN products  p  ON s.product_key  = p.product_key
GROUP BY c.customer_key, c.name, c.gender, c.city, c.country
ORDER BY lifetime_revenue_usd DESC
LIMIT 10;


-- ---------------------------------------------------------------
-- Q8: Revenue and Order Count by Gender
-- Business Question:
--   Do male and female customers differ in spending behavior?
--   Should marketing campaigns be targeted differently by gender?
-- ---------------------------------------------------------------
SELECT
    c.gender,
    COUNT(DISTINCT c.customer_key)                                             AS customer_count,
    COUNT(DISTINCT s.order_number)                                             AS total_orders,
    SUM(s.quantity)                                                            AS units_purchased,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)        AS revenue_usd,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC))
      / NULLIF(COUNT(DISTINCT s.order_number), 0), 2)                         AS avg_order_value_usd
FROM customers c
JOIN sales     s  ON c.customer_key = s.customer_key
JOIN products  p  ON s.product_key  = p.product_key
GROUP BY c.gender
ORDER BY revenue_usd DESC;


-- ---------------------------------------------------------------
-- Q9: Customer Age Group Analysis
-- Business Question:
--   Which age groups are our best customers?
--   Helps target the right age demographic in campaigns.
-- ---------------------------------------------------------------
SELECT
    CASE
        WHEN age < 25                THEN 'Under 25'
        WHEN age BETWEEN 25 AND 34  THEN '25-34'
        WHEN age BETWEEN 35 AND 44  THEN '35-44'
        WHEN age BETWEEN 45 AND 54  THEN '45-54'
        WHEN age BETWEEN 55 AND 64  THEN '55-64'
        ELSE '65+'
    END                                                                        AS age_group,
    COUNT(DISTINCT c.customer_key)                                             AS customer_count,
    COUNT(DISTINCT s.order_number)                                             AS total_orders,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)        AS revenue_usd,
    ROUND(AVG(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)        AS avg_order_value_usd
FROM (
    SELECT *,
        DATE_PART('year', AGE(CURRENT_DATE,
            TO_DATE(birthday, 'FMMM/FMDD/YYYY')))                             AS age
    FROM customers
    WHERE birthday IS NOT NULL
) c
JOIN sales    s  ON c.customer_key = s.customer_key
JOIN products p  ON s.product_key  = p.product_key
GROUP BY age_group
ORDER BY
    CASE age_group
        WHEN 'Under 25' THEN 1 WHEN '25-34' THEN 2 WHEN '35-44' THEN 3
        WHEN '45-54' THEN 4 WHEN '55-64' THEN 5 ELSE 6
    END;


-- ---------------------------------------------------------------
-- Q10: Repeat vs One-Time Customers
-- Business Question:
--   What percentage of our customers return to buy again?
--   Low repeat rate signals a need for loyalty programmes.
-- ---------------------------------------------------------------
SELECT
    purchase_type,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (), 2)                                            AS pct_of_customers
FROM (
    SELECT
        customer_key,
        CASE
            WHEN COUNT(DISTINCT order_number) = 1 THEN 'One-Time Buyer'
            WHEN COUNT(DISTINCT order_number) BETWEEN 2 AND 5 THEN 'Repeat Buyer (2-5 orders)'
            ELSE 'Loyal Buyer (6+ orders)'
        END AS purchase_type
    FROM sales
    GROUP BY customer_key
) cust_segments
GROUP BY purchase_type
ORDER BY customer_count DESC;


-- ================================================================
-- SECTION 3 : STORE & CHANNEL PERFORMANCE
-- ================================================================

-- ---------------------------------------------------------------
-- Q11: Online vs In-Store Revenue Comparison
-- Business Question:
--   How does the online channel compare to physical stores?
--   Should the business invest more in e-commerce?
-- ---------------------------------------------------------------
SELECT
    CASE WHEN s.store_key = 0 THEN 'Online' ELSE 'In-Store' END               AS channel,
    COUNT(DISTINCT s.order_number)                                             AS total_orders,
    SUM(s.quantity)                                                            AS units_sold,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)        AS revenue_usd,
    ROUND(SUM(s.quantity
        * (CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)
         - CAST(TRIM(REPLACE(p.unit_cost_usd,'$',''))  AS NUMERIC))), 2)      AS gross_profit_usd,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC))
      / NULLIF(COUNT(DISTINCT s.order_number), 0), 2)                         AS avg_order_value_usd
FROM sales    s
JOIN products p  ON s.product_key = p.product_key
GROUP BY channel
ORDER BY revenue_usd DESC;


-- ---------------------------------------------------------------
-- Q12: Top 10 Stores by Revenue
-- Business Question:
--   Which physical store locations are the best performers?
--   Helps decide where to open new stores or close underperformers.
-- ---------------------------------------------------------------
SELECT
    st.store_key,
    st.country,
    st.state,
    st.square_meters,
    COUNT(DISTINCT s.order_number)                                             AS total_orders,
    SUM(s.quantity)                                                            AS units_sold,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)        AS revenue_usd,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC))
      / NULLIF(st.square_meters, 0), 2)                                       AS revenue_per_sqm
FROM sales    s
JOIN products p  ON s.product_key = p.product_key
JOIN stores   st ON s.store_key   = st.store_key
WHERE s.store_key <> 0   -- exclude online channel
GROUP BY st.store_key, st.country, st.state, st.square_meters
ORDER BY revenue_usd DESC
LIMIT 10;


-- ---------------------------------------------------------------
-- Q13: Revenue per Square Meter (Store Efficiency)
-- Business Question:
--   Which stores generate the most revenue relative to their size?
--   A key KPI for retail space utilisation.
-- ---------------------------------------------------------------
SELECT
    st.store_key,
    st.country,
    st.state,
    st.square_meters,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)        AS revenue_usd,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC))
      / NULLIF(st.square_meters, 0), 2)                                       AS revenue_per_sqm
FROM sales    s
JOIN products p  ON s.product_key = p.product_key
JOIN stores   st ON s.store_key   = st.store_key
WHERE s.store_key <> 0
GROUP BY st.store_key, st.country, st.state, st.square_meters
ORDER BY revenue_per_sqm DESC
LIMIT 15;


-- ================================================================
-- SECTION 4 : PRODUCT, BRAND & CATEGORY ANALYSIS
-- ================================================================

-- ---------------------------------------------------------------
-- Q14: Revenue and Profit by Product Category
-- Business Question:
--   Which product categories are most profitable?
--   Where should the company focus its product portfolio?
-- ---------------------------------------------------------------
SELECT
    p.category,
    COUNT(DISTINCT p.product_key)                                              AS product_count,
    SUM(s.quantity)                                                            AS units_sold,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)        AS revenue_usd,
    ROUND(SUM(s.quantity
        * (CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)
         - CAST(TRIM(REPLACE(p.unit_cost_usd,'$',''))  AS NUMERIC))), 2)      AS gross_profit_usd,
    ROUND(
        SUM(s.quantity
            * (CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)
             - CAST(TRIM(REPLACE(p.unit_cost_usd,'$',''))  AS NUMERIC)))
      / NULLIF(SUM(s.quantity
            * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 0)
      * 100, 2)                                                                AS profit_margin_pct
FROM sales    s
JOIN products p  ON s.product_key = p.product_key
GROUP BY p.category
ORDER BY revenue_usd DESC;


-- ---------------------------------------------------------------
-- Q15: Revenue and Profit by Brand
-- Business Question:
--   Which brands contribute most to revenue and profit?
--   Helps negotiate better terms with top-performing brand partners.
-- ---------------------------------------------------------------
SELECT
    p.brand,
    COUNT(DISTINCT p.product_key)                                              AS sku_count,
    SUM(s.quantity)                                                            AS units_sold,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)        AS revenue_usd,
    ROUND(SUM(s.quantity
        * (CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)
         - CAST(TRIM(REPLACE(p.unit_cost_usd,'$',''))  AS NUMERIC))), 2)      AS gross_profit_usd,
    ROUND(
        SUM(s.quantity
            * (CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)
             - CAST(TRIM(REPLACE(p.unit_cost_usd,'$',''))  AS NUMERIC)))
      / NULLIF(SUM(s.quantity
            * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 0)
      * 100, 2)                                                                AS profit_margin_pct
FROM sales    s
JOIN products p  ON s.product_key = p.product_key
GROUP BY p.brand
ORDER BY revenue_usd DESC;


-- ---------------------------------------------------------------
-- Q16: Most Popular Product Colors
-- Business Question:
--   Which product colors sell most?
--   Helps purchasing team prioritise colour variants in inventory.
-- ---------------------------------------------------------------
SELECT
    p.color,
    COUNT(DISTINCT p.product_key)                                              AS product_skus,
    SUM(s.quantity)                                                            AS units_sold,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)        AS revenue_usd
FROM sales    s
JOIN products p  ON s.product_key = p.product_key
GROUP BY p.color
ORDER BY units_sold DESC;


-- ---------------------------------------------------------------
-- Q17: Category Revenue by Country (Cross-tab view)
-- Business Question:
--   Do certain categories perform differently by region?
--   Useful for localising the product mix per market.
-- ---------------------------------------------------------------
SELECT
    st.country,
    p.category,
    SUM(s.quantity)                                                            AS units_sold,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)        AS revenue_usd
FROM sales    s
JOIN products p  ON s.product_key = p.product_key
JOIN stores   st ON s.store_key   = st.store_key
GROUP BY st.country, p.category
ORDER BY st.country, revenue_usd DESC;


-- ================================================================
-- SECTION 5 : OPERATIONAL INSIGHTS
-- ================================================================

-- ---------------------------------------------------------------
-- Q18: Average Delivery Time by Store Country
-- Business Question:
--   How long does delivery take across different regions?
--   Long delivery times hurt customer satisfaction.
-- ---------------------------------------------------------------
SELECT
    st.country,
    CASE WHEN s.store_key = 0 THEN 'Online' ELSE 'In-Store' END               AS channel,
    COUNT(*)                                                                    AS orders_with_delivery,
    ROUND(AVG(
        TO_DATE(s.delivery_date, 'FMMM/FMDD/YYYY')
      - TO_DATE(s.order_date,    'FMMM/FMDD/YYYY')
    ), 1)                                                                       AS avg_delivery_days,
    MIN(
        TO_DATE(s.delivery_date, 'FMMM/FMDD/YYYY')
      - TO_DATE(s.order_date,    'FMMM/FMDD/YYYY')
    )                                                                           AS min_delivery_days,
    MAX(
        TO_DATE(s.delivery_date, 'FMMM/FMDD/YYYY')
      - TO_DATE(s.order_date,    'FMMM/FMDD/YYYY')
    )                                                                           AS max_delivery_days
FROM sales  s
JOIN stores st ON s.store_key = st.store_key
WHERE s.delivery_date IS NOT NULL
  AND s.delivery_date <> ''
GROUP BY st.country, channel
ORDER BY avg_delivery_days DESC;


-- ---------------------------------------------------------------
-- Q19: Undelivered / Pending Orders
-- Business Question:
--   How many orders are still awaiting delivery?
--   High undelivered count may indicate fulfilment issues.
-- ---------------------------------------------------------------
SELECT
    CASE WHEN s.store_key = 0 THEN 'Online' ELSE 'In-Store' END               AS channel,
    st.country,
    COUNT(DISTINCT s.order_number)                                             AS pending_orders,
    SUM(s.quantity)                                                            AS pending_units,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)        AS pending_revenue_usd
FROM sales    s
JOIN products p  ON s.product_key = p.product_key
JOIN stores   st ON s.store_key   = st.store_key
WHERE s.delivery_date IS NULL
   OR s.delivery_date = ''
GROUP BY channel, st.country
ORDER BY pending_revenue_usd DESC;


-- ---------------------------------------------------------------
-- Q20: Orders with Very Long Delivery Times (> 14 Days)
-- Business Question:
--   Which orders experienced unusually long delivery times?
--   Escalation report for customer service teams.
-- ---------------------------------------------------------------
SELECT
    s.order_number,
    s.order_date,
    s.delivery_date,
    (TO_DATE(s.delivery_date, 'FMMM/FMDD/YYYY')
      - TO_DATE(s.order_date,  'FMMM/FMDD/YYYY'))                             AS delivery_days,
    c.name                                                                     AS customer_name,
    c.country                                                                  AS customer_country,
    st.country                                                                 AS store_country,
    CASE WHEN s.store_key = 0 THEN 'Online' ELSE 'In-Store' END               AS channel
FROM sales     s
JOIN customers c  ON s.customer_key = c.customer_key
JOIN stores    st ON s.store_key    = st.store_key
WHERE s.delivery_date IS NOT NULL
  AND s.delivery_date <> ''
  AND (TO_DATE(s.delivery_date, 'FMMM/FMDD/YYYY')
     - TO_DATE(s.order_date,    'FMMM/FMDD/YYYY')) > 14
ORDER BY delivery_days DESC
LIMIT 20;


-- ================================================================
-- SECTION 6 : ADVANCED & STRATEGIC ANALYSIS
-- ================================================================

-- ---------------------------------------------------------------
-- Q21: Year-over-Year Revenue Growth
-- Business Question:
--   How fast is the business growing each year?
--   The growth rate signals whether the strategy is working.
-- ---------------------------------------------------------------
WITH yearly AS (
    SELECT
        EXTRACT(YEAR FROM TO_DATE(s.order_date, 'FMMM/FMDD/YYYY'))            AS yr,
        ROUND(SUM(s.quantity
            * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)    AS revenue_usd
    FROM sales    s
    JOIN products p  ON s.product_key = p.product_key
    GROUP BY yr
)
SELECT
    yr,
    revenue_usd,
    LAG(revenue_usd) OVER (ORDER BY yr)                                        AS prev_year_revenue,
    ROUND((revenue_usd - LAG(revenue_usd) OVER (ORDER BY yr))
        / NULLIF(LAG(revenue_usd) OVER (ORDER BY yr), 0) * 100, 2)            AS yoy_growth_pct
FROM yearly
ORDER BY yr;


-- ---------------------------------------------------------------
-- Q22: Quarterly Revenue Breakdown per Year
-- Business Question:
--   Does the business have a strong Q4 (holiday season)?
--   Tracks within-year seasonality for capacity planning.
-- ---------------------------------------------------------------
SELECT
    EXTRACT(YEAR  FROM TO_DATE(s.order_date,'FMMM/FMDD/YYYY'))                AS yr,
    EXTRACT(QUARTER FROM TO_DATE(s.order_date,'FMMM/FMDD/YYYY'))              AS qtr,
    COUNT(DISTINCT s.order_number)                                             AS total_orders,
    SUM(s.quantity)                                                            AS units_sold,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)        AS revenue_usd
FROM sales    s
JOIN products p  ON s.product_key = p.product_key
GROUP BY yr, qtr
ORDER BY yr, qtr;


-- ---------------------------------------------------------------
-- Q23: Product Subcategory Performance Ranked within Category
-- Business Question:
--   Within each category, which subcategories punch above their weight?
--   Identify which subcategory to expand and which to cut.
-- ---------------------------------------------------------------
SELECT
    p.category,
    p.subcategory,
    SUM(s.quantity)                                                            AS units_sold,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)        AS revenue_usd,
    ROUND(
        SUM(s.quantity
            * (CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)
             - CAST(TRIM(REPLACE(p.unit_cost_usd,'$',''))  AS NUMERIC)))
      / NULLIF(SUM(s.quantity
            * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 0)
      * 100, 2)                                                                AS profit_margin_pct,
    RANK() OVER (
        PARTITION BY p.category
        ORDER BY SUM(s.quantity
            * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)) DESC
    )                                                                          AS rank_in_category
FROM sales    s
JOIN products p  ON s.product_key = p.product_key
GROUP BY p.category, p.subcategory
ORDER BY p.category, rank_in_category;


-- ---------------------------------------------------------------
-- Q24: New Customers Acquired Each Year
-- Business Question:
--   Is the business acquiring new customers consistently?
--   Declining new-customer acquisition is an early warning sign.
-- ---------------------------------------------------------------
WITH first_purchase AS (
    SELECT
        customer_key,
        MIN(TO_DATE(order_date, 'FMMM/FMDD/YYYY'))                            AS first_order_date
    FROM sales
    GROUP BY customer_key
)
SELECT
    EXTRACT(YEAR FROM first_order_date)                                        AS acquisition_year,
    COUNT(*)                                                                    AS new_customers
FROM first_purchase
GROUP BY acquisition_year
ORDER BY acquisition_year;


-- ---------------------------------------------------------------
-- Q25: Exchange Rate Impact — Revenue Comparison (USD vs Local)
-- Business Question:
--   How much does currency fluctuation affect reported revenue?
--   Important for the FP&A team's FX risk assessment.
-- ---------------------------------------------------------------
SELECT
    er.currency,
    EXTRACT(YEAR FROM TO_DATE(s.order_date,'FMMM/FMDD/YYYY'))                 AS yr,
    ROUND(AVG(er.exchange), 4)                                                 AS avg_exchange_rate,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)), 2)        AS revenue_usd,
    ROUND(SUM(s.quantity
        * CAST(TRIM(REPLACE(p.unit_price_usd,'$','')) AS NUMERIC)
        * er.exchange), 2)                                                     AS revenue_local_currency
FROM sales           s
JOIN products        p  ON s.product_key   = p.product_key
JOIN exchange_rates  er ON s.currency_code = er.currency
                       AND s.order_date    = er.rate_date
GROUP BY er.currency, yr
ORDER BY er.currency, yr;


-- ================================================================
-- END OF FILE
-- ================================================================
-- QUICK REFERENCE: Business Questions Answered
-- ================================================================
-- Q1  → Which countries generate the most revenue?
-- Q2  → Is revenue growing year over year?
-- Q3  → Which months have the highest sales?
-- Q4  → What is revenue in each local currency?
-- Q5  → What are the top 10 revenue-generating products?
-- Q6  → Which countries/continents have the most customers?
-- Q7  → Who are the top 10 highest-value customers?
-- Q8  → Do male and female customers spend differently?
-- Q9  → Which age groups buy the most?
-- Q10 → What % of customers are repeat vs one-time buyers?
-- Q11 → How does Online channel compare to In-Store?
-- Q12 → Which physical stores earn the most?
-- Q13 → Which stores are most efficient (revenue per sqm)?
-- Q14 → Which product categories are most profitable?
-- Q15 → Which brands drive the most revenue and profit?
-- Q16 → Which product colors sell best?
-- Q17 → Do category preferences vary by country?
-- Q18 → How long does delivery take across regions?
-- Q19 → How many orders are still undelivered?
-- Q20 → Which orders had very long delivery times (>14 days)?
-- Q21 → What is the year-over-year revenue growth rate?
-- Q22 → Is there a seasonal pattern within each year (Q1-Q4)?
-- Q23 → Which subcategories rank highest within their category?
-- Q24 → How many new customers are acquired each year?
-- Q25 → How does currency fluctuation affect reported revenue?
-- ================================================================
