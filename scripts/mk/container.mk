.PHONY: \
    build-image-phomber rebuild-image-phomber clean-image-phomber \
    build-image-sherlock rebuild-image-sherlock clean-image-sherlock \
    build-all-images \
    start-container      stop-container      rm-container      restart-container \
    start-container-phomber stop-container-phomber \
    start-container-sherlock stop-container-sherlock \
    container-logs container-shell container-status

# ── PHOMBER ───────────────────────────────────────────────────────────────────

## build-image-phomber    Construye la imagen de PHOMBER (reconocimiento tel.)
build-image-phomber:
	@printf "$(CYAN)[container]$(RESET) Construyendo imagen $(PHOMBER_IMAGE)…\n"
	$(PODMAN) build \
		--tag $(PHOMBER_IMAGE) \
		--file $(PHOMBER_CONTAINERFILE) \
		--label "org.opencontainers.image.source=https://github.com/rafex/poc-OSINT" \
		.
	@printf "$(GREEN)[container]$(RESET) Imagen lista: $(PHOMBER_IMAGE)\n"

## rebuild-image-phomber  Reconstruye PHOMBER sin caché
rebuild-image-phomber:
	@printf "$(YELLOW)[container]$(RESET) Reconstruyendo $(PHOMBER_IMAGE) sin caché…\n"
	$(PODMAN) build --no-cache \
		--tag $(PHOMBER_IMAGE) \
		--file $(PHOMBER_CONTAINERFILE) \
		.

## clean-image-phomber    Detiene contenedor y elimina imagen PHOMBER
clean-image-phomber:
	$(PODMAN) stop $(PHOMBER_CONTAINER) 2>/dev/null || true
	$(PODMAN) rm   $(PHOMBER_CONTAINER) 2>/dev/null || true
	$(PODMAN) rmi  $(PHOMBER_IMAGE)     2>/dev/null || true
	@printf "$(GREEN)[container]$(RESET) PHOMBER limpiado.\n"

# ── Sherlock ──────────────────────────────────────────────────────────────────

## build-image-sherlock   Construye la imagen de Sherlock (búsqueda de usuarios)
build-image-sherlock:
	@printf "$(CYAN)[container]$(RESET) Construyendo imagen $(SHERLOCK_IMAGE)…\n"
	$(PODMAN) build \
		--tag $(SHERLOCK_IMAGE) \
		--file $(SHERLOCK_CONTAINERFILE) \
		--label "org.opencontainers.image.source=https://github.com/rafex/poc-OSINT" \
		.
	@printf "$(GREEN)[container]$(RESET) Imagen lista: $(SHERLOCK_IMAGE)\n"

## rebuild-image-sherlock Reconstruye Sherlock sin caché
rebuild-image-sherlock:
	@printf "$(YELLOW)[container]$(RESET) Reconstruyendo $(SHERLOCK_IMAGE) sin caché…\n"
	$(PODMAN) build --no-cache \
		--tag $(SHERLOCK_IMAGE) \
		--file $(SHERLOCK_CONTAINERFILE) \
		.

## clean-image-sherlock   Detiene contenedor y elimina imagen Sherlock
clean-image-sherlock:
	$(PODMAN) stop $(SHERLOCK_CONTAINER) 2>/dev/null || true
	$(PODMAN) rm   $(SHERLOCK_CONTAINER) 2>/dev/null || true
	$(PODMAN) rmi  $(SHERLOCK_IMAGE)     2>/dev/null || true
	@printf "$(GREEN)[container]$(RESET) Sherlock limpiado.\n"

## build-all-images       Construye todas las imágenes OSINT
build-all-images: build-image-phomber build-image-sherlock
	@printf "$(GREEN)[container]$(RESET) Todas las imágenes construidas.\n"

# ── Lifecycle PHOMBER (default por compatibilidad) ────────────────────────────

## start-container        Inicia el contenedor PHOMBER (alias)
start-container: start-container-phomber

## stop-container         Detiene el contenedor PHOMBER (alias)
stop-container: stop-container-phomber

## rm-container           Elimina el contenedor PHOMBER (alias)
rm-container: stop-container-phomber
	$(PODMAN) rm $(PHOMBER_CONTAINER) 2>/dev/null || true
	@printf "$(GREEN)[container]$(RESET) Contenedor eliminado.\n"

## restart-container      Reinicia el contenedor PHOMBER (alias)
restart-container: stop-container-phomber start-container-phomber

## start-container-phomber  Inicia el contenedor PHOMBER en segundo plano
start-container-phomber:
	@if $(PODMAN) container exists $(PHOMBER_CONTAINER) 2>/dev/null; then \
		printf "$(YELLOW)[container]$(RESET) '$(PHOMBER_CONTAINER)' ya existe.\n"; \
	else \
		printf "$(CYAN)[container]$(RESET) Iniciando $(PHOMBER_CONTAINER)…\n"; \
		$(PODMAN) run \
			--detach \
			--name $(PHOMBER_CONTAINER) \
			--read-only \
			--tmpfs /tmp \
			--network host \
			--security-opt no-new-privileges \
			$(PHOMBER_IMAGE); \
	fi

## stop-container-phomber   Detiene el contenedor PHOMBER
stop-container-phomber:
	@printf "$(YELLOW)[container]$(RESET) Deteniendo $(PHOMBER_CONTAINER)…\n"
	$(PODMAN) stop $(PHOMBER_CONTAINER) 2>/dev/null || true

# ── Lifecycle Sherlock ────────────────────────────────────────────────────────

## start-container-sherlock Inicia el contenedor Sherlock en segundo plano
start-container-sherlock:
	@if $(PODMAN) container exists $(SHERLOCK_CONTAINER) 2>/dev/null; then \
		printf "$(YELLOW)[container]$(RESET) '$(SHERLOCK_CONTAINER)' ya existe.\n"; \
	else \
		printf "$(CYAN)[container]$(RESET) Iniciando $(SHERLOCK_CONTAINER)…\n"; \
		$(PODMAN) run \
			--detach \
			--name $(SHERLOCK_CONTAINER) \
			--read-only \
			--tmpfs /tmp \
			--network host \
			--security-opt no-new-privileges \
			$(SHERLOCK_IMAGE); \
	fi

## stop-container-sherlock  Detiene el contenedor Sherlock
stop-container-sherlock:
	@printf "$(YELLOW)[container]$(RESET) Deteniendo $(SHERLOCK_CONTAINER)…\n"
	$(PODMAN) stop $(SHERLOCK_CONTAINER) 2>/dev/null || true

# ── Inspección ────────────────────────────────────────────────────────────────

## container-logs         Sigue los logs de PHOMBER (default)
container-logs:
	$(PODMAN) logs --follow $(PHOMBER_CONTAINER)

## container-shell        Shell interactivo en PHOMBER (default)
container-shell:
	$(PODMAN) exec -it $(PHOMBER_CONTAINER) /bin/bash

## container-status       Estado de todos los contenedores OSINT
container-status:
	@$(PODMAN) ps \
		--filter name=$(PHOMBER_CONTAINER) \
		--filter name=$(SHERLOCK_CONTAINER) \
		--format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
