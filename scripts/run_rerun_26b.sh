#!/usr/bin/env bash
set -euo pipefail
: "${MACHINE_ID:?}"; : "${PF_VER:?}"; : "${MODEL_TAG:?}"; : "${EXPECTED_CONTEXT:?}"
export PROMPTFOO_CACHE_ENABLED=false PROMPTFOO_DISABLE_TELEMETRY=1 PROMPTFOO_DISABLE_REDTEAM_REMOTE_GENERATION=true
DIR="results/$MACHINE_ID/26b-A"
mkdir -p "$DIR"
for i in $(seq "${START:-1}" "${END:-5}"); do
  printf -v n '%02d' "$i"
  path="$DIR/run_$n.json"
  test ! -e "$path" || { echo "Refusing to overwrite $path"; exit 1; }
  curl --fail --silent --show-error http://127.0.0.1:11434/api/generate \
    -d "{\"model\":\"$MODEL_TAG\",\"prompt\":\"ok\",\"stream\":false}" > "$DIR/run_$n.warmup.json"
  { date -u; ollama --version; ollama ps; } > "$DIR/run_$n.pre.txt"
  python3 - "$DIR/run_$n.pre.txt" "$MODEL_TAG" "$EXPECTED_CONTEXT" <<'PY'
import sys
lines = open(sys.argv[1]).read().splitlines()
rows = [l.split() for l in lines if l.startswith(sys.argv[2] + ' ')]
if len(rows) != 1 or '100% GPU' not in ' '.join(rows[0]) or sys.argv[3] not in rows[0]:
    raise SystemExit('GPU/context gate failed')
PY
  SECONDS=0
  set +e
  npx --yes "promptfoo@$PF_VER" eval -c rerun/promptfooconfig.rerun-26b.A.yaml --no-cache -j 1 -o "$path"
  status=$?
  set -e
  echo "elapsed_s=$SECONDS promptfoo_exit=$status" >> "$DIR/run_$n.pre.txt"
  python3 scripts/validate_run.py "$path" | tee "$DIR/run_$n.validation.txt"
  # Assertion failures may produce a nonzero eval status; validation decides run validity.
  if [[ "${PUSH_EACH_RUN:-1}" == 1 ]]; then
    (
      until mkdir /tmp/gemma26b-git-lock 2>/dev/null; do sleep 2; done
      trap 'rmdir /tmp/gemma26b-git-lock' EXIT
      git add "$DIR"
      git commit -m "rerun $MACHINE_ID 26b-A run_$n"
      git push
    )
  fi
done
