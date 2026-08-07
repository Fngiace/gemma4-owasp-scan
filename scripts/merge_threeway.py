#!/usr/bin/env python3
"""
讀 results/{26b,gb10,macmlx}/ 的 promptfoo 輸出，抽每個 OWASP 類別的 pass rate，
印出三方對照 markdown 表。

⚠️ promptfoo 的 results JSON schema 會因版本而異：
   先跑一次真的掃描，`python -m json.tool results/gb10/run.json | less` 看實際結構，
   把 extract_category_rates() 的欄位路徑對到你的版本（下面是常見結構的最佳猜測 + TODO）。
"""
import json, glob
from collections import defaultdict

MACHINES = {"26b": "26B", "gb10": "12B-Ollama", "macmlx": "12B-MLX"}
OWASP = [f"LLM{n:02d}" for n in range(1, 11)]

def load_one(machine):
    files = sorted(glob.glob(f"results/{machine}/*.json"))
    if not files:
        return None
    with open(files[-1], encoding="utf-8") as f:
        return json.load(f)

def extract_category_rates(data):
    """回傳 {LLMxx: pass_rate_0to100}。
    TODO：對到你 promptfoo 版本的實際欄位。常見在 data['results']['results']，
    每筆有 metadata（含 owasp 對映或 pluginId）與 success/pass。"""
    if not data:
        return {}
    rows = (data.get("results", {}) or {}).get("results", [])
    if not isinstance(rows, list):
        rows = data.get("results", []) if isinstance(data.get("results"), list) else []
    hits = defaultdict(lambda: [0, 0])  # cat -> [pass, total]
    for r in rows:
        meta = r.get("metadata") or (r.get("testCase") or {}).get("metadata") or {}
        blob = json.dumps(meta).lower()
        cat = next((k for k in OWASP if k.lower() in blob), None)
        if not cat:
            continue
        passed = r.get("success", r.get("pass"))
        hits[cat][1] += 1
        if passed:
            hits[cat][0] += 1
    return {c: round(100 * p / t, 1) for c, (p, t) in hits.items() if t}

def main():
    rates = {m: extract_category_rates(load_one(m)) for m in MACHINES}
    print("| OWASP | " + " | ".join(MACHINES.values()) + " | 差異(12B) |")
    print("|---|" + "---|" * (len(MACHINES) + 1))
    for cat in OWASP:
        cells = [rates[m].get(cat) for m in MACHINES]
        o, mlx = rates["gb10"].get(cat), rates["macmlx"].get(cat)
        diff = "" if o is None or mlx is None else f"{round(mlx - o, 1):+}"
        vals = " | ".join("" if c is None else f"{c}" for c in cells)
        print(f"| {cat} | {vals} | {diff} |")
    print("\n差異(12B) ≠ 0 的類別＝runtime 漂移王牌素材。")

if __name__ == "__main__":
    main()
