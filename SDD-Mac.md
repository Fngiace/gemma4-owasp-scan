# SDD · Mac mini M4 24G（macOS/MLX）— 給這台的 agy 從頭做到尾

> 你是 Mac mini 上的 agy。在本 repo 工作資料夾內、照這份從上到下做。
> 本 SDD 預設**全本地**；其餘照硬規則。

## 硬規則（agy 讀我）
1. 起模型服務**一律背景執行**（`nohup … &`）＋poll 就緒；**絕不前景跑**。
2. 每個「✅ 驗證」沒過就停。
3. 要查的值（mlx repo id）先確認再用，不要猜；不確定就停。
4. 只在工作資料夾內動作；安裝/破壞性指令先說明再執行。
5. 若被 headless 呼叫（`agy -p`），帶 `--add-dir "$(pwd)"`。

## ⚠️ 24G 記憶體注意
Gemma 4 12B QAT 4-bit ≈ 7GB，塞進 24G 綽綽有餘。**但不要同時再起一顆大 attacker/grader 模型**，會吃緊。
本 SDD 的紅隊**用 GB10 已產好的共享攻擊集**來打（§3），Mac 只需服務 12B target ＋確定性判定，記憶體最省、又保證兩台打同一批。

## §0 前置：MLX 服務 + 模型
```bash
pip install -U mlx-lm
# 確認 repo id 存在（例 mlx-community/gemma-4-12B-it-4bit）→ HF mlx-community 查
nohup mlx_lm.server --model mlx-community/gemma-4-12B-it-4bit --port 8080 >/tmp/mlx.log 2>&1 &
sleep 5
```
✅ 驗證：
```bash
curl -s http://localhost:8080/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"gemma-4-12B-it-4bit","messages":[{"role":"user","content":"ping"}]}' | head
```

## §1 裝 promptfoo
```bash
node --version                    # ✅ 20.x 或 22.x
npm install -g promptfoo@0.121
promptfoo --version               # ✅ 記錄
```

## §2 先 eval 接通（不紅隊）
用 repo 的 `promptfoo/promptfooconfig.mac.yaml`（target 已指 :8080 / MLX），暫時註掉 `redteam`、加一兩題 `tests`：
```bash
promptfoo eval -c promptfoo/promptfooconfig.mac.yaml
promptfoo view
```
✅ 看得到逐格輸出＝MLX target 接通。

## §3 用共享攻擊集打（兩台打同一批）
先 pull 到 GB10 產的攻擊集：
```bash
git pull                          # 取得 GB10 commit 的 redteam-generated.yaml
```
把該攻擊集的 target 指到本機 MLX 後 eval（確切旗標以 `promptfoo redteam --help` / docs 為準）：
```bash
PROMPTFOO_DISABLE_REDTEAM_REMOTE_GENERATION=true \
  promptfoo eval -c redteam-generated.yaml \
  --providers '[{"id":"openai:chat:gemma-4-12B-it-4bit","config":{"apiBaseUrl":"http://localhost:8080/v1","apiKey":"not-needed","temperature":0}}]' \
  -o results/macmlx/run.json
```
> 若「用生成檔換 target」在你版本不順，fallback：用 `promptfoo/promptfooconfig.mac.yaml` 跑 `redteam run`，
> 但改用與 GB10 相同的 `--seed`（§4-GB10 的 fallback），讓兩台攻擊近似。這時 grader 若需模型，
> 用本機 12B 自身當 grader（品質有上限、要在報告註明），別另起大模型。

## §4 收尾
```bash
promptfoo redteam report -o results/macmlx/report.html || true
git add results/macmlx && git commit -m "Mac MLX results" && git push
```
## Definition of Done（Mac）
- [ ] MLX 12B 服務 curl 得到回應
- [ ] promptfoo 版本記錄；§0-全本地環境變數有設
- [ ] eval 接通（§2）
- [ ] 用了 GB10 的共享攻擊集（或同 seed fallback），未另起大 attacker 模型
- [ ] results/macmlx/run.json 產出並 push
