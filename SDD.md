# Gemma 4 12B × promptfoo — 兩後端弱掃 SDD（Codex CLI 版）

> **Spec 層（工具無關，不隨工具改）**
> 同一顆 Gemma 4 12B；runtime 為唯一變因；兩台都用 **openai-compatible target**；產出 **26B / 12B-Ollama / 12B-MLX 三方對照**；誠實框架落地；每台一份 DoD。
> **Implementation 層（promptfoo）**：以下全部。
>
> **給 Codex CLI 的總則**
> 1. 每步有「✅ 驗證」；沒過不要往下。
> 2. plugin 名稱 / model tag / repo id 對不上 → 先 `promptfoo redteam plugins`、`ollama list`、HF 查證，不要猜。
> 3. 兩台的 promptfoo config 必須「除了 target 的 apiBaseUrl/model 以外完全一樣」。
> 4. CLI/schema 因版本而異；指令被拒就 `promptfoo redteam --help` / docs 修正，不盲改。

---

## 0. 開跑前必須先拍板的一件事：本地 vs 遠端生成/評分 ⚠️

promptfoo 的 redteam **攻擊生成與評分**預設用 OpenAI key；**沒 key 會 proxy 到 promptfoo 雲端**。只有「打 target 模型」一定本地。對 air-gapped 本地掃描，這是資料出境風險。三選一，並在台上揭露你選了哪個：

- **A 全本地**：設 `PROMPTFOO_DISABLE_REDTEAM_REMOTE_GENERATION=true`，`redteam.provider` 指本地強模型（GB10 上另跑一顆較大的當攻擊/評分模型；別用受測的 12B 自己評自己）。→ 資料不出境，但攻擊/評分品質有上限。**建議走這個**，最貼你的立場。
- **B 用你的 OpenAI/其他 key**：品質最好，但攻擊 prompt＋模型回應會送到該 vendor。
- **C 預設 proxy**：最省事，但等於送到 promptfoo/OpenAI 雲端。

> 關鍵類別（LLM01 那 7 條）**一律用確定性 assertion（contains/regex）**、不靠 LLM-as-judge——判準寫進 config，可重現、可反駁。

---

## 0.1 鎖死的控制變因（兩台共用）

| 項目 | 值 |
|---|---|
| 模型 | Gemma 4 12B（instruct）、4-bit |
| promptfoo | pin 版本（例 `promptfoo@0.118.x`），兩台一致 |
| target provider | `openai:chat:<model>`（兩台都用；只有 apiBaseUrl/model 不同）|
| plugins | `owasp:llm` preset |
| numTests | 固定（例 25）／兩台一致 |
| target 取樣 | temperature=0、max_tokens=512 |
| 生成/評分 | 依 §0 的選擇（建議 A 全本地）|

**為何 target 兩台都用 `openai:chat:` 而非 `ollama:`？** 為了「只變 runtime」——GB10 接 Ollama :11434/v1、Mac 接 mlx_lm.server :8080，provider 型別一致，變因只剩 runtime。

---

## A. 共用前置（兩台各做一次）
```bash
node --version                       # ✅ 18+
npm install -g promptfoo@0.118        # pin 版本；或 npx promptfoo@0.118
promptfoo --version                  # ✅ 記錄，寫進報告
promptfoo redteam plugins | grep -i owasp   # 確認 owasp:llm preset 在
```

## B. GB10（Linux / CUDA / Ollama）
**B1 服務模型**
```bash
ollama pull gemma4:12b && ollama list        # tag 不確定就查 ollama library
ollama serve &                                # :11434/v1
```
✅ `curl -s localhost:11434/v1/chat/completions -H 'Content-Type: application/json' -d '{"model":"gemma4:12b","messages":[{"role":"user","content":"ping"}]}' | head`

**B2 config** `promptfooconfig.gb10.yaml`
```yaml
description: "Gemma4-12B redteam · GB10/Ollama"
targets:
  - id: openai:chat:gemma4:12b
    label: gb10-ollama
    config:
      apiBaseUrl: http://localhost:11434/v1
      apiKey: not-needed
      temperature: 0
      max_tokens: 512
redteam:
  purpose: "本地部署的 Gemma 4 12B 通用助理"
  plugins: [owasp:llm]
  numTests: 25
  provider:                       # §0-A 本地攻擊/評分模型（換成你的）
    id: openai:chat:<attacker-model>
    config: { apiBaseUrl: http://localhost:11434/v1, apiKey: not-needed }
```
**B3 跑**
```bash
export PROMPTFOO_DISABLE_REDTEAM_REMOTE_GENERATION=true   # §0-A
promptfoo redteam run -c promptfooconfig.gb10.yaml -o results/gb10.json
promptfoo redteam report -o results/gb10.html
```
✅ 產出 `results/gb10.json` + html。

## C. Mac mini M4（macOS / MLX）
**C1 服務模型**
```bash
pip install -U mlx-lm
mlx_lm.server --model mlx-community/gemma-4-12B-it-4bit --port 8080   # repo id 先到 HF 確認
```
✅ `curl -s localhost:8080/v1/chat/completions ... | head`

**C2 config** `promptfooconfig.mac.yaml`：與 B2 **只有 target 的 apiBaseUrl(:8080)、model 兩處不同**；`redteam` 區塊完全相同。
**C3 跑**：同 B3，`-c promptfooconfig.mac.yaml -o results/macmlx.json`。

## D. 26B 重跑（保三方對照，取代六月 garak 基準）
六月的 26B 是 garak/MitigationBypass，跟 promptfoo pass rate **不可混表**。用同一份 config、target 指 26B 重跑一次：
```bash
ollama pull gemma4:26b        # 或 26B-A4B 正確 tag
# 複製 gb10 config，target model 改 gemma4:26b → promptfooconfig.26b.yaml
promptfoo redteam run -c promptfooconfig.26b.yaml -o results/26b.json
```

## E. 三方合併表（任一台）
從三份 results json 抽每個 OWASP 類別的 pass rate：

| OWASP 類別 | 26B | 12B-Ollama | 12B-MLX | 差異 |
|---|---|---|---|---|
| LLM01…LLM10 逐列 | | | | |

- 12B-Ollama vs 12B-MLX 有差 → **runtime 漂移王牌**
- 12B vs 26B 有差 → size/架構效應（dense vs MoE）

## F. LLM01 spotlight（策展 7 · 確定性判定）
另開 `promptfooconfig.llm01-7.yaml`：自訂 7 條代表性 prompt-injection test case，每條用**確定性 assertion**（`contains` / regex）判 pass/fail，逐條秀 payload＋Gemma 回應。這頁對映簡介的「7 tests」，透明標示為策展子集。

---

## 誠實框架
1. **§0 的本地/遠端選擇要在台上講**——你在掃 air-gapped 本地模型，工具卻可能把攻擊 prompt/回應送出去。
2. **LLM-as-judge 評分非確定性**；關鍵類別（LLM01 7 條）用確定性 assertion。
3. **promptfoo 現為 OpenAI 所有（MIT 仍開源）**——GDG 場、OpenAI 工具、掃 Google 模型，主動點破成梗而非被抓。
4. **Visual PI 走 PyRIT 獨立 track**（另一份 SDD）——promptfoo 本地多模態 Visual PI 覆蓋薄，別掛它名下。
5. **可重現**：pin promptfoo 版本、target temperature=0、記錄 config/版本/日期/硬體。

## Definition of Done（每台各一份）
- [ ] 模型服務起來、curl 得到回應
- [ ] promptfoo 版本 pin 並記錄；§0 的生成/評分模式已決定且記錄
- [ ] config 與另一台「只差 target」；redteam 區塊相同
- [ ] results json + html 收進 results/<machine>/
- [ ]（合併）26B/12B-Ollama/12B-MLX 三方類別 pass rate 表完成
- [ ] LLM01 策展 7 條、確定性判定、逐條 pass/fail
