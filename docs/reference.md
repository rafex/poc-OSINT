# Referencia de comandos

Guía completa de todos los targets de `make` y recetas de `just` disponibles en el proyecto.

> **Regla de oro:** `just` puede llamar a `make`. `make` **nunca** llama a `just`.
> - `make` → gestiona artefactos (build, compilación, lint, empaquetado).
> - `just` → orquesta flujos (setup, arranque de servicios, consultas, ciclos dev).

---

## Estructura del proyecto

```
poc-OSINT/
├── Makefile                    ← orquesta todos los scripts/mk/
├── Justfile                    ← orquesta todos los scripts/just/
│
├── scripts/                    ← todos los scripts y módulos de automatización
│   ├── mk/                     ← módulos Make (build)
│   │   ├── vars.mk
│   │   ├── container.mk
│   │   ├── python.mk
│   │   ├── llama.mk
│   │   ├── checks.mk
│   │   ├── compose.mk
│   │   └── secrets.mk
│   ├── just/                   ← módulos Just (flujos)
│   │   ├── setup.just
│   │   ├── dev.just
│   │   ├── stack.just
│   │   ├── osint.just
│   │   ├── compose.just
│   │   └── secrets.just
│   ├── python/                 ← scripts PEP 723 (uv run --script)
│   │   ├── check_deps.py
│   │   ├── health_check.py
│   │   ├── download_model.py
│   │   ├── setup_age.py
│   │   ├── edit_secrets.py
│   │   └── export_secrets.py
│   ├── shellscript/            ← scripts shell
│   │   ├── secrets_check.sh
│   │   ├── secrets_pubkey.sh
│   │   ├── secrets_export.sh
│   │   ├── env_init.sh
│   │   ├── wait_llama.sh
│   │   ├── check_model.sh
│   │   ├── llama_clone.sh
│   │   ├── llama_start.sh
│   │   ├── llama_stop.sh
│   │   ├── llama_status.sh
│   │   ├── check_container.sh
│   │   ├── check_api_config.sh
│   │   └── start_container.sh
│   └── pyproject.toml          ← tooling para scripts/python/ (ruff, mypy)
│
├── orchestrator/               ← proyecto Python independiente
│   ├── pyproject.toml
│   └── src/orchestrator/       ← paquete Python (src layout)
│       ├── main.py
│       ├── executor.py
│       ├── llm_client.py
│       └── intent_parser.py
│
└── container/                  ← imágenes y compose
    ├── Containerfile           ← imagen PHOMBER
    ├── Containerfile.sherlock  ← imagen Sherlock
    ├── Containerfile.llama     ← imagen llama-server
    └── compose.yaml            ← Podman Compose (context: ..)
```

---

## make — Targets de build

### Targets raíz

| Target | Descripción |
|---|---|
| `make` / `make help` | Lista todos los targets disponibles con descripción *(default)* |
| `make build` | Construye todas las imágenes OSINT + wheel Python |
| `make clean` | Limpia todos los artefactos generados |

---

### `mk/container.mk` — Imágenes OSINT

#### PHOMBER (reconocimiento de números de teléfono)

| Target | Descripción |
|---|---|
| `make build-image-phomber` | Construye `localhost/phomber:latest` desde `container/Containerfile` |
| `make rebuild-image-phomber` | Reconstruye PHOMBER forzando `--no-cache` |
| `make clean-image-phomber` | Detiene contenedor + elimina imagen PHOMBER |
| `make start-container-phomber` | Inicia el contenedor PHOMBER en segundo plano (rootless, read-only) |
| `make stop-container-phomber` | Detiene el contenedor PHOMBER |

#### Sherlock (búsqueda de usernames en redes sociales)

| Target | Descripción |
|---|---|
| `make build-image-sherlock` | Construye `localhost/sherlock:latest` desde `container/Containerfile.sherlock` |
| `make rebuild-image-sherlock` | Reconstruye Sherlock forzando `--no-cache` |
| `make clean-image-sherlock` | Detiene contenedor + elimina imagen Sherlock |
| `make start-container-sherlock` | Inicia el contenedor Sherlock en segundo plano |
| `make stop-container-sherlock` | Detiene el contenedor Sherlock |

#### Compuestos y alias

| Target | Descripción |
|---|---|
| `make build-all-images` | Construye PHOMBER + Sherlock |
| `make start-container` | Alias → `start-container-phomber` |
| `make stop-container` | Alias → `stop-container-phomber` |
| `make rm-container` | Detiene + elimina contenedor PHOMBER |
| `make restart-container` | Para + reinicia contenedor PHOMBER |
| `make container-logs` | Sigue los logs del contenedor PHOMBER en tiempo real |
| `make container-shell` | Abre `/bin/bash` interactivo en PHOMBER |
| `make container-status` | Muestra estado de **todos** los contenedores OSINT (tabla) |

---

### `mk/python.mk` — Python / uv

Todos los comandos usan `uv --directory orchestrator` para no cambiar el directorio de trabajo del shell.

#### Orquestador (`orchestrator/`)

| Target | Descripción |
|---|---|
| `make install` | `uv sync --no-dev` — instala deps de producción |
| `make install-dev` | `uv sync` — instala deps + herramientas de desarrollo (ruff, mypy, pytest) |
| `make sync` | `uv sync --frozen` — sincroniza sin modificar el lockfile |
| `make lint` | `ruff check src/orchestrator/` |
| `make format` | `ruff format src/orchestrator/` — modifica archivos in-place |
| `make format-check` | `ruff format --check` — verifica sin modificar (para CI) |
| `make typecheck` | `mypy src/orchestrator/` |
| `make test` | `pytest tests/ -v` |
| `make build-wheel` | Empaqueta el orquestador como wheel en `orchestrator/dist/` |

#### Scripts (`scripts/python/`)

| Target | Descripción |
|---|---|
| `make lint-scripts` | `ruff check scripts/python/` |
| `make format-scripts` | `ruff format scripts/python/` |

#### Limpieza

| Target | Descripción |
|---|---|
| `make clean-python` | Elimina `__pycache__`, `.pyc`, `dist/`, `.coverage`, `.pytest_cache`, `.mypy_cache`, `.ruff_cache` |

---

### `mk/llama.mk` — llama.cpp

| Target | Descripción |
|---|---|
| `make clone-llama` | Clona `ggml-org/llama.cpp` en `$HOME/llama.cpp` (o hace `git pull` si ya existe) |
| `make build-llama` | Compila llama-server con `GGML_NATIVE=ON` (optimizado para la CPU del host) |
| `make start-llama-server` | Inicia `llama-server` en background en `127.0.0.1:8080`, logs en `/tmp/llama-server.log` |
| `make stop-llama-server` | Mata el proceso que escucha en `:8080` |
| `make llama-status` | Informa si llama-server está activo en `:8080` |
| `make clean-llama` | Elimina `$HOME/llama.cpp/build/` |

---

### `mk/checks.mk` — Verificaciones

| Target | Descripción |
|---|---|
| `make check-deps` | Verifica herramientas del sistema: uv, podman, make, just, git, curl |
| `make check-health` | Health check completo del stack: contenedor + llama-server + API keys |
| `make check-container` | Verifica solo si el contenedor PHOMBER está activo |
| `make check-api-config` | Muestra qué API keys (Groq, DeepSeek) están configuradas en el entorno |
| `make check-all` | Ejecuta: `check-deps` + `check-api-config` + `lint` + `format-check` + `typecheck` + `check-container` + `check-health` |

---

### `mk/compose.mk` — Podman Compose

| Target | Descripción |
|---|---|
| `make compose-build-phomber` | Construye imagen PHOMBER vía compose |
| `make compose-build-sherlock` | Construye imagen Sherlock vía compose |
| `make compose-build-all` | Construye PHOMBER + Sherlock vía compose |
| `make compose-build-llama` | Compila imagen llama-server (~10–20 min, primera vez) |
| `make compose-up` | Levanta PHOMBER + Sherlock en background (APIs remotas) |
| `make compose-up-local` | Levanta stack completo con perfil `local-llm` |
| `make compose-stop` | Detiene servicios sin eliminar contenedores |
| `make compose-down` | Detiene y elimina todos los contenedores |
| `make compose-ps` | Estado de los servicios de compose |
| `make compose-logs` | Sigue los logs de todos los servicios |
| `make compose-restart` | `compose-down` + `compose-up` |
| `make compose-clean` | `compose-down` + elimina imágenes locales (phomber, sherlock, llama-server) |

---

### `mk/secrets.mk` — Secretos SOPS + age

| Target | Descripción |
|---|---|
| `make secrets-setup` | Genera clave age en `~/.age/key.txt` y crea `secrets/secrets.enc.yaml` |
| `make secrets-edit` | Descifra → abre vim → valida schema → re-cifra |
| `make secrets-export` | Descifra a `.env` en formato `KEY=value` (nunca commitear) |
| `make secrets-view` | Muestra secretos descifrados en terminal (solo lectura) |
| `make secrets-check` | Verifica que el archivo cifrado puede descifrarse con la clave actual |
| `make secrets-pubkey` | Muestra la clave pública age de `~/.age/key.txt` |

---

## just — Módulos y recetas

### Recetas raíz del Justfile

| Receta | Descripción |
|---|---|
| `just` | Lista todas las recetas disponibles *(default)* |
| `just bootstrap` | Onboarding completo en Raspberry Pi: `just setup raspi` |
| `just up` | Levanta el stack de producción: `just stack start` |
| `just down` | Detiene el stack: `just stack stop` |
| `just q "<número>"` | Consulta OSINT rápida: `just osint query` |
| `just status` | Estado completo del sistema: `just stack status` |
| `just ci` | CI de calidad de código: `just dev ci` |

---

### `just setup` — Preparación del entorno

```bash
just setup <receta>
```

| Receta | Descripción |
|---|---|
| `just setup install` | Instala deps de producción del orquestador (`make install`) |
| `just setup install-dev` | Instala deps de desarrollo (`make install-dev`) |
| `just setup download-model` | Descarga `qwen2-0_5b-instruct-q4_k_m.gguf` en `$HOME/models/` |
| `just setup download-model REPO FILE` | Descarga un modelo GGUF personalizado desde Hugging Face |
| `just setup raspi` | Setup completo Pi 4B: install + build-all-images + build-llama + download-model |
| `just setup env-init` | Copia `.env.example` → `.env` si no existe |
| `just setup check-api` | Muestra qué API keys están configuradas (`make check-api-config`) |

**Ejemplo — modelo personalizado:**
```bash
just setup download-model "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF" "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
```

---

### `just dev` — Flujo de desarrollo

```bash
just dev <receta>
```

| Receta | Descripción |
|---|---|
| `just dev lint` | `ruff check src/orchestrator/` |
| `just dev format` | `ruff format src/orchestrator/` — modifica in-place |
| `just dev format-check` | Verifica formato sin modificar (para CI) |
| `just dev typecheck` | `mypy src/orchestrator/` |
| `just dev test` | `pytest tests/ -v` |
| `just dev ci` | Pipeline completo: `format-check` → `lint` → `typecheck` → `test` |
| `just dev fix` | Ciclo rápido: `format` → `lint` → `typecheck` |
| `just dev logs-llama` | `tail -f /tmp/llama-server.log` en tiempo real |
| `just dev shell` | Shell interactivo en el contenedor PHOMBER |

---

### `just stack` — Ciclo de vida del stack (producción / Pi)

```bash
just stack <receta>
```

| Receta | Descripción |
|---|---|
| `just stack start` | Inicia PHOMBER + llama-server (modelo por defecto) |
| `just stack start "/ruta/modelo.gguf"` | Inicia con modelo GGUF específico |
| `just stack stop` | Detiene llama-server + contenedor PHOMBER |
| `just stack restart` | `stop` + `start` |
| `just stack wait-ready` | Espera hasta que llama-server responda (máx 30 s) |
| `just stack status` | Estado de contenedores + llama-server + health check completo |
| `just stack logs` | Logs del contenedor PHOMBER en tiempo real |
| `just stack clean` | `stop` + `make clean` |

---

### `just osint` — Consultas OSINT

```bash
just osint <receta>
```

| Receta | Descripción |
|---|---|
| `just osint query "<número>"` | Ejecuta consulta OSINT completa: PHOMBER → LLM → respuesta |
| `just osint interactive` | Modo interactivo: el orquestador pide la consulta |
| `just osint check` | Verifica contenedor PHOMBER + salud del stack antes de consultar |
| `just osint raw "<args>"` | Ejecuta PHOMBER directamente sin LLM (modo debug) |

**Ejemplos:**
```bash
just osint query "+52 55 1234 5678"
just osint query "+34 91 000 0000"
just osint raw "-p +525512345678"
LLM_PROVIDER=deepseek just osint query "+1 800 555 0199"
```

---

### `just compose` — Validación local con Podman Compose

```bash
just compose <receta>
```

| Receta | Descripción |
|---|---|
| `just compose build-phomber` | Construye imagen PHOMBER para compose |
| `just compose build-sherlock` | Construye imagen Sherlock para compose |
| `just compose build-all` | Construye PHOMBER + Sherlock para compose |
| `just compose build-llama` | Compila imagen llama-server (~10–20 min) |
| `just compose up` | Levanta PHOMBER + Sherlock (APIs remotas: Groq/DeepSeek) |
| `just compose up-local` | Levanta stack completo con llama-server local |
| `just compose stop` | Detiene servicios (mantiene imágenes) |
| `just compose down` | Detiene y elimina contenedores |
| `just compose restart` | `down` + `up` |
| `just compose status` | Estado de servicios + health check completo |
| `just compose logs` | Logs de todos los servicios en tiempo real |
| `just compose logs-service <nombre>` | Logs de un servicio específico (`phomber`, `sherlock`, `llama-server`) |
| `just compose shell` | Shell en el contenedor PHOMBER |
| `just compose clean` | Elimina contenedores e imágenes locales |

**Flujo de validación local:**
```bash
just compose build-all          # construye imágenes (~5 min)
just compose up                 # levanta PHOMBER + Sherlock
just compose status             # verifica salud
just q "+52 55 1234 5678"       # prueba end-to-end
just compose down               # limpia
```

---

### `just secrets` — Gestión de secretos (SOPS + age)

```bash
just secrets <receta>
```

| Receta | Descripción |
|---|---|
| `just secrets setup` | Genera clave age en `~/.age/key.txt`, actualiza `.sops.yaml`, crea `secrets/secrets.enc.yaml` |
| `just secrets edit` | Descifra → abre vim → valida schema → re-cifra |
| `just secrets export` | Descifra `secrets.enc.yaml` → escribe `.env` (nunca commitear) |
| `just secrets view` | Muestra secretos descifrados en terminal (solo lectura) |
| `just secrets check` | Verifica que el archivo cifrado puede descifrarse con la clave actual |
| `just secrets pubkey` | Muestra la clave pública age registrada en `~/.age/key.txt` |

**Flujo inicial:**
```bash
just secrets setup    # genera clave + archivo cifrado
just secrets edit     # rellena API keys en vim
just secrets export   # genera .env para uso local
```

**Archivos involucrados:**

| Archivo | Ubicación | Committed |
|---|---|---|
| Clave privada age | `~/.age/key.txt` | **Nunca** |
| Config SOPS | `.sops.yaml` | Sí (clave pública) |
| Secretos cifrados | `secrets/secrets.enc.yaml` | Sí (AES-256-GCM) |
| Env exportado | `.env` | **Nunca** |

---

## Variables de entorno

| Variable | Default | Descripción |
|---|---|---|
| `LLM_PROVIDER` | `groq\|deepseek\|local` | Cadena de proveedores LLM (pipe-separated) |
| `GROQ_API_KEY` | — | API key de Groq (`gsk_...`) |
| `GROQ_MODEL` | `llama-3.1-8b-instant` | Modelo Groq |
| `DEEPSEEK_API_KEY` | — | API key de DeepSeek (`sk-...`) |
| `DEEPSEEK_MODEL` | `deepseek-chat` | Modelo DeepSeek |
| `LLAMA_SERVER_URL` | `http://localhost:8080` | URL del servidor llama.cpp local |
| `LOCAL_MODEL_NAME` | `qwen2-0.5b-instruct-q4_k_m` | Nombre descriptivo del modelo local |
| `MODEL_DIR` | `$HOME/models` | Directorio de modelos GGUF |
| `MODEL_FILE` | `qwen2-0_5b-instruct-q4_k_m.gguf` | Archivo del modelo GGUF |
| `LLAMA_PORT` | `8080` | Puerto de llama-server en compose |
| `LLAMA_CTX` | `2048` | Tamaño de contexto (tokens) |
| `LLAMA_THREADS` | `4` | Hilos de CPU para llama-server |
| `CONTAINER_NAME` | `phomber` | Nombre del contenedor PHOMBER |
| `LOG_LEVEL` | `WARNING` | Nivel de log (`DEBUG`/`INFO`/`WARNING`/`ERROR`) |
| `EDITOR` | `vim` | Editor usado por `just secrets edit` |

---

## Variables internas de Make (`mk/vars.mk`)

| Variable | Valor | Descripción |
|---|---|---|
| `PHOMBER_IMAGE` | `localhost/phomber:latest` | Tag de la imagen PHOMBER |
| `PHOMBER_CONTAINER` | `phomber` | Nombre del contenedor PHOMBER |
| `PHOMBER_CONTAINERFILE` | `container/Containerfile` | Containerfile de PHOMBER |
| `SHERLOCK_IMAGE` | `localhost/sherlock:latest` | Tag de la imagen Sherlock |
| `SHERLOCK_CONTAINER` | `sherlock` | Nombre del contenedor Sherlock |
| `SHERLOCK_CONTAINERFILE` | `container/Containerfile.sherlock` | Containerfile de Sherlock |
| `COMPOSE_FILE` | `container/compose.yaml` | Ruta del archivo Compose |
| `ORCHESTRATOR_DIR` | `orchestrator` | Raíz del proyecto Python del orquestador |
| `SCRIPTS_DIR` | `scripts` | Raíz del proyecto scripts (donde vive `pyproject.toml`) |
| `SCRIPTS_PY_DIR` | `scripts/python` | Scripts PEP 723 |
| `SCRIPTS_SH_DIR` | `scripts/shellscript` | Scripts shell |
| `PYTHON_PKG` | `src/orchestrator` | Ruta del paquete Python (src layout) |
| `LLAMA_DIR` | `$HOME/llama.cpp` | Directorio de la compilación llama.cpp |
| `LLAMA_BIN` | `$HOME/llama.cpp/build/bin/llama-server` | Binario de llama-server |
| `MODEL_PATH` | `$HOME/models/qwen2-0_5b-instruct-q4_k_m.gguf` | Ruta completa del modelo GGUF |

---

## Flujos de referencia rápida

### Setup inicial — Mac (validación local)

```bash
git clone https://github.com/rafex/poc-OSINT && cd poc-OSINT
make install
just setup env-init && $EDITOR .env          # añade API keys
just compose build-all                       # ~5 min
just compose up
just q "+52 55 1234 5678"
just compose down
```

### Setup inicial — Raspberry Pi 4B

```bash
git clone https://github.com/rafex/poc-OSINT && cd poc-OSINT
just setup env-init && nano .env
just bootstrap           # ~45 min: install + imágenes + llama.cpp + modelo
just up
just q "+52 55 1234 5678"
```

### Ciclo de desarrollo

```bash
just dev fix             # format → lint → typecheck
just dev ci              # pipeline completo
LOG_LEVEL=DEBUG just q "+52 55 1234 5678" 2>&1  # debug con logs
```

### Gestión de secretos

```bash
just secrets setup       # primera vez
just secrets edit        # editar API keys en vim
just secrets export      # generar .env
just secrets check       # verificar integridad
```

### Debugging

```bash
# Ver logs del stack
just stack logs          # contenedor PHOMBER
just dev logs-llama      # llama-server
just compose logs-service sherlock

# Ejecutar herramientas OSINT directamente (sin LLM)
just osint raw "-p +525512345678"          # PHOMBER directo
podman exec sherlock sherlock username     # Sherlock directo

# Forzar proveedor LLM específico
LLM_PROVIDER=groq just q "+52 55 1234 5678"
LLM_PROVIDER=local just q "+52 55 1234 5678"
LOG_LEVEL=DEBUG just q "+52 55 1234 5678" 2>/tmp/debug.log
```
