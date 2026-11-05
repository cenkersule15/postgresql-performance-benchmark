-- Task 1: PostgreSQL at Scale
-- Meeting 2: Baseline SQL workloads
-- Dataset: 1,000,000 events
-- No additional indexes beyond the primary key.

-- Q1: Point lookup by event_id
SELECT
    event_id,
    event_ts,
    customer_id,
    product_id,
    region,
    quantity,
    unit_price_cents,
    status
FROM public.events
WHERE event_id = 500000;

-- Q2: Completed event count and revenue by month and region
SELECT
    DATE_TRUNC('month', event_ts AT TIME ZONE 'UTC') AS event_month_utc,
    region,
    COUNT(*) AS completed_events,
    SUM(quantity::bigint * unit_price_cents) AS revenue_cents
FROM public.events
WHERE status = 'completed'
GROUP BY
    DATE_TRUNC('month', event_ts AT TIME ZONE 'UTC'),
    region
ORDER BY
    event_month_utc,
    region;

-- Q3: Top 10 products by completed revenue
SELECT
    product_id,
    COUNT(*) AS completed_events,
    SUM(quantity::bigint * unit_price_cents) AS revenue_cents
FROM public.events
WHERE status = 'completed'
GROUP BY product_id
ORDER BY revenue_cents DESC, product_id
LIMIT 10;

-- Q4: Events in March 2025 (UTC)
SELECT
    COUNT(*) AS march_2025_events
FROM public.events
WHERE event_ts >= TIMESTAMPTZ '2025-03-01 00:00:00+00'
  AND event_ts < TIMESTAMPTZ '2025-04-01 00:00:00+00';

-- Q5: Customer event history
SELECT
    event_id,
    event_ts,
    product_id,
    region,
    quantity,
    unit_price_cents,
    status
FROM public.events
WHERE customer_id = 50000
ORDER BY event_ts DESC, event_id DESC;