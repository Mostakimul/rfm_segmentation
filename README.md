# Superstore Sales Data Import Guide

## Overview

This guide outlines the steps to import the **Superstore Sales** dataset into **MySQL Workbench** and verify data integrity.

## Steps to Import Data

### 1. Prepare the CSV File

- Ensure column names are formatted correctly (e.g., no spaces, consistent naming conventions).
- Verify data consistency and completeness.

### 2. Import into MySQL Workbench

- Open **MySQL Workbench**.
- Create a database if not already created:

  ```sql
  CREATE DATABASE superstore;
  USE superstore;
  ```

- Use **Data Import Wizard** to import the CSV file into the `superstore_sales` table.

### 3. Verify Data Import

To ensure that all records have been successfully imported, run the following SQL query:

```sql
SELECT COUNT(*) FROM superstore_sales AS TOTAL_RECORDS;
```

Expected Output:

```sql
+---------------+
| TOTAL_RECORDS |
+---------------+
|     9033      |
+---------------+
```

## Notes

- Ensure that the CSV file encoding is **UTF-8** to prevent character corruption.
- If there are import errors, check for missing or incorrectly formatted data.

### 4. Updating Date Fields

After importing the data, the `ORDER_DATE` and `SHIP_DATE` columns may be stored as numeric values instead of proper date formats. To correct this, follow these steps:

- Disable safe update mode to allow updates:
  ```sql
  SET SQL_SAFE_UPDATES=0;
  ```
- Convert `ORDER_DATE` from text format to an actual date:
  ```sql
  UPDATE superstore_sales
  SET
      ORDER_DATE = STR_TO_DATE('1899-12-30', '%Y-%m-%d') + INTERVAL ORDER_DATE DAY;
  ```
- Convert `SHIP_DATE` from text format to an actual date:
  ```sql
  UPDATE superstore_sales
  SET
      SHIP_DATE = STR_TO_DATE('1899-12-30', '%Y-%m-%d') + INTERVAL SHIP_DATE DAY;
  ```

These updates ensure that the dates are correctly formatted and can be used for date-based queries.

### 5. Creating a View for Unique Orders

To work with unique orders and avoid duplicate entries based on `ORDER_ID`, create a view using the following SQL:

- Create or replace a view that selects only the first occurrence of each `ORDER_ID`:

  ```sql
  CREATE OR REPLACE VIEW unique_superstore_sales AS
  SELECT *
  FROM (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY ORDER_ID ORDER BY ORDER_ID) AS RN
      FROM superstore_sales
  ) t
  WHERE RN = 1;
  ```

- Verify the unique orders by selecting all records, ordered by `ORDER_DATE` in descending order:

  ```sql
  SELECT * FROM unique_superstore_sales ORDER BY ORDER_DATE DESC;
  ```

- Count the number of unique orders:

  ```sql
  SELECT COUNT(*) FROM unique_superstore_sales;
  ```

  Expected Output:

  ```sql
  +----------+
  | COUNT(*) |
  +----------+
  |   6274   |
  +----------+
  ```

- Retrieve the first and last order dates in the dataset:
  ```sql
  SELECT
      MIN(ORDER_DATE) AS FIRST_ORDER,
      MAX(ORDER_DATE) AS LAST_ORDER
  FROM unique_superstore_sales;
  ```
  Expected Output:
  ```sql
  +-------------------------+
  | FIRST_ORDER | LAST_ORDER
  +-------------------------+
  | 2010-01-02  | 2013-12-31
  +-------------------------+
  ```

This view ensures that each order is counted only once, making it useful for aggregate analysis and reporting.

### 6. Analyzing Customer Transactions

To analyze customer transaction history, use the following queries:

- Find the last order date for each customer:

  ```sql
  SELECT
      CUSTOMER_NAME, MAX(ORDER_DATE) AS LAST_ORDER
  FROM unique_superstore_sales
  GROUP BY 1;
  ```

  Expected Output:

  ```
  | CUSTOMER_NAME      | LAST_ORDER  |
  |--------------------|-------------|
  | Dana Teague        | 2013-05-25  |
  | Vanessa Boyer      | 2013-07-21  |
  | Wesley Tate        | 2013-12-25  |
  | Brian Grady        | 2012-04-05  |
  | Kristine Connolly  | 2013-05-30  |
  ```

- Find the last transaction of the business, ordered by date:

  ```sql
  SELECT
      CUSTOMER_NAME, MAX(ORDER_DATE) AS LAST_ORDER
  FROM unique_superstore_sales
  GROUP BY 1
  ORDER BY LAST_ORDER;
  ```

- Find the latest transaction date in the dataset:
  ```sql
  SELECT MAX(ORDER_DATE) FROM unique_superstore_sales;
  ```
  Expected Output:
  ```sql
  +--------------+
  | MAX(ORDER_DATE) |
  +--------------+
  | 2013-12-31 |
  +--------------+
  ```

### 7. Creating RFM Score Data View

To segment customers based on **Recency, Frequency, and Monetary (RFM)** value, create a view using:

- Compute RFM scores:
  ```sql
  CREATE OR REPLACE VIEW RFM_SCORE_DATA AS (
  WITH CUSTOMER_AGGREGATED_DATA AS (
      SELECT
          CUSTOMER_NAME,
          DATEDIFF((SELECT MAX(ORDER_DATE) FROM unique_superstore_sales), MAX(ORDER_DATE)) AS RECENCY,
          COUNT(DISTINCT (ORDER_ID)) AS FREQUENCY,
          ROUND(SUM(SALES), 0) AS MONETARY
      FROM unique_superstore_sales
      GROUP BY CUSTOMER_NAME
  ),
  RFM_SCORE AS (
      SELECT C.*,
          NTILE(4) OVER (ORDER BY RECENCY DESC) AS R_SCORE,
          NTILE(4) OVER (ORDER BY FREQUENCY ASC) AS F_SCORE,
          NTILE(4) OVER (ORDER BY MONETARY ASC) AS M_SCORE
      FROM CUSTOMER_AGGREGATED_DATA AS C
  )
  SELECT
      R.*,
      (R_SCORE + F_SCORE + M_SCORE) AS TOTAL_RFM_SCORE,
      CONCAT_WS('', R_SCORE, F_SCORE, M_SCORE) AS RFM_SCORE_COMBINATION
  FROM RFM_SCORE AS R
  );
  ```

This view categorizes customers into segments based on their purchasing behavior, helping identify valuable customers.

### 8. Creating the RFM Analysis View

The following SQL script creates or replaces a view named `RFM_ANALYSIS`, which categorizes customers into different segments based on their RFM score combination.

```sql
-- Creating View for RFM Analysis
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
```

## Retrieving RFM Analysis Results

To get insights from the `RFM_ANALYSIS` view, use the following SQL query:

```sql
SELECT
    CUSTOMER_SEGMENT,
    COUNT(*) AS NUMBER_OF_CUSTOMER,
    ROUND(AVG(MONEYTARY), 0) AS AVERAGE_MONETARY_VALUE
FROM
    RFM_ANALYSIS
GROUP BY CUSTOMER_SEGMENT;
```

| CUSTOMER SEGMENT           | NUMBER OF CUSTOMERS | AVERAGE MONETARY VALUE |
| -------------------------- | ------------------- | ---------------------- |
| CHURNED CUSTOMER           | 547                 | 338                    |
| CANNOT BE DEFINED          | 562                 | 2349                   |
| ACTIVE                     | 345                 | 709                    |
| POTENTIAL CHURNERS         | 250                 | 712                    |
| NEW CUSTOMER               | 12                  | 150                    |
| LOYAL                      | 384                 | 6012                   |
| SLIPPING AWAY, CANNOT LOSE | 279                 | 6135                   |

## Customer Segments Explained

- **CHURNED CUSTOMER**: Customers who have stopped engaging.
- **SLIPPING AWAY, CANNOT LOSE**: Customers at risk of leaving and need attention.
- **NEW CUSTOMER**: Recently acquired customers.
- **POTENTIAL CHURNERS**: Customers showing signs of inactivity.
- **ACTIVE**: Regular customers who are consistently engaging.
- **LOYAL**: Highly engaged and valuable customers.
- **CANNOT BE DEFINED**: Customers who do not fit into predefined categories.

## Usage

- This analysis helps businesses identify different customer behaviors.
- It enables targeted marketing and retention strategies based on customer segments.
- Businesses can prioritize efforts on retaining high-value customers while re-engaging slipping or churned customers.
