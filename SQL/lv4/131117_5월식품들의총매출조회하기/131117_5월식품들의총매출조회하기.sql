-- 코드를 입력하세요
SELECT FOOD_ORDER.PRODUCT_ID, PRODUCT_NAME, PRICE * SUM(AMOUNT) TOTAL_SALES
FROM FOOD_ORDER 
JOIN FOOD_PRODUCT
ON FOOD_ORDER.PRODUCT_ID = FOOD_PRODUCT.PRODUCT_ID
WHERE DATE_FORMAT(PRODUCE_DATE, '%Y-%m') = '2022-05'
GROUP BY PRODUCT_ID
ORDER BY TOTAL_SALES DESC, PRODUCT_ID ASC