set working-directory := ".."

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
# Útil para depurar la salida raw
# Uso: just osint raw "-p +525512345678"
raw args:
    podman exec phomber phomber -s {{args}}
