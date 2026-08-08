#!/usr/bin/env python3
"""Create a small offline HTML summary from a Promptfoo JSON evaluation file."""
import html
import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
destination = Path(sys.argv[2])
data = json.loads(source.read_text(encoding="utf-8"))
results = data.get("results", {}).get("results", data.get("results", []))
if not isinstance(results, list):
    raise SystemExit("Unsupported Promptfoo result structure")

rows = []
passed = 0
for item in results:
    success = bool(item.get("success"))
    passed += success
    test = item.get("testCase", {})
    description = test.get("description", "")
    output = "\n".join(line.rstrip() for line in str(item.get("response", {}).get("output", "")).splitlines())
    reason = item.get("response", {}).get("metadata", {}).get("finishReason", "")
    status = "PASS" if success else "FAIL"
    rows.append(
        "<tr><td>{}</td><td class=\"{}\">{}</td><td>{}</td><td><pre>{}</pre></td></tr>".format(
            html.escape(str(description)), status.lower(), status,
            html.escape(str(reason)), html.escape(str(output))
        )
    )

title = html.escape(data.get("config", {}).get("description", source.stem))
body = """<!doctype html><meta charset=\"utf-8\"><title>{title}</title>
<style>body{{font-family:system-ui;margin:2rem}}table{{border-collapse:collapse;width:100%}}th,td{{border:1px solid #ccc;padding:.5rem;text-align:left;vertical-align:top}}.pass{{color:#087f23;font-weight:700}}.fail{{color:#b71c1c;font-weight:700}}pre{{white-space:pre-wrap;max-width:70rem}}</style>
<h1>{title}</h1><p>來源：{source}</p><p>通過：<strong>{passed}/{total}</strong></p>
<table><thead><tr><th>測試</th><th>結果</th><th>結束原因</th><th>轉換後輸出</th></tr></thead><tbody>{rows}</tbody></table>
""".format(title=title, source=html.escape(str(source)), passed=passed, total=len(results), rows="\n".join(rows))
destination.write_text(body, encoding="utf-8")
