# PostgreSQL Performance Benchmark

[Deutsch](README.md) · [English](README.en.md) · [Türkçe](README.tr.md)

A reproducible SQL performance project using **100,000 and 1,000,000 synthetic events**. It explores data quality, CSV ingestion, five SQL workloads, and the trade-off between query speed, storage and write costs.

**Python · PostgreSQL · SQL · Docker Compose · B-tree · Query plans**

## Results from the original local experiment

| Query | Primary key only | With two secondary indexes |
| --- | ---: | ---: |
| Q1 | 0.061 ms | 0.062 ms |
| Q2 | 260.336 ms | 262.466 ms |
| Q3 | 38.874 ms | 37.244 ms |
| Q4: Timestamp range | 17.839 ms | 2.210 ms |
| Q5: Customer history | 19.353 ms | 0.069 ms |

Q4 improved by approximately **8.07×**, and Q5 by **280.48×**. Total storage increased from about **101 to 156 MB**. In a separate 100K-row import experiment, the median rose from **192.820 to 473.743 ms** with two extra indexes (2.457×). Q1–Q3 did not substantially benefit from these indexes.

## Technical scope

- Relational schema with a primary key, `NOT NULL` and `CHECK` constraints.
- CSV bulk ingestion using `\copy`, plus row-count, ID and data-quality validation.
- Point lookup, monthly revenue, top products, timestamp range and customer history workloads.
- B-tree indexes on `event_ts` and `(customer_id, event_ts DESC, event_id DESC)`.
- Execution-plan analysis using `EXPLAIN (ANALYZE, BUFFERS)` with preserved raw measurements.

## Run with Docker

Requirements: Docker with Compose v2 (`--wait`) and Python 3 on the host. This command generates the data, starts PostgreSQL, measures the 1M queries before and after indexing, runs the separate 100K import comparison, and calculates new medians. Internet is needed for the initial image download. No database port is published to the host.

```bash
cd postgresql-performance-benchmark
bash scripts/reproduce.sh
```

The main table must be empty and have only its primary-key index. Use a new Compose project name for another independent run:

```bash
COMPOSE_PROJECT_NAME=pg_benchmark_run2 bash scripts/reproduce.sh
```

Stop containers while retaining the database volume:

```bash
docker compose down
```

`results/reproduction/<run-id>/summary.csv`

## Run without Docker

Install Python 3, PostgreSQL and `psql`. Full native steps are in the [original laboratory report](docs/ACADEMIC_REPORT.md). The import script accepts `PGDATABASE`, `CSV` and `OUT`; native connection settings use standard PostgreSQL environment variables.

```bash
PGDATABASE=bigdata_lab CSV=data/events.csv OUT=results/reproduction/import_manual bash scripts/meeting4_import_benchmark.sh
```

## Files

| Path | Content |
| --- | --- |
| `generate_events.py` | Course-supplied deterministic generator |
| `sql/` | Schema, validation, workloads, indexes |
| `scripts/reproduce.sh` | Docker reproduction |
| `scripts/summarize.py` | New query median summary |
| `scripts/meeting4_import_benchmark.sh` | Import A/B benchmark |
| `results/` | Original raw measurements and plans |
| `logs/` | Original laboratory records |
| `report/` | Original academic PDF |
| `docs/ACADEMIC_REPORT.md` | Original detailed README |
| `.github/workflows/ci.yml` | Reproduction smoke test |

## Methodology and limitations

Original environment: Apple M4 Pro, 24 GB RAM, macOS 26.1, PostgreSQL 14.18 and Python 3.9.6. Each read workload used one warm-up and three measured runs; medians exclude warm-up. Timing uses `psql \timing`; EXPLAIN execution times are separate. The import comparison uses five measurements per condition with alternating order. Cache and background activity were not fully controlled. Results are local observations, not production guarantees. One million rows does not demonstrate a distributed big-data architecture.

The original 100K/1M Q5 comparison had different matching-row counts, including zero pilot matches. It is not presented as a general scaling result. The laboratory report documents this limitation and a separate follow-up experiment.

## Attribution and publication

Adapted from Cenker Sule's university coursework. The event generator was supplied by the course; its authorship is not claimed. Confirm redistribution permission for the generator before public publication. See [NOTICE](NOTICE.md).

## Validation

Original medians were recalculated. Python/Bash checks and local tests of data generation and timing summarization were performed. Docker/PostgreSQL were unavailable here; the new container workflow and GitHub Actions have not been executed. See the [validation note](docs/VALIDATION.md).
