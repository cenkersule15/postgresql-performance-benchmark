"""Generate one reproducible synthetic workload for the laboratory."""
import argparse
import csv
import json
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path

FIELDS = ("event_id", "event_ts", "customer_id", "product_id", "region", "quantity", "unit_price_cents", "status")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rows", type=int, default=1_000_000)
    parser.add_argument("--outdir", type=Path, default=Path("data"))
    args = parser.parse_args()
    if args.rows < 1:
        parser.error("--rows must be positive")
    args.outdir.mkdir(parents=True, exist_ok=True)
    rng = random.Random(2026)
    start = datetime(2025, 1, 1, tzinfo=timezone.utc)
    csv_path = args.outdir / "events.csv"
    jsonl_path = args.outdir / "events.jsonl"
    with csv_path.open("w", encoding="utf-8", newline="") as csv_file, jsonl_path.open("w", encoding="utf-8") as jsonl_file:
        writer = csv.DictWriter(csv_file, fieldnames=FIELDS)
        writer.writeheader()
        for event_id in range(1, args.rows + 1):
            stamp = start + timedelta(minutes=rng.randrange(365 * 24 * 60))
            event = {
                "event_id": event_id,
                "event_ts": stamp.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "customer_id": rng.randint(1, 100_000),
                "product_id": rng.randint(1, 2_000),
                "region": rng.choice(("North", "South", "East", "West", "Central")),
                "quantity": rng.randint(1, 5),
                "unit_price_cents": rng.randint(100, 20_000),
                "status": rng.choices(("completed", "cancelled", "pending"), weights=(85, 5, 10))[0],
            }
            writer.writerow(event)
            mongo_event = dict(event)
            mongo_event["event_ts"] = {"$date": event["event_ts"]}
            jsonl_file.write(json.dumps(mongo_event, separators=(",", ":")) + "\n")
    print(f"Created {args.rows:,} rows in {csv_path} and {jsonl_path}")
    print("Seed: 2026; event IDs and field values match across both files.")

if __name__ == "__main__":
    main()