# PostgreSQL Performance Benchmark

[Deutsch](README.md) · [English](README.en.md) · [Türkçe](README.tr.md)

Ein reproduzierbares SQL-Performanceprojekt mit **100.000 und 1.000.000 synthetischen Ereignissen**. Es untersucht Datenqualität, CSV-Import, fünf SQL-Workloads und den Zielkonflikt zwischen schnellen Abfragen, Speicherbedarf und Schreibkosten.

**Python · PostgreSQL · SQL · Docker Compose · B-tree · Query plans**

## Ergebnisse des ursprünglichen lokalen Experiments

| Abfrage | Ohne Sekundärindizes | Mit zwei Sekundärindizes |
| --- | ---: | ---: |
| Q1 | 0.061 ms | 0.062 ms |
| Q2 | 260.336 ms | 262.466 ms |
| Q3 | 38.874 ms | 37.244 ms |
| Q4: Zeitbereich | 17.839 ms | 2.210 ms |
| Q5: Kundenhistorie | 19.353 ms | 0.069 ms |

Q4 wurde etwa **8,07×**, Q5 etwa **280,48×** schneller. Der Gesamtspeicher stieg von rund **101 auf 156 MB**. Beim separaten 100K-Importexperiment stieg der Median mit zwei zusätzlichen Indizes von **192,820 auf 473,743 ms** (2,457×). Q1–Q3 verbesserten sich durch diese Indizes nicht wesentlich.

## Technischer Umfang

- Relationales Schema mit Primärschlüssel, `NOT NULL` und `CHECK`-Constraints.
- CSV-Bulkimport mit `\copy` sowie Prüfungen für Zeilenanzahl, IDs und Datenqualität.
- Punktabfrage, Monatsumsatz, Top-Produkte, Zeitbereich und Kundenhistorie.
- B-tree-Indizes auf `event_ts` sowie `(customer_id, event_ts DESC, event_id DESC)`.
- Analyse mit `EXPLAIN (ANALYZE, BUFFERS)` und dokumentierten Rohmessungen.

## Start mit Docker

Voraussetzungen: Docker mit Compose v2 (`--wait`) und Python 3 auf dem Host. Der Befehl erzeugt Daten, startet PostgreSQL, misst die 1M-Abfragen vor und nach der Indexierung, führt den separaten 100K-Importvergleich aus und berechnet neue Mediane. Internet wird für den ersten Image-Download benötigt. Es wird kein Datenbank-Port am Host veröffentlicht.

```bash
cd postgresql-performance-benchmark
bash scripts/reproduce.sh
```

Die Haupttabelle muss leer sein und darf nur den Primärschlüsselindex besitzen. Für einen weiteren unabhängigen Versuch einen neuen Compose-Projektnamen verwenden:

```bash
COMPOSE_PROJECT_NAME=pg_benchmark_run2 bash scripts/reproduce.sh
```

Container stoppen; das Datenvolume bleibt erhalten:

```bash
docker compose down
```

`results/reproduction/<run-id>/summary.csv`

## Ohne Docker

Python 3, PostgreSQL und `psql` installieren. Die vollständigen nativen Schritte stehen im [ursprünglichen Laborbericht](docs/ACADEMIC_REPORT.md). Das Importscript unterstützt `PGDATABASE`, `CSV` und `OUT`; Host-Zugangsdaten können über die üblichen PostgreSQL-Umgebungsvariablen gesetzt werden.

```bash
PGDATABASE=bigdata_lab CSV=data/events.csv OUT=results/reproduction/import_manual bash scripts/meeting4_import_benchmark.sh
```

## Dateien

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

## Methodik und Grenzen

Originalumgebung: Apple M4 Pro, 24 GB RAM, macOS 26.1, PostgreSQL 14.18 und Python 3.9.6. Pro Leseabfrage: ein Warm-up und drei Messungen; Median ohne Warm-up. Die Zeitmessung nutzt `psql \timing`; EXPLAIN-Zeiten sind separat. Der Importvergleich umfasst fünf Messungen je Bedingung in wechselnder Reihenfolge. Cache und Hintergrundlast wurden nicht vollständig kontrolliert. Die Ergebnisse sind lokale Beobachtungen, keine Produktionsgarantie. Eine Million Zeilen belegt keine verteilte Big-Data-Architektur.

Der ursprüngliche 100K/1M-Q5-Vergleich hatte unterschiedliche Trefferzahlen, einschließlich null Treffern im Pilotlauf. Daraus wird keine allgemeine Skalierungsaussage abgeleitet. Details und der separate Folgeversuch stehen im Laborbericht.

## Herkunft und Veröffentlichung

Aus einem Hochschulprojekt von Cenker Sule weiterentwickelt. Der Ereignisgenerator wurde vom Kurs bereitgestellt; dessen Urheberschaft wird nicht beansprucht. Vor einer öffentlichen Veröffentlichung die Weitergabeerlaubnis für diesen Generator klären. Siehe [NOTICE](NOTICE.md).

## Validierung

Die Originalmediane wurden nachgerechnet; Python-/Bash-Prüfungen und lokale Tests des Generators und der Auswertung wurden durchgeführt. Docker/PostgreSQL waren hier nicht verfügbar; die neue Container-Reproduktion und GitHub Actions sind noch nicht ausgeführt. Siehe [Validierungsnotiz](docs/VALIDATION.md).
