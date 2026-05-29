set working-directory := "../.."

# osint.just — ejecución de consultas OSINT
# Llamado con: just osint <recipe>
#
# Requiere stack activo: just stack start

# Ejecuta una consulta OSINT con número de teléfono
# Uso: just osint query "+52 55 1234 5678"
query phone:
    uv --directory orchestrator run -m orchestrator.main "{{phone}}"

# Modo interactivo: el orquestador pide la query
interactive:
    uv --directory orchestrator run -m orchestrator.main

# Verifica la conexión con el contenedor PHOMBER antes de consultar
check:
    make check-container
    make check-health

# Ejecuta PHOMBER directamente (sin interpretación del SLM)
# Uso: just osint raw "-p +525512345678"
raw args:
    podman exec phomber phomber -s {{args}}

# Debug interactivo de PHOMBER: muestra stdout/stderr/exit code sin LLM
# Uso: just osint debug               → modo interactivo (bucle)
#      just osint debug "+52 55 ..."  → número directo
#      just osint debug -- --help     → ayuda de PHOMBER
debug *args:
    uv run --script scripts/python/phomber_debug.py {{args}}
