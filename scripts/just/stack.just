set working-directory := "../.."

# stack.just — ciclo de vida del stack completo
# Llamado con: just stack <recipe>
#
# Dependencias: contenedor Podman + llama-server deben estar construidos.
# Si no lo están: just setup raspi

# Inicia el stack completo: contenedor PHOMBER + llama-server
start model=`echo ${MODEL_PATH:-${MODEL_DIR:-$HOME/models}/${MODEL_FILE:-qwen2-0_5b-instruct-q4_k_m.gguf}}`:
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
restart model=`echo ${MODEL_PATH:-${MODEL_DIR:-$HOME/models}/${MODEL_FILE:-qwen2-0_5b-instruct-q4_k_m.gguf}}`:
    just stack stop
    just stack start "{{model}}"

# Espera hasta que llama-server responda (máx 30s)
wait-ready:
    bash scripts/shellscript/wait_llama.sh 30

# Estado completo del stack
status:
    @echo "=== Estado del stack ==="
    make container-status
    make llama-status
    uv run --script scripts/python/health_check.py

# Sigue los logs del contenedor PHOMBER
logs:
    make container-logs

# Limpia todo: detiene servicios y elimina artefactos
clean:
    just stack stop
    make clean
