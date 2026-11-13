/* =====================================================================
   CHINOOK MUSIC STORE — STUDENT ANSWER TEMPLATE
   ===================================================================== */

USE chinook;


/* =====================================================================
   OBJECTIVE QUESTIONS
   ===================================================================== */

-- O1
-- Does any table have missing values or duplicates? If yes how would you
-- handle it ?


-- Check for duplicate customer IDs
SELECT
    customer_id,
    COUNT(*) AS cnt
FROM customer
GROUP BY customer_id
HAVING COUNT(*) > 1;


-- Check for NULL values in customer profile columns
SELECT
    SUM(company IS NULL) AS null_company,
    SUM(state IS NULL) AS null_state,
    SUM(postal_code IS NULL) AS null_postal_code,
    SUM(phone IS NULL) AS null_phone,
    SUM(fax IS NULL) AS null_fax
FROM customer;



-- Check for NULL values in track profile columns
SELECT
    SUM(composer IS NULL) AS null_composer,
    SUM(album_id IS NULL) AS null_album_id,
    SUM(genre_id IS NULL) AS null_genre_id
FROM track;


-- O2
-- Find the top-selling tracks and top artist in the USA and identify their
-- most famous genres.

-- Top selling tracks in the USA
SELECT
    t.name AS track_name,
    ar.name AS artist_name,
    g.name AS genre_name,
    SUM(il.unit_price * il.quantity) AS revenue,
    SUM(il.quantity) AS units_sold
FROM invoice i
JOIN invoice_line il
    ON i.invoice_id = il.invoice_id
JOIN track t
    ON il.track_id = t.track_id
JOIN album a
    ON t.album_id = a.album_id
JOIN artist ar
    ON a.artist_id = ar.artist_id
JOIN genre g
    ON t.genre_id = g.genre_id
WHERE i.billing_country = 'USA'
GROUP BY
    t.track_id,
    t.name,
    ar.name,
    g.name
ORDER BY revenue DESC
LIMIT 5;

-- Top artists in the USA by revenue
SELECT
    ar.name AS artist_name,
    SUM(il.unit_price * il.quantity) AS revenue,
    SUM(il.quantity) AS units_sold
FROM invoice i
JOIN invoice_line il
    ON i.invoice_id = il.invoice_id
JOIN track t
    ON il.track_id = t.track_id
JOIN album a
    ON t.album_id = a.album_id
JOIN artist ar
    ON a.artist_id = ar.artist_id
WHERE i.billing_country = 'USA'
GROUP BY
    ar.artist_id,
    ar.name
ORDER BY revenue DESC
LIMIT 5;

-- O3
-- What is the customer demographic breakdown (age, gender, location) of
-- Chinook's customer base?

-- Customers by country, state and city

SELECT
    country,
    state,
    city,
    COUNT(*) AS customer_count
FROM customer
GROUP BY
    country,
    state,
    city
ORDER BY
    country,
    state,
    city;


-- Customers per country
SELECT
    country,
    COUNT(*) AS customer_count
FROM customer
GROUP BY country
ORDER BY customer_count DESC, country;

-- O4
-- Calculate the total revenue and number of invoices for each country, state,
-- and city:

-- Revenue and invoices by country, state and city
SELECT
    billing_country AS country,
    billing_state AS state,
    billing_city AS city,
    COUNT(invoice_id) AS num_invoices,
    SUM(total) AS total_revenue
FROM invoice
GROUP BY
    billing_country,
    billing_state,
    billing_city
ORDER BY
    billing_country,
    billing_state,
    billing_city;

-- O5
-- Find the top 5 customers by total revenue in each country

-- Top 5 customers by revenue in each country
WITH customer_revenue AS (
    SELECT
        c.country,
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        SUM(i.total) AS total_revenue
    FROM customer c
    JOIN invoice i
        ON c.customer_id = i.customer_id
    GROUP BY
        c.country,
        c.customer_id,
        c.first_name,
        c.last_name
),
ranked_customers AS (
    SELECT
        country,
        customer_name,
        total_revenue,
        DENSE_RANK() OVER (
            PARTITION BY country
            ORDER BY total_revenue DESC
        ) AS rnk
    FROM customer_revenue
)
SELECT
    country,
    customer_name,
    total_revenue,
    rnk
FROM ranked_customers
WHERE rnk <= 5
ORDER BY
    country,
    rnk,
    total_revenue DESC;

-- O6
-- Identify the top-selling track for each customer

-- Top-selling track for each customer
WITH customer_track_sales AS (
    SELECT
        c.customer_id,
        t.track_id,
        t.name AS track_name,
        SUM(il.quantity) AS units
    FROM customer c
    JOIN invoice i
        ON c.customer_id = i.customer_id
    JOIN invoice_line il
        ON i.invoice_id = il.invoice_id
    JOIN track t
        ON il.track_id = t.track_id
    GROUP BY
        c.customer_id,
        t.track_id,
        t.name
),
ranked_tracks AS (
    SELECT
        customer_id,
        track_name,
        units,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY units DESC, track_name
        ) AS rn
    FROM customer_track_sales
)
SELECT
    customer_id,
    track_name,
    units
FROM ranked_tracks
WHERE rn = 1
ORDER BY customer_id;

-- O7
-- Are there any patterns or trends in customer purchasing behavior (e.g.,
-- frequency of purchases, preferred payment methods, average order value)?

-- Store-wide purchasing averages
SELECT
    AVG(total) AS avg_order_value,
    COUNT(*) / COUNT(DISTINCT customer_id) AS avg_invoices_per_customer,
    (
        SELECT AVG(track_count)
        FROM (
            SELECT
                invoice_id,
                SUM(quantity) AS track_count
            FROM invoice_line
            GROUP BY invoice_id
        ) AS invoice_tracks
    ) AS avg_tracks_per_invoice
FROM invoice;

-- Per-customer purchasing behavior
WITH customer_behavior AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        COUNT(i.invoice_id) AS num_orders,
        AVG(i.total) AS avg_order_value,
        SUM(i.total) AS total_spend,
        DATEDIFF(
            MAX(i.invoice_date),
            MIN(i.invoice_date)
        ) AS tenure_days
    FROM customer c
    JOIN invoice i
        ON c.customer_id = i.customer_id
    GROUP BY
        c.customer_id,
        c.first_name,
        c.last_name
)
SELECT
    customer_id,
    customer_name,
    num_orders,
    avg_order_value,
    total_spend,
    tenure_days
FROM customer_behavior
ORDER BY customer_id;

-- O8
-- What is the customer churn rate?

-- Customer churn rate
WITH customer_last_purchase AS (
    SELECT
        c.customer_id,
        MAX(i.invoice_date) AS last_purchase_date
    FROM customer c
    LEFT JOIN invoice i
        ON c.customer_id = i.customer_id
    GROUP BY c.customer_id
),
churn_summary AS (
    SELECT
        COUNT(*) AS total_customers,
        SUM(
            last_purchase_date < DATE_SUB(
                (SELECT MAX(invoice_date) FROM invoice),
                INTERVAL 3 MONTH
            )
        ) AS churned_customers
    FROM customer_last_purchase
)
SELECT
    total_customers,
    churned_customers,
    ROUND(
        churned_customers * 100.0 / total_customers,
        2
    ) AS churn_rate_pct
FROM churn_summary;

-- O9
-- Calculate the percentage of total sales contributed by each genre in the
-- USA and identify the best-selling genres and artists.

-- Genre revenue and percentage of USA sales
WITH usa_genre_sales AS (
    SELECT
        g.genre_id,
        g.name AS genre,
        SUM(il.unit_price * il.quantity) AS genre_revenue
    FROM invoice i
    JOIN invoice_line il
        ON i.invoice_id = il.invoice_id
    JOIN track t
        ON il.track_id = t.track_id
    JOIN genre g
        ON t.genre_id = g.genre_id
    WHERE i.billing_country = 'USA'
    GROUP BY
        g.genre_id,
        g.name
)
SELECT
    genre,
    genre_revenue,
    ROUND(
        genre_revenue * 100.0 / SUM(genre_revenue) OVER (),
        2
    ) AS pct_of_usa_sales
FROM usa_genre_sales
ORDER BY genre_revenue DESC;


-- O10
-- Find customers who have purchased tracks from at least 3 different genres

-- Customers purchasing tracks from at least 3 genres
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    COUNT(DISTINCT t.genre_id) AS distinct_genres
FROM customer c
JOIN invoice i
    ON c.customer_id = i.customer_id
JOIN invoice_line il
    ON i.invoice_id = il.invoice_id
JOIN track t
    ON il.track_id = t.track_id
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name
HAVING COUNT(DISTINCT t.genre_id) >= 3
ORDER BY c.customer_id;

-- O11
-- Rank genres based on their sales performance in the USA

-- Rank genres by revenue in the USA
WITH usa_genre_sales AS (
    SELECT
        g.genre_id,
        g.name AS genre,
        SUM(il.unit_price * il.quantity) AS revenue
    FROM invoice i
    JOIN invoice_line il
        ON i.invoice_id = il.invoice_id
    JOIN track t
        ON il.track_id = t.track_id
    JOIN genre g
        ON t.genre_id = g.genre_id
    WHERE i.billing_country = 'USA'
    GROUP BY
        g.genre_id,
        g.name
)
SELECT
    genre,
    revenue,
    RANK() OVER (ORDER BY revenue DESC) AS sales_rank
FROM usa_genre_sales
ORDER BY sales_rank;

-- O12
-- Identify customers who have not made a purchase in the last 3 months

-- Customers with no purchase in the last 3 months
WITH last_purchase AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        c.country,
        MAX(i.invoice_date) AS last_purchase_date
    FROM customer c
    JOIN invoice i
        ON c.customer_id = i.customer_id
    GROUP BY
        c.customer_id,
        c.first_name,
        c.last_name,
        c.country
)
SELECT
    customer_id,
    customer_name,
    country,
    last_purchase_date
FROM last_purchase
WHERE last_purchase_date < DATE_SUB(
    (SELECT MAX(invoice_date) FROM invoice),
    INTERVAL 3 MONTH
)
ORDER BY last_purchase_date;


/* =====================================================================
   SUBJECTIVE QUESTIONS
   ===================================================================== */

-- S1
-- Recommend the three albums from the new record label that should be
-- prioritised for advertising and promotion in the USA based on genre
-- sales analysis.

-- Approach:
-- For the USA album sales analysis, the required data was
-- obtained by joining the invoice, invoice_line, track, genre,
-- album, and artist tables. The WHERE clause was used to filter
-- only USA sales, and I used SUM() to calculate the total sales
-- for each album. The data was then grouped by album and genre
-- using GROUP BY and arranged in decreasing order of sales
-- using ORDER BY. Finally, LIMIT 3 was used to identify the
-- top three albums.

-- Tables used:
-- invoice, invoice_line, track, genre, album, artist

-- Concepts used:
-- Joins, WHERE, GROUP BY, Aggregate Functions, ORDER BY, LIMIT

-- Query:

SELECT
    al.album_id,
    al.title AS album_title,
    ar.name AS artist_name,
    g.name AS genre_name,
    SUM(il.unit_price * il.quantity) AS total_sales
FROM invoice i
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t ON il.track_id = t.track_id
JOIN genre g ON t.genre_id = g.genre_id
JOIN album al ON t.album_id = al.album_id
JOIN artist ar ON al.artist_id = ar.artist_id
WHERE i.billing_country = 'USA'
GROUP BY al.album_id, al.title, ar.name, g.name
ORDER BY total_sales DESC, genre_name
LIMIT 3;


-- Insights:
-- The analysis shows that the top three highest-selling albums
-- in the USA are Are You Experienced?, From The Muddy Banks Of
-- The Wishkah [live], and The Doors. All three albums belong to
-- the Rock genre, indicating strong sales performance of Rock
-- albums in the USA. Are You Experienced? by Jimi Hendrix and
-- From The Muddy Banks Of The Wishkah [live] by Nirvana generated
-- the highest sales of 27.72 each, followed by The Doors by The
-- Doors with sales of 26.73.

-- Recommendation:
-- Based on the USA album sales analysis, the following three
-- albums can be prioritised for advertising and promotion:
-- 1. Are You Experienced? - Jimi Hendrix (Rock)
-- 2. From The Muddy Banks Of The Wishkah [live] - Nirvana (Rock)
-- 3. The Doors - The Doors (Rock)
--
-- Since all three top-performing albums belong to the Rock
-- genre, promotional efforts can focus on Rock music in the USA
-- market. These albums have shown the highest sales among the
-- albums in the analyzed data and can therefore be considered
-- for promotion.


-- S2
-- Determine the top-selling genres in countries other than the USA and
-- identify any commonalities or differences.

-- Approach:
-- For the sales analysis of countries other than the USA, the
-- required data was obtained by joining the invoice, invoice_line,
-- track, and genre tables. The WHERE clause was used to exclude
-- USA sales, and I used SUM() to calculate the total sales for
-- each genre. The data was grouped by genre using GROUP BY and
-- arranged in decreasing order of total sales using ORDER BY.
-- Finally, LIMIT 5 was used to identify the top five-selling
-- genres.

-- Tables used:
-- invoice, invoice_line, track, genre

-- Concepts used:
-- Joins, WHERE, GROUP BY, Aggregate Functions, ORDER BY, LIMIT

-- Query:

SELECT
    g.genre_id,
    g.name AS genre_name,
    SUM(il.unit_price * il.quantity) AS total_sales
FROM invoice i
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t ON il.track_id = t.track_id
JOIN genre g ON t.genre_id = g.genre_id
WHERE i.billing_country != 'USA'
GROUP BY g.genre_id, g.name
ORDER BY total_sales DESC, genre_name
LIMIT 5;


-- Insights:
-- The analysis shows that Rock is the top-selling genre in
-- countries other than the USA, with total sales of 2053.26.
-- It is followed by Metal with 490.05 and Alternative & Punk
-- with 358.38. Latin and Jazz are ranked fourth and fifth with
-- sales of 143.55 and 105.93, respectively.
--
-- A commonality between the USA and other countries is that
-- Rock is the highest-selling genre in both cases. However,
-- there are differences in the rankings of the other genres.
-- In the USA, Alternative & Punk ranks second and Metal ranks
-- third, whereas outside the USA, Metal ranks second and
-- Alternative & Punk ranks third.
--
-- Another difference is that Latin and Jazz appear among the
-- top five genres outside the USA, while R&B/Soul and Blues
-- are among the top five genres in the USA.


-- Recommendation:
-- The sales pattern shows that Rock has strong demand both
-- in the USA and in other countries. Therefore, Rock can be
-- considered an important genre for international promotion.
-- At the same time, the difference in genre rankings suggests
-- that promotional strategies can be adjusted according to
-- the market, with Metal receiving more attention outside the
-- USA and Alternative & Punk showing stronger performance
-- in the USA.

-- S3
-- Customer Purchasing Behavior Analysis: How do the purchasing habits
-- (frequency, basket size, spending amount) of long-term customers differ
-- from those of new customers? What insights can these patterns provide
-- about customer loyalty and retention strategies?

-- Approach:
-- Customer purchasing behavior was analyzed by dividing the
-- purchase records into Long-Term and New categories based on
-- the invoice year. I joined the invoice and invoice_line tables
-- to calculate the purchase frequency, basket size, and total
-- spending for each category. A CASE statement was used to
-- classify purchases made up to 2019 as Long-Term and purchases
-- after 2019 as New. The results were then grouped by customer
-- category to compare their purchasing behavior.

-- Tables used:
-- invoice, invoice_line

-- Concepts used:
-- Joins, GROUP BY, Aggregate Functions, CASE Statement

-- Query:

WITH cus_data AS (
    SELECT
        CASE
            WHEN YEAR(i.invoice_date) <= 2019 THEN 'Long-Term'
            ELSE 'New'
        END AS customer_category,
        COUNT(DISTINCT i.invoice_id) AS purchase_frequency,
        SUM(il.quantity) / COUNT(DISTINCT i.invoice_id) AS avg_basket_size,
        SUM(i.total) AS total_amount
    FROM invoice i
    JOIN invoice_line il
        ON i.invoice_id = il.invoice_id
    GROUP BY customer_category
)
SELECT
    customer_category,
    ROUND(AVG(purchase_frequency), 2) AS avg_purchase_frequency,
    ROUND(AVG(avg_basket_size), 2) AS avg_basket_size,
    ROUND(AVG(total_amount), 2) AS avg_total_amount
FROM cus_data
GROUP BY customer_category;


-- Insights:
-- The analysis shows that Long-Term customers have a higher
-- purchase frequency of 464 compared with 150 for New customers.
-- The average basket size is also slightly higher for Long-Term
-- customers at 7.77, compared with 7.67 for New customers.
--
-- The total amount spent by the Long-Term category is 36163.71,
-- while the New category contributes 11339.46. Overall,
-- Long-Term customers show higher purchase frequency, slightly
-- larger basket sizes, and higher total spending than New
-- customers.
--
-- These results indicate stronger engagement from the Long-Term
-- customer group. The higher purchase frequency and spending
-- suggest that retaining existing customers is important for
-- maintaining sales and customer loyalty.


-- Recommendation:
-- The store should continue focusing on retention and loyalty
-- strategies for Long-Term customers because they contribute
-- higher purchase frequency and total spending. Loyalty offers,
-- personalized recommendations, and promotions can be used to
-- encourage these customers to continue purchasing.
--
-- At the same time, the store should focus on new customer
-- engagement and conversion by providing introductory offers
-- and targeted promotions. Since the New customer category has
-- lower purchase frequency and total spending, encouraging
-- repeat purchases can help increase their engagement and
-- gradually build long-term customer relationships.

-- S4
-- Product Affinity Analysis: Which music genres, artists, or albums are
-- frequently purchased together by customers? How can this information
-- guide product recommendations and cross-selling initiatives?

-- Approach:
-- To analyze product affinity, I looked at combinations of
-- genres, artists, and albums purchased within the same invoice.
-- I joined the required tables to obtain invoice-level purchase
-- details and used separate CTEs for genre, artist, and album
-- affinity. I then performed a self join on invoice_id and used
-- a comparison condition to avoid matching the same item with
-- itself or counting the same pair twice. Finally, I used
-- GROUP BY, COUNT(), and ORDER BY to identify the five most
-- frequently purchased combinations.

-- Tables used:
-- invoice, invoice_line, track, genre, album, artist

-- Concepts used:
-- CTE, Joins, Self Join, GROUP BY, Aggregate Functions, ORDER BY


-- Genre Affinity Query:

WITH genre_data AS (
    SELECT
        i.invoice_id,
        g.name
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON t.genre_id = g.genre_id
)
SELECT
    g1.name AS genre_1,
    g2.name AS genre_2,
    COUNT(*) AS genre_frequent_purchases
FROM genre_data g1
JOIN genre_data g2
    ON g1.invoice_id = g2.invoice_id
    AND g1.name < g2.name
GROUP BY g1.name, g2.name
ORDER BY genre_frequent_purchases DESC
LIMIT 5;


-- Artist Affinity Query:

WITH artist_data AS (
    SELECT
        i.invoice_id,
        ar.name
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN album al ON t.album_id = al.album_id
    JOIN artist ar ON al.artist_id = ar.artist_id
)
SELECT
    ar1.name AS artist_1,
    ar2.name AS artist_2,
    COUNT(*) AS artist_frequent_purchases
FROM artist_data ar1
JOIN artist_data ar2
    ON ar1.invoice_id = ar2.invoice_id
    AND ar1.name < ar2.name
GROUP BY ar1.name, ar2.name
ORDER BY artist_frequent_purchases DESC
LIMIT 5;


-- Album Affinity Query:

WITH album_data AS (
    SELECT
        i.invoice_id,
        al.title
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN album al ON t.album_id = al.album_id
)
SELECT
    al1.title AS album_1,
    al2.title AS album_2,
    COUNT(*) AS album_frequent_purchases
FROM album_data al1
JOIN album_data al2
    ON al1.invoice_id = al2.invoice_id
    AND al1.title < al2.title
GROUP BY al1.title, al2.title
ORDER BY album_frequent_purchases DESC
LIMIT 5;


-- Insights:
-- The genre affinity analysis shows that Metal and Rock have
-- the highest co-purchase frequency, with 1,622 purchases
-- together. Alternative & Punk and Rock are the next highest
-- combination with 1,056, followed by Latin and Rock with 427
-- and R&B/Soul and Rock with 407. This shows that Rock
-- frequently appears together with several other genres in
-- customer purchases.
--
-- The artist affinity results show that Green Day and Led
-- Zeppelin have the highest co-purchase frequency at 24.
-- This is followed by Foo Fighters and Green Day with 20,
-- while Nirvana and The Rolling Stones and Eric Clapton and
-- Nirvana each have 19 purchases together. Green Day and
-- Metallica have 18 co-purchases.
--
-- The album analysis shows that Are You Experienced? and
-- Mezmerize have the highest co-purchase frequency at 16.
-- Mezmerize also appears in three of the top five album
-- combinations, including combinations with Vault: Def
-- Leppard's Greatest Hits, My Generation - The Very Best Of
-- The Who, and The Police Greatest Hits.
--
-- Overall, the results show that customers frequently purchase
-- certain genres, artists, and albums together. These
-- combinations can be useful for understanding customer
-- preferences and identifying products that can be promoted
-- together.


-- Recommendation:
-- The store can use these frequently purchased combinations
-- to create cross-selling recommendations. For example,
-- customers purchasing Rock music could be shown recommendations
-- from Metal, Alternative & Punk, or other genres that
-- frequently appear with Rock.
--
-- Similarly, artist combinations such as Green Day and
-- Led Zeppelin and album combinations such as Are You
-- Experienced? and Mezmerize can be used to recommend related
-- products to customers.
--
-- The store could also offer bundle promotions or discounts
-- on frequently purchased combinations. This may encourage
-- customers to purchase additional products while making the
-- recommendations more relevant to their existing music
-- preferences.

-- S5
-- Regional Market Analysis: Do customer purchasing behaviors and churn rates
-- vary across different geographic regions or store locations? How might
-- these correlate with local demographic or economic factors?

-- Approach:
-- For the regional market analysis, I analyzed customer
-- purchasing and churn behavior at the country level. I used
-- the invoice table to calculate total revenue, average order
-- amount, total orders, and total customers for each country.
-- I also identified each customer's latest purchase date and
-- classified customers as churned or active based on the
-- three-month churn period. Finally, I combined the country-level
-- sales and churn information using CTEs and LEFT JOIN to
-- compare purchasing behavior and churn rates across countries.

-- Tables used:
-- invoice

-- Concepts used:
-- CTE, Joins, GROUP BY, Aggregate Functions, CASE Statement,
-- ORDER BY


-- Query:

WITH latest_sales AS (
    SELECT
        customer_id,
        MAX(invoice_date) AS latest_purchase
    FROM invoice
    GROUP BY customer_id
),
churn_data AS (
    SELECT
        customer_id,
        latest_purchase,
        CASE
            WHEN latest_purchase < '2020-12-30' - INTERVAL 3 MONTH
                THEN 'churned_user'
            ELSE 'Active_user'
        END AS customer_category
    FROM latest_sales
),
country_data AS (
    SELECT
        billing_country AS country,
        COUNT(DISTINCT customer_id) AS total_customers,
        SUM(total) AS revenue,
        AVG(total) AS avg_order_amount,
        COUNT(invoice_id) AS total_orders
    FROM invoice
    GROUP BY billing_country
),
churn_calculations AS (
    SELECT
        i.billing_country AS country,
        c.customer_category,
        COUNT(DISTINCT c.customer_id) AS total_customers
    FROM invoice i
    JOIN churn_data c
        ON i.customer_id = c.customer_id
        AND c.customer_category = 'churned_user'
    GROUP BY country, c.customer_category
)
SELECT
    cd.country,
    cd.revenue,
    cd.avg_order_amount,
    cd.total_orders,
    cd.total_customers,
    ROUND(
        COALESCE(
            CASE
                WHEN cc.customer_category = 'churned_user'
                THEN cc.total_customers
            END,
            0
        ) * 100 / cd.total_customers,
        2
    ) AS churn_percentage
FROM country_data cd
LEFT JOIN churn_calculations cc
    ON cd.country = cc.country
ORDER BY cd.country;


-- Insights:
-- The analysis shows that customer purchasing behavior and
-- churn rates vary across different countries. For example,
-- Canada has 8 customers, 76 total orders, revenue of 535.59,
-- and a churn percentage of 12.50%. In comparison, Brazil has
-- 5 customers, 61 total orders, revenue of 427.68, and a higher
-- churn percentage of 60.00%.
--
-- Among the countries visible in the results, some countries
-- such as Australia, Czech Republic, Finland, and Hungary have
-- a 0% churn rate, while countries such as Argentina, Austria,
-- Belgium, Chile, and Denmark show 100% churn. However, some
-- of these countries have only one customer, so the churn
-- percentage should be interpreted carefully.
--
-- Other countries with multiple customers also show different
-- churn levels. Germany has 4 customers with a 75% churn rate,
-- while India has 2 customers with a 50% churn rate. France
-- has 5 customers and a 40% churn rate.
--
-- The results therefore indicate that both purchasing activity
-- and customer retention differ across geographic markets.
-- Countries with more customers and orders provide a stronger
-- basis for comparison, while percentages from countries with
-- only one customer may not be as representative.
--
-- The database does not contain detailed demographic or
-- economic information such as customer age, income, or local
-- economic indicators. Therefore, a direct correlation between
-- churn and local demographic or economic factors cannot be
-- established from this dataset.


-- Recommendation:
-- The store should monitor countries with higher churn
-- percentages, especially those with a reasonable number of
-- customers, and focus on improving customer retention through
-- personalized recommendations, loyalty offers, and targeted
-- promotions.
--
-- Markets with lower churn rates can be studied to understand
-- the purchasing patterns that are associated with better
-- customer retention. The store can use these findings to
-- develop suitable strategies for other markets.
--
-- For countries with very small customer counts, such as those
-- with only one customer, the churn percentage should be
-- interpreted carefully before making major business decisions.
-- More customer data would provide a stronger basis for
-- regional comparisons.
--
-- Since demographic and economic factors are not available in
-- the Chinook database, additional external data would be
-- required to determine whether factors such as income,
-- population characteristics, or local economic conditions are
-- related to customer purchasing behavior or churn.

-- S6
-- Customer Risk Profiling: Based on customer profiles (age, gender, location,
-- purchase history), which customer segments are more likely to churn or
-- pose a higher risk of reduced spending? What factors contribute to this
-- risk?

-- Approach:
-- For customer risk profiling, I considered the available
-- customer location and purchase history because the Chinook
-- database does not contain age and gender information. I used
-- the customer and invoice tables to calculate total spending,
-- total orders, average order amount, and the number of orders
-- made during the latest one-year period. Based on these
-- purchase-related factors, I classified customers as High Risk
-- or Low Risk using a CASE statement. Customers with fewer
-- recent purchases, fewer total orders, or lower total spending
-- were considered to have a higher risk of churn or reduced
-- spending.

-- Tables used:
-- customer, invoice

-- Concepts used:
-- CTE, Joins, GROUP BY, Aggregate Functions, CASE Statement,
-- COALESCE, ORDER BY


-- Query:

WITH recent_orders AS (
    SELECT
        customer_id,
        COUNT(*) AS latest_year_orders
    FROM invoice
    WHERE invoice_date > '2020-12-30' - INTERVAL 1 YEAR
    GROUP BY customer_id
),
customer_summary AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        c.country,
        SUM(i.total) AS total_spent,
        COUNT(i.invoice_id) AS total_orders,
        AVG(i.total) AS avg_order_amount
    FROM customer c
    JOIN invoice i
        ON c.customer_id = i.customer_id
    GROUP BY
        c.customer_id,
        c.first_name,
        c.last_name,
        c.country
)
SELECT
    s.customer_id,
    s.customer_name,
    s.country,
    s.total_spent,
    s.total_orders,
    s.avg_order_amount,
    COALESCE(r.latest_year_orders, 0) AS latest_year_orders,
    CASE
        WHEN COALESCE(r.latest_year_orders, 0) < 2
             OR s.total_orders < 5
             OR s.total_spent < 20
        THEN 'High Risk'
        ELSE 'Low Risk'
    END AS customer_status
FROM customer_summary s
LEFT JOIN recent_orders r
    ON s.customer_id = r.customer_id
ORDER BY customer_status, s.customer_id;


-- Insights:
-- The analysis identifies customers as High Risk or Low Risk
-- based on their recent purchase activity, total orders, and
-- total spending. In the displayed results, customers such as
-- François Tremblay, Bjørn Hansen, and Daan Peeters are
-- classified as High Risk because their latest-year order count
-- is below the defined threshold.
--
-- The results also show that having a reasonable total number
-- of orders or spending amount does not automatically place a
-- customer in the Low Risk category. For example, Dan Miller
-- has 12 total orders and has spent 95.04, but is still
-- classified as High Risk because his latest-year order count
-- is only 1.
--
-- This indicates that recent purchase activity is an important
-- factor in identifying customers who may be at risk of churn
-- or reduced spending. Total orders and total spending also
-- contribute to the risk classification.
--
-- Age and gender could not be included in the risk analysis
-- because these fields are not available in the Chinook
-- database. Therefore, the analysis is mainly based on
-- location and purchase history.


-- Recommendation:
-- The store should focus on customers classified as High Risk
-- by encouraging them to make repeat purchases. Personalized
-- recommendations, discounts, loyalty offers, and targeted
-- promotions can be used to re-engage customers with low recent
-- activity.
--
-- Customers with regular recent purchases can be maintained
-- through loyalty programs and personalized music recommendations.
-- The store should also periodically update the risk analysis so
-- that changes in customer purchasing behavior can be identified
-- early.
--
-- Since age and gender information is not available in the
-- database, additional customer profile data would be required
-- to analyze whether these demographic factors contribute to
-- churn or reduced spending.

-- S7
-- Customer Lifetime Value Modeling: How can you leverage customer data
-- (tenure, purchase history, engagement) to predict the lifetime value of
-- different customer segments? This could inform targeted marketing and
-- loyalty program strategies. Can you observe any common characteristics
-- or purchase patterns among customers who have stopped purchasing?

-- Approach:
-- For customer lifetime value analysis, I divided customers
-- into Churned Customer and Active Customer categories based
-- on their latest purchase date. I joined the customer and
-- invoice tables and used MIN() and MAX() to identify the first
-- and latest purchase dates. I then calculated customer tenure,
-- total spending, total orders, and average order amount using
-- aggregate functions. Finally, I used a CASE statement to
-- classify customers whose latest purchase was more than six
-- months before the reference date as Churned Customers, while
-- the remaining customers were classified as Active Customers.

-- Tables used:
-- customer, invoice

-- Concepts used:
-- Joins, GROUP BY, Aggregate Functions, CASE Statement,
-- DATEDIFF(), ORDER BY


-- Query:

SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_full_name,
    MIN(DATE(i.invoice_date)) AS first_purchase,
    MAX(DATE(i.invoice_date)) AS latest_purchase,
    DATEDIFF(
        MAX(DATE(i.invoice_date)),
        MIN(DATE(i.invoice_date))
    ) AS tenure,
    SUM(i.total) AS total_spent,
    COUNT(i.invoice_id) AS total_orders,
    ROUND(AVG(i.total), 2) AS avg_order_amount,
    CASE
        WHEN MAX(DATE(i.invoice_date)) < '2020-12-30' - INTERVAL 6 MONTH
            THEN 'Churned Customer'
        ELSE 'Active Customer'
    END AS customer_category
FROM customer c
JOIN invoice i
    ON c.customer_id = i.customer_id
GROUP BY c.customer_id
ORDER BY c.customer_id;


-- Insights:
-- The analysis shows that both Active Customers and Churned
-- Customers are present in the customer base. The results show
-- that customers can have a long tenure and still become
-- inactive. For example, François Tremblay has a tenure of
-- 1180 days, 9 total orders, and total spending of 99.99, but
-- is classified as a Churned Customer. Similarly, Bjørn Hansen
-- has a tenure of 1089 days and 9 orders but is also classified
-- as Churned.
--
-- On the other hand, some Active Customers have higher purchase
-- activity and spending. For example, Fernanda Ramos has 15
-- orders, total spending of 106.92, and is classified as an
-- Active Customer. Helena Holý has 12 orders and total spending
-- of 128.70 and is also Active.
--
-- The results indicate that tenure alone does not guarantee
-- continued engagement. Customers with long purchasing
-- histories can still stop purchasing. Purchase frequency,
-- total spending, and the recency of the latest purchase are
-- useful factors when identifying customers who may have
-- stopped engaging with the store.


-- Recommendation:
-- The store should use customer tenure, purchase frequency,
-- total spending, average order value, and latest purchase date
-- together when identifying valuable customers and customers
-- at risk of churn.
--
-- Churned customers with a long tenure and reasonable previous
-- spending can be targeted through personalized recommendations,
-- loyalty offers, and re-engagement promotions. Active customers
-- with higher purchase frequency and spending should be
-- encouraged to continue their engagement through loyalty
-- programs and personalized product recommendations.
--
-- The store can also use the calculated customer lifetime and
-- purchase history to identify high-value customers and provide
-- them with suitable offers before they become inactive.

-- S8
-- If data on promotional campaigns (discounts, events, email marketing) is
-- available, how could you measure their impact on customer acquisition,
-- retention, and overall sales?

-- Approach:
-- To evaluate the impact of promotional campaigns, I considered
-- three main areas: customer acquisition, customer retention,
-- and sales performance. I compared the number of orders and
-- total revenue before and after the campaign period to identify
-- changes in sales activity. I also checked whether customers
-- who purchased during the campaign period continued purchasing
-- after the campaign ended. If campaign exposure data were
-- available, customer groups could also be compared based on
-- factors such as location and spending behavior to understand
-- which segments responded better to the promotion.

-- Tables used:
-- invoice

-- Concepts used:
-- CASE Statement, Aggregate Functions, GROUP BY, COUNT(),
-- SUM(), Subquery, DISTINCT


-- Query 1: Sales Uplift

SELECT
    CASE
        WHEN invoice_date < '2019-01-01' THEN 'Before Campaign'
        ELSE 'After Campaign'
    END AS period,
    COUNT(DISTINCT invoice_id) AS total_orders,
    SUM(total) AS total_revenue
FROM invoice
GROUP BY period;


-- Query 2: Customer Retention

SELECT
    COUNT(DISTINCT customer_id) AS retained_customers
FROM invoice
WHERE invoice_date > '2019-03-31'
AND customer_id IN (
    SELECT DISTINCT customer_id
    FROM invoice
    WHERE invoice_date BETWEEN '2019-01-01' AND '2019-03-31'
);


-- Insights:
-- The sales comparison shows that there were 305 orders with
-- revenue of 2349.27 before the campaign period, while the
-- period after the campaign had 309 orders with revenue of
-- 2360.16. This represents an increase of 4 orders and 10.89
-- in revenue after the campaign period.
--
-- The retention analysis shows that 26 customers who made
-- purchases during the campaign period also made purchases
-- after the campaign period. This indicates that some customers
-- continued purchasing after the campaign period.
--
-- However, the available Chinook database does not contain
-- information about actual promotional campaign exposure,
-- discounts, email marketing, or events. Therefore, the
-- before-and-after results cannot by themselves prove that the
-- campaign caused the increase in sales or retained customers.


-- Recommendation:
-- If actual promotional campaign data is available, the store
-- should compare customers who were exposed to the campaign
-- with customers who were not exposed. This would provide a
-- better way to measure the actual impact of discounts, email
-- marketing, or events.
--
-- The store can also track customers after a campaign to
-- identify repeat purchases and use personalized promotions to
-- encourage customers to continue purchasing. Campaigns that
-- show improvement in both sales and repeat purchases can be
-- studied further for future promotional planning.

-- S9
-- How would you approach this problem, if the objective and subjective
-- questions weren't given?

-- Approach:
-- If the objective and subjective questions were not provided,
-- I would follow a structured, data-driven approach to
-- understand the Chinook Music Store database, identify
-- important business patterns, and find areas where the
-- business can improve.
--
-- 1. Understand the Business Context
-- First, I would understand the business model of Chinook
-- Music Store and identify the main business goals, such as
-- revenue growth, customer retention, identifying popular
-- products, and understanding customer purchasing behavior.
--
-- 2. Understand the Data and Check Data Quality
-- I would explore the database schema and understand the
-- relationships between customer, invoice, invoice_line,
-- track, genre, artist, album, and other relevant tables.
-- I would also check for missing or NULL values, duplicate
-- records, and inconsistent data.
--
-- 3. Define Important KPIs
-- I would identify key metrics such as total revenue,
-- average order value, customer purchase frequency,
-- top-selling genres, artists, and albums, and customer
-- retention and churn.
--
-- 4. Perform Exploratory Data Analysis
-- Using SQL, I would analyze sales performance across
-- countries, customer purchasing behavior, revenue by genre
-- and artist, top-performing albums and tracks, and customer
-- purchase patterns over time.
--
-- 5. Segment Customers and Products
-- I would create useful customer and product segments based
-- on customer spending, purchase frequency, engagement,
-- genre popularity, and product sales performance.
--
-- 6. Generate Insights and Visualize Results
-- I would create suitable visualizations for important
-- findings so that the results are easier to understand.
-- Each visualization would be supported by a clear business
-- insight.
--
-- 7. Provide Business Recommendations
-- Finally, I would convert the findings into actionable
-- recommendations, such as focusing marketing efforts on
-- high-value customers, promoting popular genres, artists,
-- and albums, improving retention of at-risk customers, and
-- identifying opportunities for cross-selling.
--
-- This approach would help me move from data understanding
-- to analysis, insights, and business recommendations even
-- when predefined questions are not available.

-- S10
-- How can you alter the "Albums" table to add a new column named
-- "ReleaseYear" of type INTEGER to store the release year of each album?

-- Approach:
-- To add a new column for storing the release year of each
-- album, I used the ALTER TABLE DDL statement. The ADD clause
-- was used to create a new ReleaseYear column with the INTEGER
-- data type in the album table.

-- Concepts used:
-- DDL, ALTER TABLE, ADD, INTEGER

-- Query:

ALTER TABLE album
ADD ReleaseYear INT;

SELECT * FROM album;


-- Observation:
-- As no values have been inserted into the ReleaseYear column,
-- the existing records show NULL for this newly added column.

-- S11
-- Chinook is interested in understanding the purchasing behavior of customers
-- based on their geographical location. They want to know the average
-- total amount spent by customers from each country, along with the number
-- of customers and the average number of tracks purchased per customer.
-- Write an SQL query to provide this information.

-- Approach:
-- I analyzed customer purchasing behavior at the country level
-- by first calculating the total spending and total number of
-- tracks purchased by each customer. I joined the customer,
-- invoice, and invoice_line tables to collect the required
-- information. After that, I grouped the customer-level data
-- by country to calculate the number of customers, average
-- tracks purchased per customer, and average amount spent
-- per customer.

-- Tables used:
-- customer, invoice, invoice_line

-- Concepts used:
-- CTE, Joins, GROUP BY, Aggregate Functions, ORDER BY


-- Query:

WITH customer_data AS (
    SELECT
        c.customer_id,
        c.country,
        SUM(i.total) AS total_spent,
        SUM(il.quantity) AS total_tracks
    FROM customer c
    JOIN invoice i
        ON c.customer_id = i.customer_id
    JOIN invoice_line il
        ON i.invoice_id = il.invoice_id
    GROUP BY
        c.customer_id,
        c.country
)
SELECT
    country,
    COUNT(*) AS total_customers,
    ROUND(AVG(total_tracks), 2) AS avg_tracks_per_customer,
    ROUND(AVG(total_spent), 2) AS avg_amount_spent_per_customer
FROM customer_data
GROUP BY country
ORDER BY country;


-- Insights:
-- The results show that customer purchasing behavior varies
-- across different countries. Countries with more customers,
-- such as Brazil, Canada, France, and Germany, provide a larger
-- customer base for comparison.
--
-- Among the countries visible in the output, Ireland has the
-- highest average amount spent per customer at 1433.52, with
-- an average of 116 tracks purchased per customer. The Czech
-- Republic also shows high purchasing activity, with an average
-- of 138 tracks and average spending of 1591.92 per customer.
--
-- Countries such as Argentina and Denmark have only one
-- customer and relatively lower average spending of 396.00
-- and 196.02, respectively. Their results should therefore be
-- interpreted carefully because they are based on a very small
-- customer base.
--
-- The analysis helps identify countries where customers show
-- higher purchasing activity and spending, which can be useful
-- for planning regional marketing and promotional strategies.


-- Recommendation:
-- The store can focus more promotional and marketing activities
-- on countries showing higher average spending and track
-- purchases per customer. Personalized recommendations, loyalty
-- offers, and album or genre promotions can be used to encourage
-- these customers to continue purchasing.
--
-- For countries with a small customer base, the store can focus
-- on customer acquisition while continuing to monitor purchasing
-- behavior as more customers are added.
--
-- The country-wise analysis can also be used to identify markets
-- with lower average spending and design suitable offers to
-- increase customer engagement and purchase frequency.

/* ===================================== END OF FILE ===================================== */
