-- Task 1: PostgreSQL at Scale
-- Meeting 2: Q4 baseline benchmark
-- Warm-up: 1 run
-- Measured runs: 3

\pset pager off
\pset tuples_only on
\o /dev/null
\timing on

-- Warm-up
SELECT COUNT(*) AS march_2025_events
FROM public.events_pilot
WHERE event_ts >= TIMESTAMPTZ '2025-03-01 00:00:00+00'
  AND event_ts < TIMESTAMPTZ '2025-04-01 00:00:00+00';

-- Run 1
SELECT COUNT(*) AS march_2025_events
FROM public.events_pilot
WHERE event_ts >= TIMESTAMPTZ '2025-03-01 00:00:00+00'
  AND event_ts < TIMESTAMPTZ '2025-04-01 00:00:00+00';

-- Run 2
SELECT COUNT(*) AS march_2025_events
FROM public.events_pilot
WHERE event_ts >= TIMESTAMPTZ '2025-03-01 00:00:00+00'
  AND event_ts < TIMESTAMPTZ '2025-04-01 00:00:00+00';

-- Run 3
SELECT COUNT(*) AS march_2025_events
FROM public.events_pilot
WHERE event_ts >= TIMESTAMPTZ '2025-03-01 00:00:00+00'
  AND event_ts < TIMESTAMPTZ '2025-04-01 00:00:00+00';

\o
\timing off
