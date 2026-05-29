set working-directory := "../.."

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
build-phomber:
    make compose-build-phomber

# Construye la imagen de Sherlock
build-sherlock:
    make compose-build-sherlock

# Construye todas las imágenes OSINT (PHOMBER + Sherlock)
build-all:
    make compose-build-all

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
    uv run --script scripts/python/health_check.py

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

# Elimina contenedores huérfanos (parados o con nombre en conflicto) y levanta el stack
# Útil cuando just compose up falla con "container name already in use"
reset:
    @echo "Eliminando contenedores huérfanos…"
    @podman stop phomber sherlock 2>/dev/null || true
    @podman rm   phomber sherlock 2>/dev/null || true
    just compose up

# ── Helpers internos ──────────────────────────────────────────────────────────

# Espera hasta que llama-server responda (máx 90s)
wait-llama:
    bash scripts/shellscript/wait_llama.sh 90

# Verifica que el modelo exista antes de intentar levantar llama-server
_check-model:
    bash scripts/shellscript/check_model.sh
