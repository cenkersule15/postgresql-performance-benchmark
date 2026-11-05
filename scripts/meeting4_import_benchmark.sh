#!/bin/bash
set -euo pipefail

DB="${PGDATABASE:-bigdata_lab}"
CSV="${CSV:-data/events.csv}"
OUT="${OUT:-results/reproduction/import_$(date -u +%Y%m%dT%H%M%SZ)_$$}"
MEASUREMENTS="$OUT/measurements.csv"

mkdir -p "$OUT"

if [[ ! -f "$CSV" ]]; then
  echo "ERROR: Missing $CSV" >&2
  exit 1
fi

if [[ -f "$MEASUREMENTS" ]]; then
  echo "ERROR: $MEASUREMENTS already exists. Existing results will not be overwritten." >&2
  exit 1
fi

EXPECTED=$(psql -X -A -t -v ON_ERROR_STOP=1 -d "$DB" \
  -c "SELECT COUNT(*) FROM public.events;")

if [[ "$EXPECTED" != "1000000" ]]; then
  echo "ERROR: Main events table does not contain 1,000,000 rows." >&2
  exit 1
fi

INDEX_COUNTS=$(psql -X -A -t -v ON_ERROR_STOP=1 -d "$DB" \
  -c "SELECT
        (SELECT COUNT(*) FROM pg_indexes
         WHERE schemaname='public'
           AND tablename='events_insert_no_extra_idx'),
        (SELECT COUNT(*) FROM pg_indexes
         WHERE schemaname='public'
           AND tablename='events_insert_with_extra_idx');")

if [[ "$INDEX_COUNTS" != "1|3" ]]; then
  echo "ERROR: Unexpected test-table index configuration: $INDEX_COUNTS" >&2
  exit 1
fi

echo "round,order,condition,table_name,import_ms,row_count" > "$MEASUREMENTS"

run_import() {
  local round="$1"
  local order="$2"
  local condition="$3"
  local table="$4"
  local raw="$OUT/round${round}_${condition}.txt"

  echo "Round $round | Order $order | Condition $condition"

  psql -X -v ON_ERROR_STOP=1 -d "$DB" \
    -c "TRUNCATE TABLE public.$table;" > /dev/null

  psql -X -v ON_ERROR_STOP=1 -d "$DB" \
    -c '\timing on' \
    -c "\copy public.$table (event_id, event_ts, customer_id, product_id, region, quantity, unit_price_cents, status) FROM '$CSV' WITH (FORMAT csv, HEADER true)" \
    > "$raw"

  cat "$raw"

  local duration
  duration=$(awk '/^Time: / {print $2; exit}' "$raw")

  if [[ -z "$duration" ]]; then
    echo "ERROR: Import timing missing for $table" >&2
    exit 1
  fi

  local count
  count=$(psql -X -A -t -v ON_ERROR_STOP=1 -d "$DB" \
    -c "SELECT COUNT(*) FROM public.$table;")

  if [[ "$count" != "100000" ]]; then
    echo "ERROR: Unexpected row count for $table: $count" >&2
    exit 1
  fi

  echo "$round,$order,$condition,$table,$duration,$count" >> "$MEASUREMENTS"
}

A="events_insert_no_extra_idx"
B="events_insert_with_extra_idx"

for round in 1 2 3 4 5; do
  if (( round % 2 == 1 )); then
    run_import "$round" "AB" "A" "$A"
    run_import "$round" "AB" "B" "$B"
  else
    run_import "$round" "BA" "B" "$B"
    run_import "$round" "BA" "A" "$A"
  fi
done

echo
echo "=== All 10 imports completed ==="
cat "$MEASUREMENTS"

echo
echo "=== Main table verification ==="
psql -X -v ON_ERROR_STOP=1 -d "$DB" \
  -c "SELECT COUNT(*) AS main_events_count FROM public.events;"
