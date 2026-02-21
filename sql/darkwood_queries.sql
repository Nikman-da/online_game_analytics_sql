/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: 
 * Дата: 
*/
-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков
-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь
SELECT
	COUNT(payer) AS total_users, -- общее количество игроков
	SUM(payer) AS total_payers, -- количество платящих игроков
	ROUND(AVG(payer),4) AS share_payers --доля платящих игроков
FROM fantasy.users;
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь
SELECT
	r.race,
	SUM(u.payer) AS total_payers,
	COUNT(u.payer) AS total_players,
	AVG(u.payer)::NUMERIC(5,4) AS share_payers
FROM fantasy.users AS u
JOIN fantasy.race AS r USING(race_id)
GROUP BY r.race
ORDER BY total_players DESC;
-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь
--Статистика по всем показателям поля amount
SELECT
	COUNT(amount) AS total_amount,
	SUM(amount) AS sum_amount,
	MIN(amount) AS min_amount,
	MAX(amount) AS max_amount,
	AVG(amount)::numeric(6,2) AS avg_amount,
	PERCENTILE_CONT(0.5)WITHIN GROUP (ORDER BY amount)::numeric(6,2) AS median,
	STDDEV(amount)::numeric(6,2) AS stand_dev
FROM fantasy.events;
--Статистика по полю amount без нулевых покупок
SELECT
	COUNT(amount) AS total_amount,
	SUM(amount) AS sum_amount,
	MIN(amount) AS min_amount,
	MAX(amount) AS max_amount,
	AVG(amount)::numeric(6,2) AS avg_amount,
	PERCENTILE_CONT(0.5)WITHIN GROUP (ORDER BY amount)::numeric(6,2) AS median,
	STDDEV(amount)::numeric(6,2) AS stand_dev
FROM fantasy.events
WHERE amount > 0;
-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь
SELECT
  COUNT(*) FILTER (WHERE amount = 0) AS zero_buy,
  (COUNT(*) FILTER (WHERE amount = 0)::real / COUNT(*))::numeric(5,4) AS zero_part_buy
FROM fantasy.events; 
-- 2.3: Популярные эпические предметы:
-- Напишите ваш запрос здесь
--СТЕ для расчета показателей покупок по предметам
WITH item_info AS (
	SELECT
		i.item_code,
        i.game_items,
		COUNT(e.amount) AS item_sell,
		COUNT (DISTINCT id) AS unique_id
	FROM fantasy.events AS e
	JOIN fantasy.items AS i ON e.item_code = i.item_code 
	WHERE amount > 0
	GROUP BY i.item_code
	ORDER BY item_sell DESC
),
--CTE для расчета общих значений
events_info AS (
	SELECT 
		COUNT(amount) AS total_buy,
		COUNT(DISTINCT id) AS total_unique_id
	FROM fantasy.events 
	WHERE amount > 0
	)
SELECT 
	game_items,
	(item_sell::real/(SELECT total_buy FROM events_info))::numeric(5,4) AS per_buy,
	(unique_id::REAL/(SELECT total_unique_id FROM events_info))::numeric(5,4) AS per_players
FROM item_info;
-- Часть 2. Решение ad hoc-задачbи
-- Задача: Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь
WITH users_race AS(
	SELECT
		race_id,
		COUNT(u.id) AS total_users
	FROM fantasy.users AS u 
	GROUP BY race_id
),
payer_race AS (
	SELECT 
		race_id,
		COUNT(id) AS buyer_players,
		AVG(payer)::numeric(5,4) AS per_payer_players
	FROM fantasy.users
	WHERE id IN (SELECT DISTINCT id FROM fantasy.events WHERE amount > 0)
	GROUP BY race_id
),
users_statistics AS (
	SELECT
		race_id,
		COUNT(transaction_id) AS total_buyers,
		SUM(amount) AS total_amount
	FROM fantasy.events AS e
	JOIN fantasy.users AS u ON e.id = u.id 
	WHERE amount > 0
	GROUP BY race_id
)
SELECT 
	r.race,
	ur.total_users,
	pr.buyer_players,
	(pr.buyer_players/total_users::real)::numeric(5,4) AS per_buyer_players,
	pr.per_payer_players,
	(us.total_buyers/pr.buyer_players::REAL)::numeric(5,2) AS avg_buy_player,
	(us.total_amount/us.total_buyers::REAL)::numeric(5,2) AS avg_amount_player,
	(us.total_amount/pr.buyer_players::REAL)::numeric(7,2) AS avg_amount_sum
FROM users_race AS ur
JOIN fantasy.race AS r ON ur.race_id = r.race_id
JOIN payer_race AS pr ON ur.race_id = pr.race_id
JOIN users_statistics AS us ON ur.race_id = us.race_id
ORDER BY total_users DESC
