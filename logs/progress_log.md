# Task 1 — PostgreSQL at Scale

## Laboratory Progress Log and Experimental Evidence

**Course:** Handling Large Data Sets  
**Assignment:** Assignment 1 — PostgreSQL at Scale (25 points)  
**Laboratory sessions:** Meetings 1–4  
**Initial documentation:** 27 October 2026  
**Last updated:** 29 October 2026  
**Status:** Meetings 1–4 and supplementary pilot/controlled-Q5 technical experiments documented; instructor checkpoints, demonstrations, and final submission audit unconfirmed.  
**Platform:** MacBook Pro (Apple M4 Pro, 12 CPU cores, 24 GB RAM), macOS 26.1, Python 3.9.6, PostgreSQL 14.18 (Homebrew).

> **Evidence convention:** “Observed” means a recorded experiment output; “calculated” means derived from recorded values; “proposed” means untested. Client `psql` timings and server-side `EXPLAIN ANALYZE` execution times are not interchangeable. The document records the reported experimental evidence, not a fresh independent audit of local files or instructor approval.

---

## 1. Project Overview

### 1.1 Objective

Investigate PostgreSQL ingestion, validation, query execution, indexing, storage, and write-maintenance costs using deterministic synthetic datasets of 100,000 and 1,000,000 events. The course-supplied `generate_events.py` was retained without altering its generation logic; random seed **2026** was used throughout.

| Meeting | Scope | Technical status |
|---|---|---|
| 1 | Relational model, pilot generation, import, validation | Completed; checkpoint unconfirmed |
| 2 | One-million-row import, five queries, baseline measurements | Completed; checkpoint unconfirmed |
| 3 | Execution plans, two secondary indexes, before/after evaluation | Completed; checkpoint unconfirmed |
| 4 | Repeated indexed versus unindexed bulk-import experiment | Completed; checkpoint unconfirmed |

### 1.2 Experimental principles

The experiments retain raw observations, distinguish measurement from interpretation, use one warm-up plus three measured executions for query benchmarks, preserve the same SQL for pre/post-index comparisons, and disclose uncontrolled cache/background load, synthetic-data effects, small samples, and absence of concurrency. The later controlled-Q5 supplement uses server-side `EXPLAIN ANALYZE` execution times, not the client-side `psql \timing` values in the original benchmarks. Large generated CSV/JSONL files and identifying hardware metadata are excluded from the intended submission.

---

## 2. Experimental Environment

### 2.1 Software and hardware

| Component | Recorded value |
|---|---|
| Host | MacBook Pro, model Mac16,8 |
| Processor | Apple M4 Pro; 12 CPU cores (8 performance, 4 efficiency) |
| RAM | 24 GB |
| OS | macOS 26.1, build 25B78 |
| Editor | Visual Studio Code |
| Python | 3.9.6 |
| PostgreSQL | 14.18, Homebrew, ARM64, 64-bit |
| Database | `bigdata_lab` (UTF8) |
| Client | `psql` |
| Data formats | CSV and JSONL |
| Seed | 2026 |

Verification commands:

```bash
pg_isready
psql -d postgres -c "SELECT current_user, version();"
```

Recorded readiness: `/tmp:5432 - accepting connections`. The PostgreSQL build string `aarch64-apple-darwin24.4.0` does not independently identify the host operating-system version.

### 2.2 Database settings

| Setting | Recorded value |
|---|---:|
| `shared_buffers` | 128 MiB |
| `effective_cache_size` | 4 GiB |
| `work_mem` | 4 MiB |
| `maintenance_work_mem` | 64 MiB |
| `max_parallel_workers_per_gather` | 2 |
| `random_page_cost` | 4 |
| `effective_io_concurrency` | 0 |
| `synchronous_commit` | on |

`effective_cache_size` is a planner estimate, not allocated memory. At inspection, the filesystem reported approximately 460 GiB capacity and 190 GiB available; this is not a verified physical drive-capacity measurement. Evidence: `results/meeting4_postgres_settings.txt`. The original `results/meeting4_system_info.txt` contains device identifiers and **must not be included unredacted**.

---

## 3. Project Organization and Evidence

The submission project is organized around the original generator, reproducible SQL, scripts, raw measurements, progress log, and report:

```text
task1_Sule/
├── README.md
├── generate_events.py
├── sql/
│   ├── 01_schema.sql
│   ├── 02_validation.sql
│   ├── 03_validation_1m.sql
│   ├── 04_workloads.sql
│   ├── 05_benchmark_q1.sql ... 09_benchmark_q5.sql
│   └── pilot/
│       └── 05_benchmark_q1.sql ... 09_benchmark_q5.sql
├── scripts/
│   └── meeting4_import_benchmark.sh
├── results/
│   ├── benchmark_baseline/
│   ├── benchmark_after_index1/
│   ├── benchmark_after_index2/
│   ├── benchmark_final/
│   ├── pilot_100k/
│   ├── meeting4_import_benchmark/
│   └── meeting*_*.txt
├── logs/
│   ├── progress_log.md
│   ├── q5_controlled_comparison.sql
│   └── q5_controlled_comparison.txt
└── report/
    └── Task1_PostgreSQL_Report.pdf
```

The `data/` directory is generated locally and omitted from the submission archive. This tree summarizes documented evidence; actual ZIP contents must be checked again before submission. The raw system-information capture is excluded for privacy.

---

## 4. Meeting 1 — Data Model and Pilot Import

**Technical status:** Completed; instructor checkpoint unconfirmed.

Objectives: generate and inspect 100,000 events, verify data integrity, implement a constrained PostgreSQL table, time a CSV import, validate rows, and discuss relational alternatives and scaling risks.

---

## 5. Dataset Description

| Column | Type/role | Generated domain |
|---|---|---|
| `event_id` | Unique event identifier | Sequential positive integers |
| `event_ts` | UTC event timestamp | Calendar year 2025 |
| `customer_id` | Customer key | 1–100,000 |
| `product_id` | Product key | 1–2,000 |
| `region` | Category | North, South, East, West, Central |
| `quantity` | Units | 1–5 |
| `unit_price_cents` | Integer unit price | 100–20,000 |
| `status` | Event state | completed, cancelled, pending |

Approximate generator probabilities are 85% completed, 5% cancelled, and 10% pending. Actual observed distributions are reported separately. The data are synthetic, and JSONL was generated alongside the CSV but was not used for PostgreSQL `\copy`.

---

## 6. Pilot Dataset Generation

```bash
python3 generate_events.py --rows 100000 --outdir data
```

Recorded output: `data/events.csv` (100,000 records plus header) and `data/events.jsonl` (100,000 records). Pilot generation duration was not measured.

---

## 7. Pilot File Inspection

```bash
ls -lh data/events.csv data/events.jsonl
wc -l data/events.csv data/events.jsonl
head -n 2 data/events.csv
tail -n 1 data/events.csv
```

| File | Lines | Exact bytes |
|---|---:|---:|
| `data/events.csv` | 100,001 | 6,147,339 |
| `data/events.jsonl` | 100,000 | 17,547,257 |

CSV header:

```text
event_id,event_ts,customer_id,product_id,region,quantity,unit_price_cents,status
```

First CSV record: `1,2025-03-28T17:46:00Z,41876,1030,Central,1,7416,cancelled`.

Last CSV record: `100000,2025-10-13T06:22:00Z,23565,553,South,2,1062,completed`.

---

## 8. Pilot SHA-256 Integrity References

```bash
shasum -a 256 data/events.csv data/events.jsonl
```

| File | Recorded SHA-256 |
|---|---|
| Pilot CSV | `d831ab1d6b95fbdc830e16415aff2c68b6264e1a24560d3655b7f94ad2927667` |
| Pilot JSONL | `8cdbaaff727e8d28416ec71b7ec1365edd1529eec57c00f265604530af0b37b8` |

Hashes establish byte-level comparison references, not semantic correctness on their own.

---

## 9. PostgreSQL Database Creation

```bash
createdb bigdata_lab
psql -d bigdata_lab -c "SELECT current_database(), current_user;"
psql -d postgres -c "\l"
```

The dedicated `bigdata_lab` database was confirmed with UTF8 encoding. `createdb` is a one-time setup step; an existing database should be inspected rather than overwritten.

---

## 10. Relational Schema Design

### 10.1 Implemented schema

Saved as `sql/01_schema.sql`:

```sql
CREATE TABLE IF NOT EXISTS events (
    event_id BIGINT PRIMARY KEY,
    event_ts TIMESTAMPTZ NOT NULL,
    customer_id INTEGER NOT NULL CHECK (customer_id BETWEEN 1 AND 100000),
    product_id INTEGER NOT NULL CHECK (product_id BETWEEN 1 AND 2000),
    region TEXT NOT NULL CHECK (region IN ('North','South','East','West','Central')),
    quantity INTEGER NOT NULL CHECK (quantity BETWEEN 1 AND 5),
    unit_price_cents INTEGER NOT NULL CHECK (unit_price_cents >= 0),
    status TEXT NOT NULL CHECK (status IN ('completed','cancelled','pending'))
);
```

All eight columns are `NOT NULL`. There are six column-level `CHECK` constraints (customer, product, region, quantity, price, status) and a primary-key constraint. The price constraint intentionally allows any nonnegative integer, rather than restricting values to the generator's narrower domain. `BIGINT` arithmetic avoids integer overflow in revenue calculations. `TIMESTAMPTZ` stores instants; display depends on the session time zone.

### 10.2 Schema inspection

```bash
psql -X -v ON_ERROR_STOP=1 -d bigdata_lab -f sql/01_schema.sql
psql -P pager=off -d bigdata_lab -c "\d events"
```

The schema inspection confirmed the `events_pkey` primary-key B-tree index.

---

## 11. Pilot Import Experiment

The destination table was verified empty before import.

```bash
psql -X -v ON_ERROR_STOP=1 -d bigdata_lab \
  -c "\timing on" \
  -c "\copy events (event_id, event_ts, customer_id, product_id, region, quantity, unit_price_cents, status) FROM 'data/events.csv' WITH (FORMAT csv, HEADER true)"
```

Observed: `COPY 100000`; **224.680 ms**. This was one successful timed import. The measurement covers the client-observed `\copy` operation, not generation, connection setup, or validation.

---

## 12. Pilot Post-Import Validation

SQL: `sql/02_validation.sql`. Evidence: `results/meeting1_validation.txt`.

```bash
psql -X -P pager=off -v ON_ERROR_STOP=1 -d bigdata_lab -f sql/02_validation.sql
```

| Check | Observed result |
|---|---:|
| Rows / distinct IDs | 100,000 / 100,000 |
| Minimum / maximum ID | 1 / 100,000 |
| Earliest UTC | 2025-01-01 00:01:00 |
| Latest UTC | 2025-12-31 23:55:00 |
| Outside 2025 UTC | 0 |
| NULL values across required fields | 0 |
| Completed | 85,039 (85.039%) |
| Cancelled | 4,897 (4.897%) |
| Pending | 10,064 (10.064%) |

The latest UTC timestamp displayed locally as `2026-01-01 00:55:00+01`; this is the same instant as `2025-12-31 23:55:00+00`, not an out-of-range event. Year boundaries were evaluated in UTC.

---

## 13. Experimental Evidence and Interpretation Rules

The project distinguishes terminal outputs, derived statistics, untested design proposals, and administrative milestones. Raw files should be retained alongside calculated medians; a reported speedup must identify the numerator, denominator, and measurement method. Instructor approval cannot be inferred from completed technical work.

---

## 14. Alternative Relational Schema Designs

### 14.1 Single event table — implemented

One table minimizes import complexity and avoids joins in the specified five-query workload.

### 14.2 Normalized schema — proposed, not benchmarked

Separate customers, products, regions, and events could improve referential integrity and reduce repeated descriptive attributes, but require foreign-key maintenance, additional joins, and more complex ingestion.

### 14.3 Monthly range partitioning — proposed, not benchmarked

Partitioning by `event_ts` could support partition pruning for date ranges and simplify retention. Setup and maintenance are more complex. In PostgreSQL, a unique or primary-key constraint on a partitioned table must include all partition key columns; a composite `(event_id, event_ts)` key does not by itself guarantee `event_id` uniqueness across different timestamps.

| Criterion | Single table | Normalized | Time-partitioned |
|---|---|---|---|
| Implementation complexity | Low | Medium | Medium–high |
| Initial ingestion | Simple | Multi-table | Partition setup required |
| Referential integrity | Limited | Stronger with FKs | Schema-dependent |
| Date filtering | Index-dependent | Index-dependent | Pruning possible |
| Maintenance | Low | Medium | Higher |

These are qualitative architectural assessments, not measured performance comparisons.

---

## 15. Relational Scalability Considerations

Sequential scans, grouping, sorting, joins, and write-ahead logging can become more expensive with increasing data volume. Appropriate indexes, updated planner statistics, query rewrites, and selective partitioning may help, depending on workload and data distribution. Secondary indexes also require storage and maintenance on writes; Meetings 3–4 quantify this trade-off locally.

---

## 16. Meeting 1 — Issues and Resolutions

| Issue | Observation | Resolution |
|---|---|---|
| `cleqr` typo | Shell command not found | Used `clear`; no database impact |
| Interactive pager | Long output paused | Exited with `q`; used `-P pager=off` |
| `l` typo | Shell command not found | Re-ran schema inspection |
| Local timestamp appeared in 2026 | UTC offset changed displayed date | Verified the UTC instant |

---

## 17. Meeting 1 — Findings

The 100,000-row pilot was generated, inspected, imported, and validated. The recorded import took **224.680 ms**. Unique IDs, UTC time bounds, non-null constraints, and status distributions were consistent with expectations. One import is insufficient to establish general throughput.

---

## 18. Meeting 1 — Checkpoint Status

| Requirement | Status |
|---|---|
| Generate and inspect 100K records | Completed |
| Inspect header, counts, boundaries, hashes | Completed |
| Create and inspect constrained schema | Completed |
| Time pilot CSV import | Completed: 224.680 ms |
| Validate IDs, UTC bounds, NULLs, statuses | Completed |
| Discuss two schema alternatives | Completed |
| Instructor demonstration/checkpoint | **Unconfirmed** |

---

## 19. Meeting 2 — Full Dataset and Baseline Workloads

### 19.1 Objective

Generate one million deterministic records without overwriting the pilot files; import and validate the larger dataset; implement five workloads; record a primary-key-only baseline.

### 19.2 Generation and import

```bash
mkdir -p data/full_1m
time python3 generate_events.py --rows 1000000 --outdir data/full_1m
```

Recorded generation wall-clock time: **8.473 s**. After explicitly resetting the dedicated `public.events` table, `\copy` returned `COPY 1000000` in **1666.363 ms**. The one-million-row source remained intact through the later index and scratch-table experiments.

### 19.3 Workloads

| Query | Purpose |
|---|---|
| Q1 | Lookup `event_id = 500000` |
| Q2 | Completed revenue/count by UTC month and region |
| Q3 | Top 10 products by completed revenue |
| Q4 | Count events in March 2025 UTC |
| Q5 | History of `customer_id = 50000`, newest first |

### 19.4 Benchmark protocol

Each benchmark script executes one warm-up and three measured queries in one `psql` session. `\timing` measures client-observed elapsed time; `\o /dev/null` avoids terminal rendering but not protocol transfer. The warm-up is excluded from the median.

---

## 20. Meeting 3 — Query Plans and Indexing

Before secondary indexes, Q1 used the existing primary key; Q2 and Q3 relied on broad scans and aggregation; Q4 and Q5 used expensive scans for selective predicates. Two indexes were created sequentially:

```sql
CREATE INDEX idx_events_customer_ts_id
ON public.events (customer_id, event_ts DESC, event_id DESC);

CREATE INDEX idx_events_event_ts
ON public.events (event_ts);
```

Final client-side medians improved from **17.839 to 2.210 ms** for Q4 and **19.353 to 0.069 ms** for Q5. Q1–Q3 remained broadly similar. Rounded index storage increased from **21 MB to 76 MB**, a roughly **55 MB** addition. A separate single-run 100K import comparison was **221.196 ms** (PK only) versus **529.940 ms** (PK plus two indexes). Details and limitations appear in Section 27.

---

## 21. Meeting 4 — Extension and Final Evaluation

Five repeated 100K-row imports were recorded for each of two scratch-table conditions: A, primary key only; B, primary key plus two secondary indexes. Orders alternated **AB, BA, AB, BA, AB**. Each trial truncated only its scratch table, imported the same CSV, checked `COPY 100000`, and verified row counts. The original `public.events` remained at one million rows.

Median client-observed import durations were **192.820 ms** (A) and **473.743 ms** (B), giving a **2.457× ratio of medians** and **145.69%** relative increase. Five trials per condition and uncontrolled environmental effects restrict the conclusion to a descriptive local comparison.

---

## 22. Reproducibility and Experimental Integrity

The fixed seed and unmodified generator support regeneration. Reproducibility artifacts include schema and validation SQL, workload definitions, benchmark scripts, hashes, raw timing files, plan captures, and calculated summaries. The original pilot and full-scale imports were single observations. The Meeting 3 single-run import comparison and Meeting 4 five-round extension are separate experiments and must not be pooled without justification.

---

## 23. Current Project Status

### 23.1 Completed technical work

1. Configured the local PostgreSQL database and constrained eight-column schema.
2. Generated and inspected the 100K pilot and 1M full-scale datasets with seed 2026.
3. Recorded SHA-256 references and exact dataset file sizes.
4. Imported and validated 100K and 1M rows, with UTC-aware checks.
5. Defined and verified Q1–Q5; captured full-scale baseline measurements.
6. Saved baseline and final `EXPLAIN (ANALYZE, BUFFERS)` plans.
7. Created two workload-specific B-tree indexes and captured intermediate evidence.
8. Recorded final indexed benchmarks and relation/index storage sizes.
9. Compared single-run imports with one versus three indexes.
10. Repeated the 100K import comparison five times per condition, preserving raw evidence.
11. Benchmarked Q1–Q5 on a separate 100K pilot table and saved scaling summaries.
12. Verified the original Q5 pilot filter had zero matches versus 15 at 1M, then performed a separately labeled, same-customer, PK-only, server-instrumented Q5 supplement (Section 33).

### 23.2 Items requiring final confirmation

1. Instructor checkpoints and live demonstrations are **not verified**.
2. Check that all newly added pilot SQL/results and `logs/q5_controlled_comparison.*` are included in the final ZIP.
3. Confirm that the PDF report reflects the pilot query benchmark if the report claims to summarize all experiments.
4. Rebuild and audit the ZIP after the latest edits; do not rely on an earlier integrity check.
5. Exclude raw identifying hardware capture, credentials, and generated CSV/JSONL files.

---

## 24. Research Objective and Current Interpretation

The full-scale import was approximately **7.42×** the pilot import duration for **10×** as many rows, based on one import per size. This ratio does not establish a scaling law. The later Q1–Q5 100K pilot benchmark provides a descriptive comparison with the one-million-row primary-key-only baseline (Section 31), subject to a material Q5 zero-match versus 15-match confound. A separate matched-customer PK-only Q5 experiment (Section 33) addresses that specific issue without eliminating other sources of variability. Targeted indexes improved the measured Q4/Q5 workloads but increased storage and import maintenance cost; broad Q2/Q3 aggregations did not materially benefit.

---

## 25. Meeting 2 — Detailed Experimental Record

### 25.1 Full-scale dataset integrity

| Metric | Recorded value |
|---|---:|
| Generation duration | 8.473 s |
| CSV lines | 1,000,001 including header |
| JSONL lines | 1,000,000 |
| CSV bytes | 62,479,517 |
| JSONL bytes | 176,479,435 |
| CSV SHA-256 | `5bc5a278384e35dc3b16e4907aa6b261a0611e30b6e4f332b413a01af7123de5` |
| JSONL SHA-256 | `ab9dbb1eef1e159ba16fa77b8cfbb13387e146857f32405f3a7d4852fbac8493` |

### 25.2 Full-scale import

The target `public.events` table was deliberately emptied before the million-row load, preserving its schema and primary key. The import command was:

```bash
psql -X -v ON_ERROR_STOP=1 -d bigdata_lab \
  -c "\timing on" \
  -c "\copy public.events (event_id, event_ts, customer_id, product_id, region, quantity, unit_price_cents, status) FROM 'data/full_1m/events.csv' WITH (FORMAT csv, HEADER true)"
```

Observed: `COPY 1000000`; **1666.363 ms**. This is one `\copy` timing, not a complete pipeline timing.

### 25.3 Full-scale validation

Evidence: `sql/03_validation_1m.sql`, `results/meeting2_validation.txt`.

| Check | Observed |
|---|---:|
| Total / distinct IDs | 1,000,000 / 1,000,000 |
| ID range | 1–1,000,000 |
| Earliest UTC | 2025-01-01 00:00:00 |
| Latest UTC | 2025-12-31 23:59:00 |
| Completed | 849,606 (84.9606%) |
| Cancelled | 49,753 (4.9753%) |
| Pending | 100,641 (10.0641%) |
| Out-of-year / NULL / invalid-range records | 0 |

`ANALYZE public.events;` was run before baseline benchmarking.

### 25.4 Five SQL workloads

**Q1 — Point lookup**

```sql
SELECT event_id, event_ts, customer_id, product_id, region,
       quantity, unit_price_cents, status
FROM public.events
WHERE event_id = 500000;
```

Observed one event: customer 59974, product 74, status completed.

**Q2 — Completed revenue by UTC month and region**

```sql
SELECT DATE_TRUNC('month', event_ts AT TIME ZONE 'UTC') AS event_month_utc,
       region, COUNT(*) AS completed_events,
       SUM(quantity::bigint * unit_price_cents) AS revenue_cents
FROM public.events
WHERE status = 'completed'
GROUP BY DATE_TRUNC('month', event_ts AT TIME ZONE 'UTC'), region
ORDER BY event_month_utc, region;
```

Observed 60 month-region groups.

**Q3 — Top products by completed revenue**

```sql
SELECT product_id, COUNT(*) AS completed_events,
       SUM(quantity::bigint * unit_price_cents) AS revenue_cents
FROM public.events
WHERE status = 'completed'
GROUP BY product_id
ORDER BY revenue_cents DESC, product_id
LIMIT 10;
```

Observed ten rows; top product 1595, revenue 15,550,932 cents.

**Q4 — March 2025 UTC range**

```sql
SELECT COUNT(*) AS march_2025_events
FROM public.events
WHERE event_ts >= TIMESTAMPTZ '2025-03-01 00:00:00+00'
  AND event_ts < TIMESTAMPTZ '2025-04-01 00:00:00+00';
```

Observed **84,715** rows.

**Q5 — Customer history**

```sql
SELECT event_id, event_ts, product_id, region,
       quantity, unit_price_cents, status
FROM public.events
WHERE customer_id = 50000
ORDER BY event_ts DESC, event_id DESC;
```

Observed **15** rows.

### 25.5 Baseline timing method

SQL scripts: `sql/05_benchmark_q1.sql` through `sql/09_benchmark_q5.sql`. Example:

```bash
psql -X -P pager=off -v ON_ERROR_STOP=1 -d bigdata_lab \
  -f sql/05_benchmark_q1.sql \
  | tee results/benchmark_baseline/q1_raw.txt
```

The same command pattern was used for Q2–Q5. One warm-up and three timed runs per query; medians exclude warm-up.

### 25.6 Baseline raw results

| Query | Warm-up (ms) | Run 1 | Run 2 | Run 3 | Median (ms) |
|---|---:|---:|---:|---:|---:|
| Q1 | 0.911 | 0.078 | 0.061 | 0.055 | **0.061** |
| Q2 | 301.929 | 267.216 | 258.451 | 260.336 | **260.336** |
| Q3 | 73.329 | 40.323 | 38.352 | 38.874 | **38.874** |
| Q4 | 38.023 | 24.448 | 17.839 | 15.561 | **17.839** |
| Q5 | 35.312 | 22.519 | 19.353 | 14.717 | **19.353** |

Evidence: `results/benchmark_baseline/q*_raw.txt`, `measurements.csv`, `medians.csv`.

### 25.7 Baseline storage

| Component | Rounded PostgreSQL size |
|---|---:|
| Table | 80 MB |
| Primary-key index | 21 MB |
| Total relation | 101 MB |

Source: `results/meeting2_storage.txt`. Values are human-readable rounded sizes, not exact byte counts.

### 25.8 Limitations and completion

The baseline comprises three measured executions per query on one local machine, with no controlled cold-cache state or concurrent load. All technical Meeting 2 tasks were recorded; instructor checkpoint unconfirmed.

---

## 26. Milestones and Submission Readiness

Meetings 1–4 experimental work, the supplementary 100K query benchmark, and the controlled-Q5 follow-up have been recorded. Before submission, verify the final ZIP contents, ensure that the PDF and README accurately describe the evidence, and document any instructor demonstrations separately. No instructor sign-off is claimed here.

---

## 27. Meeting 3 — Detailed Query Plans, Indexing, and Trade-offs

### 27.1 Experimental design

The validated one-million-row `public.events` table initially had only `events_pkey`. Baseline `EXPLAIN (ANALYZE, BUFFERS)` plans were captured for Q1–Q5. The two secondary indexes were then added sequentially, with intermediate and final plans, benchmark timings, and storage evidence recorded. The million-row source table was not truncated in these tests.

### 27.2 Baseline plans

| Query | Recorded baseline plan | Plan execution (ms) |
|---|---|---:|
| Q1 | `events_pkey` Index Scan | 0.068 |
| Q2 | Seq Scan, external merge sort, GroupAggregate | 335.669 |
| Q3 | Parallel Seq Scan, partial/final aggregation, top-N heapsort | 72.063 |
| Q4 | Parallel Seq Scan | 36.828 |
| Q5 | Parallel Seq Scan and sort | 32.082 |

Q2 selected 849,606 completed events and spilled approximately **28,288 kB** during external sorting. Q3 launched two parallel workers, aggregated 2,000 product groups, and used a 26 kB top-N heapsort. Q4 matched 84,715 events; Q5 matched 15 customer events. Evidence: `results/meeting3_q1_plan_before.txt` through `meeting3_q5_plan_before.txt`.

### 27.3 Index design and intermediate observations

**Customer-history index (Q5):**

```sql
CREATE INDEX idx_events_customer_ts_id
ON public.events (customer_id, event_ts DESC, event_id DESC);
```

The leading equality column targets the customer filter; the following descending keys align with the requested ordering. The observed intermediate plan used a Bitmap Index Scan and Bitmap Heap Scan; its execution time was **0.204 ms**. Intermediate client timings: warm-up **2.431 ms**; measured **0.326, 0.207, 0.179 ms**; median **0.207 ms**. Rounded index size: **39 MB**.

**Timestamp index (Q4):**

```sql
CREATE INDEX idx_events_event_ts
ON public.events (event_ts);
```

The half-open UTC range predicate became eligible for an Index Only Scan, with **0 heap fetches** in the observed intermediate plan. Intermediate plan execution time: **11.132 ms**. Client timings: warm-up **8.965 ms**; measured **7.296, 8.172, 5.007 ms**; median **7.296 ms**.

Intermediate evidence: `results/meeting3_q5_plan_after_index1.txt`, `results/meeting3_q4_plan_after_index2.txt`, `results/benchmark_after_index1/`, `results/benchmark_after_index2/`.

### 27.4 Final plans

| Query | Recorded final access path | Plan execution (ms) |
|---|---|---:|
| Q1 | `events_pkey` Index Scan | 0.058 |
| Q2 | Seq Scan, external merge sort, GroupAggregate | 331.813 |
| Q3 | Parallel Seq Scan, partial/final aggregation, top-N heapsort | 96.515 |
| Q4 | `idx_events_event_ts` Index Only Scan | 10.489 |
| Q5 | Bitmap Index Scan + Bitmap Heap Scan + quicksort | 0.109 |

Q1 remained a one-row primary-key lookup, with seven shared buffer hits recorded in both plans. Q2 still scanned the table and spilled **28,288 kB** to temporary disk; its final plan recorded `temp read=4831 written=4852`. Q3 still used parallel scan and aggregation; a slower single instrumented execution does not establish a systematic regression. Q4 returned 84,715 matches (87,449 estimated) with **Heap Fetches: 0** and **180 shared buffer hits** in its final index-only plan. Q5 returned 15 rows (11 estimated), with **15 exact heap blocks** and **24 shared buffer hits**; bitmap access did not preserve the index's order, so a small quicksort remained. The UTC date boundaries are equivalent despite local DST display offsets.

Evidence: `results/meeting3_q1_plan_after.txt` through `meeting3_q5_plan_after.txt`.

### 27.5 Final client-side benchmark

| Query | Warm-up (ms) | Run 1 | Run 2 | Run 3 | Median (ms) |
|---|---:|---:|---:|---:|---:|
| Q1 | 0.852 | 0.062 | 0.071 | 0.049 | **0.062** |
| Q2 | 305.644 | 262.466 | 277.666 | 257.660 | **262.466** |
| Q3 | 38.540 | 37.864 | 37.244 | 37.075 | **37.244** |
| Q4 | 2.870 | 2.210 | 2.391 | 2.146 | **2.210** |
| Q5 | 0.645 | 0.080 | 0.069 | 0.065 | **0.069** |

The same SQL and timing procedure were used before and after indexing. Evidence: `results/benchmark_final/q*_raw.txt`, `measurements.csv`, `medians.csv`.

### 27.6 Baseline versus final medians

| Query | Baseline (ms) | Indexed (ms) | Interpretation |
|---|---:|---:|---|
| Q1 | 0.061 | 0.062 | Effectively unchanged |
| Q2 | 260.336 | 262.466 | Effectively unchanged |
| Q3 | 38.874 | 37.244 | Small, inconclusive difference |
| Q4 | 17.839 | **2.210** | **8.07×** sampled median speedup |
| Q5 | 19.353 | **0.069** | **280.48×** sampled median speedup |

Speedups are ratios of sampled client-side medians; they are not promises of production latency or statistical significance.

### 27.7 Storage cost

| Component | Before | After |
|---|---:|---:|
| Table | 80 MB | 80 MB |
| All indexes | 21 MB | 76 MB |
| Total relation | 101 MB | 156 MB |

Final index sizes: `events_pkey` **21 MB**, `idx_events_customer_ts_id` **39 MB**, `idx_events_event_ts` **16 MB**. Thus, two secondary indexes added approximately **55 MB** of rounded reported storage. Evidence: `results/meeting3_index_sizes_final.txt`, `results/meeting3_storage_final.txt`.

### 27.8 Single-run import overhead

Two separate scratch tables were created using `LIKE public.events INCLUDING ALL`, copying schema, constraints, and indexes. The two secondary indexes were removed only from `public.events_insert_no_extra_idx`, leaving its primary key; `public.events_insert_with_extra_idx` retained all three. Verified index definitions distinguished the conditions.

| Condition | Imported rows | Index count | One `\copy` timing |
|---|---:|---:|---:|
| PK only | 100,000 | 1 | **221.196 ms** |
| PK + two secondary | 100,000 | 3 | **529.940 ms** |

The observed difference was **308.744 ms**, a **~2.40×** ratio (approximately **139.6%** longer). This comparison has one trial per condition; sequence, caches, and background activity were uncontrolled. Both scratch tables were validated at 100,000 rows, and the original `public.events` remained at **1,000,000**. Evidence: `results/meeting3_import_no_extra_idx.txt`, `meeting3_import_with_extra_idx.txt`, `meeting3_import_validation.txt`.

### 27.9 Interpretation

The tested secondary indexes specifically target Q4 and Q5, not the broad status-filtered aggregations Q2/Q3. Read improvements came with extra disk usage and index-maintenance cost. `EXPLAIN ANALYZE` timings include instrumentation and cannot be directly equated with `psql \timing` medians. Further partial indexes, higher `work_mem`, and end-to-end drop/rebuild strategies are **proposals**, not results of this experiment.

### 27.10 Meeting 3 checkpoint

Baseline plans, intermediate/final index evidence, repeated final query timings, storage comparisons, and the single-run import trade-off were documented. Instructor demonstration **unconfirmed**.

---

## 28. Meeting 4 Transition and Final Submission Plan

Meeting 3's single-run write comparison motivated a repeated experiment. Meeting 4 measured five imports per condition in alternating order, with per-trial validation and preserved raw logs. Final packaging should include the scripts and evidence while excluding generated datasets and identifying system captures. Instructor sign-off remains unconfirmed.

---

## 29. Meeting 4 — Repeated Import/Index-Maintenance Experiment

**Date:** 29 October 2026.  
**Research question:** What is the observed cost of maintaining two secondary B-tree indexes while bulk-importing the same 100,000 events?

### 29.1 Input and environment

The input was the preserved pilot `data/events.csv` (6,147,339 bytes, 100,000 data records). PostgreSQL 14.18 ran on the local Apple M4 Pro machine described in Section 2. No concurrent-client load was deliberately generated. The JSONL file was not imported into PostgreSQL.

### 29.2 Conditions

| Condition | Scratch table | Indexes |
|---|---|---|
| A | `public.events_insert_no_extra_idx` | Primary key on `event_id` |
| B | `public.events_insert_with_extra_idx` | Primary key + customer composite + timestamp B-tree |

Each trial separately truncated its scratch table, ran `psql \copy` for the same CSV, checked `COPY 100000`, and verified 100,000 rows. `TRUNCATE` preserved index definitions. The original one-million-row `public.events` table was not modified by the trial script. The round orders were **AB, BA, AB, BA, AB** (partially, not perfectly, counterbalanced).

The timed interval was the client-observed `\copy` command; it excluded separate truncation, connection startup, and verification. Each import used a separate `psql` process. There was no dedicated warm-up import; all ten observations count.

### 29.3 Raw timings

| Round | Order | A: PK only (ms) | B: PK + 2 indexes (ms) |
|---|---|---:|---:|
| 1 | AB | 213.980 | 830.925 |
| 2 | BA | 202.670 | 473.743 |
| 3 | AB | 192.820 | 475.926 |
| 4 | BA | 133.752 | 315.061 |
| 5 | AB | 124.535 | 318.984 |

All ten imports returned `COPY 100000`; scratch-table counts were verified after each. The source million-row table remained at 1,000,000 rows.

### 29.4 Descriptive statistics

| Statistic | A: PK only | B: PK + 2 indexes |
|---|---:|---:|
| Sample size | 5 | 5 |
| Mean | 173.551 ms | 482.928 ms |
| **Median** | **192.820 ms** | **473.743 ms** |
| Minimum | 124.535 ms | 315.061 ms |
| Maximum | 213.980 ms | 830.925 ms |
| Sample standard deviation | 41.353 ms | 209.936 ms |

The ratio of medians is **473.743 / 192.820 = 2.457×**, equivalent to **145.69%** longer relative to condition A. This is *not* the median of within-round ratios. B was slower in all five observed rounds. The first B timing, 830.925 ms, is high relative to subsequent B observations, increasing dispersion; medians provide a more robust descriptive summary than means here. No confidence interval or statistical-significance claim is made.

### 29.5 Comparison with Meeting 3

Meeting 3's one-off comparison yielded **221.196 versus 529.940 ms**, or about **2.40×**. Meeting 4's repeated comparison yielded a **2.457× ratio of medians**. The two experiments are directionally consistent but differ in sequence and conditions and are not pooled.

The indexes that increased import-maintenance cost also produced sampled read-query improvements for Q4 and Q5 (8.07× and 280.48×, respectively), at a rounded additional index-storage cost of 55 MB. Index retention should be decided using actual read/write workload priorities, not a single universal rule.

### 29.6 Threats to validity

1. Five trials per condition provide limited information about long-term variability.
2. Cache and background system activity were not instrumented or held constant.
3. Scratch tables were reused after `TRUNCATE`, rather than recreated for every trial.
4. AB occurred three times and BA twice; order was not perfectly balanced.
5. There was no dedicated warm-up; the first B run was unusually slow.
6. `\copy` timing excludes connection setup, truncation, and verification.
7. Only one computer, database configuration, fixed-seed synthetic input, and single client were tested.
8. No end-to-end drop-index/load/rebuild-index strategy was measured.
9. No concurrency, lock contention, or production transaction throughput was evaluated.
10. Index selectivity and planner behavior may differ for real data distributions.

### 29.7 Evidence inventory

| Artifact | Project path |
|---|---|
| PostgreSQL settings | `results/meeting4_postgres_settings.txt` |
| Input file sizes | `results/meeting4_file_sizes.txt` |
| Verified scratch indexes | `results/meeting4_test_table_indexes.txt` |
| Initial table counts | `results/meeting4_pre_experiment_counts.txt` |
| Executable script | `scripts/meeting4_import_benchmark.sh` |
| Chronological output | `results/meeting4_import_benchmark/experiment_console.txt` |
| Raw trial measurements | `results/meeting4_import_benchmark/measurements.csv` |
| Calculated statistics | `results/meeting4_import_benchmark/summary.csv` |
| Individual trial outputs | `results/meeting4_import_benchmark/round*_*.txt` |
| Raw hardware capture — **exclude unredacted** | `results/meeting4_system_info.txt` |

**Meeting 4 conclusion:** In this local, repeated 100K-row `\copy` experiment, maintaining two additional secondary indexes was associated with a **2.457× ratio of median import durations** relative to a primary-key-only table. This is descriptive evidence of a read/write trade-off, not a general performance guarantee. Instructor checkpoint unconfirmed.

---

## 30. Final Documentation and Submission Status

| Deliverable | Recorded status / required check |
|---|---|
| Meeting 1 pilot and validation | Technical evidence documented |
| Meeting 2 full-scale baseline | Technical evidence documented |
| Meeting 3 plans/indexing/storage | Technical evidence documented |
| Meeting 4 repeated import experiment | Technical evidence documented |
| Supplementary 100K query benchmark | Completed; see Section 31 |
| Controlled Q5 follow-up (PK-only) | Completed; see Section 33; raw SQL and EXPLAIN outputs recorded |
| README | Updated with 100K pilot comparison; final audit recommended |
| SQL and benchmark scripts | Documented; verify final ZIP includes pilot scripts |
| Raw measurements and progress log | Documented; verify final ZIP contents |
| 3–5 page PDF report | Earlier version reported prepared; verify coverage of latest pilot results |
| Final ZIP | **Rebuild and recheck after latest changes** |
| Instructor demonstrations/checkpoints | **Unconfirmed** |

**Submission hygiene:** Exclude generated CSV/JSONL data, credentials, serial numbers, device UUIDs, provisioning identifiers, `__MACOSX`/`._*` metadata, and unrelated files. Preserve the unmodified generator, SQL, scripts, raw measurements, README, progress log, and final PDF. Do not claim the final ZIP has been audited until the archive has actually been regenerated and inspected after these changes.

---

## 31. Supplementary 100K Pilot Query Benchmark — 29 October 2026

### 31.1 Motivation and design

The original 100K pilot import and the 1M baseline were completed at different points in the project. To strengthen the two-scale comparison, a separate `public.events_pilot` table was populated with **100,000 validated events** and benchmarked for Q1–Q5. This preserved the original one-million-row `public.events` table and its secondary indexes. The pilot table had **only its primary-key index** during the pilot query benchmark; the one-million-row comparator was the previously saved **primary-key-only baseline**, not the final indexed benchmark.

Pilot validation confirmed 100,000 rows, 100,000 distinct event IDs, ID range 1–100,000, and zero NULL timestamps. The table was analyzed before benchmarking. The pilot Q1 used `event_id = 50000`, whereas the full-scale Q1 used `event_id = 500000`; other workload structures were retained with the pilot table substituted. This parameter difference and uncontrolled cache conditions limit exact cross-scale comparability.

### 31.2 Measurement protocol and raw results

Each pilot workload was run once for warm-up and three times for measurement using `psql \timing`. The median is calculated from the three measured executions only.

| Query | Warm-up (ms) | Run 1 | Run 2 | Run 3 | Pilot median (ms) |
|---|---:|---:|---:|---:|---:|
| Q1 | 2.819 | 0.122 | 0.091 | 0.068 | **0.091** |
| Q2 | 57.213 | 33.217 | 24.805 | 23.613 | **24.805** |
| Q3 | 9.364 | 8.107 | 8.147 | 8.244 | **8.147** |
| Q4 | 3.796 | 2.446 | 2.541 | 2.443 | **2.446** |
| Q5 | 3.019 | 2.039 | 2.093 | 2.140 | **2.093** |

### 31.3 Two-scale descriptive comparison

| Query | 100K pilot median (ms) | 1M PK-only baseline median (ms) | 1M / 100K |
|---|---:|---:|---:|
| Q1 | 0.091 | 0.061 | **0.670×** |
| Q2 | 24.805 | 260.336 | **10.495×** |
| Q3 | 8.147 | 38.874 | **4.772×** |
| Q4 | 2.446 | 17.839 | **7.293×** |
| Q5 | 2.093 | 19.353 | **9.247×** |

The Q1 ratio below 1 is consistent with very short primary-key lookups being dominated by timing noise and fixed overhead at this measurement scale; it is not evidence that larger tables universally improve point-lookup latency. Q2's broad aggregation increased approximately in proportion to the row count in these observations, while Q3 and Q4 exhibited workload-dependent ratios. **Q5 is not a like-for-like cardinality comparison:** the pilot query with `customer_id = 50000` returned **0 rows**, whereas the 1M baseline query returned **15 rows**. Its **9.247×** ratio is retained as a calculation from the original recorded timings, but **must not be interpreted as a dataset-size scaling effect**. Different match counts, runtime conditions, and cache states confound that comparison. Section 33 documents a separate follow-up using a customer present in both tables. All ratios are descriptive, not scaling laws or statistically tested effects.

### 31.4 Evidence and reproducibility

| Artifact | Relative path |
|---|---|
| Pilot benchmark SQL | `sql/pilot/05_benchmark_q1.sql` through `09_benchmark_q5.sql` |
| Raw `psql` outputs | `results/pilot_100k/05_benchmark_q1.txt` through `09_benchmark_q5.txt` |
| Individual measurements | `results/pilot_100k/raw_measurements.csv` |
| Pilot medians | `results/pilot_100k/summary.csv` |
| Two-scale ratios | `results/pilot_100k/scaling_comparison.csv` |

**Pilot conclusion:** All five workloads have recorded warm-up and three-run measurements on both the 100K primary-key-only pilot and the historical 1M primary-key-only baseline. Q5 had zero matching pilot rows versus 15 full-scale rows and therefore is **not suitable for a clean scale-factor inference**. The original results remain unchanged for traceability. The supplementary measurements do not remove cache, run-count, parameter, or single-machine limitations.

---

## 32. Final Research Conclusions and Academic Integrity

The experiments establish the following **local observations**: the fixed-seed datasets passed the recorded validation checks; one-million-row aggregation queries required substantially more work than primary-key point lookups; the targeted timestamp and customer indexes reduced Q4 and Q5 sampled client-side medians substantially; two additional indexes consumed approximately 55 MB of rounded storage and increased the measured cost of 100K-row bulk imports; and the supplementary 100K query benchmark documented workload-specific differences across dataset sizes. The original Q5 cross-scale comparison is explicitly qualified because its pilot predicate returned zero rows. A later same-customer, PK-only follow-up (Section 33) yielded a 1.890× ratio of sampled **server-side** medians, with different match counts and execution strategies still present.

The study does **not** establish universal speedup factors, production-scale throughput, statistically significant differences, benefits from untested schema alternatives, or superiority of an unmeasured drop-and-rebuild index strategy. The 1.890× server-instrumented Q5 ratio must not be directly compared with client-side `psql` ratios as though they used identical measurement methods. Instructor checkpoint and live demonstration points remain unconfirmed. Before submission, compare this log, README, report, and raw files for consistency, then regenerate and audit the ZIP.

---

## 33. Supplementary Controlled Q5 Follow-up — 29 October 2026

### 33.1 Motivation and research question

A post-benchmark cardinality check established that the original pilot Q5 filter (`customer_id = 50000`) matched **0** events in `public.events_pilot`, whereas the historical 1M Q5 baseline matched **15** events in `public.events`. The 9.247× original cross-scale timing ratio is therefore not an isolated measure of dataset-size effects. The follow-up asks: *How did a customer-history query perform at the two table sizes when the same customer identifier and primary-key-only index configuration were used?*

A pilot frequency check identified `customer_id = 66808` with **8** matching pilot events. The full dataset had **14** matching events for that identifier. This reduces the zero-result asymmetry but does **not** equalize result cardinality.

### 33.2 Baseline-copy preparation and verification

The original `public.events` table already had three indexes: `events_pkey`, `idx_events_customer_ts_id`, and `idx_events_event_ts`. Comparing its then-current indexed Q5 performance with the PK-only pilot would have mixed table-size and indexing effects. To avoid altering existing experiments, a separate table `public.events_baseline_1m` was created with the original table's schema and indexes, and its two copied secondary indexes were dropped. A subsequent `pg_indexes` inspection verified that **only `events_baseline_1m_pkey` on `event_id` remained**. The original `public.events` retained all three indexes; `public.events_pilot` retained only `events_pilot_pkey`.

The following copy was executed successfully:

```sql
INSERT INTO public.events_baseline_1m
SELECT * FROM public.events;
```

The terminal reported `INSERT 0 1000000`. `ANALYZE public.events_baseline_1m;` was run. Subsequent validation reported **1,000,000 total rows**, **1,000,000 distinct `event_id` values**, and **14** rows with `customer_id = 66808`. This new table is a **PK-only copy of the already indexed full dataset**, not the historical original baseline measurement session. No claim is made that copying reproduces the original physical layout or cache state.

### 33.3 Query and measurement protocol

The same SQL structure was executed against `public.events_pilot` and `public.events_baseline_1m`, substituting only the table name:

```sql
SELECT event_id, customer_id, event_ts
FROM public.events_pilot  -- replace with public.events_baseline_1m for 1M
WHERE customer_id = 66808
ORDER BY event_ts DESC, event_id DESC
LIMIT 50;
```

**Important workload distinction:** This follow-up is a **Q5-style customer-history variant**, not byte-for-byte the original Q5. Original Q5 selected seven columns and had **no `LIMIT`**; the follow-up selected three columns and used `LIMIT 50`. Both observed result counts (8 and 14) were below 50, so the limit did not truncate returned rows, but the narrower projection and limit can still affect query planning and performance. **Do not substitute these follow-up timings for the original Q5 timings.**

A single `psql` script executed **one warm-up and three measured runs per table**, with all four pilot executions preceding all four 1M executions. Each run used `EXPLAIN (ANALYZE, BUFFERS)`. Times below are PostgreSQL-reported **server-side execution times**, not client-side `psql \timing` measurements. The warm-ups were excluded from medians. Because runs were grouped by table rather than interleaved, order and progressive warming remain possible confounders.

### 33.4 Raw execution times and calculated medians

| Execution | 100K PK-only pilot (ms) | 1M PK-only copy (ms) |
|---|---:|---:|
| Warm-up — excluded | 9.589 | 21.029 |
| Measured run 1 | 9.239 | 16.103 |
| Measured run 2 | 7.222 | 13.653 |
| Measured run 3 | 3.583 | 11.826 |
| **Median of three measured runs** | **7.222** | **13.653** |

**Calculated ratio of sampled medians:** `13.653 / 7.222 ≈ 1.8905`, or approximately **1.890×**. The absolute difference between the sampled medians was **6.431 ms**. These calculations use the three measured runs only; no inferential uncertainty interval was estimated.

### 33.5 Observed execution plans

- **100K pilot:** `Seq Scan on events_pilot` followed by an in-memory `quicksort` on `(event_ts DESC, event_id DESC)`. The scan reported **8 matching rows** and **99,992 rows removed by filter**. No customer-specific secondary index was present.
- **1M PK-only copy:** `Parallel Seq Scan on events_baseline_1m` followed by per-process sorting and result gathering. The parallel scan reported **`loops=3`**; its approximately **5 matching rows per loop** and **333,329 rows removed by filter per loop** are rounded per-loop averages, not exact counts for individual participants. The independently verified total matching-row count was **14**. The displayed excerpt does not independently establish how much work the leader performed relative to the workers, and per-loop `EXPLAIN` counts should not be treated as exact global totals.
- Both plans used scanning rather than a customer-specific index lookup; their different serial/parallel strategies mean the comparison is not an isolation of table size alone.

### 33.6 Interpretation and threats to validity

The sampled 1M median was approximately **1.890×** the sampled 100K median for this specific Q5-style variant under the recorded conditions. This comparison aligns the **customer identifier**, **index configuration**, **projection**, **ordering**, **limit**, and **instrumentation method** across the two tables. It does **not** align matching-row counts (8 versus 14), physical table layout, parallel execution choice, or cache state.

Measured times declined across runs (pilot **9.239 → 7.222 → 3.583 ms**; 1M **16.103 → 13.653 → 11.826 ms**), consistent with potential cache warming or other runtime variation; the cause was not independently measured. The small number of observations, single local machine, synthetic data, sequential group ordering, and absence of concurrent load further restrict inference. In particular, the 1.890× result **does not disprove or replace** the earlier 9.247× arithmetic ratio: the two ratios describe different query variants, parameter cardinalities, measurement protocols, and experimental sessions.

### 33.7 Reproducibility artifacts and provenance

| Artifact | Path | Purpose |
|---|---|---|
| Executed supplementary SQL | `logs/q5_controlled_comparison.sql` | Eight `EXPLAIN (ANALYZE, BUFFERS)` executions with run labels |
| Captured raw plan output | `logs/q5_controlled_comparison.txt` | Full server execution plans and timings |
| This progress log | `logs/progress_log.md` | Recorded setup, raw timing transcription, interpretation, and limitations |

The SQL script was confirmed to contain **eight** `EXPLAIN (ANALYZE, BUFFERS)` statements, and the output file was generated successfully. Both evidence files must be included in the **newly rebuilt** submission archive; their presence in any previously prepared ZIP has **not** been verified. The copy table exists in the local database, not as a portable data artifact; regenerating it requires the original full dataset and the documented index preparation.

**Follow-up status:** Experiment completed and reported with limitations. Original Q5 measurements and the zero-versus-15-match discrepancy are preserved; instructor sign-off and final submission audit remain unconfirmed.

---

**End of progress log — Meetings 1–4, supplementary 100K query evidence, and controlled Q5 follow-up documented. Final PDF/README/ZIP consistency checks and instructor checkpoint confirmation remain outstanding.**
