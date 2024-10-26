-- 코드를 입력하세요
WITH SEOUL AS (
    SELECT *
    FROM REST_INFO
    WHERE ADDRESS LIKE '서울%'
),
SCORES AS (
    SELECT ROUND(AVG(REVIEW_SCORE), 2) AS SCORE, REST_ID
    FROM REST_REVIEW
    GROUP BY REST_ID
)
SELECT SEOUL.REST_ID, REST_NAME, FOOD_TYPE, FAVORITES, ADDRESS, SCORES.SCORE AS SCORE
FROM SEOUL
JOIN SCORES
ON SEOUL.REST_ID = SCORES.REST_ID
ORDER BY SCORE DESC, FAVORITES DESC