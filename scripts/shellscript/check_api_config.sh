#!/usr/bin/env bash
set -euo pipefail

GREEN=$'\033[32m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'; BOLD=$'\033[1m'; RESET=$'\033[0m'

printf "%b[checks]%b Configuración LLM_PROVIDER=%b%s%b\n" \
    "${CYAN}" "${RESET}" "${BOLD}" "${LLM_PROVIDER:-groq|deepseek|local}" "${RESET}"

if [ -n "${GROQ_API_KEY:-}" ]; then
    printf "  %b✓%b GROQ_API_KEY     configurada\n" "${GREEN}" "${RESET}"
else
    printf "  %b–%b GROQ_API_KEY     no definida\n" "${YELLOW}" "${RESET}"
fi

if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
    printf "  %b✓%b DEEPSEEK_API_KEY configurada\n" "${GREEN}" "${RESET}"
else
    printf "  %b–%b DEEPSEEK_API_KEY no definida\n" "${YELLOW}" "${RESET}"
fi

printf "  %b✓%b local            siempre disponible (llama-server)\n" "${GREEN}" "${RESET}"
