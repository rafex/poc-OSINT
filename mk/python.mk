.PHONY: install install-dev sync lint format typecheck test build-wheel clean-python

## install           Instala dependencias de producción (uv sync)
install:
	@printf "$(CYAN)[python]$(RESET) Instalando dependencias…\n"
	$(UV) sync --no-dev
	@printf "$(GREEN)[python]$(RESET) Entorno listo.\n"

## install-dev       Instala dependencias incluyendo dev (ruff, mypy, pytest)
install-dev:
	@printf "$(CYAN)[python]$(RESET) Instalando dependencias de desarrollo…\n"
	$(UV) sync
	@printf "$(GREEN)[python]$(RESET) Entorno dev listo.\n"

## sync              Sincroniza el lockfile sin instalar extras
sync:
	$(UV) sync --frozen

## lint              Verifica estilo y errores con ruff
lint:
	@printf "$(CYAN)[python]$(RESET) Ejecutando ruff check…\n"
	$(UV) run ruff check $(PYTHON_PKG)/

## format            Formatea el código con ruff
format:
	@printf "$(CYAN)[python]$(RESET) Formateando con ruff…\n"
	$(UV) run ruff format $(PYTHON_PKG)/

## format-check      Verifica formato sin modificar (para CI)
format-check:
	$(UV) run ruff format --check $(PYTHON_PKG)/

## typecheck         Verifica tipos con mypy
typecheck:
	@printf "$(CYAN)[python]$(RESET) Verificando tipos con mypy…\n"
	$(UV) run mypy $(PYTHON_PKG)/

## test              Ejecuta la suite de pruebas con pytest
test:
	@printf "$(CYAN)[python]$(RESET) Ejecutando tests…\n"
	$(UV) run pytest tests/ -v

## build-wheel       Empaqueta el proyecto como wheel
build-wheel:
	@printf "$(CYAN)[python]$(RESET) Construyendo wheel…\n"
	$(UV) build
	@printf "$(GREEN)[python]$(RESET) Artefactos en dist/\n"

## clean-python      Elimina cachés y artefactos de Python
clean-python:
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.py[cod]" -delete 2>/dev/null || true
	rm -rf dist/ build/ .eggs/ .coverage htmlcov/ .pytest_cache/ .mypy_cache/ .ruff_cache/
	@printf "$(GREEN)[python]$(RESET) Caché limpiado.\n"
