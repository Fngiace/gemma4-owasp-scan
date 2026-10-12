#!/usr/bin/env bash
set -euo pipefail
cd /Users/fngi/work/gemma4-owasp-scan
export PATH=/Users/fngi/work/node-v22.23.2-darwin-arm64/bin:/Users/fngi/bin:/opt/homebrew/bin:$PATH
MODEL_TAG=gemma4:26b
while ! ollama list | grep -q '001e5dafc3c7'; do
  kill -0 2002 2>/dev/null || { echo 'Download process ended without matching model; inspect pull result'; exit 1; }
  echo "$(date -u) waiting for matching model download"
  sleep 30
done
while ! pmset -g batt | grep -q 'AC Power'; do
  echo "$(date -u) waiting for AC power before long eval"
  sleep 30
done
test "$(sysctl -n iogpu.wired_limit_mb)" = 26624
# Restart our own idle service to pick up the newly set GPU memory limit.
tmux kill-session -t gemma-ollama
tmux new-session -d -s gemma-ollama 'export OLLAMA_HOST=127.0.0.1:11434 OLLAMA_KEEP_ALIVE=-1 OLLAMA_ORIGINS="*" OLLAMA_CONTEXT_LENGTH=262144; /Users/fngi/bin/ollama serve > /Users/fngi/work/ollama-serve.log 2>&1'
until curl -fsS http://127.0.0.1:11434/api/version >/dev/null; do sleep 2; done
{ date -u; node --version; ollama --version; ollama list; sysctl iogpu.wired_limit_mb; } >> results/mbp-m1-pro/env.txt
python3.12 - <<'PY'
import json,hashlib,pathlib
root=pathlib.Path.home()/'.ollama/models'
p=root/'manifests/registry.ollama.ai/library/gemma4/26b'
assert hashlib.sha256(p.read_bytes()).hexdigest() == '001e5dafc3c77684c2307ebc6ab8e336e10c9b18eca52acf547d72fc83c3ca8c'
manifest=json.loads(p.read_text())
print('Verified manifest identity and digest inventory:',manifest)
# The registry pull verifies blob checksums; no changes to quantization or context.
data=json.load(open('results/gb10_1/26b-A/run_01.json'))['config']
config={k:data[k] for k in ('prompts','providers','defaultTest')}
config['tests']=[{'description':'harmless-connectivity','vars':{'prompt':'請問查詢訂單需要提供什麼資訊？'}}]
pathlib.Path('/tmp/gemma-mac-harmless.json').write_text(json.dumps(config,ensure_ascii=False))
PY
export PROMPTFOO_CACHE_ENABLED=false PROMPTFOO_DISABLE_TELEMETRY=1 PROMPTFOO_DISABLE_REDTEAM_REMOTE_GENERATION=true
npx --yes promptfoo@0.121.20 --version
set +e
npx --yes promptfoo@0.121.20 eval -c /tmp/gemma-mac-harmless.json --no-cache -j 1 -o results/mbp-m1-pro/harmless.json
set -e
python3.12 - <<'PY'
import json
r=json.load(open('results/mbp-m1-pro/harmless.json'))['results']['results']
assert len(r)==1 and not r[0]['response'].get('error') and r[0]['gradingResult']['componentResults']
PY
while tmux has-session -t gemma-gb10-supervisor 2>/dev/null; do sleep 30; done
export MACHINE_ID=mbp-m1-pro PF_VER=0.121.20 EXPECTED_CONTEXT=262144 MODEL_TAG START=1 END=5
bash scripts/run_rerun_26b.sh
