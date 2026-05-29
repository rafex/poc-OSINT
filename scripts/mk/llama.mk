.PHONY: clone-llama build-llama start-llama-server stop-llama-server \
        llama-status clean-llama

## clone-llama       Clona el repositorio de llama.cpp
clone-llama:
	@LLAMA_REPO=$(LLAMA_REPO) LLAMA_DIR=$(LLAMA_DIR) \
		bash $(SCRIPTS_SH_DIR)/llama_clone.sh

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
	@LLAMA_PORT=$(LLAMA_PORT) MODEL_PATH=$(MODEL_PATH) \
		LLAMA_CTX=$(LLAMA_CTX) LLAMA_THREADS=$(LLAMA_THREADS) \
		bash $(SCRIPTS_SH_DIR)/llama_start.sh

## stop-llama-server  Detiene llama-server
stop-llama-server:
	@LLAMA_PORT=$(LLAMA_PORT) bash $(SCRIPTS_SH_DIR)/llama_stop.sh

## llama-status       Estado del servidor llama.cpp
llama-status:
	@LLAMA_PORT=$(LLAMA_PORT) bash $(SCRIPTS_SH_DIR)/llama_status.sh

## clean-llama        Elimina los artefactos de compilación de llama.cpp
clean-llama:
	rm -rf $(LLAMA_DIR)/build
	@printf "$(GREEN)[llama]$(RESET) Build artifacts eliminados.\n"
