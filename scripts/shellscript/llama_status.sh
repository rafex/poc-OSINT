#!/usr/bin/env bash
set -euo pipefail

LLAMA_PORT="${LLAMA_PORT:-8080}"
GREEN=$'\033[32m'; RED=$'\033[31m'; RESET=$'\033[0m'

if lsof -i ":${LLAMA_PORT}" -sTCP:LISTEN -t > /dev/null 2>&1; then
    printf "%b[llama]%b llama-server ACTIVO en :%s\n" "${GREEN}" "${RESET}" "${LLAMA_PORT}"
else
    printf "%b[llama]%b llama-server INACTIVO\n" "${RED}" "${RESET}"
fi
