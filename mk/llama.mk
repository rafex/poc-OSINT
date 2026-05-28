.PHONY: clone-llama build-llama start-llama-server stop-llama-server \
        llama-status clean-llama

## clone-llama       Clona el repositorio de llama.cpp
clone-llama:
	@if [ -d "$(LLAMA_DIR)" ]; then \
		printf "$(YELLOW)[llama]$(RESET) $(LLAMA_DIR) ya existe — actualizando…\n"; \
		$(GIT) -C $(LLAMA_DIR) pull --ff-only; \
	else \
		printf "$(CYAN)[llama]$(RESET) Clonando llama.cpp en $(LLAMA_DIR)…\n"; \
		$(GIT) clone --depth 1 $(LLAMA_REPO) $(LLAMA_DIR); \
	fi

## build-llama       Compila llama.cpp con soporte nativo ARM64 / x86
build-llama: clone-llama
	@printf "$(CYAN)[llama]$(RESET) Compilando (esto tarda varios minutos en Raspberry Pi)…\n"
	cmake -S $(LLAMA_DIR) -B $(LLAMA_DIR)/build \
		-DGGML_NATIVE=ON \
		-DCMAKE_BUILD_TYPE=Release
	cmake --build $(LLAMA_DIR)/build \
		--config Release \
		--parallel $$(nproc)
	@printf "$(GREEN)[llama]$(RESET) Compilado: $(LLAMA_BIN)\n"

## start-llama-server  Inicia llama-server en background
start-llama-server:
	@if ! [ -f "$(LLAMA_BIN)" ]; then \
		printf "$(RED)[llama]$(RESET) Binario no encontrado: $(LLAMA_BIN)\n"; \
		printf "       Ejecuta: make build-llama\n"; \
		exit 1; \
	fi
	@if ! [ -f "$(MODEL_PATH)" ]; then \
		printf "$(RED)[llama]$(RESET) Modelo no encontrado: $(MODEL_PATH)\n"; \
		printf "       Ejecuta: just setup download-model\n"; \
		exit 1; \
	fi
	@if lsof -i :$(LLAMA_PORT) -sTCP:LISTEN -t >/dev/null 2>&1; then \
		printf "$(YELLOW)[llama]$(RESET) Puerto $(LLAMA_PORT) ya en uso — servidor activo.\n"; \
	else \
		printf "$(CYAN)[llama]$(RESET) Iniciando llama-server en 127.0.0.1:$(LLAMA_PORT)…\n"; \
		nohup $(LLAMA_BIN) \
			--model $(MODEL_PATH) \
			--host 127.0.0.1 \
			--port $(LLAMA_PORT) \
			--ctx-size $(LLAMA_CTX) \
			--threads $(LLAMA_THREADS) \
			> /tmp/llama-server.log 2>&1 & \
		printf "$(GREEN)[llama]$(RESET) PID $$! — logs: /tmp/llama-server.log\n"; \
	fi

## stop-llama-server  Detiene llama-server
stop-llama-server:
	@PID=$$(lsof -ti :$(LLAMA_PORT) -sTCP:LISTEN 2>/dev/null); \
	if [ -n "$$PID" ]; then \
		kill $$PID && printf "$(GREEN)[llama]$(RESET) Servidor detenido (PID $$PID).\n"; \
	else \
		printf "$(YELLOW)[llama]$(RESET) No hay servidor activo en :$(LLAMA_PORT).\n"; \
	fi

## llama-status       Estado del servidor llama.cpp
llama-status:
	@if lsof -i :$(LLAMA_PORT) -sTCP:LISTEN -t >/dev/null 2>&1; then \
		printf "$(GREEN)[llama]$(RESET) llama-server ACTIVO en :$(LLAMA_PORT)\n"; \
	else \
		printf "$(RED)[llama]$(RESET) llama-server INACTIVO\n"; \
	fi

## clean-llama        Elimina los artefactos de compilación de llama.cpp
clean-llama:
	rm -rf $(LLAMA_DIR)/build
	@printf "$(GREEN)[llama]$(RESET) Build artifacts eliminados.\n"
