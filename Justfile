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
mod setup   'just/setup.just'
mod dev     'just/dev.just'
mod stack   'just/stack.just'
mod osint   'just/osint.just'
mod compose 'just/compose.just'

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
