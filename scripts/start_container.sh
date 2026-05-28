#!/usr/bin/env bash
# Start the PHOMBER container and llama-server on a Raspberry Pi 4B.
# Usage: ./scripts/start_container.sh [model_path]
#
# Prerequisites:
#   - Podman installed (sudo apt install podman)
#   - llama.cpp compiled for ARM64 (see https://github.com/ggml-org/llama.cpp)
#   - Qwen2 0.5B Q4_K_M GGUF downloaded to ~/models/

set -euo pipefail

IMAGE_NAME="localhost/phomber:latest"
CONTAINER_NAME="phomber"
MODEL_PATH="${1:-$HOME/models/qwen2-0_5b-instruct-q4_k_m.gguf}"
LLAMA_SERVER="${LLAMA_SERVER_BIN:-$HOME/llama.cpp/llama-server}"
LLAMA_PORT=8080

# ── 1. Build image if not present ──────────────────────────────────────────
if ! podman image exists "$IMAGE_NAME"; then
    echo "[*] Building PHOMBER image…"
    podman build \
        --tag "$IMAGE_NAME" \
        --file "$(dirname "$0")/../container/Containerfile" \
        .
fi

# ── 2. Start PHOMBER container (idempotent) ─────────────────────────────────
if podman container exists "$CONTAINER_NAME"; then
    echo "[*] Container '$CONTAINER_NAME' already running."
else
    echo "[*] Starting PHOMBER container…"
    podman run \
        --detach \
        --name "$CONTAINER_NAME" \
        --read-only \
        --tmpfs /tmp \
        --network host \
        --security-opt no-new-privileges \
        "$IMAGE_NAME"
fi

# ── 3. Start llama-server ────────────────────────────────────────────────────
if ! command -v "$LLAMA_SERVER" &>/dev/null; then
    echo "[!] llama-server not found at: $LLAMA_SERVER"
    echo "    Set LLAMA_SERVER_BIN or compile llama.cpp first."
    exit 1
fi

if lsof -i ":$LLAMA_PORT" -sTCP:LISTEN -t &>/dev/null 2>&1; then
    echo "[*] llama-server already listening on port $LLAMA_PORT."
else
    if [[ ! -f "$MODEL_PATH" ]]; then
        echo "[!] Model not found: $MODEL_PATH"
        echo "    Download Qwen2 0.5B Q4_K_M from Hugging Face and set MODEL_PATH."
        exit 1
    fi

    echo "[*] Starting llama-server with model: $MODEL_PATH"
    nohup "$LLAMA_SERVER" \
        --model "$MODEL_PATH" \
        --host 127.0.0.1 \
        --port "$LLAMA_PORT" \
        --ctx-size 2048 \
        --threads 4 \
        > /tmp/llama-server.log 2>&1 &

    echo "[*] llama-server PID $! — logs: /tmp/llama-server.log"
    echo "[*] Waiting for server to be ready…"
    for i in $(seq 1 30); do
        if curl -sf "http://127.0.0.1:$LLAMA_PORT/health" &>/dev/null; then
            echo "[+] llama-server ready."
            break
        fi
        sleep 1
    done
fi

echo ""
echo "[+] Stack ready."
echo "    Run: python -m orchestrator.main 'busca info sobre +52 55 1234 5678'"
