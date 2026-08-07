# AGENTS.md — Gemma 4 12B × promptfoo 兩後端弱掃（GB10）

> 這台開跑前：`cp AGENTS.gb10.md AGENTS.md`。agy 與 Codex 都會自動讀 AGENTS.md。

## 這台機器
- MACHINE: GB10
- TARGET_ENDPOINT: http://localhost:11434/v1

## 你的角色
照 ./SDD.md 執行：這台只做 §A、§B、§D（Mac 的 §C 不要碰）。
模型服務已由人類在另一個 terminal 起好，跑在 TARGET_ENDPOINT。
**不要自己去 `ollama serve`——前景長駐程序會把你卡死。**

## 硬規則
1. §0「本地 vs 遠端生成/評分」由人類拍板。走到那裡先停下來問。
2. 要查的值（ollama tag、attacker-model）用 SDD 指令解出，不要猜；不確定就停。
3. 每個「✅ 驗證」沒過就停。
4. 正式跑 owasp:llm 前，先 numTests:1、單一 plugin smoke test，給人類看過再跑全套。
5. 只在工作資料夾內動作；破壞性/安裝指令先說明再執行。
6. 結果只寫 results/gb10 與 results/26b。
7. target temperature=0、pin promptfoo 版本、每份報告記 版本/seed/日期/硬體。
