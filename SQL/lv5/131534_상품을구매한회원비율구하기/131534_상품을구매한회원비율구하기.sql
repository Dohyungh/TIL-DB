-- 코드를 입력하세요
WITH MEMBERS AS (
    SELECT USER_ID
    FROM USER_INFO
    WHERE year(JOINED) = 2021
),
PURCHASED AS (
    SELECT COUNT(DISTINCT USER_ID) AS COUNT, year(SALES_DATE) AS YEAR, month(SALES_DATE) AS MONTH
    FROM ONLINE_SALE
    WHERE USER_ID IN (SELECT * FROM MEMBERS)
    GROUP BY year(SALES_DATE), month(SALES_DATE)
)
SELECT PURCHASED.YEAR, PURCHASED.MONTH, PURCHASED.COUNT AS PURCHASED_USERS, 
ROUND(PURCHASED.COUNT / (SELECT COUNT(*) FROM MEMBERS), 1) AS PURCHASED_RATIO
FROM PURCHASED
ORDER BY YEAR ASC, MONTH ASC