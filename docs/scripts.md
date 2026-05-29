# Scripts — referencia individual

Todos los scripts viven bajo `scripts/`. Los archivos `Justfile` y `Makefile` son proxies que los invocan; esta guía explica cómo ejecutar cada script directamente, sin pasar por `just` ni `make`.

> **Cuándo conviene ejecutarlos directamente:** depuración, CI personalizado, integración con otros sistemas, o cuando quieres entender exactamente qué hace cada paso.

---

## Estructura

```
scripts/
├── python/          ← scripts PEP 723 (autoinstalables con uv)
│   ├── check_deps.py
│   ├── health_check.py
│   ├── download_model.py
│   ├── setup_age.py
│   ├── edit_secrets.py
│   └── export_secrets.py
├── shellscript/     ← scripts Bash (delegados por just y make)
│   ├── secrets_check.sh
│   ├── secrets_pubkey.sh
│   ├── secrets_export.sh
│   ├── env_init.sh
│   ├── wait_llama.sh
│   ├── check_model.sh
│   ├── llama_clone.sh
│   ├── llama_start.sh
│   ├── llama_stop.sh
│   ├── llama_status.sh
│   ├── check_container.sh
│   ├── check_api_config.sh
│   └── start_container.sh
├── just/            ← módulos Just (proxies de flujos)
├── mk/              ← módulos Make (proxies de build)
└── pyproject.toml   ← tooling para scripts/python/ (ruff, mypy)
```

---

## Scripts Python (`scripts/python/`)

Los scripts Python siguen el estándar **PEP 723**: declaran sus dependencias en un bloque `# /// script` embebido y se ejecutan con `uv run --script`. No requieren virtualenv previo.

**Forma canónica de ejecución (desde la raíz del proyecto):**

```bash
uv run --script scripts/python/<nombre>.py [argumentos]
```

---

### `check_deps.py` — Verificar dependencias del sistema

Comprueba que todas las herramientas requeridas (`uv`, `podman`, `make`, `just`, `git`, `curl`) y opcionales (`cmake`, `nohup`, `lsof`) estén en el `PATH`. Muestra una tabla con versiones y sale con código `1` si falta alguna herramienta requerida.

**Uso:**

```bash
uv run --script scripts/python/check_deps.py
```

**Sin argumentos.** Salida: tabla Rich con estado de cada herramienta.

**Proxy en just/make:**
```bash
just setup check-api   # (indirecto a través de make check-deps)
make check-deps
```

---

### `health_check.py` — Health check del stack

Verifica en una sola pasada: contenedor PHOMBER activo, Python ejecutable dentro del contenedor, llama-server respondiendo en `LLAMA_SERVER_URL`, y presencia de API keys. Muestra la cadena LLM efectiva.

**Uso:**

```bash
uv run --script scripts/python/health_check.py
```

**Variables de entorno relevantes:**

| Variable | Default | Efecto |
|---|---|---|
| `LLAMA_SERVER_URL` | `http://127.0.0.1:8080` | URL del health endpoint de llama-server |
| `CONTAINER_NAME` | `phomber` | Nombre del contenedor a verificar |
| `LLM_PROVIDER` | `openai-compat\|local` | Qué providers incluir en el check |
| `PROVIDER_LLM_API_KEY` | — | Si está definida, el proveedor remoto se marca como configurado |
| `PROVIDER_LLM_BASE_URL` | — | Si está definida, el proveedor remoto se marca como configurado |

**Ejemplo — solo verificar LLM local:**

```bash
LLM_PROVIDER=local uv run --script scripts/python/health_check.py
```

**Proxy en just/make:**
```bash
just compose status   # incluye health_check
just stack status     # incluye health_check
make check-health
```

---

### `download_model.py` — Descargar modelo GGUF

Descarga un modelo GGUF desde Hugging Face Hub con barra de progreso. Si el archivo ya existe, informa el tamaño y no lo sobreescribe.

**Uso:**

```bash
uv run --script scripts/python/download_model.py [opciones]
```

**Argumentos:**

| Argumento | Default | Descripción |
|---|---|---|
| `--repo` | `Qwen/Qwen2-0.5B-Instruct-GGUF` | ID del repositorio en HuggingFace |
| `--file` | `qwen2-0_5b-instruct-q4_k_m.gguf` | Nombre del archivo GGUF a descargar |
| `--dir` | `$HOME/models` | Directorio destino |
| `--token` | `$HF_TOKEN` | Token HuggingFace (opcional, para repos privados) |

**Ejemplos:**

```bash
# Modelo por defecto (Qwen2 0.5B Q4_K_M)
uv run --script scripts/python/download_model.py

# Modelo personalizado
uv run --script scripts/python/download_model.py \
    --repo "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF" \
    --file "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"

# Destino personalizado
uv run --script scripts/python/download_model.py --dir /mnt/modelos

# Con token HuggingFace
HF_TOKEN=hf_xxx uv run --script scripts/python/download_model.py
```

**Proxy en just/make:**
```bash
just setup download-model
just setup download-model "TheBloke/..." "archivo.gguf"
```

---

### `setup_age.py` — Configurar SOPS + age

Genera una keypair age en `~/.age/key.txt`, actualiza `.sops.yaml` con la clave pública y crea `secrets/secrets.enc.yaml` cifrado con una plantilla inicial. Idempotente: no sobreescribe si ya existen.

**Uso:**

```bash
uv run --script scripts/python/setup_age.py
```

**Prerrequisitos:** `age-keygen` y `sops` instalados. El archivo `.sops.yaml` debe existir con el placeholder `PLACEHOLDER_AGE_PUBLIC_KEY`.

**Sin argumentos.** Debe ejecutarse desde la raíz del proyecto.

**Proxy en just/make:**
```bash
just secrets setup
make secrets-setup
```

---

### `edit_secrets.py` — Editar secretos con validación

Flujo completo de edición segura: descifra `secrets/secrets.enc.yaml` a un archivo temporal, abre el editor (`$EDITOR`, default `vim`), valida el YAML contra el schema del proyecto, y re-cifra si pasa la validación. Borra el temporal de forma segura al terminar.

**Uso:**

```bash
SOPS_AGE_KEY_FILE="$HOME/.age/key.txt" \
    uv run --script scripts/python/edit_secrets.py
```

**Variables de entorno:**

| Variable | Default | Descripción |
|---|---|---|
| `SOPS_AGE_KEY_FILE` | `~/.age/key.txt` | Clave privada age para SOPS |
| `EDITOR` | `vim` | Editor a abrir |

**Ejemplo con editor alternativo:**

```bash
EDITOR=nano SOPS_AGE_KEY_FILE="$HOME/.age/key.txt" \
    uv run --script scripts/python/edit_secrets.py
```

**Proxy en just/make:**
```bash
just secrets edit
make secrets-edit
```

---

### `export_secrets.py` — Exportar secretos a `.env`

Lee YAML descifrado desde `stdin` y escribe pares `KEY=value` a `stdout`. Filtra claves internas de SOPS (prefijo `sops`), líneas vacías y comentarios.

**Uso:**

```bash
SOPS_AGE_KEY_FILE="$HOME/.age/key.txt" \
    sops --decrypt secrets/secrets.enc.yaml \
    | python3 scripts/python/export_secrets.py \
    > .env
```

**Sin argumentos.** Lee de `stdin`, escribe a `stdout`.

**Proxy en just/make:**
```bash
just secrets export
make secrets-export
```

---

## Scripts Shell (`scripts/shellscript/`)

Se ejecutan directamente con `bash`. Usan `set -euo pipefail` y leen configuración vía variables de entorno con valores por defecto. Deben ejecutarse desde la **raíz del proyecto**.

```bash
bash scripts/shellscript/<nombre>.sh [argumentos]
```

---

### `secrets_check.sh` — Verificar descifrado de secretos

Verifica que `secrets/secrets.enc.yaml` puede descifrarse con la clave age actual. Sale con código `1` si falla.

**Uso:**

```bash
bash scripts/shellscript/secrets_check.sh
```

**Variables de entorno:** ninguna (usa `$HOME/.age/key.txt` como ruta fija).

**Proxy en just/make:**
```bash
just secrets check
make secrets-check
```

---

### `secrets_pubkey.sh` — Mostrar clave pública age

Muestra la clave pública age registrada en `~/.age/key.txt`. Necesaria para configurar `.sops.yaml` al agregar un nuevo colaborador.

**Uso:**

```bash
bash scripts/shellscript/secrets_pubkey.sh
```

**Proxy en just/make:**
```bash
just secrets pubkey
make secrets-pubkey
```

---

### `secrets_export.sh` — Exportar secretos a `.env`

Combina `sops --decrypt` con `export_secrets.py` y escribe el resultado en `.env`. Equivalente al uso manual de `export_secrets.py` pero en un solo comando.

**Uso:**

```bash
bash scripts/shellscript/secrets_export.sh
```

**Variables de entorno:** ninguna (usa `$HOME/.age/key.txt` como ruta fija).

**Proxy en just/make:**
```bash
just secrets export
```

---

### `env_init.sh` — Inicializar `.env` desde el ejemplo

Copia `.env.example` a `.env` si `.env` no existe. No sobreescribe un `.env` existente.

**Uso:**

```bash
bash scripts/shellscript/env_init.sh
```

**Proxy en just/make:**
```bash
just setup env-init
```

---

### `wait_llama.sh` — Esperar a llama-server

Sondea el endpoint `/health` de llama-server hasta que responde o se agota el timeout. Útil como paso de sincronización en scripts de arranque.

**Uso:**

```bash
bash scripts/shellscript/wait_llama.sh [timeout_segundos]
```

**Argumentos posicionales:**

| Posición | Default | Descripción |
|---|---|---|
| `$1` | `90` | Segundos máximos de espera |

**Variables de entorno:**

| Variable | Default | Descripción |
|---|---|---|
| `LLAMA_PORT` | `8080` | Puerto donde escucha llama-server |

**Ejemplos:**

```bash
# Esperar máximo 90 segundos (default)
bash scripts/shellscript/wait_llama.sh

# Esperar máximo 30 segundos
bash scripts/shellscript/wait_llama.sh 30

# Puerto personalizado
LLAMA_PORT=9090 bash scripts/shellscript/wait_llama.sh 60
```

**Proxy en just/make:**
```bash
just compose wait-llama    # timeout 90s
just stack wait-ready      # timeout 30s
```

---

### `check_model.sh` — Verificar existencia del modelo GGUF

Comprueba que el archivo del modelo exista en el directorio configurado. Sale con código `1` y mensaje de ayuda si no se encuentra.

**Uso:**

```bash
bash scripts/shellscript/check_model.sh
```

**Variables de entorno:**

| Variable | Default | Descripción |
|---|---|---|
| `MODEL_DIR` | `$HOME/models` | Directorio de modelos |
| `MODEL_FILE` | `qwen2-0_5b-instruct-q4_k_m.gguf` | Nombre del archivo GGUF |

**Ejemplo con modelo alternativo:**

```bash
MODEL_DIR=/mnt/modelos MODEL_FILE=tinyllama.gguf \
    bash scripts/shellscript/check_model.sh
```

**Proxy en just/make:**
```bash
just compose up-local   # llama _check-model internamente
```

---

### `llama_clone.sh` — Clonar o actualizar llama.cpp

Si el directorio destino existe, hace `git pull --ff-only`. Si no existe, clona con `--depth 1`.

**Uso:**

```bash
bash scripts/shellscript/llama_clone.sh
```

**Variables de entorno:**

| Variable | Default | Descripción |
|---|---|---|
| `LLAMA_REPO` | `https://github.com/ggml-org/llama.cpp` | URL del repositorio |
| `LLAMA_DIR` | `$HOME/llama.cpp` | Directorio de clonación |

**Proxy en just/make:**
```bash
make clone-llama
```

---

### `llama_start.sh` — Iniciar llama-server en background

Resuelve el binario automáticamente, verifica que el modelo exista, y lanza `llama-server` con `nohup` si el puerto no está ya en uso. Los logs van a `/tmp/llama-server.log`.

**Resolución del binario (por orden de prioridad):**

1. `LLAMA_BIN` definida en entorno y el archivo existe → se usa directamente
2. `llama-server` encontrado en `$PATH` vía `which` → se usa y se informa la ruta
3. `$HOME/llama.cpp/build/bin/llama-server` existe → se usa el build local
4. Ninguno encontrado → error con instrucciones de solución

**Uso:**

```bash
bash scripts/shellscript/llama_start.sh
```

**Variables de entorno:**

| Variable | Default / Descubrimiento | Descripción |
|---|---|---|
| `LLAMA_BIN` | auto-descubierto (ver arriba) | Ruta explícita al binario (opcional) |
| `LLAMA_PORT` | `8080` | Puerto de escucha |
| `MODEL_PATH` | `$HOME/models/qwen2-0_5b-instruct-q4_k_m.gguf` | Ruta completa al modelo |
| `LLAMA_CTX` | `2048` | Tamaño de contexto en tokens |
| `LLAMA_THREADS` | `4` | Hilos de CPU |

**Ejemplos:**

```bash
# Sin configuración — auto-descubre llama-server si está en PATH
bash scripts/shellscript/llama_start.sh

# Forzar binario específico
LLAMA_BIN=/usr/local/bin/llama-server \
    bash scripts/shellscript/llama_start.sh

# Con modelo alternativo y más hilos
MODEL_PATH=$HOME/models/tinyllama.gguf \
LLAMA_PORT=9090 \
LLAMA_THREADS=8 \
    bash scripts/shellscript/llama_start.sh
```

**Proxy en just/make:**
```bash
make start-llama-server
just stack start
```

---

### `llama_stop.sh` — Detener llama-server

Localiza el PID del proceso escuchando en `LLAMA_PORT` y lo termina con `kill`.

**Uso:**

```bash
bash scripts/shellscript/llama_stop.sh
```

**Variables de entorno:**

| Variable | Default | Descripción |
|---|---|---|
| `LLAMA_PORT` | `8080` | Puerto donde está escuchando |

**Proxy en just/make:**
```bash
make stop-llama-server
just stack stop
```

---

### `llama_status.sh` — Estado de llama-server

Informa si hay un proceso escuchando en `LLAMA_PORT`. No hace requests HTTP; solo comprueba el puerto con `lsof`.

**Uso:**

```bash
bash scripts/shellscript/llama_status.sh
```

**Variables de entorno:**

| Variable | Default | Descripción |
|---|---|---|
| `LLAMA_PORT` | `8080` | Puerto a verificar |

**Proxy en just/make:**
```bash
make llama-status
just stack status   # incluye llama_status
```

---

### `check_container.sh` — Estado del contenedor OSINT

Verifica si un contenedor está en estado `running` usando `podman ps`. Informa con color pero no sale con error si el contenedor está inactivo.

**Uso:**

```bash
bash scripts/shellscript/check_container.sh
```

**Variables de entorno:**

| Variable | Default | Descripción |
|---|---|---|
| `CONTAINER_NAME` | `phomber` | Nombre del contenedor a verificar |
| `PODMAN` | `podman` | Binario de Podman (permite apuntar a otra ruta) |

**Ejemplos:**

```bash
# Verificar Sherlock
CONTAINER_NAME=sherlock bash scripts/shellscript/check_container.sh

# Usar binario alternativo
PODMAN=/usr/local/bin/podman bash scripts/shellscript/check_container.sh
```

**Proxy en just/make:**
```bash
make check-container
just osint check
```

---

### `check_api_config.sh` — Mostrar configuración de API keys

Muestra qué proveedor LLM está activo y si `PROVIDER_LLM_API_KEY` y `PROVIDER_LLM_BASE_URL` están presentes en el entorno.

**Uso:**

```bash
bash scripts/shellscript/check_api_config.sh
```

**Variables de entorno leídas (no requeridas):**

| Variable | Descripción |
|---|---|
| `LLM_PROVIDER` | Cadena de proveedores activos (default: `openai-compat\|local`) |
| `PROVIDER_LLM_API_KEY` | Si está definida, el proveedor remoto se marca activo |
| `PROVIDER_LLM_BASE_URL` | Si está definida, el proveedor remoto se marca activo |

**Proxy en just/make:**
```bash
make check-api-config
just setup check-api
```

---

### `start_container.sh` — Arranque completo Pi (legado)

Script de arranque original para Raspberry Pi 4B: construye la imagen si no existe, inicia el contenedor PHOMBER y llama-server, y espera a que el servidor esté listo. Útil como script standalone en sistemas sin `just`/`make`.

**Uso:**

```bash
bash scripts/shellscript/start_container.sh [model_path]
```

**Argumentos posicionales:**

| Posición | Default | Descripción |
|---|---|---|
| `$1` | `$HOME/models/qwen2-0_5b-instruct-q4_k_m.gguf` | Ruta al modelo GGUF |

**Variables de entorno:**

| Variable | Default | Descripción |
|---|---|---|
| `LLAMA_SERVER_BIN` | `$HOME/llama.cpp/llama-server` | Ruta al binario de llama-server |

**Ejemplo:**

```bash
MODEL_PATH=/mnt/modelos/qwen2.gguf \
    bash scripts/shellscript/start_container.sh /mnt/modelos/qwen2.gguf
```

> Este script es el punto de entrada autónomo original del PoC. Para flujos normales de desarrollo usa `just stack start`.

---

## Tabla de equivalencias rápida

| Script directo | Equivalente `just` | Equivalente `make` |
|---|---|---|
| `uv run --script scripts/python/check_deps.py` | — | `make check-deps` |
| `uv run --script scripts/python/health_check.py` | `just compose status` | `make check-health` |
| `uv run --script scripts/python/download_model.py` | `just setup download-model` | — |
| `uv run --script scripts/python/setup_age.py` | `just secrets setup` | `make secrets-setup` |
| `uv run --script scripts/python/edit_secrets.py` | `just secrets edit` | `make secrets-edit` |
| `sops --decrypt … \| python3 scripts/python/export_secrets.py > .env` | `just secrets export` | `make secrets-export` |
| `bash scripts/shellscript/secrets_check.sh` | `just secrets check` | `make secrets-check` |
| `bash scripts/shellscript/secrets_pubkey.sh` | `just secrets pubkey` | `make secrets-pubkey` |
| `bash scripts/shellscript/secrets_export.sh` | `just secrets export` | — |
| `bash scripts/shellscript/env_init.sh` | `just setup env-init` | — |
| `bash scripts/shellscript/wait_llama.sh 90` | `just compose wait-llama` | — |
| `bash scripts/shellscript/wait_llama.sh 30` | `just stack wait-ready` | — |
| `bash scripts/shellscript/check_model.sh` | *(interno de compose)* | — |
| `bash scripts/shellscript/llama_clone.sh` | — | `make clone-llama` |
| `bash scripts/shellscript/llama_start.sh` | `just stack start` | `make start-llama-server` |
| `bash scripts/shellscript/llama_stop.sh` | `just stack stop` | `make stop-llama-server` |
| `bash scripts/shellscript/llama_status.sh` | `just stack status` | `make llama-status` |
| `bash scripts/shellscript/check_container.sh` | `just osint check` | `make check-container` |
| `bash scripts/shellscript/check_api_config.sh` | `just setup check-api` | `make check-api-config` |
| `bash scripts/shellscript/start_container.sh` | `just stack start` | — |
