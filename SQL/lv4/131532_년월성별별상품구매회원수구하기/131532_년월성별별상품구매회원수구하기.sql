-- 코드를 입력하세요
WITH CTE AS (
    SELECT DISTINCT ONLINE_SALE.USER_ID, year(SALES_DATE) AS YEAR, month(SALES_DATE) AS MONTH, USER_INFO.GENDER
    FROM ONLINE_SALE
    JOIN USER_INFO
    ON ONLINE_SALE.USER_ID = USER_INFO.USER_ID
)
SELECT YEAR, MONTH, GENDER, COUNT(DISTINCT USER_ID) USERS
FROM CTE
WHERE GENDER IS NOT NULL
GROUP BY YEAR, MONTH, GENDER