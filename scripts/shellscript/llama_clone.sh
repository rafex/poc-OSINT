#!/usr/bin/env bash
set -euo pipefail

LLAMA_REPO="${LLAMA_REPO:-https://github.com/ggml-org/llama.cpp}"
LLAMA_DIR="${LLAMA_DIR:-$HOME/llama.cpp}"
GREEN=$'\033[32m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'; RESET=$'\033[0m'

if [ -d "${LLAMA_DIR}" ]; then
    printf "%b[llama]%b %s ya existe — actualizando…\n" "${YELLOW}" "${RESET}" "${LLAMA_DIR}"
    git -C "${LLAMA_DIR}" pull --ff-only
else
    printf "%b[llama]%b Clonando llama.cpp en %s…\n" "${CYAN}" "${RESET}" "${LLAMA_DIR}"
    git clone --depth 1 "${LLAMA_REPO}" "${LLAMA_DIR}"
fi
