# Referencia de comandos

Guía rápida de todos los comandos disponibles en `just` y `make`.

---

## just — módulos y recetas

### Recetas de alto nivel (raíz del Justfile)

```bash
just                   # lista todas las recetas disponibles
just bootstrap         # setup completo en Raspberry Pi (una sola vez)
just up                # levanta el stack (just stack start)
just down              # detiene el stack (just stack stop)
just q "<número>"      # consulta OSINT rápida
just status            # estado completo del sistema
just ci                # CI de calidad de código (just dev ci)
```

---

### `just setup` — preparación del entorno

```bash
just setup install                  # instala dependencias de producción (uv sync --no-dev)
just setup install-dev              # instala deps + herramientas dev (ruff, mypy, pytest)
just setup download-model           # descarga Qwen2 0.5B Q4_K_M en $HOME/models/
just setup download-model REPO FILE # descarga modelo personalizado desde Hugging Face
just setup raspi                    # setup completo para Raspberry Pi
just setup env-init                 # crea .env desde .env.example (no sobreescribe)
just setup check-api                # muestra qué API keys están configuradas
```

Ejemplo de modelo personalizado:
```bash
just setup download-model \
    "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF" \
    "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
```

---

### `just dev` — flujo de desarrollo

```bash
just dev lint          # ruff check orchestrator/
just dev format        # ruff format orchestrator/
just dev format-check  # verifica formato sin modificar (para CI)
just dev typecheck     # mypy orchestrator/
just dev test          # pytest tests/
just dev ci            # format-check → lint → typecheck → test
just dev fix           # format → lint → typecheck
just dev logs-llama    # tail -f /tmp/llama-server.log
just dev shell         # shell interactivo en el contenedor PHOMBER
```

---

### `just stack` — ciclo de vida del stack (producción / Pi)

```bash
just stack start                     # inicia PHOMBER + llama-server
just stack start "/ruta/modelo.gguf" # inicia con modelo específico
just stack stop                      # detiene todos los servicios
just stack restart                   # stop + start
just stack wait-ready                # espera hasta que llama-server responda
just stack status                    # estado del contenedor + llama + health check
just stack logs                      # logs del contenedor PHOMBER
just stack clean                     # stop + make clean
```

---

### `just osint` — consultas OSINT

```bash
just osint query "+52 55 1234 5678"  # consulta con número
just osint interactive               # modo interactivo (prompt)
just osint check                     # verifica contenedor y stack antes de consultar
just osint raw "-p +525512345678"    # salida raw de PHOMBER (sin LLM)
```

---

### `just compose` — Podman Compose (validación local)

```bash
just compose build                      # construye imagen PHOMBER
just compose build-llama                # compila imagen llama-server (lento, ~15 min)
just compose up                         # levanta PHOMBER (APIs remotas)
just compose up-local                   # levanta PHOMBER + llama-server
just compose stop                       # detiene servicios (mantiene imágenes)
just compose down                       # detiene y elimina contenedores
just compose restart                    # down + up
just compose status                     # compose ps + health check
just compose logs                       # logs de todos los servicios
just compose logs-service phomber       # logs de un servicio específico
just compose logs-service llama-server
just compose shell                      # shell en PHOMBER
just compose clean                      # down + elimina imágenes locales
```

---

## make — targets de build

### Contenedor PHOMBER

```bash
make build-image        # construye localhost/phomber:latest
make rebuild-image      # reconstruye sin caché
make start-container    # inicia el contenedor (sin compose)
make stop-container     # detiene el contenedor
make rm-container       # elimina el contenedor (stop + rm)
make restart-container  # stop + start
make container-logs     # sigue los logs del contenedor
make container-shell    # abre /bin/bash dentro del contenedor
make container-status   # muestra estado en tabla
make clean-image        # elimina imagen + contenedor
```

### Python / uv

```bash
make install            # uv sync --no-dev
make install-dev        # uv sync (con dev deps)
make sync               # uv sync --frozen
make lint               # ruff check orchestrator/
make format             # ruff format orchestrator/
make format-check       # ruff format --check (sin modificar)
make typecheck          # mypy orchestrator/
make test               # pytest tests/ -v
make build-wheel        # uv build → dist/
make clean-python       # elimina __pycache__, .coverage, dist/, etc.
```

### llama.cpp

```bash
make clone-llama        # clona $HOME/llama.cpp (o git pull si existe)
make build-llama        # compila llama-server con NATIVE=ON
make start-llama-server # inicia llama-server en background (:8080)
make stop-llama-server  # mata el proceso en :8080
make llama-status       # indica si :8080 está escuchando
make clean-llama        # elimina $HOME/llama.cpp/build
```

### Checks y salud

```bash
make check-deps         # verifica herramientas del sistema (uv, podman, make, just…)
make check-health       # salud completa del stack (contenedor + llama + keys)
make check-container    # solo verifica si el contenedor PHOMBER está activo
make check-api-config   # muestra qué API keys están configuradas
make check-all          # ejecuta check-deps + lint + format-check + typecheck + check-container + check-health
```

### Podman Compose

```bash
make compose-build       # construye imagen phomber vía compose
make compose-build-llama # construye imagen llama-server vía compose
make compose-up          # levanta phomber (detached)
make compose-up-local    # levanta phomber + llama-server (profile local-llm)
make compose-stop        # detiene servicios
make compose-down        # down (elimina contenedores)
make compose-ps          # estado de servicios
make compose-logs        # logs (follow)
make compose-restart     # down + up
make compose-clean       # down + rmi imágenes locales
```

### Targets compuestos

```bash
make build    # build-image + build-wheel
make clean    # clean-python + clean-image
make help     # lista todos los targets con descripción
```

---

## Variables de entorno clave

| Variable | Default | Descripción |
|---|---|---|
| `LLM_PROVIDER` | `groq\|deepseek\|local` | Cadena de proveedores (pipe-separated) |
| `GROQ_API_KEY` | — | API key de Groq |
| `GROQ_MODEL` | `llama-3.1-8b-instant` | Modelo a usar en Groq |
| `DEEPSEEK_API_KEY` | — | API key de DeepSeek |
| `DEEPSEEK_MODEL` | `deepseek-chat` | Modelo a usar en DeepSeek |
| `LLAMA_SERVER_URL` | `http://localhost:8080` | URL del servidor llama.cpp |
| `LOCAL_MODEL_NAME` | `qwen2-0.5b-instruct-q4_k_m` | Nombre descriptivo del modelo local |
| `MODEL_DIR` | `$HOME/models` | Directorio de modelos GGUF |
| `MODEL_FILE` | `qwen2-0_5b-instruct-q4_k_m.gguf` | Nombre del archivo de modelo |
| `LLAMA_PORT` | `8080` | Puerto de llama-server en compose |
| `LLAMA_CTX` | `2048` | Tamaño de contexto (tokens) |
| `LLAMA_THREADS` | `4` | Hilos de CPU para llama-server |
| `CONTAINER_NAME` | `phomber` | Nombre del contenedor PHOMBER |
| `LOG_LEVEL` | `WARNING` | Nivel de log (`DEBUG` / `INFO` / `WARNING` / `ERROR`) |

---

## Scripts Python (PEP 723 — ejecución directa con uv)

Los scripts en `scripts/` tienen metadata de dependencias inline.
Se ejecutan con `uv run` sin necesitar el entorno virtual del proyecto.

```bash
uv run scripts/check_deps.py        # verifica herramientas del sistema
uv run scripts/health_check.py      # salud del stack
uv run scripts/download_model.py    # descarga modelo (flags: --repo, --file, --dir, --token)
```

---

## Flujos de referencia rápida

### Setup inicial en Mac (validación)

```bash
git clone https://github.com/rafex/poc-OSINT && cd poc-OSINT
make install
just setup env-init && $EDITOR .env
make build-image
just compose up
just q "+52 55 1234 5678"
just compose down
```

### Setup inicial en Raspberry Pi 4B

```bash
git clone https://github.com/rafex/poc-OSINT && cd poc-OSINT
just setup env-init && nano .env
just bootstrap          # tarda ~45 min (compila llama.cpp)
just up
just q "+52 55 1234 5678"
```

### Ciclo diario en Pi

```bash
just up                 # mañana
just q "+34 91 000 0000"
just status             # verificar
just down               # al terminar
```

### Debugging con logs completos

```bash
LOG_LEVEL=DEBUG just q "+52 55 1234 5678" 2>&1 | tee /tmp/debug.log
```
