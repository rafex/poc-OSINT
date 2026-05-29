#!/usr/bin/env bash
set -euo pipefail

LLAMA_PORT="${LLAMA_PORT:-8080}"
GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'

PID=$(lsof -ti ":${LLAMA_PORT}" -sTCP:LISTEN 2>/dev/null || true)
if [ -n "${PID}" ]; then
    kill "${PID}"
    printf "%b[llama]%b Servidor detenido (PID %s).\n" "${GREEN}" "${RESET}" "${PID}"
else
    printf "%b[llama]%b No hay servidor activo en :%s.\n" "${YELLOW}" "${RESET}" "${LLAMA_PORT}"
fi
