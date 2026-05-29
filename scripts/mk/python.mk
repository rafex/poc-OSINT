# Todos los comandos uv se ejecutan con --directory para apuntar al proyecto
# correcto sin cambiar el directorio de trabajo del shell.
UV_ORCH  := $(UV) --directory $(ORCHESTRATOR_DIR)
UV_SCRIP := $(UV) --directory $(SCRIPTS_DIR)

.PHONY: install install-dev sync lint format typecheck test build-wheel clean-python \
        lint-scripts format-scripts

## install           Instala dependencias de producción del orquestador
install:
	@printf "$(CYAN)[python]$(RESET) Instalando dependencias del orquestador…\n"
	$(UV_ORCH) sync --no-dev
	@printf "$(GREEN)[python]$(RESET) Entorno listo.\n"

## install-dev       Instala dependencias incluyendo herramientas de desarrollo
install-dev:
	@printf "$(CYAN)[python]$(RESET) Instalando deps de desarrollo…\n"
	$(UV_ORCH) sync
	@printf "$(GREEN)[python]$(RESET) Entorno dev listo.\n"

## sync              Sincroniza el lockfile sin instalar extras
sync:
	$(UV_ORCH) sync --frozen

## lint              Verifica estilo y errores del orquestador (ruff)
lint:
	@printf "$(CYAN)[python]$(RESET) ruff check orchestrator/…\n"
	$(UV_ORCH) run ruff check $(PYTHON_PKG)/

## format            Formatea el código del orquestador (ruff)
format:
	@printf "$(CYAN)[python]$(RESET) ruff format orchestrator/…\n"
	$(UV_ORCH) run ruff format $(PYTHON_PKG)/

## format-check      Verifica formato sin modificar (para CI)
format-check:
	$(UV_ORCH) run ruff format --check $(PYTHON_PKG)/

## typecheck         Verifica tipos del orquestador (mypy)
typecheck:
	@printf "$(CYAN)[python]$(RESET) mypy orchestrator/…\n"
	$(UV_ORCH) run mypy $(PYTHON_PKG)/

## test              Ejecuta la suite de pruebas del orquestador
test:
	@printf "$(CYAN)[python]$(RESET) pytest…\n"
	$(UV_ORCH) run pytest tests/ -v

## build-wheel       Empaqueta el orquestador como wheel
build-wheel:
	@printf "$(CYAN)[python]$(RESET) Construyendo wheel…\n"
	$(UV_ORCH) build
	@printf "$(GREEN)[python]$(RESET) Artefactos en $(ORCHESTRATOR_DIR)/dist/\n"

## lint-scripts      Verifica estilo de los scripts PEP 723 (ruff)
lint-scripts:
	@printf "$(CYAN)[python]$(RESET) ruff check $(SCRIPTS_PY_DIR)/…\n"
	$(UV_SCRIP) run ruff check $(SCRIPTS_PY_DIR)/

## format-scripts    Formatea los scripts PEP 723 (ruff)
format-scripts:
	$(UV_SCRIP) run ruff format $(SCRIPTS_PY_DIR)/

## clean-python      Elimina cachés y artefactos de Python
clean-python:
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.py[cod]" -delete 2>/dev/null || true
	rm -rf \
		$(ORCHESTRATOR_DIR)/dist/ \
		$(ORCHESTRATOR_DIR)/build/ \
		$(ORCHESTRATOR_DIR)/.coverage \
		$(ORCHESTRATOR_DIR)/htmlcov/ \
		$(ORCHESTRATOR_DIR)/.pytest_cache/ \
		$(ORCHESTRATOR_DIR)/.mypy_cache/ \
		$(ORCHESTRATOR_DIR)/.ruff_cache/ \
		$(SCRIPTS_DIR)/.ruff_cache/ \
		$(SCRIPTS_DIR)/.mypy_cache/
	@printf "$(GREEN)[python]$(RESET) Caché limpiado.\n"
