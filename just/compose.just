set working-directory := ".."

# compose.just — gestión del stack vía Podman Compose (validación local)
# Llamado con: just compose <recipe>
#
# El orquestador corre en el HOST. Este módulo gestiona la infraestructura.
# Flujo recomendado para validar antes de desplegar en Raspberry Pi:
#
#   1. just compose build               # construye imágenes
#   2. just compose up                  # levanta PHOMBER (usa Groq/DeepSeek)
#      ó just compose up-local          # + llama-server local
#   3. just compose status              # verifica que todo esté OK
#   4. just q "+52 55 1234 5678"        # prueba end-to-end
#   5. just compose down                # limpia al terminar

# Construye la imagen de PHOMBER
build:
    make compose-build

# Construye la imagen de llama-server (compilación lenta, solo si necesitas LLM local)
build-llama:
    make compose-build-llama

# Levanta PHOMBER (modo API remota: Groq/DeepSeek)
up:
    make compose-up
    @echo ""
    @echo "Stack listo. Prueba con: just q \"+52 55 1234 5678\""

# Levanta PHOMBER + llama-server (modo local completo)
up-local: _check-model
    make compose-up-local
    just compose wait-llama
    @echo ""
    @echo "Stack local listo. Prueba con: LLM_PROVIDER=local just q \"+52 55 1234 5678\""

# Detiene los servicios (mantiene imágenes)
stop:
    make compose-stop

# Detiene y elimina los contenedores
down:
    make compose-down

# Reinicia el stack activo
restart:
    just compose down
    just compose up

# Estado de los servicios compose + health checks
status:
    make compose-ps
    @echo ""
    uv run --script scripts/health_check.py

# Sigue los logs de todos los servicios
logs:
    make compose-logs

# Sigue los logs de un servicio específico
logs-service service:
    podman compose -f container/compose.yaml --profile local-llm logs --follow {{service}}

# Abre shell en el contenedor PHOMBER
shell:
    podman exec -it phomber /bin/bash

# Elimina contenedores e imágenes construidas localmente
clean:
    make compose-clean

# ── Helpers internos ──────────────────────────────────────────────────────────

# Espera hasta que llama-server responda (máx 90s)
wait-llama:
    #!/usr/bin/env bash
    echo "Esperando que llama-server esté listo..."
    port="${LLAMA_PORT:-8080}"
    for i in $(seq 1 90); do
        if curl -sf "http://127.0.0.1:${port}/health" > /dev/null 2>&1; then
            echo "llama-server listo en :${port}"
            exit 0
        fi
        sleep 1
    done
    echo "ADVERTENCIA: llama-server no respondió en 90s"
    echo "Revisa los logs: just compose logs-service llama-server"

# Verifica que el modelo exista antes de intentar levantar llama-server
_check-model:
    #!/usr/bin/env bash
    model_dir="${MODEL_DIR:-$HOME/models}"
    model_file="${MODEL_FILE:-qwen2-0_5b-instruct-q4_k_m.gguf}"
    model_path="${model_dir}/${model_file}"
    if [ ! -f "${model_path}" ]; then
        echo "ERROR: modelo no encontrado en ${model_path}"
        echo "Descárgalo con: just setup download-model"
        exit 1
    fi
    echo "Modelo OK: ${model_path}"
