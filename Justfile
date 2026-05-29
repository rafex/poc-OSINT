# edge-osint-lab — Justfile principal
# Requiere: just >= 1.19.0 (soporte mod)
#
# Regla de oro: just puede llamar a make. Make NO llama a just.
#
# Módulos disponibles:
#   just setup   <recipe>  — preparación del entorno
#   just dev     <recipe>  — flujo de trabajo de desarrollo
#   just stack   <recipe>  — ciclo de vida del stack (producción / Pi)
#   just osint   <recipe>  — ejecución de consultas OSINT
#   just compose <recipe>  — gestión del stack vía Podman Compose (validación local)

set shell := ["bash", "-euo", "pipefail", "-c"]
set dotenv-load := true

# ── Módulos ───────────────────────────────────────────────────────────────────
mod setup   'scripts/just/setup.just'
mod dev     'scripts/just/dev.just'
mod stack   'scripts/just/stack.just'
mod osint   'scripts/just/osint.just'
mod compose 'scripts/just/compose.just'
mod secrets 'scripts/just/secrets.just'

# ── Receta por defecto: muestra ayuda ─────────────────────────────────────────
default:
    @just --list --unsorted

# ── Atajos de alto nivel ──────────────────────────────────────────────────────

# Onboarding completo en Raspberry Pi (una sola vez)
bootstrap:
    just setup raspi

# Inicia el stack con configuración por defecto
up:
    just stack start

# Detiene todo
down:
    just stack stop

# Ejecuta una consulta rápida
# Uso: just q "+52 55 1234 5678"
q phone:
    just osint query "{{phone}}"

# Verifica el estado completo del sistema
status:
    just stack status

# Ejecuta CI completo de calidad de código
ci:
    just dev ci

# Configura .env de forma interactiva (detecta hardware y modelos)
wizard:
    just setup env-wizard

# Proxy directo a PHOMBER en el contenedor (sin LLM, sin filtros)
# Uso: just phomber                  → sesión interactiva
#      just phomber -- -p +52551234  → consulta directa
#      just phomber -- --help        → ayuda de PHOMBER
phomber *args:
    bash scripts/shellscript/phomber_proxy.sh {{args}}

# Proxy directo a Sherlock en el contenedor (sin LLM, sin filtros)
# Uso: just sherlock usuario                → buscar username
#      just sherlock -- --print-all user    → todos los sitios
#      just sherlock -- --help              → ayuda de Sherlock
sherlock *args:
    bash scripts/shellscript/sherlock_proxy.sh {{args}}

# Proxy directo a GitFive en el contenedor — OSINT de GitHub
# Primera vez: just gitfive init  (configura el token de GitHub)
# Uso: just gitfive init                  → configurar token (interactivo)
#      just gitfive user <username>        → investigar usuario GitHub
#      just gitfive email <email>          → investigar por email
#      just gitfive -- --help              → ayuda de GitFive
gitfive *args:
    bash scripts/shellscript/gitfive_proxy.sh {{args}}

# Proxy directo a NumSpy — detalles de números de teléfono
# Uso: just numspy +525512345678     → consultar número
#      just numspy -- --version      → versión instalada
numspy *args:
    bash scripts/shellscript/numspy_proxy.sh {{args}}

# Proxy directo a WhatsMyName — username checker en 600+ sitios
# Uso: just whatsmyname usuario             → buscar username
#      just whatsmyname usuario --all       → todos los sitios
#      just whatsmyname -- --list-categories
whatsmyname *args:
    bash scripts/shellscript/whatsmyname_proxy.sh {{args}}
