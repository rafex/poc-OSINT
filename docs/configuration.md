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
# Solo se intentan los proveedores que tengan su API key configurada.
# El proveedor "local" siempre está disponible como último recurso.
LLM_PROVIDER=groq|deepseek|local
```

Ejemplos válidos:

| Valor | Comportamiento |
|---|---|
| `groq\|deepseek\|local` | Groq → DeepSeek → llama local (default) |
| `groq\|local` | Groq → llama local |
| `deepseek\|local` | DeepSeek → llama local |
| `local` | Solo llama local |
| `groq` | Solo Groq, sin fallback |

### Groq

```bash
# Obtén tu key en https://console.groq.com/keys
GROQ_API_KEY=gsk_...

# Modelos disponibles en Groq:
#   llama-3.1-8b-instant     ← recomendado (rápido, gratuito)
#   llama-3.3-70b-versatile  ← mejor calidad, más lento
#   gemma2-9b-it
GROQ_MODEL=llama-3.1-8b-instant
```

### DeepSeek

```bash
# Obtén tu key en https://platform.deepseek.com/api_keys
DEEPSEEK_API_KEY=sk-...

# Modelos disponibles:
#   deepseek-chat      ← V3, alta calidad, contexto 64k (recomendado)
#   deepseek-reasoner  ← R1, razonamiento profundo, más lento
DEEPSEEK_MODEL=deepseek-chat
```

### llama.cpp local (fallback)

```bash
# URL donde escucha llama-server
# En producción (Pi): http://localhost:8080
# En compose: http://localhost:8080 (puerto expuesto)
LLAMA_SERVER_URL=http://localhost:8080

# Nombre descriptivo del modelo cargado (solo aparece en logs y banner)
LOCAL_MODEL_NAME=qwen2-0.5b-instruct-q4_k_m
```

### Compose y modelos

```bash
# Directorio donde residen los archivos GGUF
MODEL_DIR=$HOME/models

# Nombre del archivo de modelo dentro de MODEL_DIR
MODEL_FILE=qwen2-0_5b-instruct-q4_k_m.gguf

# Puerto expuesto por llama-server en compose
LLAMA_PORT=8080

# Parámetros de inferencia del servidor local
LLAMA_CTX=2048      # tamaño de contexto (tokens)
LLAMA_THREADS=4     # hilos de CPU
```

### Contenedor

```bash
# Nombre del contenedor PHOMBER (debe coincidir con container_name en compose.yaml)
CONTAINER_NAME=phomber
```

### Logging

```bash
# Niveles: DEBUG | INFO | WARNING | ERROR | CRITICAL
# WARNING (default): muestra solo errores y advertencias
# DEBUG: muestra la cadena de proveedores, fallbacks y llamadas completas
LOG_LEVEL=WARNING
```

---

## Verificar la configuración

```bash
# Muestra qué providers y keys están activos
just setup check-api

# O directamente:
make check-api-config
```

Salida de ejemplo:
```
[checks] Configuración LLM_PROVIDER=groq|deepseek|local
  ✓ GROQ_API_KEY     configurada
  ✓ DEEPSEEK_API_KEY configurada
  ✓ local            siempre disponible (llama-server)
```

---

## Comportamiento de la cadena de proveedores

La lógica de fallback es **transparente al usuario**. El resultado final siempre
llega, pero el camino recorrido queda en los logs.

### Errores que avanzan al siguiente proveedor

| Error | Ejemplo | Acción |
|---|---|---|
| `AuthenticationError` | Key inválida o revocada | Log WARNING → siguiente |
| `APIConnectionError` | Sin conectividad | Log WARNING → siguiente |
| `APITimeoutError` | Respuesta tardó demasiado | Log WARNING → siguiente |
| `RateLimitError` | Cuota agotada | Log WARNING → siguiente |
| `APIStatusError` 5xx | Error del servidor | Log WARNING → siguiente |

### Errores que detienen la cadena

| Error | Ejemplo | Acción |
|---|---|---|
| `APIStatusError` 4xx | Prompt inválido | Log ERROR + retorna mensaje de error |

### Ver el camino recorrido

```bash
LOG_LEVEL=DEBUG just q "+52 55 1234 5678" 2>&1 | grep '\[INFO\]\|\[WARNING\]\|\[ERROR\]'
```

Ejemplo de salida con Groq caído:
```
12:34:56 [INFO    ] orchestrator.llm_client — Cadena de proveedores: groq → deepseek → local
12:34:56 [INFO    ] orchestrator.llm_client — Intentando proveedor: groq  modelo=llama-3.1-8b-instant
12:34:57 [WARNING ] orchestrator.llm_client — Proveedor 'groq': conexión fallida. Continuando cadena.
12:34:57 [INFO    ] orchestrator.llm_client — Intentando proveedor: deepseek  modelo=deepseek-chat
12:34:59 [INFO    ] orchestrator.llm_client — Proveedor 'deepseek' respondió correctamente.
```

---

## Ejemplo de `.env` mínimo funcional

Solo con Groq (configuración más simple para empezar):

```bash
LLM_PROVIDER=groq|local
GROQ_API_KEY=gsk_TU_KEY_AQUI
GROQ_MODEL=llama-3.1-8b-instant
LLAMA_SERVER_URL=http://localhost:8080
CONTAINER_NAME=phomber
LOG_LEVEL=WARNING
```

## Ejemplo de `.env` completo

```bash
LLM_PROVIDER=groq|deepseek|local

GROQ_API_KEY=gsk_...
GROQ_MODEL=llama-3.1-8b-instant

DEEPSEEK_API_KEY=sk-...
DEEPSEEK_MODEL=deepseek-chat

LLAMA_SERVER_URL=http://localhost:8080
LOCAL_MODEL_NAME=qwen2-0.5b-instruct-q4_k_m

MODEL_DIR=$HOME/models
MODEL_FILE=qwen2-0_5b-instruct-q4_k_m.gguf
LLAMA_PORT=8080
LLAMA_CTX=2048
LLAMA_THREADS=4

CONTAINER_NAME=phomber
LOG_LEVEL=WARNING
```
