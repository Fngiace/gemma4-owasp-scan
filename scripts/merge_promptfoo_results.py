#!/usr/bin/env python3
"""Merge one-test Promptfoo JSON files without changing their individual evidence."""
import json
import sys
from pathlib import Path

destination = Path(sys.argv[1])
sources = [Path(path) for path in sys.argv[2:]]
if not sources:
    raise SystemExit("No result files supplied")

documents = [json.loads(path.read_text(encoding="utf-8")) for path in sources]
merged = documents[0]
all_results = []
for document in documents:
    results = document.get("results", {})
    if not isinstance(results, dict) or not isinstance(results.get("results"), list):
        raise SystemExit("Unsupported Promptfoo result structure: " + str(document.keys()))
    all_results.extend(results["results"])
merged["results"]["results"] = all_results
destination.write_text(json.dumps(merged, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
