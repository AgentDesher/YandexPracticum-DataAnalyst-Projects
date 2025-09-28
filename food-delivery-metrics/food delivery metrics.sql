-- 1. DAU 
-- Рассчитаем ежедневное количество активных зарегистрированных клиентов 
-- (user_id) за май и июнь 2021 года в городе Саранске. 

SELECT log_date,
       COUNT(DISTINCT user_id) DAU
FROM analytics_events as ae
JOIN cities as c using(city_id)
WHERE DATE(log_date) BETWEEN '2021-05-01' AND '2021-06-30' 
  AND city_name = 'Саранск'
  AND order_id IS NOT NULL
GROUP BY log_date
ORDER BY log_date ASC

log_date	dau
2021-05-01	56
2021-05-02	36
2021-05-03	72
2021-05-04	85
2021-05-05	60

-- 2. Conversion Rate
-- Определить активность аудитории: как часто зарегистрированные пользователи переходят к размещению заказа, 
-- существуют ли колебания показателя по дням или видны сезонные колебания в поведении пользователей. 

SELECT log_date,
       ROUND((COUNT(DISTINCT user_id) filter (WHERE order_id IS NOT NULL)) / COUNT(DISTINCT user_id)::numeric, 2) CR
FROM analytics_events as ae
JOIN cities as c using(city_id)
WHERE DATE(log_date) BETWEEN '2021-05-01' AND '2021-06-30' AND city_name = 'Саранск'
GROUP BY log_date
ORDER BY log_date ASC

-- log_date	cr
-- 2021-05-01	0.43
-- 2021-05-02	0.28
-- 2021-05-03	0.41
-- 2021-05-04	0.41
-- 2021-05-05	0.32
-- ...
-- 2021-06-26	0.31
-- 2021-06-27	0.3
-- 2021-06-28	0.22
-- 2021-06-29	0.31
-- 2021-06-30	0.37

-- 3. Средний чек. Рассчитаем размер среднего чека для мая и июня.
-- Рассчитываем величину комиссии с каждого заказа, отбираем заказы по дате и городу
WITH orders AS
    (SELECT *,
            revenue * commission AS commission_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск')

SELECT 
        CAST(DATE_TRUNC('month', log_date) AS date) AS "Месяц",
        COUNT(DISTINCT order_id) AS "Количество заказов",
        ROUND(SUM(commission_revenue)::numeric, 2) AS "Сумма комиссии",
        ROUND((SUM(commission_revenue) / COUNT(DISTINCT order_id))::numeric, 2) AS "Средний чек"
FROM orders
GROUP BY CAST(DATE_TRUNC('month', log_date) AS date)
ORDER BY 1 ASC

-- Месяц	Количество заказов	Сумма комиссии	Средний чек
-- 2021-05-01	2111	286852	135.88
-- 2021-06-01	2225	328539	147.66


-- 4. LTV. Определим три ресторана из Саранска с наибольшим LTV с начала мая до конца июня. 
-- Рассчитываем величину комиссии с каждого заказа, отбираем заказы по дате и городу
WITH orders AS
    (SELECT analytics_events.rest_id,
            analytics_events.city_id,
            revenue * commission AS commission_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск')
SELECT 
        o.rest_id,
        chain AS "Название сети",
        type AS "Тип кухни",
        ROUND(SUM(commission_revenue)::numeric, 2) LTV
FROM orders as o
JOIN partners as p ON p.rest_id = o.rest_id and p.city_id = o.city_id
GROUP BY o.rest_id, 
         chain, 
         type
ORDER BY LTV DESC
LIMIT 3

-- rest_id	Название сети	Тип кухни	ltv
-- 2e2b2b9c458b42ce9da395ba9c247fdc	Гурманское Наслаждение	Ресторан	170479
-- b94505e7efff41d2b2bf6bbb78fe71f2	Гастрономический Шторм	Ресторан	164508
-- 42d14fe9fd254ba9b18ab4acd64d4f33	Шоколадный Рай	Кондитерская	61199.8

-- 5. LTV наиблоее популярных блюд.-- Рассчитываем величину комиссии с каждого заказа, отбираем заказы по дате и городу
WITH orders AS
    (SELECT analytics_events.rest_id,
            analytics_events.city_id,
            analytics_events.object_id,
            revenue * commission AS commission_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'), 
-- Рассчитываем два ресторана с наибольшим LTV 
top_ltv_restaurants AS
    (SELECT orders.rest_id,
            chain,
            type,
            ROUND(SUM(commission_revenue)::numeric, 2) AS LTV
     FROM orders
     JOIN partners ON orders.rest_id = partners.rest_id AND orders.city_id = partners.city_id
     GROUP BY 1, 2, 3
     ORDER BY LTV DESC
     LIMIT 2)
SELECT 
        chain AS "Название сети",
        name AS "Название блюда",
        spicy,
        fish,
        meat,
        ROUND(SUM(commission_revenue)::numeric, 2) AS LTV
FROM top_ltv_restaurants t
JOIN orders as o ON o.rest_id = t.rest_id 
JOIN dishes as d ON d.rest_id = t.rest_id and d.object_id = o.object_id
GROUP BY chain, 
        o.object_id, 
        name,         
        spicy,
        fish,
        meat
ORDER BY LTV DESC
LIMIT 5

-- Название сети	Название блюда	spicy	fish	meat	ltv
-- Гастрономический Шторм	brokkoli zapechennaja v duhovke s jajcami i travami	0	1	1	41140.4
-- Гурманское Наслаждение	govjazhi shashliki v pesto iz kinzi	0	1	1	36676.8
-- Гурманское Наслаждение	medaloni iz lososja	0	1	1	14946.9
-- Гурманское Наслаждение	myasnye ezhiki	0	0	1	14337.9
-- Гастрономический Шторм	teljatina s sousom iz belogo vina petrushki	0	1	1	13981

-- 6. Retention Rate. Определим какой процент пользователей возвращается в приложение 
-- в течение первой недели после регистрации и в какие дни.
-- Рассчитываем новых пользователей по дате первого посещения продукта
WITH new_users AS
    (SELECT DISTINCT first_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE first_date BETWEEN '2021-05-01' AND '2021-06-24'
         AND city_name = 'Саранск'),
-- Рассчитываем активных пользователей по дате события
active_users AS
    (SELECT DISTINCT log_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'),
-- Срок жизни пользователя
daily_retention as (
    SELECT
        n.user_id,
        first_date,
        log_date::date - first_date::date as day_since_install
    FROM new_users n
    JOIN active_users using(user_id)
    WHERE log_date >= first_date)
SELECT 
    day_since_install,
    COUNT(DISTINCT user_id) retained_users,
    ROUND(1.0 * COUNT(DISTINCT user_id) / (select count(DISTINCT user_id) from new_users), 2) AS retention_rate
FROM daily_retention
WHERE day_since_install < 8
GROUP BY day_since_install
ORDER BY day_since_install ASC

-- |day_since_install|retained_users|retention_rate|
-- |-----------------|--------------|--------------|
-- |				0|			5572|	 		  1|
-- |				1|			 768|		   0.14|
-- |				2|			 419|		   0.08|
-- |				3|			 283|		   0.05|
-- |				4|			 251|		   0.05|
-- |				5|			 207|		   0.04|
-- |				6|			 205|		   0.04|
-- |				7|			 205|		   0.04|

-- 7. Retention Rate по месяцам
-- Рассчитываем новых пользователей по дате первого посещения продукта
WITH new_users AS
    (SELECT DISTINCT first_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE first_date BETWEEN '2021-05-01' AND '2021-06-24'
         AND city_name = 'Саранск'),
-- Рассчитываем активных пользователей по дате события
active_users AS
    (SELECT DISTINCT log_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'),
-- Соединяем таблицы с новыми и активными пользователями
daily_retention AS
    (SELECT new_users.user_id,
            first_date,
            log_date::date - first_date::date AS day_since_install
     FROM new_users
     JOIN active_users ON new_users.user_id = active_users.user_id
     AND log_date >= first_date)
SELECT 
    CAST(DATE_TRUNC('month', first_date) AS date) AS "Месяц",
    day_since_install,
    COUNT(DISTINCT user_id) retained_users,
    ROUND(1.0 * COUNT(DISTINCT user_id) / MAX(COUNT(DISTINCT user_id)) OVER (PARTITION BY CAST(DATE_TRUNC('month', first_date) AS date) ORDER by day_since_install), 2) AS retention_rate 
FROM daily_retention
WHERE day_since_install < 8
GROUP BY "Месяц", day_since_install
ORDER BY "Месяц", day_since_install ASC
--
-- |Месяц		|day_since_install|retained_users|retention_rate|
-- |------------|-----------------|--------------|--------------|
-- |2021-05-01	|				 0|			 3069|			   1|
-- |2021-05-01	|				 1|			  443|			0.14|
-- |2021-05-01	|				 2|			  223|			0.07|
-- |2021-05-01	|				 3|			  144|			0.05|
-- |2021-05-01	|				 4|			  142|			0.05|
-- ...
-- |2021-06-01	|				 2|			  196|			0.08|
-- |2021-06-01	|				 3|			  140|			0.05|
-- |2021-06-01	|				 4|			  109|			0.04|
-- |2021-06-01	|				 5|			   86|			0.03|
-- |2021-06-01	|				 6|			   85|			0.03|
-- |2021-06-01	|				 7|			   65|			0.03|


