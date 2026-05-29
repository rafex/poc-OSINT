.PHONY: \
    build-image-phomber    rebuild-image-phomber    clean-image-phomber \
    build-image-sherlock   rebuild-image-sherlock   clean-image-sherlock \
    build-image-gitfive    rebuild-image-gitfive    clean-image-gitfive \
    build-image-numspy     rebuild-image-numspy     clean-image-numspy \
    build-image-whatsmyname rebuild-image-whatsmyname clean-image-whatsmyname \
    build-all-images \
    start-container      stop-container      rm-container      restart-container \
    start-container-phomber    stop-container-phomber \
    start-container-sherlock   stop-container-sherlock \
    start-container-gitfive    stop-container-gitfive \
    start-container-numspy     stop-container-numspy \
    start-container-whatsmyname stop-container-whatsmyname \
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

## build-image-gitfive    Construye la imagen de GitFive (OSINT de GitHub)
build-image-gitfive:
	@printf "$(CYAN)[container]$(RESET) Construyendo imagen $(GITFIVE_IMAGE)…\n"
	$(PODMAN) build \
		--tag $(GITFIVE_IMAGE) \
		--file $(GITFIVE_CONTAINERFILE) \
		--label "org.opencontainers.image.source=https://github.com/rafex/poc-OSINT" \
		.
	@printf "$(GREEN)[container]$(RESET) Imagen lista: $(GITFIVE_IMAGE)\n"

## rebuild-image-gitfive  Reconstruye GitFive sin caché
rebuild-image-gitfive:
	@printf "$(YELLOW)[container]$(RESET) Reconstruyendo $(GITFIVE_IMAGE) sin caché…\n"
	$(PODMAN) build --no-cache \
		--tag $(GITFIVE_IMAGE) \
		--file $(GITFIVE_CONTAINERFILE) \
		.

## clean-image-gitfive    Detiene contenedor y elimina imagen GitFive
clean-image-gitfive:
	$(PODMAN) stop $(GITFIVE_CONTAINER) 2>/dev/null || true
	$(PODMAN) rm   $(GITFIVE_CONTAINER) 2>/dev/null || true
	$(PODMAN) rmi  $(GITFIVE_IMAGE)     2>/dev/null || true
	@printf "$(GREEN)[container]$(RESET) GitFive limpiado.\n"

## start-container-gitfive  Inicia el contenedor GitFive en segundo plano
start-container-gitfive:
	@if $(PODMAN) container exists $(GITFIVE_CONTAINER) 2>/dev/null; then \
		printf "$(YELLOW)[container]$(RESET) '$(GITFIVE_CONTAINER)' ya existe.\n"; \
	else \
		printf "$(CYAN)[container]$(RESET) Iniciando $(GITFIVE_CONTAINER)…\n"; \
		$(PODMAN) run \
			--detach \
			--name $(GITFIVE_CONTAINER) \
			--network host \
			--security-opt no-new-privileges \
			$(GITFIVE_IMAGE); \
	fi

## stop-container-gitfive   Detiene el contenedor GitFive
stop-container-gitfive:
	@printf "$(YELLOW)[container]$(RESET) Deteniendo $(GITFIVE_CONTAINER)…\n"
	$(PODMAN) stop $(GITFIVE_CONTAINER) 2>/dev/null || true

## build-image-numspy     Construye la imagen de NumSpy (detalles de número telefónico)
build-image-numspy:
	@printf "$(CYAN)[container]$(RESET) Construyendo imagen $(NUMSPY_IMAGE)…\n"
	$(PODMAN) build \
		--tag $(NUMSPY_IMAGE) \
		--file $(NUMSPY_CONTAINERFILE) \
		--label "org.opencontainers.image.source=https://github.com/rafex/poc-OSINT" \
		.
	@printf "$(GREEN)[container]$(RESET) Imagen lista: $(NUMSPY_IMAGE)\n"

## rebuild-image-numspy   Reconstruye NumSpy sin caché
rebuild-image-numspy:
	@printf "$(YELLOW)[container]$(RESET) Reconstruyendo $(NUMSPY_IMAGE) sin caché…\n"
	$(PODMAN) build --no-cache --tag $(NUMSPY_IMAGE) --file $(NUMSPY_CONTAINERFILE) .

## clean-image-numspy     Detiene contenedor y elimina imagen NumSpy
clean-image-numspy:
	$(PODMAN) stop $(NUMSPY_CONTAINER) 2>/dev/null || true
	$(PODMAN) rm   $(NUMSPY_CONTAINER) 2>/dev/null || true
	$(PODMAN) rmi  $(NUMSPY_IMAGE)     2>/dev/null || true
	@printf "$(GREEN)[container]$(RESET) NumSpy limpiado.\n"

## start-container-numspy   Inicia el contenedor NumSpy
start-container-numspy:
	@if $(PODMAN) container exists $(NUMSPY_CONTAINER) 2>/dev/null; then \
		printf "$(YELLOW)[container]$(RESET) '$(NUMSPY_CONTAINER)' ya existe.\n"; \
	else \
		printf "$(CYAN)[container]$(RESET) Iniciando $(NUMSPY_CONTAINER)…\n"; \
		$(PODMAN) run --detach --name $(NUMSPY_CONTAINER) \
			--network host \
			--security-opt no-new-privileges \
			--read-only --tmpfs /tmp \
			$(NUMSPY_IMAGE); \
	fi

## stop-container-numspy    Detiene el contenedor NumSpy
stop-container-numspy:
	@printf "$(YELLOW)[container]$(RESET) Deteniendo $(NUMSPY_CONTAINER)…\n"
	$(PODMAN) stop $(NUMSPY_CONTAINER) 2>/dev/null || true

## build-image-whatsmyname  Construye la imagen de WhatsMyName (username checker)
build-image-whatsmyname:
	@printf "$(CYAN)[container]$(RESET) Construyendo imagen $(WHATSMYNAME_IMAGE)…\n"
	$(PODMAN) build \
		--tag $(WHATSMYNAME_IMAGE) \
		--file $(WHATSMYNAME_CONTAINERFILE) \
		--label "org.opencontainers.image.source=https://github.com/rafex/poc-OSINT" \
		.
	@printf "$(GREEN)[container]$(RESET) Imagen lista: $(WHATSMYNAME_IMAGE)\n"

## rebuild-image-whatsmyname Reconstruye WhatsMyName sin caché (refresca wmn-data.json)
rebuild-image-whatsmyname:
	@printf "$(YELLOW)[container]$(RESET) Reconstruyendo $(WHATSMYNAME_IMAGE) sin caché…\n"
	$(PODMAN) build --no-cache --tag $(WHATSMYNAME_IMAGE) --file $(WHATSMYNAME_CONTAINERFILE) .

## clean-image-whatsmyname  Detiene contenedor y elimina imagen WhatsMyName
clean-image-whatsmyname:
	$(PODMAN) stop $(WHATSMYNAME_CONTAINER) 2>/dev/null || true
	$(PODMAN) rm   $(WHATSMYNAME_CONTAINER) 2>/dev/null || true
	$(PODMAN) rmi  $(WHATSMYNAME_IMAGE)     2>/dev/null || true
	@printf "$(GREEN)[container]$(RESET) WhatsMyName limpiado.\n"

## start-container-whatsmyname  Inicia el contenedor WhatsMyName
start-container-whatsmyname:
	@if $(PODMAN) container exists $(WHATSMYNAME_CONTAINER) 2>/dev/null; then \
		printf "$(YELLOW)[container]$(RESET) '$(WHATSMYNAME_CONTAINER)' ya existe.\n"; \
	else \
		printf "$(CYAN)[container]$(RESET) Iniciando $(WHATSMYNAME_CONTAINER)…\n"; \
		$(PODMAN) run --detach --name $(WHATSMYNAME_CONTAINER) \
			--network host \
			--security-opt no-new-privileges \
			--read-only --tmpfs /tmp \
			$(WHATSMYNAME_IMAGE); \
	fi

## stop-container-whatsmyname   Detiene el contenedor WhatsMyName
stop-container-whatsmyname:
	@printf "$(YELLOW)[container]$(RESET) Deteniendo $(WHATSMYNAME_CONTAINER)…\n"
	$(PODMAN) stop $(WHATSMYNAME_CONTAINER) 2>/dev/null || true

## build-all-images       Construye todas las imágenes OSINT
build-all-images: build-image-phomber build-image-sherlock build-image-gitfive build-image-numspy build-image-whatsmyname
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
