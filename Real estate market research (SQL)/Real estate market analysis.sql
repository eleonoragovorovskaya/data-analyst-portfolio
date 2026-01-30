
-- Задание 1
SELECT 
	MIN(first_day_exposition) AS earliest_date,
	MAX(first_day_exposition) AS latest_date
FROM real_estate.advertisement;

-- Задание 2
SELECT 
	COUNT(t.type_id) AS ads,
		TYPE
FROM real_estate.TYPE AS t
JOIN real_estate.flats AS f USING(type_id)
GROUP BY TYPE
ORDER BY ads DESC;

-- Задание 3
SELECT 
	MIN(days_exposition) AS min_exposition,
	MAX(days_exposition) AS max_exposition,
	ROUND(AVG(days_exposition::numeric), 2) AS max_exposition,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_exposition) AS median_exposition
FROM real_estate.advertisement;

-- Задание 4
SELECT
    COUNT(*) FILTER (WHERE c.city = 'Санкт-Петербург')
    / COUNT(*)::numeric * 100 AS spb_percent
FROM real_estate.flats f
JOIN real_estate.city c USING (city_id);

-- Задание 5

WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
categorization AS (
	SELECT
		CASE 
			WHEN city = 'Санкт-Петербург' THEN 'Санкт-Петербург' 
 			ELSE 'ЛенОбл' 
 		END AS region,
 		CASE 
 			WHEN days_exposition BETWEEN 1 AND 30 THEN '1-30 days'
 			WHEN days_exposition BETWEEN 31 AND 90 THEN '31-90 days'
 			WHEN days_exposition BETWEEN 91 AND 180 THEN '91-180 days' 
 			WHEN days_exposition > 180 THEN '> 181 days' 
 			ELSE 'active'
 		END AS PERIOD,
 		last_price / total_area AS price_per_square_meter,
 		total_area,
 		rooms,
 		balcony,
 		floor
		FROM real_estate.city
		JOIN real_estate.flats USING(city_id)
		JOIN real_estate.advertisement USING(id)
		JOIN real_estate.TYPE USING(type_id)
	WHERE TYPE = 'город' AND id IN (SELECT * FROM filtered_id) AND EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018
)
SELECT 
	region AS region,
	PERIOD AS activity_segment,
	COUNT(*) AS total_ads,
	ROUND(AVG(price_per_square_meter::numeric)) AS avg_price_per_m2, 
	ROUND(AVG(total_area::numeric)) AS avg_square,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rooms) AS rooms_median,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony) AS balcony_median,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floor) AS floors_median
FROM categorization
GROUP BY region, PERIOD
ORDER BY region DESC, period ASC;


-- Задание 6
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
days_stats AS (
    SELECT 
        id, 
        last_price,
        days_exposition,
        EXTRACT(MONTH FROM first_day_exposition) AS month_publication,
        EXTRACT (MONTH FROM first_day_exposition + (days_exposition * INTERVAL '1 day')) AS month_removal
    FROM real_estate.advertisement 
    	WHERE EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018 
    	AND id IN (SELECT * FROM filtered_id)
),
publication_stats AS (
    SELECT
        month_publication AS MONTH,
        COUNT(id) AS ads_count,
        ROUND(AVG(total_area)::numeric) AS avg_total_area,
        ROUND(AVG(last_price / total_area)::numeric) AS avg_price_per_m2,
        'publication' AS period_type
    FROM days_stats
    JOIN real_estate.flats USING (id)
    JOIN real_estate.TYPE USING(type_id)
    WHERE TYPE = 'город'
    GROUP BY month_publication
),
removal_stats AS (
    SELECT
        month_removal AS MONTH,
        COUNT(id) AS ads_count,
        ROUND(AVG(total_area)::numeric) AS avg_total_area,
        ROUND(AVG(last_price / total_area)::numeric) AS avg_price_per_m2,
        'removal' AS period_type
    FROM days_stats
    JOIN real_estate.flats USING (id)
    JOIN real_estate.TYPE USING(type_id)
    WHERE TYPE = 'город' AND days_exposition IS NOT NULL 
    GROUP BY month_removal
)
SELECT * 
FROM publication_stats
UNION ALL
SELECT *
FROM removal_stats
ORDER BY period_type;