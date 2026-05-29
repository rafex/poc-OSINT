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

# Proxy transparente a PHOMBER en el contenedor — cualquier comando, sin filtros
# Uso: just osint phomber                  → sesión interactiva con menú de PHOMBER
#      just osint phomber -- -p +52551234  → consulta directa
#      just osint phomber -- --help        → ayuda de PHOMBER
#      just osint phomber -- -v            → versión
phomber *args:
    bash scripts/shellscript/phomber_proxy.sh {{args}}

# Proxy transparente a Sherlock en el contenedor — cualquier comando, sin filtros
# Uso: just osint sherlock                        → ayuda de Sherlock
#      just osint sherlock usuario                → buscar un username
#      just osint sherlock user1 user2            → varios usernames
#      just osint sherlock -- --print-all usuario → todos los sitios (encontrados y no)
#      just osint sherlock -- --timeout 10 user   → timeout personalizado
#      just osint sherlock -- --version           → versión instalada
sherlock *args:
    bash scripts/shellscript/sherlock_proxy.sh {{args}}

# Debug con salida formateada (stdout/stderr/exit code separados, sin LLM)
# Uso: just osint debug               → interactivo
#      just osint debug -- -p +52...  → comando con rich output
debug *args:
    uv run --script scripts/python/phomber_debug.py {{args}}
