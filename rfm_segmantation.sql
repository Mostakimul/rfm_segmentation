use superstore;-- using superstore database

SELECT 
    COUNT(*)
FROM
    superstore_sales AS TOTAL_RECORDS;-- 9033

SELECT 
    *
FROM
    superstore_sales
LIMIT 10; -- check for records are showing correctly

-- SAFE UPDATE
SET SQL_SAFE_UPDATES=0;

-- UPDATING ORDER_DATE
UPDATE superstore_sales 
SET 
    ORDER_DATE = STR_TO_DATE('1899-12-30', '%Y-%m-%d') + INTERVAL ORDER_DATE DAY;
    
-- UPDATING SHIP_DATE
UPDATE superstore_sales 
SET 
    SHIP_DATE = STR_TO_DATE('1899-12-30', '%Y-%m-%d') + INTERVAL SHIP_DATE DAY;
    
-- CREATING A VIEW WITH UNIQUE ORDER_ID
CREATE OR REPLACE VIEW unique_superstore_sales AS
SELECT * 
FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY ORDER_ID ORDER BY ORDER_ID) AS RN
    FROM superstore_sales
) t
WHERE RN = 1;

-- SELECT ALL
SELECT 
    *
FROM
    unique_superstore_sales
ORDER BY ORDER_DATE DESC;

SELECT 
    COUNT(*)
FROM
    unique_superstore_sales
LIMIT 10;-- 6274

SELECT 
    MIN(ORDER_DATE) AS FIRST_ORDER,
    MAX(ORDER_DATE) AS LAST_ORDER
FROM
    unique_superstore_sales;
    
-- FINDING LAST ORDER BY CUSTOMER
SELECT 
    CUSTOMER_NAME, MAX(ORDER_DATE) AS LAST_ORDER
FROM
    unique_superstore_sales
GROUP BY 1;

--  LAST TRANSACTION OF BUSINESS
SELECT 
    CUSTOMER_NAME, MAX(ORDER_DATE) AS LAST_ORDER
FROM
    unique_superstore_sales
GROUP BY 1
ORDER BY LAST_ORDER;

-- LAST TRANSACTION DATE
SELECT 
    MAX(ORDER_DATE)
FROM
    unique_superstore_sales;-- 2013-12-31

SELECT 
    CUSTOMER_NAME,
    MAX(ORDER_DATE) AS LAST_ORDER,
    DATEDIFF((SELECT 
                    MAX(ORDER_DATE)
                FROM
                    unique_superstore_sales),
            MAX(ORDER_DATE)) AS RECENCY
FROM
    unique_superstore_sales
GROUP BY 1
ORDER BY RECENCY;


-- RFM Segmentation: Segment the customer based on their Recency (R), Frequency (F) and Monetary (M)
-- Common table expression (CTE)
-- Making view for simplicity

create or replace view RFM_SCORE_DATA as(
WITH CUSTOMER_AGGREGATED_DATA AS
(SELECT 
    CUSTOMER_NAME,
    DATEDIFF((SELECT 
                    MAX(ORDER_DATE)
                FROM
                    unique_superstore_sales),
            MAX(ORDER_DATE)) AS RECENCY,
    COUNT(DISTINCT (ORDER_ID)) AS FREQUENCY,
    ROUND(SUM(SALES), 0) AS MONEYTARY
FROM
    unique_superstore_sales
GROUP BY CUSTOMER_NAME),
-- group number by valuable customer
-- Window function (NTILE)
RFM_SCORE AS (
SELECT C.*,
NTILE(4) OVER (ORDER BY RECENCY desc) AS R_SCORE,
NTILE(4) OVER (ORDER BY FREQUENCY ASC) AS F_SCORE,
	NTILE(4) OVER (ORDER BY MONEYTARY ASC) AS M_SCORE
 FROM CUSTOMER_AGGREGATED_DATA AS C)
 SELECT 
 R.*, 
( R_SCORE + F_SCORE + M_SCORE) AS TOTAL_RFM_SCORE,
concat_ws('',R_SCORE, F_SCORE, M_SCORE ) AS RFM_SCORE_COMBINATION
 FROM RFM_SCORE AS R);
 
 -- SELECT RFM SCORE DATA
SELECT 
    *
FROM
    rfm_score_data
WHERE
    M_SCORE = 4;
 
 -- CREATING VIEW FOR RFM_ANALYSIS
CREATE OR REPLACE VIEW RFM_ANALYSIS AS
    (SELECT 
        rfm_score_data.*,
        CASE
            WHEN rfm_score_combination IN (111 , 112, 121, 132, 211, 211, 212, 114, 141) THEN 'CHURNED CUSTOMER'
            WHEN rfm_score_combination IN (133 , 134, 143, 224, 334, 343, 344, 144) THEN 'SLIPPING AWAY, CANNOT LOSE'
            WHEN rfm_score_combination IN (311 , 411, 331) THEN 'NEW CUSTOMER'
            WHEN rfm_score_combination IN (222 , 231, 221, 223, 233, 322) THEN 'POTENTIAL CHURNERS'
            WHEN rfm_score_combination IN (323 , 333, 321, 341, 422, 332, 432) THEN 'ACTIVE'
            WHEN rfm_score_combination IN (433 , 434, 443, 444) THEN 'LOYAL'
            ELSE 'CANNOT BE DEFINED'
        END AS CUSTOMER_SEGMENT
    FROM
        rfm_score_data);
    
    
SELECT 
    CUSTOMER_SEGMENT,
    COUNT(*) AS NUMBER_OF_CUSTOMER,
    ROUND(AVG(MONEYTARY), 0) AS AVERAGE_MONETARY_VALUE
FROM
    RFM_ANALYSIS
GROUP BY CUSTOMER_SEGMENT;
