#!/usr/bin/env bash
set -euo pipefail

LLAMA_BIN="${LLAMA_BIN:-$HOME/llama.cpp/build/bin/llama-server}"
LLAMA_PORT="${LLAMA_PORT:-8080}"
MODEL_PATH="${MODEL_PATH:-$HOME/models/qwen2-0_5b-instruct-q4_k_m.gguf}"
LLAMA_CTX="${LLAMA_CTX:-2048}"
LLAMA_THREADS="${LLAMA_THREADS:-4}"
GREEN=$'\033[32m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'; RED=$'\033[31m'; RESET=$'\033[0m'

if [ ! -f "${LLAMA_BIN}" ]; then
    printf "%b[llama]%b Binario no encontrado: %s\n" "${RED}" "${RESET}" "${LLAMA_BIN}"
    printf "       Ejecuta: make build-llama\n"
    exit 1
fi
if [ ! -f "${MODEL_PATH}" ]; then
    printf "%b[llama]%b Modelo no encontrado: %s\n" "${RED}" "${RESET}" "${MODEL_PATH}"
    printf "       Ejecuta: just setup download-model\n"
    exit 1
fi
if lsof -i ":${LLAMA_PORT}" -sTCP:LISTEN -t > /dev/null 2>&1; then
    printf "%b[llama]%b Puerto %s ya en uso — servidor activo.\n" "${YELLOW}" "${RESET}" "${LLAMA_PORT}"
else
    printf "%b[llama]%b Iniciando llama-server en 127.0.0.1:%s…\n" "${CYAN}" "${RESET}" "${LLAMA_PORT}"
    nohup "${LLAMA_BIN}" \
        --model "${MODEL_PATH}" \
        --host 127.0.0.1 \
        --port "${LLAMA_PORT}" \
        --ctx-size "${LLAMA_CTX}" \
        --threads "${LLAMA_THREADS}" \
        > /tmp/llama-server.log 2>&1 &
    printf "%b[llama]%b PID %s — logs: /tmp/llama-server.log\n" "${GREEN}" "${RESET}" "$!"
fi
