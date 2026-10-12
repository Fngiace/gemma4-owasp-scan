#!/usr/bin/env bash
set -euo pipefail
cd /Users/fngi/work/gemma4-owasp-scan
export PATH=/Users/fngi/work/node-v22.23.2-darwin-arm64/bin:/Users/fngi/bin:/opt/homebrew/bin:$PATH
REMOTE=/home/fngi/work/gemma4-owasp-scan
retry() { local attempt; for attempt in 1 2 3 4 5; do if "$@"; then return 0; fi; sleep 10; done; return 1; }
for i in 2 3 4 5; do
  printf -v n '%02d' "$i"
  session="gemma26b-run-$n"
  while true; do
    state=$(retry ssh -o BatchMode=yes -o ConnectTimeout=30 gb10_1 "cd $REMOTE; if test -f results/gb10_1/run_$n.exit; then echo done; elif tmux has-session -t $session 2>/dev/null; then echo running; elif test -e results/gb10_1/26b-A/run_$n.json; then echo orphan; else echo absent; fi")
    case "$state" in
      done) break ;;
      running) sleep 30 ;;
      orphan) echo "Unverified existing result for run_$n; inspect before proceeding"; exit 1 ;;
      absent)
        # If dispatch observation fails, query the same session again before any retry.
        ssh -o BatchMode=yes -o ConnectTimeout=30 gb10_1 "cd $REMOTE; tmux new-session -d -s $session 'cd $REMOTE; export PATH=/home/fngi/.nvm/versions/node/v22.23.2/bin:\$PATH MACHINE_ID=gb10_1 PF_VER=0.121.20 MODEL_TAG=gemma4:26b EXPECTED_CONTEXT=262144 START=$i END=$i PUSH_EACH_RUN=0; bash scripts/run_rerun_26b.sh > results/gb10_1/run_$n.runner.log 2>&1; echo \$? > results/gb10_1/run_$n.exit'" || true
        sleep 5 ;;
      *) echo "Unexpected remote state: $state"; exit 1 ;;
    esac
  done
  status=$(retry ssh -o BatchMode=yes -o ConnectTimeout=30 gb10_1 "cat $REMOTE/results/gb10_1/run_$n.exit")
  retry scp -q -o BatchMode=yes -o ConnectTimeout=30 -r "gb10_1:$REMOTE/results/gb10_1/26b-A" results/gb10_1/
  retry scp -q -o BatchMode=yes -o ConnectTimeout=30 "gb10_1:$REMOTE/results/gb10_1/run_$n.runner.log" results/gb10_1/
  test "$status" = 0
  python3.12 scripts/validate_run.py "results/gb10_1/26b-A/run_$n.json" > "results/gb10_1/26b-A/run_$n.validation.txt"
  (
    until mkdir /tmp/gemma26b-git-lock 2>/dev/null; do sleep 2; done
    trap 'rmdir /tmp/gemma26b-git-lock' EXIT
    git add results/gb10_1
    if ! git diff --cached --quiet; then git commit -m "rerun gb10_1 26b-A run_$n"; fi
    retry git push
  )
done
echo 'GB10 all five runs validated and pushed'
