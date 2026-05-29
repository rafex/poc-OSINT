# edge-osint-lab — Makefile principal
# Responsabilidad: BUILD y artefactos.
# Las tareas de flujo de trabajo (run, setup, dev) están en Justfile.
#
# Regla de oro: Make NO llama a just. Just puede llamar a make.
#
# Uso rápido:
#   make                     → muestra esta ayuda
#   make build-image-phomber → construye imagen Podman de PHOMBER
#   make build-image-sherlock→ construye imagen Podman de Sherlock
#   make build-all-images    → construye todas las imágenes OSINT
#   make install-dev         → instala dependencias Python con uv
#   make check-all           → valida todo el proyecto

.DEFAULT_GOAL := help

# Desactivar reglas implícitas para builds más rápidos
MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

# Incluir variables compartidas primero
include scripts/mk/vars.mk

# Incluir módulos de build
include scripts/mk/container.mk
include scripts/mk/python.mk
include scripts/mk/llama.mk
include scripts/mk/checks.mk
include scripts/mk/compose.mk
include scripts/mk/secrets.mk

# ── Targets compuestos ────────────────────────────────────────────────────────

.PHONY: build clean help

## build              Construye todas las imágenes OSINT + wheel Python
build: build-all-images build-wheel

## clean              Limpia todos los artefactos generados
clean: clean-python clean-image
	@printf "$(GREEN)[make]$(RESET) Limpieza completa.\n"

# ── Help ──────────────────────────────────────────────────────────────────────
## help               Muestra esta ayuda (default)
help:
	@printf "$(BOLD)edge-osint-lab$(RESET) — targets disponibles\n\n"
	@grep -hE '^## [a-zA-Z_-]' \
		scripts/mk/vars.mk \
		scripts/mk/container.mk \
		scripts/mk/python.mk \
		scripts/mk/llama.mk \
		scripts/mk/checks.mk \
		scripts/mk/compose.mk \
		scripts/mk/secrets.mk \
		Makefile \
		| sed 's/^## //' \
		| awk -F'  +' '{ printf "  $(CYAN)%-22s$(RESET) %s\n", $$1, $$2 }'
	@printf "\n$(YELLOW)Nota:$(RESET) para tareas de flujo de trabajo usa $(BOLD)just$(RESET)\n"
