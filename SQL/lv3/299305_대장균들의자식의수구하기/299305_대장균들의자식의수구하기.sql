-- 코드를 작성해주세요
SELECT ECOLI_DATA.ID, IFNULL(C.CHILD_COUNT, 0) AS CHILD_COUNT FROM ECOLI_DATA left JOIN
(SELECT A.ID, CASE
WHEN COUNT(*) = 0 THEN 0
ELSE COUNT(*) END AS CHILD_COUNT
FROM ECOLI_DATA AS A JOIN ECOLI_DATA AS B ON A.ID = B.PARENT_ID
GROUP BY B.PARENT_ID ) AS C ON ECOLI_DATA.ID = C.ID
ORDER BY ECOLI_DATA.ID
