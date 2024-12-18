-- 코드를 입력하세요
WITH JULY_ORDER AS (
    SELECT FLAVOR, SUM(TOTAL_ORDER) AS SUMS
    FROM JULY
    GROUP BY FLAVOR
),
CTE AS (
    SELECT FIRST_HALF.TOTAL_ORDER + JULY_ORDER.SUMS AS ORDERS, JULY_ORDER.FLAVOR
    FROM JULY_ORDER
    JOIN FIRST_HALF
    ON JULY_ORDER.FLAVOR = FIRST_HALF.FLAVOR
)
SELECT FLAVOR
FROM CTE
ORDER BY ORDERS DESC
LIMIT 0, 3