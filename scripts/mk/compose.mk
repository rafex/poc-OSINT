# COMPOSE_CMD y COMPOSE_FILE vienen de mk/vars.mk
.PHONY: compose-build-phomber compose-build-sherlock compose-build-gitfive \
        compose-build-numspy compose-build-whatsmyname compose-build-all compose-build-llama \
        compose-up compose-up-local \
        compose-down compose-stop \
        compose-ps compose-logs \
        compose-restart compose-clean

## compose-build-phomber  Construye la imagen de PHOMBER para compose
compose-build-phomber:
	@printf "$(CYAN)[compose]$(RESET) Construyendo imagen phomber…\n"
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) build phomber

## compose-build-sherlock Construye la imagen de Sherlock para compose
compose-build-sherlock:
	@printf "$(CYAN)[compose]$(RESET) Construyendo imagen sherlock…\n"
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) build sherlock

## compose-build-gitfive  Construye la imagen de GitFive para compose
compose-build-gitfive:
	@printf "$(CYAN)[compose]$(RESET) Construyendo imagen gitfive…\n"
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) build gitfive

## compose-build-numspy      Construye la imagen de NumSpy para compose
compose-build-numspy:
	@printf "$(CYAN)[compose]$(RESET) Construyendo imagen numspy…\n"
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) build numspy

## compose-build-whatsmyname Construye la imagen de WhatsMyName para compose
compose-build-whatsmyname:
	@printf "$(CYAN)[compose]$(RESET) Construyendo imagen whatsmyname…\n"
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) build whatsmyname

## compose-build-all      Construye todas las imágenes OSINT para compose
compose-build-all: compose-build-phomber compose-build-sherlock compose-build-gitfive compose-build-numspy compose-build-whatsmyname
	@printf "$(GREEN)[compose]$(RESET) Imágenes OSINT listas.\n"

## compose-build-llama    Construye la imagen de llama-server (tarda varios minutos)
compose-build-llama:
	@printf "$(CYAN)[compose]$(RESET) Construyendo llama-server (compilando llama.cpp)…\n"
	@printf "$(YELLOW)[compose]$(RESET) Esto puede tardar 10–20 min en primera ejecución.\n"
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) --profile local-llm build llama-server

## compose-up             Levanta todos los servicios OSINT en background
compose-up:
	@printf "$(CYAN)[compose]$(RESET) Iniciando stack OSINT…\n"
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) up --detach phomber sherlock gitfive numspy whatsmyname
	@printf "$(GREEN)[compose]$(RESET) Stack OSINT activo.\n"

## compose-up-local       Levanta stack completo + llama-server local
compose-up-local:
	@printf "$(CYAN)[compose]$(RESET) Iniciando stack completo (perfil: local-llm)…\n"
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) --profile local-llm up --detach
	@printf "$(GREEN)[compose]$(RESET) Stack completo activo.\n"

## compose-stop           Detiene los servicios sin eliminarlos
compose-stop:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) --profile local-llm stop

## compose-down           Detiene y elimina los contenedores
compose-down:
	@printf "$(YELLOW)[compose]$(RESET) Deteniendo y eliminando contenedores…\n"
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) --profile local-llm down

## compose-ps             Estado de los servicios de compose
compose-ps:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) --profile local-llm ps

## compose-logs           Sigue los logs de todos los servicios
compose-logs:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) --profile local-llm logs --follow

## compose-restart        Reinicia todos los servicios activos
compose-restart: compose-down compose-up

## compose-clean          Elimina contenedores, imágenes y volumes locales
compose-clean: compose-down
	@printf "$(YELLOW)[compose]$(RESET) Eliminando imágenes y volumes locales…\n"
	$(PODMAN) volume rm edge-osint-lab_gitfive-config 2>/dev/null || true
	$(PODMAN) rmi $(PHOMBER_IMAGE)          2>/dev/null || true
	$(PODMAN) rmi $(SHERLOCK_IMAGE)         2>/dev/null || true
	$(PODMAN) rmi $(GITFIVE_IMAGE)          2>/dev/null || true
	$(PODMAN) rmi $(NUMSPY_IMAGE)           2>/dev/null || true
	$(PODMAN) rmi $(WHATSMYNAME_IMAGE)      2>/dev/null || true
	$(PODMAN) rmi localhost/llama-server:latest 2>/dev/null || true
	@printf "$(GREEN)[compose]$(RESET) Imágenes eliminadas.\n"
