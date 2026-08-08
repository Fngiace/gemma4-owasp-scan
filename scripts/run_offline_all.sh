#!/usr/bin/env bash
# Finish 12B, then run 26B, validate evidence, and publish only the final reports.
set -euo pipefail

repo_dir="$HOME/gemma4-owasp-scan"
export PATH="$HOME/.nvm/versions/node/v22.23.2/bin:$PATH"
cd "$repo_dir"

while pgrep -f 'run_offline_thermal.sh promptfoo/promptfooconfig.offline.12b.yaml' >/dev/null; do
  sleep 15
done

parts=(results/gb10/offline-parts/*.json)
(( ${#parts[@]} == 25 ))
python3 scripts/merge_promptfoo_results.py results/gb10/run.json "${parts[@]}"
python3 scripts/make_redteam_report.py results/gb10/run.json results/gb10/report.html
python3 scripts/validate_redteam_results.py results/gb10/run.json 25

scripts/run_offline_thermal.sh promptfoo/promptfooconfig.offline.26b.yaml results/26b/offline-parts results/26b/run.json
python3 scripts/validate_redteam_results.py results/26b/run.json 25
mv results/26b/run.html results/26b/report.html

git add results/gb10/run.json results/gb10/report.html results/26b/run.json results/26b/report.html
git diff --cached --check
git commit -m "Add offline Gemma redteam evaluation results"
git push origin main
