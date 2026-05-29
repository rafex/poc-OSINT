#!/usr/bin/env bash
set -euo pipefail

GREEN=$'\033[32m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'; BOLD=$'\033[1m'; RESET=$'\033[0m'

printf "%b[checks]%b Configuración LLM_PROVIDER=%b%s%b\n" \
    "${CYAN}" "${RESET}" "${BOLD}" "${LLM_PROVIDER:-openai-compat|local}" "${RESET}"

# openai-compat: requiere BASE_URL + API_KEY
base_url="${PROVIDER_LLM_BASE_URL:-}"
api_key="${PROVIDER_LLM_API_KEY:-}"

if [ -n "${api_key}" ] && [ -n "${base_url}" ]; then
    printf "  %b✓%b openai-compat    API key configurada → %s\n" "${GREEN}" "${RESET}" "${base_url}"
elif [ -n "${api_key}" ]; then
    printf "  %b!%b openai-compat    API key OK pero PROVIDER_LLM_BASE_URL no definida\n" "${YELLOW}" "${RESET}"
elif [ -n "${base_url}" ]; then
    printf "  %b!%b openai-compat    BASE_URL OK pero PROVIDER_LLM_API_KEY no definida\n" "${YELLOW}" "${RESET}"
else
    printf "  %b–%b openai-compat    PROVIDER_LLM_API_KEY y PROVIDER_LLM_BASE_URL no definidas\n" "${YELLOW}" "${RESET}"
fi

printf "  %b✓%b local            siempre disponible (llama-server)\n" "${GREEN}" "${RESET}"
