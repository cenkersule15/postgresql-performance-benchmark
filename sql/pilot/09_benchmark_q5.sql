-- Task 1: PostgreSQL at Scale
-- Meeting 2: Q5 baseline benchmark
-- Warm-up: 1 run
-- Measured runs: 3

\pset pager off
\pset tuples_only on
\o /dev/null
\timing on

-- Warm-up
SELECT
    event_id,
    event_ts,
    product_id,
    region,
    quantity,
    unit_price_cents,
    status
FROM public.events_pilot
WHERE customer_id = 50000
ORDER BY event_ts DESC, event_id DESC;

-- Run 1
SELECT
    event_id,
    event_ts,
    product_id,
    region,
    quantity,
    unit_price_cents,
    status
FROM public.events_pilot
WHERE customer_id = 50000
ORDER BY event_ts DESC, event_id DESC;

-- Run 2
SELECT
    event_id,
    event_ts,
    product_id,
    region,
    quantity,
    unit_price_cents,
    status
FROM public.events_pilot
WHERE customer_id = 50000
ORDER BY event_ts DESC, event_id DESC;

-- Run 3
SELECT
    event_id,
    event_ts,
    product_id,
    region,
    quantity,
    unit_price_cents,
    status
FROM public.events_pilot
WHERE customer_id = 50000
ORDER BY event_ts DESC, event_id DESC;

\o
\timing off
