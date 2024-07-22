1. What is the total number of rows in each of the 3 tables in the database?

select count(*) from customers_new;
select count(*) from prod_cat_info;
select count(*) from transactions_new;

2. What is the total number of transactions that have a return?

select count(transaction_id) from transactions_new
where Qty>0;

3.you would have noticed, the dates provided across the datasets are not in a correct format. As first steps, pls convert the date variables into valid date formats before proceeding ahead.

SET SQL_SAFE_UPDATES = 0; 

UPDATE mini_project.customers_new
SET DOB = STR_TO_DATE(DOB, '%d-%m-%Y')
WHERE DOB IS NOT NULL;


ALTER TABLE mini_project.customers_new 
CHANGE COLUMN DOB DOB DATE NULL DEFAULT NULL;


UPDATE mini_project.transactions_new
SET tran_date = STR_TO_DATE(tran_date, '%d-%m-%Y')
WHERE tran_date IS NOT NULL;


ALTER TABLE mini_project.transactions_new 
CHANGE COLUMN tran_date tran_date DATE NULL DEFAULT NULL;

4. What is the time range of the transaction data available for analysis? Show the output in number of days, months and years simultaneously in different columns.

SELECT 
    MIN(tran_date) AS min_order_date,
    MAX(tran_date) AS max_delivery_date,
    TIMESTAMPDIFF(DAY, MIN(tran_date), MAX(tran_date)) AS total_days,
    TIMESTAMPDIFF(MONTH, MIN(tran_date), MAX(tran_date)) AS total_months,
    TIMESTAMPDIFF(YEAR, MIN(tran_date), MAX(tran_date)) AS total_years
FROM 
    mini_project.transactions_new;

5. Which product category does the sub-category "DIY" belong to?

select prod_cat from prod_cat_info   
where prod_subcat="DIY";

------------#DATA ANALYSIS---------------

1. Which channel is most frequently used for transactions?

select A.Store_type from
(select  count(distinct(transaction_id)) as TOTAL_COUNT,Store_type from transactions_new
group by Store_type
order by TOTAL_COUNT  desc
limit 1 ) A

2. What is the count of Male and Female customers in the database?

select  count(distinct( customer_Id)),Gender from customers_new
where Gender in ('M','F')
group by Gender;

3. From which city do we have the maximum number of customers and how many?

select  count(distinct(customer_Id))as ID,city_code from customers_new
group by city_code
order by ID desc
limit 1;

4.How many sub-categories are there under the Books category?

select count(prod_sub_cat_code) from prod_cat_info 
where prod_cat='Books'

5. What is the maximum quantity of products ever ordered?

select A.qty from
(SELECT prod_cat_code,COUNT(DISTINCT transaction_id) AS I,SUM(Qty) as qty
FROM transactions_new
GROUP BY prod_cat_code
order by qty desc
limit 1) A

6. What is the net total revenue generated in categories Electronics and Books?

select sum(T.total_amt)AS Total_Revenue,P.prod_cat
from transactions_new T
Left join prod_cat_info P on 
T.prod_subcat_code = P.prod_sub_cat_code and
T.prod_cat_code = P.prod_cat_code
where P.prod_cat in ('Electronics','Books')
GROUP BY P.prod_cat;

7. How many customers have >10 transactions with us, excluding returns?

select count(transaction_id),cust_id from transactions_new
GROUP BY cust_id
HAVING count(transaction_id)>10;

8. What is the combined revenue earned from the "Electronics" & "Clothing" categories, from "Flagship stores"?

select *  from transactions_new T
Left join prod_cat_info P on 
T.prod_subcat_code = P.prod_sub_cat_code and
T.prod_cat_code = P.prod_cat_code 
HAVING P.prod_cat in ('Electronics','Clothing') and T.Store_type = 'Flagship stores';   

9. What is the total revenue generated from "Male" customers in "Electronics" category? Output should display total revenue by prod sub-cat.

select sum(T.total_amt)AS Total_Revenue,T.prod_subcat_code  from customers_new C
Left join transactions_new T on 
C.customer_Id = T.cust_id 
Left join prod_cat_info P on
T.prod_subcat_code = P.prod_sub_cat_code and
T.prod_cat_code = P.prod_cat_code 
where C.Gender ='M' and P.prod_cat ='Electronics'
group by T.prod_subcat_code;

10. What is percentage of sales and returns by product sub category; display only top 5 sub categories in terms of sales?

WITH SubcategorySales AS (
    SELECT 
        t.prod_subcat_code,
        p.prod_subcat,
        SUM(t.total_amt) AS total_sales,
        SUM(CASE WHEN t.Qty < 0 THEN t.total_amt ELSE 0 END) AS total_returns
    FROM 
        transactions_new t
    JOIN 
        prod_cat_info p ON t.prod_subcat_code = p.prod_sub_cat_code
    GROUP BY 
        t.prod_subcat_code, p.prod_subcat
),
TopSubcategories AS (
    SELECT 
        prod_subcat_code,
        prod_subcat,
        total_sales,
        total_returns,
        RANK() OVER (ORDER BY total_sales DESC) AS sales_rank
    FROM 
        SubcategorySales
)
SELECT 
    prod_subcat,
    total_sales,
    (total_sales / (SELECT SUM(total_sales) FROM SubcategorySales) * 100) AS sales_percentage,
    total_returns,
    (total_returns / (SELECT SUM(total_returns) FROM SubcategorySales) * 100) AS returns_percentage
FROM 
    TopSubcategories
WHERE 
    sales_rank <= 5;

11. For all customers aged between 25 to 35 years find what is the net total revenue generated by these consumers in last 30 days of transactions from max transaction date available in the      data?
-- Step 1: Determine the maximum transaction date
WITH MaxTranDate AS (
    SELECT MAX(tran_date) AS max_date
    FROM transactions_new
),

-- Step 2: Filter transactions within the last 30 days from the maximum transaction date
RecentTransactions AS (
    SELECT t.*, m.max_date
    FROM transactions_new t
    CROSS JOIN MaxTranDate m
    WHERE DATE(t.tran_date) BETWEEN DATE_SUB(m.max_date, INTERVAL 30 DAY) AND m.max_date
),

-- Step 3: Calculate the age of customers and filter those aged between 25 and 35 years
EligibleCustomers AS (
    SELECT c.customer_Id, 
           c.DOB,
           YEAR(m.max_date) - YEAR(c.DOB) - (DATE_FORMAT(m.max_date, '%m%d') < DATE_FORMAT(c.DOB, '%m%d')) AS age
    FROM customers_new c
    CROSS JOIN MaxTranDate m
    WHERE YEAR(m.max_date) - YEAR(c.DOB) - (DATE_FORMAT(m.max_date, '%m%d') < DATE_FORMAT(c.DOB, '%m%d')) BETWEEN 25 AND 35
),

-- Step 4: Join recent transactions with eligible customers and calculate net total revenue
NetTotalRevenue AS (
    SELECT SUM(t.total_amt) AS net_total_revenue
    FROM RecentTransactions t
    JOIN EligibleCustomers e ON t.cust_id = e.customer_Id
)

-- Step 5: Select the result
SELECT net_total_revenue
FROM NetTotalRevenue;

12. Which product category has seen the max value of returns in the last 3 months of transactions?

-- Step 1: Determine the maximum transaction date
WITH MaxTranDate AS (
    SELECT MAX(tran_date) AS max_date
    FROM transactions_new
),

-- Step 2: Filter transactions within the last 3 months from the maximum transaction date
RecentTransactions AS (
    SELECT t.*, m.max_date
    FROM transactions_new t
    CROSS JOIN MaxTranDate m
    WHERE DATE(t.tran_date) BETWEEN DATE_SUB(m.max_date, INTERVAL 3 MONTH) AND m.max_date
),

-- Step 3: Join recent transactions with product category information and calculate returns
ReturnsByCategory AS (
    SELECT 
        p.prod_cat_code,
        p.prod_cat,
        SUM(t.total_amt) AS total_returns
    FROM 
        RecentTransactions t
    JOIN 
        prod_cat_info p ON t.prod_cat_code = p.prod_cat_code
    WHERE 
        t.total_amt < 0  -- Assuming returns have negative total amounts
    GROUP BY 
        p.prod_cat_code, p.prod_cat
),

-- Step 4: Find the product category with the maximum value of returns
MaxReturnsCategory AS (
    SELECT 
        prod_cat,
        total_returns
    FROM 
        ReturnsByCategory
    ORDER BY 
        total_returns DESC
    LIMIT 1
)

-- Step 5: Select the result
SELECT 
    prod_cat,
    total_returns
FROM 
    MaxReturnsCategory;

13. Which store-type sells the maximum products; by value of sales amount and by quantity sold?

WITH SalesByStoreType AS (
    SELECT 
        Store_type,
        SUM(Qty) AS total_quantity_sold,
        SUM(total_amt) AS total_sales_amount
    FROM 
        transactions_new
    GROUP BY 
        Store_type
)

SELECT 
    Store_type,
    total_quantity_sold,
    total_sales_amount
FROM 
    SalesByStoreType
WHERE 
    total_quantity_sold = (SELECT MAX(total_quantity_sold) FROM SalesByStoreType)
    OR total_sales_amount = (SELECT MAX(total_sales_amount) FROM SalesByStoreType);


14. What are the categories for which average revenue is above the overall average.

WITH CategoryAvgRevenue AS (
    SELECT 
        prod_cat_code,
        AVG(total_amt) AS avg_revenue
    FROM 
        transactions_new
    GROUP BY 
        prod_cat_code
),
OverallAvgRevenue AS (
    SELECT 
        AVG(total_amt) AS overall_avg_revenue
    FROM 
        transactions_new
)

SELECT 
    p.prod_cat,
    c.avg_revenue
FROM 
    CategoryAvgRevenue c
JOIN 
    OverallAvgRevenue o ON c.avg_revenue > o.overall_avg_revenue
JOIN 
    prod_cat_info p ON c.prod_cat_code = p.prod_cat_code;

15. Find the average and total revenue by each subcategory for the categories which are among top 5 categories in terms of quantity sold.

WITH TopCategories AS (
    SELECT 
        prod_cat_code,
        SUM(Qty) AS total_quantity_sold
    FROM 
        transactions_new
    GROUP BY 
        prod_cat_code
    ORDER BY 
        total_quantity_sold DESC
    LIMIT 5
),
SubcategoryRevenue AS (
    SELECT 
        t.prod_subcat_code,
        p.prod_subcat,
        SUM(t.total_amt) AS total_revenue,
        AVG(t.total_amt) AS avg_revenue
    FROM 
        transactions_new t
    JOIN 
        prod_cat_info p ON t.prod_subcat_code = p.prod_sub_cat_code
    JOIN 
        TopCategories tc ON t.prod_cat_code = tc.prod_cat_code
    GROUP BY 
        t.prod_subcat_code, p.prod_subcat
)

SELECT 
    prod_subcat,
    total_revenue,
    avg_revenue
FROM 
    SubcategoryRevenue
ORDER BY 
    total_revenue DESC;
