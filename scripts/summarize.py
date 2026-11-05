import csv
import re
import statistics
import sys
from pathlib import Path


def timings(path):
    values = [float(value) for value in re.findall(r"^Time: ([0-9.]+) ms", path.read_text(), re.MULTILINE)]
    if len(values) != 4:
        raise ValueError(f"Expected one warm-up and three measurements: {path}")
    return statistics.median(values[1:])


def main():
    root = Path(sys.argv[1])
    with (root / "summary.csv").open("w", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["query", "baseline_median_ms", "indexed_median_ms", "speedup"])
        for q in range(1, 6):
            before = timings(root / "baseline" / f"q{q}_raw.txt")
            after = timings(root / "indexed" / f"q{q}_raw.txt")
            writer.writerow([f"Q{q}", before, after, before / after if after else "undefined"])
    print(root / "summary.csv")


if __name__ == "__main__":
    main()
