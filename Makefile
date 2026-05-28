# edge-osint-lab — Makefile principal
# Responsabilidad: BUILD y artefactos.
# Las tareas de flujo de trabajo (run, setup, dev) están en Justfile.
#
# Regla de oro: Make NO llama a just. Just puede llamar a make.
#
# Uso rápido:
#   make              → muestra esta ayuda
#   make build-image  → construye imagen Podman de PHOMBER
#   make install-dev  → instala dependencias Python con uv
#   make check-all    → valida todo el proyecto

.DEFAULT_GOAL := help

# Desactivar reglas implícitas para builds más rápidos
MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

# Incluir variables compartidas primero
include mk/vars.mk

# Incluir módulos de build
include mk/container.mk
include mk/python.mk
include mk/llama.mk
include mk/checks.mk
include mk/compose.mk

# ── Targets compuestos ────────────────────────────────────────────────────────

.PHONY: build clean help

## build              Construye imagen de contenedor + wheel Python
build: build-image build-wheel

## clean              Limpia todos los artefactos generados
clean: clean-python clean-image
	@printf "$(GREEN)[make]$(RESET) Limpieza completa.\n"

# ── Help ──────────────────────────────────────────────────────────────────────
## help               Muestra esta ayuda (default)
help:
	@printf "$(BOLD)edge-osint-lab$(RESET) — targets disponibles\n\n"
	@grep -hE '^## [a-zA-Z_-]' \
		mk/vars.mk mk/container.mk mk/python.mk mk/llama.mk mk/checks.mk mk/compose.mk Makefile \
		| sed 's/^## //' \
		| awk -F'  +' '{ printf "  $(CYAN)%-22s$(RESET) %s\n", $$1, $$2 }'
	@printf "\n$(YELLOW)Nota:$(RESET) para tareas de flujo de trabajo usa $(BOLD)just$(RESET)\n"
