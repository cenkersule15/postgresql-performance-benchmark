# Package validation

The original source archive was inspected. The original generator and academic evidence are preserved byte for byte. Original query medians were recalculated from measured CSV rows and matched the README tables. Python files were parsed/compiled, Bash scripts passed `bash -n`, and the new timing summarizer was exercised against the supplied raw timings. A small generated CSV/JSONL sample was checked for reproducibility and consistency.

Docker and PostgreSQL executables were not available in the packaging environment. The Compose workflow and SQL experiments have not been executed there. The included GitHub Actions workflow is a new integration check; no remote passing run is claimed.
