# SDD · GB10（Linux/CUDA/Ollama）— 給這台的 agy 從頭做到尾

> 你是 GB10 上的 agy。在本 repo 工作資料夾內、照這份從上到下做。
> 本 SDD 預設**全本地**（不送資料出去），你不用停下來問政策；其餘照硬規則。

## 硬規則（agy 讀我）
1. 起模型服務**一律背景執行**（`nohup … &`）＋poll 就緒；**絕不前景跑**，前景會把你卡死。
2. 每個「✅ 驗證」沒過就停，別硬往下。
3. 要查的值（ollama tag、26B tag）先用列表指令解出，不要猜；不確定就停下來問。
4. 只在工作資料夾內動作；安裝/破壞性指令先說明再執行。
5. 若你是被 headless 呼叫（`agy -p`），記得帶 `--add-dir "$(pwd)"`，否則看不到這些檔。

## §0 前置：Ollama 服務 + 模型
```bash
# Ollama 在 Linux 常已是 systemd 服務；先驗證，沒起才背景起
curl -sf http://localhost:11434/api/tags >/dev/null || (nohup ollama serve >/tmp/ollama.log 2>&1 & sleep 3)
ollama pull gemma4:12b            # tag 不確定 → `ollama list` / 查 ollama library
ollama pull gemma4:26b            # §D 三方對照用；解出正確 26B(A4B) tag
```
✅ 驗證（就緒才往下）：
```bash
curl -s http://localhost:11434/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"gemma4:12b","messages":[{"role":"user","content":"ping"}]}' | head
```

## §1 裝 promptfoo
```bash
node --version                    # ✅ 20.x 或 22.x
npm install -g promptfoo@0.121
promptfoo --version               # ✅ 記錄
```

## §2 先 eval 接通（不紅隊）——照 Fngi 自己的規矩：先確認打得到、看得懂報告
用 repo 的 `promptfoo/promptfooconfig.gb10.yaml`，暫時把 `redteam` 區塊註掉、加一兩題 `tests`：
```bash
promptfoo eval -c promptfoo/promptfooconfig.gb10.yaml
promptfoo view                    # 本地網頁看報告（確認能讀懂再往下）
```
✅ 看得到逐格輸出＝target 接通。

## §3 紅隊 smoke（先小的）
把 `promptfoo/promptfooconfig.gb10.yaml` 的 `redteam.numTests` 暫設 1、plugins 只留一項：
```bash
export PROMPTFOO_DISABLE_REDTEAM_REMOTE_GENERATION=true    # 全本地
promptfoo redteam run -c promptfoo/promptfooconfig.gb10.yaml -o results/gb10/smoke.json
```
✅ 有 output、能評分＝流程通。**停下來把 smoke 結果給人看過**，再跑全套。

## §4 產生共享攻擊集（兩後端王牌的關鍵：兩台打同一批）
```bash
promptfoo redteam generate -c promptfoo/promptfooconfig.gb10.yaml -o redteam-generated.yaml
git add redteam-generated.yaml && git commit -m "shared redteam attack set" && git push
```
> 這份 commit 上去，Mac 會 pull 同一份來打。若 generate 的 target 綁定方式讓 Mac 難以換 target，
> 改用 fallback：兩台用同一 seed 各自 generate（`--seed`，以 `promptfoo redteam --help` 確認旗標）。

## §5 紅隊全套（12B-Ollama）
`numTests` 調回 25、plugins 用 `owasp:llm`：
```bash
PROMPTFOO_DISABLE_REDTEAM_REMOTE_GENERATION=true \
  promptfoo redteam run -c promptfoo/promptfooconfig.gb10.yaml -o results/gb10/run.json
promptfoo redteam report -o results/gb10/report.html
```

## §6 26B 重跑（三方對照基準）
```bash
PROMPTFOO_DISABLE_REDTEAM_REMOTE_GENERATION=true \
  promptfoo redteam run -c promptfoo/promptfooconfig.26b.yaml -o results/26b/run.json
```

## §7 收尾
```bash
git add results/gb10 results/26b && git commit -m "GB10 + 26B results" && git push
```
## Definition of Done（GB10）
- [ ] 12B、26B 服務都 curl 得到回應
- [ ] promptfoo 版本記錄；§0-全本地環境變數有設
- [ ] eval 接通（§2 看得懂報告）
- [ ] smoke 結果給人看過
- [ ] 共享攻擊集 redteam-generated.yaml 已 commit
- [ ] results/gb10/run.json 與 results/26b/run.json 產出並 push
