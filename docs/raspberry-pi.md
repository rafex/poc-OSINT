# Despliegue en Raspberry Pi 4B

Esta guía cubre el despliegue completo del stack en una Raspberry Pi 4B,
desde el sistema operativo hasta la primera consulta OSINT.

---

## Hardware recomendado

| Componente | Mínimo | Recomendado |
|---|---|---|
| RAM | 4 GB | **8 GB** |
| Almacenamiento | microSD 32 GB | **SSD USB 3.0 128 GB+** |
| Refrigeración | Pasiva | **Activa (ventilador)** |
| Alimentación | 3 A | **3.5 A (cargador oficial)** |

> **SSD USB 3.0:** El modelo GGUF ocupa ~330 MB y llama-server escribe archivos
> temporales. Una microSD de clase 10 funciona pero es notablemente más lenta.
> Un SSD mejora los tiempos de carga del modelo de ~30 s a ~5 s.

---

## Sistema operativo

### Opción A — Raspberry Pi OS Lite (recomendado)

Sin escritorio, mínimo consumo de RAM. Usa **Raspberry Pi Imager**:

1. Descarga [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. Selecciona: **Raspberry Pi OS Lite (64-bit)**
3. En configuración avanzada: habilita SSH, configura Wi-Fi y usuario
4. Graba en la microSD/SSD

### Opción B — Debian Bookworm (arm64)

Alternativa si prefieres Debian puro. Ambas son compatibles con esta guía.

---

## Preparación del sistema operativo

Conéctate por SSH a la Pi y actualiza:

```bash
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y \
    git \
    curl \
    wget \
    make \
    cmake \
    build-essential \
    ca-certificates \
    lsof
```

### Instalar uv

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env
```

### Instalar just

```bash
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh \
    | bash -s -- --to /usr/local/bin
```

### Instalar Podman

```bash
sudo apt-get install -y podman
```

Verifica que Podman funciona en modo rootless:
```bash
podman run --rm hello-world
```

---

## Clonar el proyecto

```bash
git clone https://github.com/rafex/poc-OSINT
cd poc-OSINT
```

---

## Configuración

```bash
just setup env-init
nano .env    # o vim, emacs
```

Rellena como mínimo `PROVIDER_LLM_BASE_URL` + `PROVIDER_LLM_API_KEY` para usar un proveedor remoto, o deja `LLM_PROVIDER=local` para modo sin internet.
Para uso completamente offline, puedes dejar las claves vacías y usar solo `LLM_PROVIDER=local`.

Ver [configuration.md](configuration.md) para el detalle completo.

---

## Setup automático completo

```bash
just bootstrap
```

Este comando ejecuta en secuencia:

```
just setup raspi
  ├── make install          → instala dependencias Python con uv
  ├── make build-image      → construye imagen PHOMBER (~5 min en Pi)
  ├── make build-llama      → compila llama.cpp (~30–60 min en Pi 4B)
  └── just setup download-model → descarga Qwen2 0.5B Q4_K_M (~330 MB)
```

> **Paciencia:** La compilación de llama.cpp en la Pi 4B tarda entre 30 y 60
> minutos la primera vez. Solo ocurre una vez; las siguientes son instantáneas.

Monitorea el progreso:
```bash
# En otra terminal SSH
watch -n5 "ps aux | grep cmake"
```

---

## Setup manual paso a paso

Si prefieres controlar cada etapa:

### 1. Instalar dependencias Python

```bash
make install
```

### 2. Construir imagen PHOMBER

```bash
make build-image
```

### 3. Compilar llama.cpp (nativo ARM64)

La compilación nativa con `GGML_NATIVE=ON` genera un binario optimizado
para el procesador Cortex-A72 de la Pi 4B:

```bash
make clone-llama    # clona el repositorio
make build-llama    # compila (tarda 30–60 min)
```

Resultado: binario en `$HOME/llama.cpp/build/bin/llama-server`.

### 4. Descargar el modelo

```bash
just setup download-model
```

Descarga `qwen2-0_5b-instruct-q4_k_m.gguf` en `$HOME/models/`.

Para modelos alternativos:

| Modelo | Tamaño | RAM necesaria | Calidad |
|---|---|---|---|
| Qwen2 0.5B Q4_K_M | ~330 MB | ~500 MB | Básica |
| TinyLlama 1.1B Q4_K_M | ~600 MB | ~900 MB | Media |
| Gemma 2B Q4_K_M | ~1.4 GB | ~2 GB | Buena |

```bash
# Ejemplo con TinyLlama
just setup download-model "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF" "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
```

---

## Arrancar el stack

```bash
just up
```

Equivale a `just stack start`. Inicia el contenedor PHOMBER y llama-server,
y espera a que llama-server esté listo.

Salida esperada:
```
=== Iniciando stack edge-osint-lab ===
[container] Iniciando phomber…
[llama] Iniciando llama-server en 127.0.0.1:8080…
Esperando llama-server...
llama-server listo.
=== Stack listo. Usa: just osint query <número> ===
```

---

## Primera consulta

```bash
just q "+52 55 1234 5678"
```

---

## Gestión del stack en producción

```bash
# Ver estado
just status

# Detener
just down

# Reiniciar con modelo diferente
just stack restart "$HOME/models/otro-modelo.gguf"

# Ver logs del contenedor
just stack logs

# Ver logs de llama-server
just dev logs-llama
```

---

## Autoarranque al iniciar la Pi

Para que el stack se levante automáticamente al reiniciar:

```bash
# Crear servicio systemd del usuario
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/edge-osint-lab.service << 'EOF'
[Unit]
Description=edge-osint-lab stack
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=%h/poc-OSINT
ExecStart=/usr/local/bin/just up
ExecStop=/usr/local/bin/just down
Environment="PATH=/usr/local/bin:/usr/bin:/bin:%h/.local/bin"

[Install]
WantedBy=default.target
EOF

# Habilitar
systemctl --user daemon-reload
systemctl --user enable edge-osint-lab.service
loginctl enable-linger $USER
```

---

## Rendimiento esperado en Pi 4B

Con Qwen2 0.5B Q4_K_M compilado con `NATIVE=ON`:

| Operación | Tiempo aproximado |
|---|---|
| Arranque del contenedor PHOMBER | ~2 s |
| Carga del modelo en llama-server | ~5–10 s (SSD) / ~25 s (microSD) |
| Consulta PHOMBER | ~3–8 s |
| Inferencia LLM (Groq) | ~1–3 s |
| Inferencia LLM (DeepSeek) | ~3–8 s |
| Inferencia LLM local (Qwen2 0.5B) | ~15–40 s |
| Tiempo total (cadena Groq→local) | ~10–20 s |

> La inferencia local es más lenta pero el sistema funciona **sin internet**.

---

## Solución de problemas en Pi

### `make build-llama` falla por falta de memoria

```bash
# Reducir paralelismo
cmake --build $HOME/llama.cpp/build --parallel 1
```

### llama-server consume demasiada RAM

Reduce el contexto en `.env`:
```bash
LLAMA_CTX=1024   # default 2048
```

### Contenedor no arranca: `no space left on device`

```bash
# Limpiar imágenes no usadas
podman system prune -f
```

### Podman no tiene permisos rootless

```bash
# Verificar subuid/subgid
grep $USER /etc/subuid /etc/subgid

# Si no están configurados
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER
podman system migrate
```
