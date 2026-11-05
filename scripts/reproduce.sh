#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)_$$"
OUT="results/reproduction/$RUN_ID"
mkdir -p "$OUT"
pg() { docker compose exec -T db psql -X -P pager=off -v ON_ERROR_STOP=1 "$@"; }
docker compose up -d --wait db
pg -f sql/01_schema.sql
COUNT=$(pg -At -c "SELECT COUNT(*) FROM public.events;")
INDEXES=$(pg -At -c "SELECT COUNT(*) FROM pg_index WHERE indrelid='public.events'::regclass;")
if [[ "$COUNT" != "0" || "$INDEXES" != "1" ]]; then
  echo "Use a fresh Compose project name: events must be empty with only its primary key." >&2
  exit 1
fi
docker compose run --rm generator --rows 100000 --outdir data
docker compose run --rm generator --rows 1000000 --outdir data/full_1m
pg -c '\timing on' -c "\copy public.events (event_id,event_ts,customer_id,product_id,region,quantity,unit_price_cents,status) FROM 'data/full_1m/events.csv' WITH (FORMAT csv, HEADER true)" | tee "$OUT/import_1m.txt"
pg -f sql/03_validation_1m.sql | tee "$OUT/validation.txt"
pg -c 'ANALYZE public.events;'
benchmark() {
  local stage="$1"
  mkdir -p "$OUT/$stage"
  for q in 1 2 3 4 5; do
    printf -v file 'sql/%02d_benchmark_q%d.sql' "$((q+4))" "$q"
    pg -f "$file" | tee "$OUT/$stage/q${q}_raw.txt"
  done
}
benchmark baseline
pg -f sql/10_indexes.sql | tee "$OUT/indexes.txt"
benchmark indexed
pg -f sql/11_meeting4_setup.sql | tee "$OUT/import_setup.txt"
docker compose exec -T -e OUT="$OUT/import" db bash scripts/meeting4_import_benchmark.sh | tee "$OUT/import_console.txt"
python3 scripts/summarize.py "$OUT"
echo "Saved new measurements to $OUT"
