.PHONY: check-deps check-health check-container check-api-config check-all

## check-deps         Verifica herramientas requeridas (uv, podman, make, git)
check-deps:
	@printf "$(CYAN)[checks]$(RESET) Verificando dependencias del sistema…\n"
	$(UV) run --script $(SCRIPTS_PY_DIR)/check_deps.py

## check-health       Verifica que el stack completo esté operativo
check-health:
	@printf "$(CYAN)[checks]$(RESET) Verificando salud del stack…\n"
	$(UV) run --script $(SCRIPTS_PY_DIR)/health_check.py

## check-container    Verifica solo el estado del contenedor PHOMBER
check-container:
	@CONTAINER_NAME=$(CONTAINER_NAME) PODMAN=$(PODMAN) \
		bash $(SCRIPTS_SH_DIR)/check_container.sh

## check-api-config   Muestra la cadena LLM activa y qué keys están configuradas
check-api-config:
	@bash $(SCRIPTS_SH_DIR)/check_api_config.sh

## check-all          Ejecuta todos los checks disponibles
check-all: check-deps check-api-config lint format-check typecheck check-container check-health
	@printf "$(GREEN)[checks]$(RESET) Todos los checks completados.\n"
