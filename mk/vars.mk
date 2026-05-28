# ── Herramientas ──────────────────────────────────────────────────────────────
UV              := uv
PODMAN          := podman
GIT             := git

# ── Contenedor ────────────────────────────────────────────────────────────────
IMAGE_NAME      := localhost/phomber:latest
CONTAINER_NAME  := phomber
CONTAINERFILE   := container/Containerfile

# ── llama.cpp ─────────────────────────────────────────────────────────────────
LLAMA_REPO      := https://github.com/ggml-org/llama.cpp
LLAMA_DIR       := $(HOME)/llama.cpp
LLAMA_BIN       := $(LLAMA_DIR)/build/bin/llama-server
LLAMA_PORT      := 8080
LLAMA_THREADS   := 4
LLAMA_CTX       := 2048

# ── Modelo ────────────────────────────────────────────────────────────────────
MODEL_DIR       := $(HOME)/models
MODEL_FILE      := qwen2-0_5b-instruct-q4_k_m.gguf
MODEL_PATH      := $(MODEL_DIR)/$(MODEL_FILE)

# ── Compose ───────────────────────────────────────────────────────────────────
COMPOSE_CMD     := podman compose
COMPOSE_FILE    := compose.yaml

# ── Python / proyecto ─────────────────────────────────────────────────────────
PYTHON_PKG      := orchestrator
SCRIPTS_DIR     := scripts

# ── Colores ANSI ──────────────────────────────────────────────────────────────
BOLD   := \033[1m
RESET  := \033[0m
GREEN  := \033[32m
YELLOW := \033[33m
CYAN   := \033[36m
RED    := \033[31m
