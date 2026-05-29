# Instalación

Esta guía cubre la instalación en una máquina de desarrollo (macOS o Linux x86_64/ARM64).
Para despliegue en Raspberry Pi 4B consulta [raspberry-pi.md](raspberry-pi.md).

---

## Prerrequisitos

### Herramientas obligatorias

| Herramienta | Versión mínima | Instalación |
|---|---|---|
| `git` | 2.x | Sistema operativo |
| `make` | 3.81 | `brew install make` / `apt install make` |
| `just` | 1.19.0 | Ver abajo |
| `uv` | 0.4.x | Ver abajo |
| `podman` | 4.x | Ver abajo |
| Python | 3.11 | Gestionado por uv (no requiere instalación manual) |

### Herramientas opcionales (solo si usas LLM local)

| Herramienta | Uso |
|---|---|
| `cmake` | Compilar llama.cpp |
| `curl` | Health checks |
| `lsof` | Verificar puertos |

---

## Instalación de herramientas

### uv

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Verifica:
```bash
uv --version
# uv 0.4.x
```

### just

```bash
# macOS
brew install just

# Linux (cualquier distro)
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin
```

Verifica que sea >= 1.19.0 (requerido para soporte `mod`):
```bash
just --version
# just 1.x.x
```

### Podman

```bash
# macOS
brew install podman
podman machine init
podman machine start

# Debian/Ubuntu
sudo apt-get install -y podman

# Fedora/RHEL
sudo dnf install -y podman
```

Verifica:
```bash
podman --version
# podman version 4.x.x
```

> **macOS:** Podman usa una máquina virtual Linux interna.
> Los comandos `podman exec` y `podman compose` funcionan de forma transparente
> desde la terminal del host.

---

## Clonar el repositorio

```bash
git clone https://github.com/rafex/poc-OSINT
cd poc-OSINT
```

---

## Instalar dependencias Python

```bash
# Dependencias de producción
make install

# O con herramientas de desarrollo (ruff, mypy, pytest)
make install-dev
```

uv crea automáticamente un entorno virtual en `.venv/` y genera `uv.lock`.

Verifica:
```bash
uv run python --version
# Python 3.11.x
```

---

## Configurar variables de entorno

```bash
# Copia la plantilla
just setup env-init

# Edita el archivo con tus claves de API
# (mínimo: PROVIDER_LLM_BASE_URL + PROVIDER_LLM_API_KEY para funcionar sin modelo local)
$EDITOR .env
```

Para obtener claves:
- **Groq:** [console.groq.com/keys](https://console.groq.com/keys) — tier gratuito disponible
- **DeepSeek:** [platform.deepseek.com/api_keys](https://platform.deepseek.com/api_keys) — muy económico

Ver [configuration.md](configuration.md) para detalle de todas las variables.

---

## Verificar la instalación

```bash
# Verifica que todas las herramientas del sistema estén disponibles
make check-deps
```

Salida esperada:
```
┌───────────────────────────────────────────────────────────────┐
│ Verificación de dependencias — edge-osint-lab                 │
├──────────────┬─────────────────────┬──────────┬──────────────┤
│ Herramienta  │ Descripción         │ Estado   │ Versión      │
├──────────────┼─────────────────────┼──────────┼──────────────┤
│ uv           │ Gestor de paquetes  │ ✓ OK     │ uv 0.4.x     │
│ podman       │ Contenedores        │ ✓ OK     │ podman 4.x.x │
│ make         │ Build system        │ ✓ OK     │ GNU Make 4.x │
│ just         │ Task runner         │ ✓ OK     │ just 1.x.x   │
│ git          │ Control versiones   │ ✓ OK     │ git version  │
│ curl         │ HTTP client         │ ✓ OK     │ curl 8.x.x   │
└──────────────┴─────────────────────┴──────────┴──────────────┘
Todas las herramientas requeridas están disponibles.
```

---

## Construir la imagen de PHOMBER

```bash
make build-image
```

Este comando clona PHOMBER desde GitHub dentro de la imagen y la construye.
La primera vez tarda ~2–3 minutos según la velocidad de red.

Verifica:
```bash
podman images | grep phomber
# localhost/phomber   latest   ...
```

---

## Siguiente paso

Con la instalación completa:

- **Validar localmente** (recomendado antes de ir a la Pi): [local-validation.md](local-validation.md)
- **Desplegar en Raspberry Pi:** [raspberry-pi.md](raspberry-pi.md)
- **Empezar a usar directamente:** [usage.md](usage.md)
