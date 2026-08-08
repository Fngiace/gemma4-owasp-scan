#!/usr/bin/env bash
# Reversible low-clock mode for long local model evaluations on NVIDIA GB10.
set -euo pipefail

mode="${1:-status}"
case "$mode" in
  enable)
    sudo nvidia-smi -lgc 800,800
    ;;
  disable)
    sudo nvidia-smi -rgc
    ;;
  status)
    ;;
  *)
    echo "Usage: $0 {enable|disable|status}" >&2
    exit 2
    ;;
esac

nvidia-smi --query-gpu=name,clocks.current.graphics,temperature.gpu,power.draw \
  --format=csv,noheader
