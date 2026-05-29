# Validación local con Podman Compose

Antes de desplegar en la Raspberry Pi, valida el stack completo en tu máquina
de desarrollo usando Podman Compose. El orquestador corre en el host; Compose
gestiona solo la infraestructura (PHOMBER y opcionalmente llama-server).

```
HOST (tu Mac)
  │
  ├─ Orquestador Python     ← corre con uv run, accede al contenedor via podman exec
  │
  └─ Podman Compose
       ├─ phomber            ← siempre activo
       └─ llama-server       ← solo con --profile local-llm
```

---

## Prerrequisitos

- Instalación completa según [installation.md](installation.md)
- `.env` configurado con al menos una API key (ver [configuration.md](configuration.md))
- `podman machine` en ejecución (macOS):
  ```bash
  podman machine start
  ```

---

## Opción A — Con proveedor remoto (openai-compat)

La forma más rápida de validar. No necesita modelo local.
Configura `PROVIDER_LLM_BASE_URL`, `PROVIDER_LLM_API_KEY` y `PROVIDER_LLM_MODEL` en `.env`.

### Paso 1 — Construir la imagen de PHOMBER

```bash
just compose build
```

Primera ejecución: ~2–3 min (clona PHOMBER, instala dependencias).

### Paso 2 — Levantar el stack

```bash
just compose up
```

Salida esperada:
```
[compose] Iniciando stack (perfil: api remota)…
[compose] phomber activo. Listo para: just osint query <número>

Stack listo. Prueba con: just q "+52 55 1234 5678"
```

### Paso 3 — Verificar salud

```bash
just compose status
```

Salida esperada:
```
CONTAINER ID  IMAGE                    ...  STATUS
phomber       localhost/phomber:latest  ...  Up 30 seconds

Health Check — edge-osint-lab  [LLM_PROVIDER=openai-compat|local]
┌──────────────────┬───────────────────────────┬───────┬──────────────────────────────────────┐
│ Componente       │ Descripción               │ Estado│ Detalle                              │
├──────────────────┼───────────────────────────┼───────┼──────────────────────────────────────┤
│ Podman container │ PHOMBER activo            │ ✓ OK  │ en ejecución                         │
│ PHOMBER exec     │ Python alcanzable         │ ✓ OK  │ Python 3.11.x                        │
│ openai-compat    │ API key + base URL pres.  │ ✓ OK  │ key=gsk_xx…1234  url=https://api...  │
└──────────────────┴───────────────────────────┴───────┴──────────────────────────────────────┘

Cadena LLM efectiva: openai-compat → local
```

### Paso 4 — Ejecutar una consulta

```bash
just q "+52 55 1234 5678"
```

Ver [usage.md](usage.md) para ejemplos de salida y más comandos.

---

## Opción B — Con llama-server local (sin APIs externas)

Requiere el modelo GGUF descargado y compilar llama-server en un contenedor.

### Paso 1 — Descargar el modelo

```bash
just setup download-model
```

Descarga `qwen2-0_5b-instruct-q4_k_m.gguf` (~330 MB) en `$HOME/models/`.

Para un modelo diferente:
```bash
just setup download-model "Qwen/Qwen2-0.5B-Instruct-GGUF" "qwen2-0_5b-instruct-q4_k_m.gguf"
```

### Paso 2 — Construir la imagen de llama-server

```bash
just compose build-llama
```

> **Esto tarda.** Compila llama.cpp desde fuente dentro del contenedor.
> Primera ejecución: 10–25 min según la CPU. Las siguientes son instantáneas
> (imagen cacheada).

### Paso 3 — Levantar el stack completo

```bash
just compose up-local
```

El comando verifica que el modelo exista, levanta ambos servicios y espera
(hasta 90 s) a que llama-server esté listo.

Salida esperada:
```
Modelo OK: /Users/tu_usuario/models/qwen2-0_5b-instruct-q4_k_m.gguf
[compose] Iniciando stack completo (perfil: local-llm)…
Esperando que llama-server esté listo...
llama-server listo en :8080

Stack local listo. Prueba con: LLM_PROVIDER=local just q "+52 55 1234 5678"
```

### Paso 4 — Forzar uso del LLM local

```bash
LLM_PROVIDER=local just q "+52 55 1234 5678"
```

---

## Ciclo de trabajo habitual

```bash
# Mañana: levantar
just compose up          # o up-local

# Trabajar...
just q "+34 91 000 0000"
just osint interactive

# Ver logs si algo falla
just compose logs
just compose logs-service phomber
just compose logs-service llama-server

# Verificar salud en cualquier momento
just compose status

# Al terminar: bajar
just compose down
```

---

## Comandos de compose disponibles

| Comando | Descripción |
|---|---|
| `just compose build` | Construye imagen PHOMBER |
| `just compose build-llama` | Construye imagen llama-server (lento) |
| `just compose up` | Levanta PHOMBER (APIs remotas) |
| `just compose up-local` | Levanta PHOMBER + llama-server |
| `just compose stop` | Detiene servicios (mantiene imágenes) |
| `just compose down` | Detiene y elimina contenedores |
| `just compose restart` | Reinicia el stack |
| `just compose status` | Estado de servicios + health check |
| `just compose logs` | Logs en tiempo real (todos los servicios) |
| `just compose logs-service phomber` | Logs de un servicio específico |
| `just compose shell` | Shell interactivo en PHOMBER |
| `just compose clean` | Elimina contenedores e imágenes |

---

## Problemas frecuentes

### `Error: container phomber does not exist`

El contenedor no está corriendo. Levántalo:
```bash
just compose up
```

### `podman machine` no está iniciada (macOS)

```bash
podman machine start
# Espera ~30 s y reintenta
```

### llama-server no responde en 90 s

```bash
# Ver qué está pasando
just compose logs-service llama-server

# Causas comunes:
# - El modelo GGUF no existe en MODEL_DIR
# - Poca RAM (el modelo Qwen2 0.5B necesita ~500 MB)
# - La imagen aún está compilando (primera vez)
```

### Proveedor remoto no disponible

Verifica que `.env` tiene las variables del proveedor:
```bash
cat .env | grep PROVIDER_LLM
just setup check-api
```

El archivo `.env` debe estar en la raíz del proyecto, no en `docs/`.
