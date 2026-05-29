#!/usr/bin/env bash
set -euo pipefail

TIMEOUT="${1:-90}"
PORT="${LLAMA_PORT:-8080}"

echo "Esperando que llama-server esté listo en :${PORT} (máx ${TIMEOUT}s)..."
for i in $(seq 1 "${TIMEOUT}"); do
    if curl -sf "http://127.0.0.1:${PORT}/health" > /dev/null 2>&1; then
        echo "llama-server listo en :${PORT}"
        exit 0
    fi
    sleep 1
done
echo "ADVERTENCIA: llama-server no respondió en ${TIMEOUT}s"
echo "Revisa los logs: just compose logs-service llama-server"
