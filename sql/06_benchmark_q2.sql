-- Task 1: PostgreSQL at Scale
-- Meeting 2: Q2 baseline benchmark
-- Warm-up: 1 run
-- Measured runs: 3

\pset pager off
\pset tuples_only on
\o /dev/null
\timing on

-- Warm-up
SELECT
    DATE_TRUNC('month', event_ts AT TIME ZONE 'UTC') AS event_month_utc,
    region,
    COUNT(*) AS completed_events,
    SUM(quantity::bigint * unit_price_cents) AS revenue_cents
FROM public.events
WHERE status = 'completed'
GROUP BY DATE_TRUNC('month', event_ts AT TIME ZONE 'UTC'), region
ORDER BY event_month_utc, region;

-- Run 1
SELECT
    DATE_TRUNC('month', event_ts AT TIME ZONE 'UTC') AS event_month_utc,
    region,
    COUNT(*) AS completed_events,
    SUM(quantity::bigint * unit_price_cents) AS revenue_cents
FROM public.events
WHERE status = 'completed'
GROUP BY DATE_TRUNC('month', event_ts AT TIME ZONE 'UTC'), region
ORDER BY event_month_utc, region;

-- Run 2
SELECT
    DATE_TRUNC('month', event_ts AT TIME ZONE 'UTC') AS event_month_utc,
    region,
    COUNT(*) AS completed_events,
    SUM(quantity::bigint * unit_price_cents) AS revenue_cents
FROM public.events
WHERE status = 'completed'
GROUP BY DATE_TRUNC('month', event_ts AT TIME ZONE 'UTC'), region
ORDER BY event_month_utc, region;

-- Run 3
SELECT
    DATE_TRUNC('month', event_ts AT TIME ZONE 'UTC') AS event_month_utc,
    region,
    COUNT(*) AS completed_events,
    SUM(quantity::bigint * unit_price_cents) AS revenue_cents
FROM public.events
WHERE status = 'completed'
GROUP BY DATE_TRUNC('month', event_ts AT TIME ZONE 'UTC'), region
ORDER BY event_month_utc, region;

\o
\timing off
