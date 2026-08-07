# Visual PI（PyRIT）獨立 track
把注入指令藏進圖片、測 Gemma 4 12B Unified 的多模態 prompt injection，對映簡介「Visual PI 3 確認 2」。
- 執行規格見 `SDD.md`
- 腳本骨架見 `visual_pi_scan.py`（判定用確定性 SubStringScorer）
- 只在一個 backend 跑（建議 GB10/Ollama）；不是兩後端王牌
