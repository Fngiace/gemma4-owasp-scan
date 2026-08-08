#!/usr/bin/env bash
# Run each deterministic test independently, waiting for GB10 to cool first.
set -euo pipefail

config="$1"
result_dir="$2"
final_json="$3"
repo_dir="$HOME/gemma4-owasp-scan"
promptfoo_bin="$HOME/.nvm/versions/node/v22.23.2/bin/promptfoo"
export PATH="$HOME/.nvm/versions/node/v22.23.2/bin:$PATH"
cool_threshold=75
stop_threshold=90
test_count=25

read_temp() {
  sensors | awk '/acpitz-acpi-0/{seen=1} seen && /temp1:/{gsub(/[+°C]/, "", $2); print $2; exit}'
}

mkdir -p "$result_dir"
for ((index=0; index<test_count; index++)); do
  part="$result_dir/$(printf '%02d' "$index").json"
  log="$result_dir/$(printf '%02d' "$index").log"
  if [[ -s "$part" ]]; then
    continue
  fi
  while :; do
    temp="$(read_temp)"
    temp_int="${temp%.*}"
    if (( temp_int <= cool_threshold )); then
      break
    fi
    printf '%s waiting: %.1f°C > %d°C\n' "$(date -Is)" "$temp" "$cool_threshold" >> "$result_dir/thermal.log"
    sleep 30
  done
  printf '%s starting test %d at %.1f°C\n' "$(date -Is)" "$index" "$temp" >> "$result_dir/thermal.log"
  "$promptfoo_bin" eval -c "$config" --no-cache --max-concurrency 1 --filter-range "$index:$((index + 1))" -o "$part" >"$log" 2>&1 &
  child=$!
  stopped=0
  while kill -0 "$child" 2>/dev/null; do
    temp="$(read_temp)"
    temp_int="${temp%.*}"
    if (( temp_int >= stop_threshold )); then
      printf '%s stopping test %d at %.1f°C\n' "$(date -Is)" "$index" "$temp" >> "$result_dir/thermal.log"
      kill -TERM "$child" 2>/dev/null || true
      stopped=1
      break
    fi
    sleep 5
  done
  set +e
  wait "$child"
  status=$?
  set -e
  if (( stopped || status != 0 )) || [[ ! -s "$part" ]]; then
    printf '%s test %d did not complete (status=%d); stopping run\n' "$(date -Is)" "$index" "$status" >> "$result_dir/thermal.log"
    exit 1
  fi
done

python3 "$repo_dir/scripts/merge_promptfoo_results.py" "$final_json" "$result_dir"/*.json
python3 "$repo_dir/scripts/make_redteam_report.py" "$final_json" "${final_json%.json}.html"
