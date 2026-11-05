\pset pager off

\echo '=== 100K PILOT: WARM-UP ==='

EXPLAIN (ANALYZE, BUFFERS)
SELECT event_id, customer_id, event_ts
FROM public.events_pilot
WHERE customer_id = 66808
ORDER BY event_ts DESC, event_id DESC
LIMIT 50;


\echo '=== 100K PILOT: RUN 1 ==='

EXPLAIN (ANALYZE, BUFFERS)
SELECT event_id, customer_id, event_ts
FROM public.events_pilot
WHERE customer_id = 66808
ORDER BY event_ts DESC, event_id DESC
LIMIT 50;


\echo '=== 100K PILOT: RUN 2 ==='

EXPLAIN (ANALYZE, BUFFERS)
SELECT event_id, customer_id, event_ts
FROM public.events_pilot
WHERE customer_id = 66808
ORDER BY event_ts DESC, event_id DESC
LIMIT 50;


\echo '=== 100K PILOT: RUN 3 ==='

EXPLAIN (ANALYZE, BUFFERS)
SELECT event_id, customer_id, event_ts
FROM public.events_pilot
WHERE customer_id = 66808
ORDER BY event_ts DESC, event_id DESC
LIMIT 50;


\echo '=== 1M BASELINE: WARM-UP ==='

EXPLAIN (ANALYZE, BUFFERS)
SELECT event_id, customer_id, event_ts
FROM public.events_baseline_1m
WHERE customer_id = 66808
ORDER BY event_ts DESC, event_id DESC
LIMIT 50;


\echo '=== 1M BASELINE: RUN 1 ==='

EXPLAIN (ANALYZE, BUFFERS)
SELECT event_id, customer_id, event_ts
FROM public.events_baseline_1m
WHERE customer_id = 66808
ORDER BY event_ts DESC, event_id DESC
LIMIT 50;


\echo '=== 1M BASELINE: RUN 2 ==='

EXPLAIN (ANALYZE, BUFFERS)
SELECT event_id, customer_id, event_ts
FROM public.events_baseline_1m
WHERE customer_id = 66808
ORDER BY event_ts DESC, event_id DESC
LIMIT 50;


\echo '=== 1M BASELINE: RUN 3 ==='

EXPLAIN (ANALYZE, BUFFERS)
SELECT event_id, customer_id, event_ts
FROM public.events_baseline_1m
WHERE customer_id = 66808
ORDER BY event_ts DESC, event_id DESC
LIMIT 50;

