WITH SALES AS (
    SELECT *, SUM(SALES) AS SUMS
    FROM BOOK_SALES
    WHERE year(SALES_DATE) = 2022 AND month(SALES_DATE) = 1
    GROUP BY BOOK_ID
),
A AS (
    SELECT SALES.SUMS, BOOK.*
    FROM SALES
    JOIN BOOK
    ON SALES.BOOK_ID = BOOK.BOOK_ID
),
CTE AS (
    SELECT AUTHOR.AUTHOR_NAME, A.*
    FROM AUTHOR
    JOIN A
    ON AUTHOR.AUTHOR_ID = A.AUTHOR_ID
)
SELECT AUTHOR_ID AS AUTHOR_ID, AUTHOR_NAME, CATEGORY AS CATEGORY, SUM(SUMS * PRICE) AS TOTAL_SALES
FROM CTE
GROUP BY AUTHOR_ID, CATEGORY
ORDER BY AUTHOR_ID, CATEGORY DESC