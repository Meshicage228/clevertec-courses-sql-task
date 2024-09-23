-- Вывести к каждому самолету класс обслуживания и количество мест этого класса

SELECT air.model AS model, s.fare_conditions AS condition, count(s.seat_no) AS seat_count
FROM aircrafts AS air
JOIN seats AS s ON air.aircraft_code = s.aircraft_code
GROUP BY model, condition;

-- Найти 3 самых вместительных самолета (модель + кол-во мест)

SELECT air.model AS model, count(air.model) AS seats_count
FROM aircrafts AS air
JOIN seats ON air.aircraft_code = seats.aircraft_code
GROUP BY model
LIMIT 3;

-- Вывести код, модель самолета и места не эконом класса для самолета 'Аэробус A321-200' с сортировкой по местам

SELECT air.aircraft_code, air.model, s.seat_no AS seat_number
FROM aircrafts AS air
JOIN seats AS s ON air.aircraft_code = s.aircraft_code
WHERE s.fare_conditions != 'Economy' AND air.model = 'Аэробус A321-200'
ORDER BY seat_number;

-- Вывести города в которых больше 1 аэропорта ( код аэропорта, аэропорт, город)

WITH cities AS (SELECT ad.city AS city
                FROM airports_data AS ad
                GROUP BY ad.city
                HAVING count(ad.city) > 1)
SELECT ad.airport_code, ad.airport_name, ad.city
FROM airports_data AS ad
WHERE ad.city IN (SELECT city FROM cities);

-- Найти ближайший вылетающий рейс из Екатеринбурга в Москву, на который еще не завершилась регистрация

SELECT f.* FROM flights f
JOIN airports dep_air ON f.departure_airport = dep_air.airport_code
JOIN airports arr_air ON f.arrival_airport = arr_air.airport_code
WHERE dep_air.city = 'Санкт-Петербург'
  AND arr_air.city = 'Москва'
  AND f.status NOT IN ('Cancelled', 'Arrived', 'Departed')
ORDER BY f.scheduled_departure ASC
LIMIT 1;

-- Вывести самый дешевый и дорогой билет и стоимость (в одном результирующем ответе)

select t.*, max_el.max_amount AS amount FROM tickets AS t
JOIN (
    SELECT max(amount) AS max_amount, ticket_no AS max_n
    FROM ticket_flights
    GROUP BY max_n
    ORDER BY max_amount DESC
    LIMIT 1
) AS max_el ON t.ticket_no = max_el.max_n
UNION ALL
SELECT t.*, min_el.min_amount AS amount FROM tickets AS t
JOIN (
    SELECT min(amount) AS min_amount, ticket_no AS min_n
    FROM ticket_flights
    GROUP BY min_n
    ORDER BY min_amount ASC
    LIMIT 1
) AS min_el ON t.ticket_no = min_el.min_n;

-- Вывести информацию о вылете с наибольшей суммарной стоимостью билетов

-- Первое решение : чуть медленней
--WITH sums AS (SELECT sum(tf.amount) AS total_sum, f.flight_id
--              FROM ticket_flights AS tf
--              JOIN flights AS f ON tf.flight_id = f.flight_id
--              GROUP BY f.flight_id)
--     , getMax AS (SELECT flight_id FROM sums
--                  WHERE total_sum = (SELECT max(total_sum) FROM sums))
--SELECT * FROM flights
--WHERE flights.flight_id = (SELECT * FROM getMax);

-- Второе решение
SELECT f.* FROM flights f
JOIN (
  SELECT flight_id, sum(tf.amount) AS total_sum
  FROM ticket_flights tf
  GROUP BY flight_id
  ORDER BY total_sum DESC
  LIMIT 1
) AS sums ON f.flight_id = sums.flight_id;

-- Найти модель самолета, принесшую наибольшую прибыль (наибольшая суммарная стоимость билетов). Вывести код модели, информацию о модели и общую стоимость

-- Первое решение. Этот запрос рабочий но медленней
-- WITH sums AS (SELECT sum(ticket.amount) AS each_sum, f.aircraft_code
--               FROM flights_v AS f
--               JOIN ticket_flights AS ticket ON f.flight_id = ticket.flight_id
--               GROUP BY f.aircraft_code)
-- , max_res AS (SELECT each_sum AS max_sum, aircraft_code  FROM sums
--               WHERE each_sum = (SELECT max(each_sum) AS max_sum FROM sums))
-- SELECT max_sum, ms.aircraft_code, model
-- FROM max_res AS ms
-- JOIN aircrafts AS ar ON ms.aircraft_code = ar.aircraft_code;

-- Второе решение

SELECT ac.*, max_result.max_sum FROM aircrafts AS ac
JOIN (
  SELECT sum(amount) AS max_sum, aircraft_code
  FROM ticket_flights AS tf
  JOIN flights AS f ON tf.flight_id = f.flight_id
  GROUP BY aircraft_code
  ORDER BY max_sum DESC
  LIMIT 1
) AS max_result ON ac.aircraft_code = max_result.aircraft_code;

-- Найти самый частый аэропорт назначения для каждой модели самолета. Вывести количество вылетов, информацию о модели самолета, аэропорт назначения, город


-- Первое решение
WITH colleted_count_and_keys AS (SELECT count(airport_name) AS count_airport, air.airport_code , f.aircraft_code AS ac_code
    FROM airports AS air
    JOIN flights AS f ON air.airport_code = f.arrival_airport
    GROUP BY airport_code, ac_code),
 max_arrival AS (SELECT max(count_airport) as max_count, ac_code
                 FROM colleted_count_and_keys
                 GROUP BY ac_code)
SELECT aircrafts.*, count_airport AS max_arrivals, airports.airport_name, airports.city
FROM colleted_count_and_keys AS collected
JOIN airports ON collected.airport_code = airports.airport_code
JOIN aircrafts ON collected.ac_code = aircrafts.aircraft_code
JOIN max_arrival ON collected.ac_code = max_arrival.ac_code
WHERE count_airport = max_arrival.max_count;

-- Второе решение : чуть быстрее
SELECT a.aircraft_code, a.model, ar.airport_name, ar.city, cnt AS max_arrivals
FROM (
  SELECT aircraft_code, airport_code, count(*) AS cnt
  FROM flights
  JOIN airports ON arrival_airport = airport_code
  GROUP BY aircraft_code, airport_code
) AS count_keys
JOIN (
  SELECT aircraft_code, max(cnt) AS max_cnt
  FROM (
    SELECT aircraft_code, airport_code, count(*) AS cnt
    FROM flights
    JOIN airports ON arrival_airport = airport_code
    GROUP BY aircraft_code, airport_code
  ) AS subquery
  GROUP BY aircraft_code
) AS max_subquery ON count_keys.aircraft_code = max_subquery.aircraft_code AND count_keys.cnt = max_subquery.max_cnt
JOIN aircrafts AS a ON count_keys.aircraft_code = a.aircraft_code
JOIN airports AS ar ON count_keys.airport_code = ar.airport_code;