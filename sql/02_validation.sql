-- Task 1: PostgreSQL at Scale
-- Meeting 1: Pilot dataset validation
-- Expected rows: 100000
-- Dataset timestamps are generated in UTC.

-- 1. Total rows and unique event IDs
SELECT
    COUNT(*) AS total_events,
    COUNT(DISTINCT event_id) AS unique_events,
    MIN(event_id) AS first_id,
    MAX(event_id) AS last_id
FROM events;

-- 2. Timestamp range displayed explicitly in UTC
SELECT
    MIN(event_ts) AT TIME ZONE 'UTC' AS earliest_event_utc,
    MAX(event_ts) AT TIME ZONE 'UTC' AS latest_event_utc,
    COUNT(*) FILTER (WHERE event_ts IS NULL) AS null_timestamps
FROM events;

-- 3. Event status distribution
SELECT
    status,
    COUNT(*) AS event_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        3
    ) AS percentage
FROM events
GROUP BY status
ORDER BY status;

-- 4. Verify that every timestamp belongs to 2025 UTC
SELECT
    COUNT(*) FILTER (
        WHERE event_ts < TIMESTAMPTZ '2025-01-01 00:00:00+00'
           OR event_ts >= TIMESTAMPTZ '2026-01-01 00:00:00+00'
    ) AS events_outside_2025_utc
FROM events;

-- 5. Verify that required fields contain no NULL values
SELECT
    COUNT(*) FILTER (WHERE event_id IS NULL) AS null_event_ids,
    COUNT(*) FILTER (WHERE event_ts IS NULL) AS null_timestamps,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS null_customer_ids,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS null_product_ids,
    COUNT(*) FILTER (WHERE region IS NULL) AS null_regions,
    COUNT(*) FILTER (WHERE quantity IS NULL) AS null_quantities,
    COUNT(*) FILTER (WHERE unit_price_cents IS NULL) AS null_prices,
    COUNT(*) FILTER (WHERE status IS NULL) AS null_statuses
FROM events;