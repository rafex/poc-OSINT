.PHONY: build-image rebuild-image clean-image \
        start-container stop-container rm-container restart-container \
        container-logs container-shell container-status

## build-image       Construye la imagen de PHOMBER con Podman
build-image:
	@printf "$(CYAN)[container]$(RESET) Construyendo imagen $(IMAGE_NAME)…\n"
	$(PODMAN) build \
		--tag $(IMAGE_NAME) \
		--file $(CONTAINERFILE) \
		--label "org.opencontainers.image.source=https://github.com/rafex/poc-OSINT" \
		.
	@printf "$(GREEN)[container]$(RESET) Imagen lista: $(IMAGE_NAME)\n"

## rebuild-image     Reconstruye la imagen sin caché
rebuild-image:
	@printf "$(YELLOW)[container]$(RESET) Reconstruyendo sin caché…\n"
	$(PODMAN) build --no-cache \
		--tag $(IMAGE_NAME) \
		--file $(CONTAINERFILE) \
		.

## start-container   Inicia el contenedor PHOMBER en segundo plano
start-container:
	@if $(PODMAN) container exists $(CONTAINER_NAME) 2>/dev/null; then \
		printf "$(YELLOW)[container]$(RESET) El contenedor '$(CONTAINER_NAME)' ya existe.\n"; \
	else \
		printf "$(CYAN)[container]$(RESET) Iniciando $(CONTAINER_NAME)…\n"; \
		$(PODMAN) run \
			--detach \
			--name $(CONTAINER_NAME) \
			--read-only \
			--tmpfs /tmp \
			--network host \
			--security-opt no-new-privileges \
			$(IMAGE_NAME); \
	fi

## stop-container    Detiene el contenedor PHOMBER
stop-container:
	@printf "$(YELLOW)[container]$(RESET) Deteniendo $(CONTAINER_NAME)…\n"
	$(PODMAN) stop $(CONTAINER_NAME) 2>/dev/null || true

## rm-container      Elimina el contenedor (requiere stop previo)
rm-container: stop-container
	$(PODMAN) rm $(CONTAINER_NAME) 2>/dev/null || true
	@printf "$(GREEN)[container]$(RESET) Contenedor eliminado.\n"

## restart-container Reinicia el contenedor
restart-container: stop-container start-container

## container-logs    Muestra los logs del contenedor
container-logs:
	$(PODMAN) logs --follow $(CONTAINER_NAME)

## container-shell   Abre shell interactivo dentro del contenedor
container-shell:
	$(PODMAN) exec -it $(CONTAINER_NAME) /bin/bash

## container-status  Estado del contenedor
container-status:
	@$(PODMAN) ps --filter name=$(CONTAINER_NAME) --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"

## clean-image       Elimina la imagen local
clean-image: rm-container
	$(PODMAN) rmi $(IMAGE_NAME) 2>/dev/null || true
	@printf "$(GREEN)[container]$(RESET) Imagen eliminada.\n"
