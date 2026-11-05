# Attribution and scope

This portfolio presentation is based on Cenker Sule's coursework for Handling Large Data Sets, Task 1 — PostgreSQL at Scale (27–29 October 2026).

`generate_events.py` was supplied by the course. Its generation logic is unchanged. Authorship of that generator is not claimed by Cenker Sule. The source archive does not identify its author or grant a redistribution licence; confirm permission before publishing that file publicly. This package does not grant rights to third-party material.

The student's work documented here comprises the schema and validation SQL, workload and indexing experiments, local benchmarking, execution-plan analysis and interpretation. The portfolio packaging adds multilingual documentation, a Compose environment, configurable output paths, a reproduction runner and a timing summarizer.

`results/`, `logs/`, `report/` and `docs/ACADEMIC_REPORT.md` preserve the supplied academic evidence. Recorded timings were not regenerated for this portfolio package. New runs write under `results/reproduction/`, which is excluded from Git by default. No general-purpose licence has been added over the mixed-source coursework.

The recorded hardware and software describe the original measurements. Docker reproduction uses PostgreSQL 14 and Python 3.12 images; image tags can change, and new results will differ. There is no browser dashboard, HTTP API or distributed processing component.
