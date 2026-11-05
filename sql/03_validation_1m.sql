-- Task 1: PostgreSQL at Scale
-- Meeting 2: Full dataset validation
-- Expected rows: 1000000
-- Dataset timestamps are generated in UTC.

-- 1. Record count and event ID uniqueness
SELECT
    COUNT(*) AS total_events,
    COUNT(DISTINCT event_id) AS unique_events,
    MIN(event_id) AS first_id,
    MAX(event_id) AS last_id
FROM public.events;

-- 2. Timestamp boundaries in UTC
SELECT
    MIN(event_ts) AT TIME ZONE 'UTC' AS earliest_event_utc,
    MAX(event_ts) AT TIME ZONE 'UTC' AS latest_event_utc,
    COUNT(*) FILTER (WHERE event_ts IS NULL) AS null_timestamps
FROM public.events;

-- 3. Status distribution
SELECT
    status,
    COUNT(*) AS event_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        3
    ) AS percentage
FROM public.events
GROUP BY status
ORDER BY status;

-- 4. Events outside the expected UTC year
SELECT
    COUNT(*) FILTER (
        WHERE event_ts < TIMESTAMPTZ '2025-01-01 00:00:00+00'
           OR event_ts >= TIMESTAMPTZ '2026-01-01 00:00:00+00'
    ) AS events_outside_2025_utc
FROM public.events;

-- 5. Missing-value checks
SELECT
    COUNT(*) FILTER (WHERE event_id IS NULL) AS null_event_ids,
    COUNT(*) FILTER (WHERE event_ts IS NULL) AS null_timestamps,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS null_customer_ids,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS null_product_ids,
    COUNT(*) FILTER (WHERE region IS NULL) AS null_regions,
    COUNT(*) FILTER (WHERE quantity IS NULL) AS null_quantities,
    COUNT(*) FILTER (WHERE unit_price_cents IS NULL) AS null_prices,
    COUNT(*) FILTER (WHERE status IS NULL) AS null_statuses
FROM public.events;

-- 6. Generated value-range checks
SELECT
    COUNT(*) FILTER (
        WHERE customer_id NOT BETWEEN 1 AND 100000
    ) AS invalid_customer_ids,
    COUNT(*) FILTER (
        WHERE product_id NOT BETWEEN 1 AND 2000
    ) AS invalid_product_ids,
    COUNT(*) FILTER (
        WHERE quantity NOT BETWEEN 1 AND 5
    ) AS invalid_quantities,
    COUNT(*) FILTER (
        WHERE unit_price_cents NOT BETWEEN 100 AND 20000
    ) AS prices_outside_generator_range
FROM public.events;