Use project;

ALTER TABLE fact_bookings
DROP COLUMN MyUnknownColumn;

ALTER TABLE fact_bookings
ADD COLUMN check_in_date_clean DATE,
ADD COLUMN checkout_date_clean DATE;

SET SQL_SAFE_UPDATES = 0;

UPDATE fact_bookings
SET 
  check_in_date_clean = STR_TO_DATE(check_in_date, '%Y-%m-%d'),
  checkout_date_clean = STR_TO_DATE(checkout_date, '%Y-%m-%d');

UPDATE fact_bookings
SET 
  check_in_date_clean = CAST(check_in_date AS DATE),
  checkout_date_clean = CAST(checkout_date AS DATE);
  
ALTER TABLE fact_aggregated_bookings
ADD COLUMN check_in_date_clean DATE;

UPDATE fact_aggregated_bookings
SET check_in_date_clean = CAST(check_in_date AS DATE);

UPDATE fact_aggregated_bookings
SET check_in_date_clean = STR_TO_DATE(check_in_date, '%d-%b-%y');

ALTER TABLE dim_date ADD COLUMN date_clean DATE;

UPDATE dim_date
SET date_clean = STR_TO_DATE(date, '%d-%b-%y');

CREATE OR REPLACE VIEW w_hotel_booking_analysiss AS
SELECT
    fb.booking_id,
    fb.property_id,
    dh.property_name,
    dh.category AS hotel_category,
    dh.city,
    fb.check_in_date_clean AS check_in_date,
    dd.check_in_month,
    dd.check_in_week,
    dd.day_type AS check_in_day_type,
    fb.checkout_date_clean AS checkout_date,
    fb.no_guests,
    fb.room_category,
    dr.room_id,
    fb.booking_platform,
    CAST(fb.ratings_given AS DECIMAL(3,2)) AS ratings_given,
    fb.booking_status,
    fb.revenue_generated,
    fb.revenue_realized,
    fab.successful_bookings,
    fab.capacity
FROM fact_bookings fb
LEFT JOIN dim_hotels dh ON fb.property_id = dh.property_id
LEFT JOIN dim_date dd ON fb.check_in_date_clean = dd.date_clean
LEFT JOIN dim_rooms dr ON LOWER(TRIM(fb.room_category)) = LOWER(TRIM(dr.room_class))
LEFT JOIN fact_aggregated_bookings fab ON
    fb.property_id = fab.property_id
    AND fb.check_in_date_clean = fab.check_in_date_clean
    AND fb.room_category = fab.room_category;

select * from w_hotel_booking_analysiss;

------------------------------------------------
## TOTAL REVENUE & TOTAL SUCCESSFUL BOOKING------

  SELECT
  SUM(revenue_realized) AS total_revenue
FROM w_hotel_booking_analysiss
WHERE booking_status = 'checked Out';

## OCCUPANCY % BY MONTH -----

SELECT
  check_in_month,
  SUM(successful_bookings) / SUM(capacity) * 100 AS occupancy_rate_percent
FROM w_hotel_booking_analysiss
GROUP BY check_in_month
ORDER BY STR_TO_DATE(CONCAT('01 ', check_in_month), '%d %b %y');

## CANCELLATION % -----

SELECT
  COUNT(CASE WHEN booking_status = 'Cancelled' THEN 1 END) / COUNT(*) * 100 AS cancellation_rate_percent
FROM w_hotel_booking_analysiss;

## TOTAL BOOKING -----

SELECT
  COUNT(*) AS total_bookings
FROM w_hotel_booking_analysiss;

## WEEKDAY VS WEEKEND ( TOTAL REVENUE AND TOTAL BOOKING ) -----

SELECT
  check_in_day_type,
  COUNT(*) AS total_bookings,
  SUM(revenue_realized) AS total_revenue
FROM w_hotel_booking_analysiss
GROUP BY check_in_day_type;

#  TOTAL REVENUE BY CITY AND THEIR RESPECTIVE HOTELS -----

SELECT
  city,
  property_name,
  SUM(revenue_realized) AS total_revenue
FROM w_hotel_booking_analysiss
GROUP BY city, property_name
ORDER BY city, total_revenue DESC;

## TOTAL REVENUE BY ROOM CATEGORY -----

SELECT
  room_category,
  SUM(revenue_realized) AS total_revenue
FROM w_hotel_booking_analysiss
GROUP BY room_category
ORDER BY total_revenue DESC;

## BOOKING STATUS COUNT ( CHECKED OUT , CANCELLED & NO SHOW ) -----

SELECT
  booking_status,
  COUNT(*) AS booking_count
FROM w_hotel_booking_analysiss
GROUP BY booking_status;

## CANCELLETION BOOKING AND CANCELLATION PERCENT BY BOOKING PLATFORMS -----

SELECT
  booking_platform,
  COUNT(*) AS total_bookings,
  COUNT(CASE WHEN booking_status = 'Cancelled' THEN 1 END) AS cancelled_bookings,
  ROUND(COUNT(CASE WHEN booking_status = 'Cancelled' THEN 1 END) * 100.0 / COUNT(*), 2) AS cancellation_rate_percent
FROM w_hotel_booking_analysiss
GROUP BY booking_platform
ORDER BY cancellation_rate_percent DESC;

# TOTAL BOOKING AND OCCUPACY % BY MONTH -----

SELECT
  check_in_month,
  SUM(revenue_realized) AS total_revenue,
  SUM(successful_bookings) / SUM(capacity) * 100 AS occupancy_rate_percent
FROM w_hotel_booking_analysiss
GROUP BY check_in_month
ORDER BY STR_TO_DATE(CONCAT('01 ', check_in_month), '%d %b %y');

## UTILIZED % BY MONTH -----

SELECT
  check_in_month,
  SUM(no_guests) / SUM(capacity) * 100 AS utilized_capacity_percent
FROM w_hotel_booking_analysiss
GROUP BY check_in_month
ORDER BY STR_TO_DATE(CONCAT('01 ', check_in_month), '%d %b %y');

## ------