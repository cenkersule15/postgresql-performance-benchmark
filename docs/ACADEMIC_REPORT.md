# Task 1 — PostgreSQL at Scale

Course: Handling Large Data Sets
Assignment: Assignment 1 — PostgreSQL at Scale
Laboratory sessions: Meetings 1–4
Experimental dates: 27–29 October 2026

## 1. Project Overview

This project evaluates PostgreSQL performance using deterministic synthetic event datasets containing 100,000 and 1,000,000 records.

The investigation covers relational schema design, data validation, CSV ingestion, five SQL workloads, query benchmarking, execution-plan analysis, B-tree indexing, storage overhead, and bulk-import performance.

The official course-provided generate_events.py is preserved without modifications to its event-generation logic.

## 2. Experimental Environment

| Component | Configuration |
| --- | --- |
| Hardware | MacBook Pro, Apple M4 Pro |
| Processor | 12 CPU cores |
| Memory | 24 GB |
| Operating system | macOS 26.1 |
| Python | 3.9.6 |
| PostgreSQL | 14.18, Homebrew, ARM64 |
| Database | bigdata_lab |
| Generator seed | 2026 |

Selected PostgreSQL settings:

| Parameter | Value |
| --- | --- |
| shared_buffers | 128 MiB |
| effective_cache_size | 4 GiB |
| work_mem | 4 MiB |
| maintenance_work_mem | 64 MiB |
| max_parallel_workers_per_gather | 2 |
| synchronous_commit | on |

All performance measurements were collected on a single local machine.

## 3. Project Structure

The project contains the following components:

* generate_events.py — Original deterministic dataset generator.
* sql/01_schema.sql — Relational schema.
* sql/02_validation.sql — Pilot dataset validation.
* sql/03_validation_1m.sql — Full-scale dataset validation.
* sql/04_workloads.sql — Five representative SQL workloads.
* sql/05_benchmark_q1.sql through 09_benchmark_q5.sql — Query benchmark scripts.
* sql/10_indexes.sql — Secondary index definitions.
* sql/11_meeting4_setup.sql — Import benchmark table setup.
* scripts/meeting4_import_benchmark.sh — Repeated import experiment.
* results/ — Raw timings, execution plans, validation outputs, and statistics.
* logs/progress_log.md — Detailed laboratory progress log.
* report/ — Final academic report.

Generated CSV and JSONL datasets are excluded from the final submission archive because of their size.

## 4. Prerequisites

Python 3, PostgreSQL, and the psql command-line client must be installed.

Verify the environment:

```bash
python3 --version
psql --version
pg_isready
```

Run all subsequent commands from the project root.

Create the dedicated database:

```bash
createdb bigdata_lab
```

If the database already exists, do not recreate it.

Create the relational schema:

```bash
psql -X -v ON_ERROR_STOP=1 -d bigdata_lab -f sql/01_schema.sql
```

For a clean reproduction, use an empty coursework database.

## 5. Meeting 1 — Pilot Dataset

Generate 100,000 synthetic events:

```bash
mkdir -p data
python3 generate_events.py --rows 100000 --outdir data
```

Inspect the generated files:

```bash
wc -l data/events.csv data/events.jsonl
shasum -a 256 data/events.csv data/events.jsonl
```

Expected line counts:

* CSV: 100,001, including the header.
* JSONL: 100,000.

Import the CSV into an empty public.events table:

```bash
psql -X -v ON_ERROR_STOP=1 -d bigdata_lab \
  -c "\timing on" \
  -c "\copy public.events (event_id, event_ts, customer_id, product_id, region, quantity, unit_price_cents, status) FROM 'data/events.csv' WITH (FORMAT csv, HEADER true)"
```

Validate the imported data:

```bash
psql -X -P pager=off -v ON_ERROR_STOP=1 \
  -d bigdata_lab -f sql/02_validation.sql
```

Observed pilot import time: 224.680 ms.

## 6. Meeting 2 — One Million Events

Generate the full dataset separately:

```bash
mkdir -p data/full_1m
time python3 generate_events.py --rows 1000000 --outdir data/full_1m
```

Observed generation time: 8.473 seconds.

Before loading the full dataset, the pilot rows must be removed from the dedicated coursework table.

Warning: The following command deletes all existing rows in public.events. Run it only in a database intended for reproducing this experiment.

```bash
psql -X -v ON_ERROR_STOP=1 -d bigdata_lab \
  -c "TRUNCATE TABLE public.events;"
```

Import the one-million-row CSV:

```bash
psql -X -v ON_ERROR_STOP=1 -d bigdata_lab \
  -c "\timing on" \
  -c "\copy public.events (event_id, event_ts, customer_id, product_id, region, quantity, unit_price_cents, status) FROM 'data/full_1m/events.csv' WITH (FORMAT csv, HEADER true)"
```

Observed import time: 1666.363 ms.

Validate the data and update PostgreSQL planner statistics:

```bash
psql -X -P pager=off -v ON_ERROR_STOP=1 \
  -d bigdata_lab -f sql/03_validation_1m.sql
psql -X -v ON_ERROR_STOP=1 \
  -d bigdata_lab -c "ANALYZE public.events;"
```

The original experiment verified 1,000,000 rows, 1,000,000 distinct event IDs, valid UTC timestamps, and no NULL values.

## 6A. Supplementary 100K Pilot Benchmark

A separate public.events_pilot table containing 100,000 validated events was benchmarked with only its primary-key index. Each Q1–Q5 workload was executed once for warm-up and three times for measurement; the median excludes warm-up.

| Query | 100K median (ms) | 1M baseline median (ms) | 1M / 100K |
| --- | ---: | ---: | ---: |
| Q1 | 0.091 | 0.061 | 0.670x |
| Q2 | 24.805 | 260.336 | 10.495x |
| Q3 | 8.147 | 38.874 | 4.772x |
| Q4 | 2.446 | 17.839 | 7.293x |
| Q5 | 2.093 | 19.353 | 9.247x |

The pilot SQL scripts are in `sql/pilot/`. Raw timings and calculated summaries are in `results/pilot_100k/`. The pilot Q1 used `event_id = 50000`, while the full-scale Q1 used `event_id = 500000`. **Critical Q5 comparability caveat:** the original pilot Q5 predicate (`customer_id = 50000`) matched **zero** rows at 100K, but **15** rows at 1M. The recorded **9.247×** ratio is arithmetically correct but **must not be attributed to dataset scaling alone**. Cardinality, cache state, and execution conditions differ. The original measurements remain unchanged for traceability.

### 6B. Supplementary matched-customer, PK-only Q5 follow-up

A separate Q5-style follow-up used `customer_id = 66808`, present in both datasets (**8 matching rows at 100K; 14 at 1M**). To align index configuration without changing `public.events`, a 1M scratch copy (`public.events_baseline_1m`) was prepared with **only its primary-key index**, analyzed, and checked for 1,000,000 unique event IDs. The pilot table also had only its primary key. The follow-up used the same query shape on both tables:

```sql
SELECT event_id, customer_id, event_ts
FROM public.events_pilot
WHERE customer_id = 66808
ORDER BY event_ts DESC, event_id DESC
LIMIT 50;
```

Replace `public.events_pilot` with `public.events_baseline_1m` for the full-scale copy. This is **not the original Q5**: it projects three rather than seven columns and uses `LIMIT 50`, although neither result set reached the limit. Each table had one warm-up plus three measured `EXPLAIN (ANALYZE, BUFFERS)` executions. Unlike the original benchmarks, the following timings are **server-side EXPLAIN execution times**, not `psql \timing` values.

| Run | 100K PK-only (ms) | 1M PK-only copy (ms) |
| --- | ---: | ---: |
| Warm-up (excluded) | 9.589 | 21.029 |
| 1 | 9.239 | 16.103 |
| 2 | 7.222 | 13.653 |
| 3 | 3.583 | 11.826 |
| **Median** | **7.222** | **13.653** |

The sampled ratio of medians is **13.653 / 7.222 ≈ 1.8905×** (approximately **1.890×**). The 100K plan used a sequential scan and sort; the 1M plan used a parallel sequential scan and sorting. This experiment aligns customer ID, index configuration, and measurement method, **but not** matching-row counts, physical layout, parallelism, cache conditions, or execution order. Its 1.890× ratio neither replaces nor directly compares with the original 9.247× client-timed ratio.

Evidence: `logs/q5_controlled_comparison.sql` (eight EXPLAIN statements), `logs/q5_controlled_comparison.txt` (raw plans and timings), and Section 33 of `logs/progress_log.md`. The SQL file reruns the query on the **existing** pilot and scratch-copy tables; preparation of those tables is documented in the progress log rather than automated by this script. To reproduce the scratch copy, create it in a separate coursework database with the source schema and primary key only, insert the million source rows, analyze it, and verify index definitions and counts before benchmarking. Cache and background activity were not controlled, so neither ratio is a general scaling law.

## 7. SQL Workloads

Five workloads were defined:

| ID | Description |
| --- | --- |
| Q1 | Point lookup by event ID |
| Q2 | Completed revenue by UTC month and region |
| Q3 | Top ten products by completed revenue |
| Q4 | March 2025 UTC timestamp-range count |
| Q5 | Customer 50000 event history |

Run the workload queries:

```bash
psql -X -P pager=off -v ON_ERROR_STOP=1 \
  -d bigdata_lab -f sql/04_workloads.sql
```

The original queries and parameters were preserved across baseline and indexed comparisons.

## 8. Baseline Benchmarking

Run baseline benchmarks before creating secondary indexes.

Each benchmark script executes the query four times in one psql session:

1. One warm-up execution.
2. Three measured executions.

The reported median excludes the warm-up.

Execute the five benchmark scripts:

```bash
mkdir -p results/reproduction_baseline
for q in 1 2 3 4 5; do
  script=$(printf "sql/%02d_benchmark_q%d.sql" "$((q + 4))" "$q")
  psql -X -P pager=off -v ON_ERROR_STOP=1 \
    -d bigdata_lab -f "$script" \
    | tee "results/reproduction_baseline/q${q}_raw.txt"
done
```

Original measurements are preserved in results/benchmark_baseline/.

The timing method uses psql \timing. Results include server execution and client-side result transfer/processing but exclude initial connection establishment.

## 9. Meeting 3 — Secondary Indexes

Two B-tree indexes were introduced sequentially:

Customer-history index:

```sql
CREATE INDEX idx_events_customer_ts_id
ON public.events (customer_id, event_ts DESC, event_id DESC);
```

Timestamp-range index:

```sql
CREATE INDEX idx_events_event_ts
ON public.events (event_ts);
```

The combined index script is available at sql/10_indexes.sql.

To recreate the final indexed state:

```bash
psql -X -v ON_ERROR_STOP=1 -d bigdata_lab -f sql/10_indexes.sql
```

To reproduce the intermediate experiments, create the customer-history index first, collect Q5 measurements, then create the timestamp index and collect Q4 measurements.

Execution plans were captured using EXPLAIN (ANALYZE, BUFFERS).

Plan execution times and psql benchmark times are different measurement scopes.

## 10. Final Indexed Benchmarks

After both indexes are present, rerun the original benchmark scripts:

```bash
mkdir -p results/reproduction_final
for q in 1 2 3 4 5; do
  script=$(printf "sql/%02d_benchmark_q%d.sql" "$((q + 4))" "$q")
  psql -X -P pager=off -v ON_ERROR_STOP=1 \
    -d bigdata_lab -f "$script" \
    | tee "results/reproduction_final/q${q}_raw.txt"
done
```

Original results are preserved in results/benchmark_final/.

Performance Comparison

| Query | Baseline median | Indexed median |
| --- | --- | --- |
| Q1 | 0.061 ms | 0.062 ms |
| Q2 | 260.336 ms | 262.466 ms |
| Q3 | 38.874 ms | 37.244 ms |
| Q4 | 17.839 ms | 2.210 ms |
| Q5 | 19.353 ms | 0.069 ms |

Observed median speedups:

* Q4: Approximately 8.07×.
* Q5: Approximately 280.48×.

Q1–Q3 did not show substantial improvements attributable to the two secondary indexes.

Storage Overhead

| Component | Baseline | Indexed |
| --- | --- | --- |
| Table | 80 MB | 80 MB |
| Indexes | 21 MB | 76 MB |
| Total | 101 MB | 156 MB |

The secondary indexes added approximately 55 MB of rounded PostgreSQL storage.

## 11. Meeting 4 — Import Performance Extension

The extension compared two experimental tables:

Condition A: Primary-key index only.

Condition B: Primary key plus two secondary B-tree indexes.

The setup SQL is saved in sql/11_meeting4_setup.sql.

To prepare the experimental tables after creating both indexes:

```bash
psql -X -v ON_ERROR_STOP=1 \
  -d bigdata_lab -f sql/11_meeting4_setup.sql
```

Safety note: The setup script can remove secondary indexes from the Condition A scratch table. Review existing experimental tables before execution. It does not truncate the main million-row table.

The benchmark script is:

```bash
bash scripts/meeting4_import_benchmark.sh
```

The script truncates and reloads the two scratch tables, not public.events.

Do not rerun the script over the original experiment directory. Preserve the original measurements before starting a new reproduction.

Five rounds were executed in alternating order:

AB → BA → AB → BA → AB

Import Measurements

| Round | A: PK only | B: PK + 2 indexes |
| --- | --- | --- |
| 1 | 213.980 ms | 830.925 ms |
| 2 | 202.670 ms | 473.743 ms |
| 3 | 192.820 ms | 475.926 ms |
| 4 | 133.752 ms | 315.061 ms |
| 5 | 124.535 ms | 318.984 ms |

Condition A median: 192.820 ms.

Condition B median: 473.743 ms.

Ratio of medians: 2.457×.

Relative median increase: 145.69%.

Each import successfully loaded 100,000 records. The original public.events table remained at 1,000,000 records.

The recorded timing covers the psql \copy operation, excluding separate truncation, connection setup, and row-count validation.

## 12. Evidence Files

The following files preserve experimental evidence:

* logs/progress_log.md
* logs/q5_controlled_comparison.sql and logs/q5_controlled_comparison.txt
* sql/pilot/05_benchmark_q1.sql through 09_benchmark_q5.sql
* results/pilot_100k/ raw benchmark outputs and summaries
* results/meeting1_validation.txt
* results/meeting2_validation.txt
* results/benchmark_baseline/measurements.csv
* results/benchmark_baseline/medians.csv
* results/benchmark_final/measurements.csv
* results/benchmark_final/medians.csv
* results/meeting3_q1_plan_before.txt, meeting3_q2_plan_before.txt, meeting3_q3_plan_before.txt, meeting3_q4_plan_before.txt, and meeting3_q5_plan_before.txt
* results/meeting3_q1_plan_after.txt, meeting3_q2_plan_after.txt, meeting3_q3_plan_after.txt, meeting3_q4_plan_after.txt, and meeting3_q5_plan_after.txt
* results/meeting3_index_sizes_final.txt
* results/meeting3_storage_final.txt
* results/meeting4_import_benchmark/measurements.csv
* results/meeting4_import_benchmark/summary.csv
* results/meeting4_import_benchmark/round*_*.txt

The complete methodology and detailed experimental interpretation are documented in logs/progress_log.md.

## 13. Experimental Limitations

The experiment has several limitations:

* Measurements were collected on one local computer.
* All events were synthetic and deterministically generated.
* The original 100k and 1M imports were measured once each.
* Read-query medians were based on three measured repetitions.
* Meeting 4 used five import measurements per condition.
* Cache state and background system activity were not fully controlled.
* The import experiment reused scratch tables.
* No concurrent-client benchmark was performed.
* Index removal and rebuilding were not benchmarked end-to-end.

The results are descriptive and should not be interpreted as universal production-performance guarantees.

## 14. Submission and Privacy

The final submission package should contain:

* The original, unmodified event generator.
* This README.
* SQL schema, validation, workload, benchmark, and index scripts.
* Meeting 4 import benchmark script.
* Raw timing CSVs and execution-plan evidence.
* Four-meeting progress log, supplementary pilot benchmark, and controlled-Q5 follow-up evidence.
* Final academic PDF report (3–5 pages).

The final ZIP must exclude:

* Large generated CSV/JSONL datasets.
* Passwords and credentials.
* Hardware serial numbers, UUIDs, and provisioning identifiers.
* macOS metadata such as __MACOSX and ._*.
* Unrelated local files.

The original results/meeting4_system_info.txt contains identifying device information and must be sanitized or excluded.

## 15. Academic Integrity

All reported benchmark timings originate from the documented local experiments. Ratios and speedups are derived calculations.

Instructor checkpoints have not been independently verified and are not claimed as approved.

For the complete laboratory record, consult logs/progress_log.md.
