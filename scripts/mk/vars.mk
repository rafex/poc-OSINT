# ── Herramientas ──────────────────────────────────────────────────────────────
UV              := uv
PODMAN          := podman
GIT             := git

# ── Contenedores OSINT ────────────────────────────────────────────────────────
# PHOMBER — reconocimiento de números de teléfono
PHOMBER_IMAGE         := localhost/phomber:latest
PHOMBER_CONTAINER     := phomber
PHOMBER_CONTAINERFILE := container/Containerfile

# Sherlock — búsqueda de usernames en redes sociales
SHERLOCK_IMAGE         := localhost/sherlock:latest
SHERLOCK_CONTAINER     := sherlock
SHERLOCK_CONTAINERFILE := container/Containerfile.sherlock

# GitFive — OSINT sobre usuarios y organizaciones de GitHub
GITFIVE_IMAGE         := localhost/gitfive:latest
GITFIVE_CONTAINER     := gitfive
GITFIVE_CONTAINERFILE := container/Containerfile.gitfive

# NumSpy — detalles de números de teléfono
NUMSPY_IMAGE         := localhost/numspy:latest
NUMSPY_CONTAINER     := numspy
NUMSPY_CONTAINERFILE := container/Containerfile.numspy

# WhatsMyName — username checker en 600+ sitios
WHATSMYNAME_IMAGE         := localhost/whatsmyname:latest
WHATSMYNAME_CONTAINER     := whatsmyname
WHATSMYNAME_CONTAINERFILE := container/Containerfile.whatsmyname

# Alias heredado (apunta a PHOMBER por compatibilidad con checks.mk)
CONTAINER_NAME := $(PHOMBER_CONTAINER)
IMAGE_NAME     := $(PHOMBER_IMAGE)

# ── llama.cpp ─────────────────────────────────────────────────────────────────
LLAMA_REPO      := https://github.com/ggml-org/llama.cpp
LLAMA_DIR       := $(HOME)/llama.cpp
LLAMA_BIN       := $(LLAMA_DIR)/build/bin/llama-server
LLAMA_PORT      := 8080
LLAMA_THREADS   := 4
LLAMA_CTX       := 2048

# ── Modelo ────────────────────────────────────────────────────────────────────
# ?= permite que las variables de entorno (cargadas por just desde .env) tengan prioridad
MODEL_DIR  ?= $(HOME)/models
MODEL_FILE ?= qwen2-0_5b-instruct-q4_k_m.gguf
MODEL_PATH ?= $(MODEL_DIR)/$(MODEL_FILE)

# ── Compose ───────────────────────────────────────────────────────────────────
COMPOSE_CMD          := podman compose
COMPOSE_FILE         := container/compose.yaml

# ── Python / proyectos ────────────────────────────────────────────────────────
ORCHESTRATOR_DIR := orchestrator
# raíz del proyecto scripts (pyproject.toml)
SCRIPTS_DIR      := scripts
# scripts PEP 723
SCRIPTS_PY_DIR   := scripts/python
# scripts shell
SCRIPTS_SH_DIR   := scripts/shellscript
# Ruta del paquete dentro de orchestrator/ (src layout)
PYTHON_PKG       := src/orchestrator

# ── Colores ANSI ──────────────────────────────────────────────────────────────
BOLD   := \033[1m
RESET  := \033[0m
GREEN  := \033[32m
YELLOW := \033[33m
CYAN   := \033[36m
RED    := \033[31m
