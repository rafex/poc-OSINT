#!/usr/bin/env bash
set -euo pipefail

model_dir="${MODEL_DIR:-$HOME/models}"
model_file="${MODEL_FILE:-qwen2-0_5b-instruct-q4_k_m.gguf}"
model_path="${model_dir}/${model_file}"

if [ ! -f "${model_path}" ]; then
    echo "ERROR: modelo no encontrado en ${model_path}"
    echo "Descárgalo con: just setup download-model"
    exit 1
fi
echo "Modelo OK: ${model_path}"
