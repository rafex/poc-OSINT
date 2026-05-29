# Configuración

Toda la configuración se gestiona mediante variables de entorno en el archivo `.env`,
que Justfile carga automáticamente (`set dotenv-load := true`).

---

## Crear el archivo `.env`

```bash
just setup env-init
```

Esto copia `.env.example` a `.env` si no existe. El archivo `.env` **nunca se sube
al repositorio** (está en `.gitignore`).

---

## Variables de entorno

### Cadena de proveedores LLM

```bash
# Orden de prioridad separado por pipes.
# Valores válidos: openai-compat, local
LLM_PROVIDER=openai-compat|local
```

| Valor | Comportamiento |
|---|---|
| `openai-compat\|local` | Proveedor remoto → llama local (default) |
| `local` | Solo llama local, sin APIs externas |
| `openai-compat` | Solo remoto, sin fallback |

---

### Proveedor remoto — `openai-compat`

Cualquier API que implemente el protocolo OpenAI funciona aquí: Groq, DeepSeek,
OpenRouter, Together AI, Ollama remoto, etc.

```bash
# URL base del API (incluye la versión)
PROVIDER_LLM_BASE_URL=https://api.groq.com/openai/v1

# API key del proveedor
PROVIDER_LLM_API_KEY=tu_key_aqui

# Modelo a usar
PROVIDER_LLM_MODEL=llama-3.1-8b-instant
```

**URLs de referencia por proveedor:**

| Proveedor | `PROVIDER_LLM_BASE_URL` | Obtener key |
|---|---|---|
| Groq | `https://api.groq.com/openai/v1` | [console.groq.com/keys](https://console.groq.com/keys) |
| DeepSeek | `https://api.deepseek.com/v1` | [platform.deepseek.com/api_keys](https://platform.deepseek.com/api_keys) |
| OpenRouter | `https://openrouter.ai/api/v1` | [openrouter.ai/keys](https://openrouter.ai/keys) |
| Ollama (local expuesto) | `http://host:11434/v1` | — (sin key, usa `ollama` como placeholder) |

El proveedor `openai-compat` se **omite automáticamente** de la cadena si
`PROVIDER_LLM_API_KEY` o `PROVIDER_LLM_BASE_URL` no están definidas.

---

### llama.cpp local — `local`

```bash
# URL donde escucha llama-server
LLAMA_SERVER_URL=http://localhost:8080

# Nombre descriptivo del modelo cargado (solo aparece en logs y banner)
LOCAL_MODEL_NAME=qwen2-0.5b-instruct-q4_k_m
```

El proveedor `local` **no requiere API key** y siempre está disponible como
último recurso en la cadena.

---

### Compose y modelos

```bash
MODEL_DIR=$HOME/models
MODEL_FILE=qwen2-0_5b-instruct-q4_k_m.gguf
LLAMA_PORT=8080
LLAMA_CTX=2048      # tamaño de contexto (tokens)
LLAMA_THREADS=4     # hilos de CPU — ajusta al número de cores físicos
```

---

### Contenedor

```bash
CONTAINER_NAME=phomber
```

### Logging

```bash
# DEBUG | INFO | WARNING | ERROR | CRITICAL
LOG_LEVEL=WARNING
```

---

## Verificar la configuración

```bash
just setup check-api
# o directamente:
make check-api-config
```

Salida de ejemplo:

```
[checks] Configuración LLM_PROVIDER=openai-compat|local
  ✓ openai-compat    API key configurada → https://api.groq.com/openai/v1
  ✓ local            siempre disponible (llama-server)
```

---

## Comportamiento de la cadena de proveedores

La lógica de fallback es **transparente al usuario**. El resultado siempre llega,
pero el camino recorrido queda en los logs.

### Errores que avanzan al siguiente proveedor

| Error | Ejemplo | Acción |
|---|---|---|
| `AuthenticationError` | Key inválida o revocada | Log WARNING → siguiente |
| `APIConnectionError` | Sin conectividad | Log WARNING → siguiente |
| `APITimeoutError` | Respuesta tardó demasiado | Log WARNING → siguiente |
| `RateLimitError` | Cuota agotada | Log WARNING → siguiente |
| `APIStatusError` 5xx | Error del servidor | Log WARNING → siguiente |

### Errores que detienen la cadena

| Error | Acción |
|---|---|
| `APIStatusError` 4xx (no auth/rate) | Log ERROR + retorna mensaje de error |

### Ver el camino recorrido

```bash
LOG_LEVEL=DEBUG just q "+52 55 1234 5678" 2>&1
```

---

## Ejemplos de `.env`

### Mínimo — solo local (sin internet)

```bash
LLM_PROVIDER=local
LLAMA_SERVER_URL=http://localhost:8080
LOCAL_MODEL_NAME=qwen2-0.5b-instruct-q4_k_m
CONTAINER_NAME=phomber
LOG_LEVEL=WARNING
```

### Con Groq como proveedor remoto

```bash
LLM_PROVIDER=openai-compat|local
PROVIDER_LLM_BASE_URL=https://api.groq.com/openai/v1
PROVIDER_LLM_API_KEY=gsk_...
PROVIDER_LLM_MODEL=llama-3.1-8b-instant
LLAMA_SERVER_URL=http://localhost:8080
LOCAL_MODEL_NAME=qwen2-0.5b-instruct-q4_k_m
CONTAINER_NAME=phomber
LOG_LEVEL=WARNING
```

### Con DeepSeek como proveedor remoto

```bash
LLM_PROVIDER=openai-compat|local
PROVIDER_LLM_BASE_URL=https://api.deepseek.com/v1
PROVIDER_LLM_API_KEY=sk-...
PROVIDER_LLM_MODEL=deepseek-chat
LLAMA_SERVER_URL=http://localhost:8080
LOCAL_MODEL_NAME=qwen2-0.5b-instruct-q4_k_m
CONTAINER_NAME=phomber
LOG_LEVEL=WARNING
```
