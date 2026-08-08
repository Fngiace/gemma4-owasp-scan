#!/usr/bin/env python3
"""Validate the expected shape and cardinality of an offline Promptfoo run."""
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
expected = int(sys.argv[2])
data = json.loads(path.read_text(encoding="utf-8"))
results = data.get("results", {}).get("results")
if not isinstance(results, list) or len(results) != expected:
    raise SystemExit(f"expected {expected} results, got {len(results) if isinstance(results, list) else 'invalid'}")
if any("response" not in result or "testCase" not in result for result in results):
    raise SystemExit("a result lacks Promptfoo response/testCase evidence")
print(f"valid: {path} ({len(results)} results)")
