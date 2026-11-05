-- Task 1: PostgreSQL at Scale
-- Meeting 2: Q1 baseline benchmark
-- Warm-up: 1 run
-- Measured runs: 3

\pset pager off
\pset tuples_only on
\o /dev/null
\timing on

-- Warm-up (excluded from median)
SELECT *
FROM public.events
WHERE event_id = 500000;

-- Run 1
SELECT *
FROM public.events
WHERE event_id = 500000;

-- Run 2
SELECT *
FROM public.events
WHERE event_id = 500000;

-- Run 3
SELECT *
FROM public.events
WHERE event_id = 500000;

\o
\timing off