-- Task 1: PostgreSQL at Scale
-- Meeting 2: Q3 baseline benchmark
-- Warm-up: 1 run
-- Measured runs: 3

\pset pager off
\pset tuples_only on
\o /dev/null
\timing on

-- Warm-up
SELECT
    product_id,
    COUNT(*) AS completed_events,
    SUM(quantity::bigint * unit_price_cents) AS revenue_cents
FROM public.events_pilot
WHERE status = 'completed'
GROUP BY product_id
ORDER BY revenue_cents DESC, product_id
LIMIT 10;

-- Run 1
SELECT
    product_id,
    COUNT(*) AS completed_events,
    SUM(quantity::bigint * unit_price_cents) AS revenue_cents
FROM public.events_pilot
WHERE status = 'completed'
GROUP BY product_id
ORDER BY revenue_cents DESC, product_id
LIMIT 10;

-- Run 2
SELECT
    product_id,
    COUNT(*) AS completed_events,
    SUM(quantity::bigint * unit_price_cents) AS revenue_cents
FROM public.events_pilot
WHERE status = 'completed'
GROUP BY product_id
ORDER BY revenue_cents DESC, product_id
LIMIT 10;

-- Run 3
SELECT
    product_id,
    COUNT(*) AS completed_events,
    SUM(quantity::bigint * unit_price_cents) AS revenue_cents
FROM public.events_pilot
WHERE status = 'completed'
GROUP BY product_id
ORDER BY revenue_cents DESC, product_id
LIMIT 10;

\o
\timing off
