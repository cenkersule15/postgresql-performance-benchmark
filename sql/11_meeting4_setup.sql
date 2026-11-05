-- Task 1: PostgreSQL at Scale
-- Meeting 4: Reproducible import benchmark setup
--
-- Prerequisites:
--   1. public.events exists with the original schema.
--   2. Both secondary indexes have been created using 10_indexes.sql.
--
-- Run:
--   psql -X -v ON_ERROR_STOP=1 -d bigdata_lab -f sql/11_meeting4_setup.sql
--
-- Safety:
--   Existing experimental tables are never dropped or truncated.
--   The original public.events table is never modified.
--
-- Expected final index counts:
--   events_insert_no_extra_idx   = 1
--   events_insert_with_extra_idx = 3

BEGIN;

-- Condition A: same column definitions and constraints,
-- with only the primary-key index.
CREATE TABLE IF NOT EXISTS public.events_insert_no_extra_idx
(
    LIKE public.events INCLUDING ALL
);

-- Condition B: same definitions, retaining all source indexes.
CREATE TABLE IF NOT EXISTS public.events_insert_with_extra_idx
(
    LIKE public.events INCLUDING ALL
);

DO $$
DECLARE
    index_name TEXT;
BEGIN
    -- Remove copied secondary indexes from condition A only.
    -- Never remove its primary-key index.
    FOR index_name IN
        SELECT quote_ident(ns.nspname) || '.' || quote_ident(idx.relname)
        FROM pg_index pi
        JOIN pg_class tbl ON tbl.oid = pi.indrelid
        JOIN pg_class idx ON idx.oid = pi.indexrelid
        JOIN pg_namespace ns ON ns.oid = idx.relnamespace
        WHERE tbl.oid = 'public.events_insert_no_extra_idx'::regclass
          AND NOT pi.indisprimary
    LOOP
        EXECUTE 'DROP INDEX IF EXISTS ' || index_name;
    END LOOP;
END
$$;

COMMIT;

-- Verify index counts without modifying the source table.
SELECT
    tbl.relname AS table_name,
    COUNT(idx.indexrelid) AS index_count
FROM pg_class tbl
JOIN pg_namespace ns ON ns.oid = tbl.relnamespace
LEFT JOIN pg_index idx ON idx.indrelid = tbl.oid
WHERE ns.nspname = 'public'
  AND tbl.relname IN (
      'events_insert_no_extra_idx',
      'events_insert_with_extra_idx'
  )
GROUP BY tbl.relname
ORDER BY tbl.relname;

-- Confirm that the source table still has one million rows.
SELECT COUNT(*) AS source_event_rows
FROM public.events;
