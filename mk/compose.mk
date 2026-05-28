COMPOSE_CMD    := podman compose
COMPOSE_FILE   := compose.yaml

.PHONY: compose-build compose-build-llama \
        compose-up compose-up-local \
        compose-down compose-stop \
        compose-ps compose-logs \
        compose-restart compose-clean

## compose-build       Construye la imagen de PHOMBER para compose
compose-build:
	@printf "$(CYAN)[compose]$(RESET) Construyendo imagen phomber…\n"
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) build phomber

## compose-build-llama Construye la imagen de llama-server (tarda varios minutos)
compose-build-llama:
	@printf "$(CYAN)[compose]$(RESET) Construyendo imagen llama-server (compilando llama.cpp)…\n"
	@printf "$(YELLOW)[compose]$(RESET) Esto puede tardar 10–20 min en primera ejecución.\n"
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) --profile local-llm build llama-server

## compose-up          Levanta PHOMBER en background (APIs remotas Groq/DeepSeek)
compose-up:
	@printf "$(CYAN)[compose]$(RESET) Iniciando stack (perfil: api remota)…\n"
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) up --detach phomber
	@printf "$(GREEN)[compose]$(RESET) phomber activo. Listo para: just osint query <número>\n"

## compose-up-local    Levanta PHOMBER + llama-server en background
compose-up-local:
	@printf "$(CYAN)[compose]$(RESET) Iniciando stack completo (perfil: local-llm)…\n"
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) --profile local-llm up --detach
	@printf "$(GREEN)[compose]$(RESET) Stack completo activo.\n"

## compose-stop        Detiene los servicios sin eliminarlos
compose-stop:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) --profile local-llm stop

## compose-down        Detiene y elimina los contenedores
compose-down:
	@printf "$(YELLOW)[compose]$(RESET) Deteniendo y eliminando contenedores…\n"
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) --profile local-llm down

## compose-ps          Estado de los servicios de compose
compose-ps:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) --profile local-llm ps

## compose-logs        Sigue los logs de todos los servicios
compose-logs:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) --profile local-llm logs --follow

## compose-restart     Reinicia todos los servicios activos
compose-restart: compose-down compose-up

## compose-clean       Elimina contenedores + imágenes construidas localmente
compose-clean: compose-down
	@printf "$(YELLOW)[compose]$(RESET) Eliminando imágenes locales…\n"
	$(PODMAN) rmi localhost/phomber:latest     2>/dev/null || true
	$(PODMAN) rmi localhost/llama-server:latest 2>/dev/null || true
	@printf "$(GREEN)[compose]$(RESET) Imágenes eliminadas.\n"
