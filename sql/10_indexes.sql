-- Task 1: PostgreSQL at Scale
-- Meeting 3: Secondary B-tree indexes
--
-- Prerequisites:
--   1. public.events exists.
--   2. The 1,000,000-row dataset has been imported.
--   3. Baseline benchmarks and execution plans have been captured.
--
-- Run:
--   psql -X -v ON_ERROR_STOP=1 -d bigdata_lab -f sql/10_indexes.sql
--
-- Do not execute before collecting baseline measurements.
-- Index creation is idempotent for the expected index names.

-- Index 1: Supports Q5 customer-history filtering.
-- The descending keys match the requested result ordering.
CREATE INDEX IF NOT EXISTS idx_events_customer_ts_id
ON public.events (
    customer_id,
    event_ts DESC,
    event_id DESC
);

-- Index 2: Supports Q4's UTC timestamp-range predicate.
CREATE INDEX IF NOT EXISTS idx_events_event_ts
ON public.events (event_ts);

-- Refresh planner statistics after index creation.
ANALYZE public.events;
