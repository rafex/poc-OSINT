#!/usr/bin/env bash
set -euo pipefail

LLAMA_PORT="${LLAMA_PORT:-8080}"
# Resolve MODEL_PATH: explícito > MODEL_DIR/MODEL_FILE > default hardcodeado
if [ -z "${MODEL_PATH:-}" ]; then
    MODEL_PATH="${MODEL_DIR:-$HOME/models}/${MODEL_FILE:-qwen2-0_5b-instruct-q4_k_m.gguf}"
fi
LLAMA_CTX="${LLAMA_CTX:-2048}"
LLAMA_THREADS="${LLAMA_THREADS:-4}"
GREEN=$'\033[32m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'; RED=$'\033[31m'; RESET=$'\033[0m'

# Resolución del binario: variable explícita > PATH > build local
if [ -n "${LLAMA_BIN:-}" ] && [ -f "${LLAMA_BIN}" ]; then
    : # usar LLAMA_BIN tal cual
elif LLAMA_BIN=$(command -v llama-server 2>/dev/null); then
    printf "%b[llama]%b Binario descubierto en PATH: %s\n" "${CYAN}" "${RESET}" "${LLAMA_BIN}"
elif [ -f "${HOME}/llama.cpp/build/bin/llama-server" ]; then
    LLAMA_BIN="${HOME}/llama.cpp/build/bin/llama-server"
    printf "%b[llama]%b Usando build local: %s\n" "${CYAN}" "${RESET}" "${LLAMA_BIN}"
else
    printf "%b[llama]%b llama-server no encontrado.\n" "${RED}" "${RESET}"
    printf "  Opciones:\n"
    printf "  1. Instala en PATH: sudo cp llama-server /usr/local/bin/\n"
    printf "  2. Compila con:     make build-llama\n"
    printf "  3. Define en .env:  LLAMA_BIN=/ruta/al/binario\n"
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
