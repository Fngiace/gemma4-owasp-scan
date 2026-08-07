# gemma4-owasp-scan

用 promptfoo 對本地部署的 **Gemma 4 12B** 跑 OWASP LLM Top 10 弱掃，
在兩個 runtime（GB10/Ollama、Mac/MLX）上比較，並與 26B 做三方對照。

## 信任錨：你不用信我的數字，自己重跑
判準都在 config 裡、target 用 `temperature=0`、結果是純資料。
對**任何** OpenAI-compatible 的 open LLM 重跑同一套：

```bash
ollama serve                 # 或 mlx_lm.server / vLLM …（OpenAI-compatible 端點）
# 改 promptfoo/promptfooconfig.*.yaml 的 target.apiBaseUrl / model
npm install -g promptfoo@0.118
PROMPTFOO_DISABLE_REDTEAM_REMOTE_GENERATION=true \
  promptfoo redteam run -c promptfoo/promptfooconfig.gb10.yaml -o results/gb10/run.json
python scripts/merge_threeway.py
```

## 怎麼跑（兩台）
見 `SDD.md`。每台把自己那份複製成 AGENTS.md 再開 agy/Codex：
```bash
cp AGENTS.gb10.md AGENTS.md      # Mac 上改用 AGENTS.mac.md
```

## 結構
```
SDD.md                     # 執行規格（做什麼）
AGENTS.gb10.md / .mac.md   # 每台的 agent 規則；複製成 AGENTS.md（gitignored）
promptfoo/                 # 四份 config：gb10 / mac / 26b / llm01-7
scripts/merge_threeway.py  # 讀三方 results → 類別 pass rate 對照表
visual-pi-pyrit/           # Visual PI 獨立 track（多模態，另做）
results/{gb10,macmlx,26b}/ # 各機器寫各自子目錄，避免 git 衝突
.env.example               # 走遠端評分才需 key；真 key 放 .env（gitignored）
```

## 誠實框架（跟簡報一致）
- promptfoo redteam 生成/評分預設連 OpenAI（無 key 會 proxy 雲端）。全本地：
  `PROMPTFOO_DISABLE_REDTEAM_REMOTE_GENERATION=true` + 本地 attacker/grader。台上揭露你選了哪個。
- promptfoo 現為 OpenAI 所有（MIT 仍開源）。GDG 場、OpenAI 工具、掃 Google 模型——主動點破。
- LLM-as-judge / MitigationBypass 是排序訊號，非已確認漏洞；關鍵類別用確定性 assertion。
- 六月的 26B garak 數字是另一套指標，不與 promptfoo pass rate 混表。
