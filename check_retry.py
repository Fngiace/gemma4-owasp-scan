import json
d = json.load(open("results/gb10/probe-track2-retry.json"))
for r in d["results"]["results"]:
    print("=" * 60)
    print(r["testCase"].get("description",""), "| success:", r["success"], "| finishReason:", r["response"].get("finishReason"))
    out = r["response"]["output"]
    m = out.find("<answer>")
    print(out[m:m+600] if m != -1 else "（沒有 <answer> 標籤）")
