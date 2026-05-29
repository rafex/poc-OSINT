set working-directory := ".."

# stack.just — ciclo de vida del stack completo
# Llamado con: just stack <recipe>
#
# Dependencias: contenedor Podman + llama-server deben estar construidos.
# Si no lo están: just setup raspi

# Inicia el stack completo: contenedor PHOMBER + llama-server
start model=`echo ${MODEL_PATH:-$HOME/models/qwen2-0_5b-instruct-q4_k_m.gguf}`:
    @echo "=== Iniciando stack edge-osint-lab ==="
    make start-container
    make start-llama-server MODEL_PATH="{{model}}"
    just stack wait-ready
    @echo "=== Stack listo. Usa: just osint query <número> ==="

# Detiene todo el stack
stop:
    @echo "=== Deteniendo stack ==="
    make stop-llama-server
    make stop-container
    @echo "=== Stack detenido ==="

# Reinicia el stack completo
restart model=`echo ${MODEL_PATH:-$HOME/models/qwen2-0_5b-instruct-q4_k_m.gguf}`:
    just stack stop
    just stack start "{{model}}"

# Espera hasta que llama-server responda (máx 30s)
wait-ready:
    @echo "Esperando llama-server..."
    @for i in $(seq 1 30); do \
        curl -sf http://127.0.0.1:8080/health > /dev/null 2>&1 && echo "llama-server listo." && exit 0; \
        sleep 1; \
    done; \
    echo "ADVERTENCIA: llama-server no respondió en 30s. Revisa /tmp/llama-server.log"

# Estado completo del stack
status:
    @echo "=== Estado del stack ==="
    make container-status
    make llama-status
    uv run --script scripts/health_check.py

# Sigue los logs del contenedor PHOMBER
logs:
    make container-logs

# Limpia todo: detiene servicios y elimina artefactos
clean:
    just stack stop
    make clean
