.PHONY: check-deps check-health check-container check-api-config check-all

## check-deps         Verifica herramientas requeridas (uv, podman, make, git)
check-deps:
	@printf "$(CYAN)[checks]$(RESET) Verificando dependencias del sistema…\n"
	$(UV) run --script $(SCRIPTS_DIR)/check_deps.py

## check-health       Verifica que el stack completo esté operativo
check-health:
	@printf "$(CYAN)[checks]$(RESET) Verificando salud del stack…\n"
	$(UV) run --script $(SCRIPTS_DIR)/health_check.py

## check-container    Verifica solo el estado del contenedor PHOMBER
check-container:
	@$(PODMAN) ps \
		--filter name=$(CONTAINER_NAME) \
		--filter status=running \
		--format "{{.Names}}" \
		| grep -q $(CONTAINER_NAME) \
	&& printf "$(GREEN)[checks]$(RESET) Contenedor '$(CONTAINER_NAME)' ACTIVO.\n" \
	|| printf "$(RED)[checks]$(RESET) Contenedor '$(CONTAINER_NAME)' INACTIVO.\n"

## check-api-config   Muestra la cadena LLM activa y qué keys están configuradas
check-api-config:
	@printf "$(CYAN)[checks]$(RESET) Configuración LLM_PROVIDER=$(BOLD)$${LLM_PROVIDER:-groq|deepseek|local}$(RESET)\n"
	@[ -n "$${GROQ_API_KEY}" ] \
		&& printf "  $(GREEN)✓$(RESET) GROQ_API_KEY     configurada\n" \
		|| printf "  $(YELLOW)–$(RESET) GROQ_API_KEY     no definida\n"
	@[ -n "$${DEEPSEEK_API_KEY}" ] \
		&& printf "  $(GREEN)✓$(RESET) DEEPSEEK_API_KEY configurada\n" \
		|| printf "  $(YELLOW)–$(RESET) DEEPSEEK_API_KEY no definida\n"
	@printf "  $(GREEN)✓$(RESET) local            siempre disponible (llama-server)\n"

## check-all          Ejecuta todos los checks disponibles
check-all: check-deps check-api-config lint format-check typecheck check-container check-health
	@printf "$(GREEN)[checks]$(RESET) Todos los checks completados.\n"
