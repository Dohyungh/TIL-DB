-- 코드를 작성해주세요
SELECT COUNT(*) as FISH_COUNT, month(TIME) as MONTH
FROM FISH_INFO
GROUP BY month(TIME)
ORDER BY MONTH