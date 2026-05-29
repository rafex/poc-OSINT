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

# Proxy transparente a GitFive en el contenedor — OSINT sobre usuarios de GitHub
# Primera vez: just osint gitfive init  (configura el token de GitHub, interactivo)
# Uso: just osint gitfive init                   → configurar token (primera vez)
#      just osint gitfive user <username>         → investigar usuario GitHub
#      just osint gitfive email <email>           → investigar por email
#      just osint gitfive -- --version            → versión instalada
#      just osint gitfive -- --help               → ayuda completa
gitfive *args:
    bash scripts/shellscript/gitfive_proxy.sh {{args}}

# Proxy transparente a NumSpy en el contenedor — detalles de números de teléfono
# Uso: just osint numspy +525512345678  → consultar número
#      just osint numspy -- --version   → versión instalada
numspy *args:
    bash scripts/shellscript/numspy_proxy.sh {{args}}

# Proxy transparente a WhatsMyName en el contenedor — username checker en 600+ sitios
# Uso: just osint whatsmyname usuario                → buscar username
#      just osint whatsmyname usuario --all          → todos los resultados
#      just osint whatsmyname usuario --category social
#      just osint whatsmyname -- --list-categories   → categorías disponibles
#      just osint whatsmyname -- --version           → info datos
whatsmyname *args:
    bash scripts/shellscript/whatsmyname_proxy.sh {{args}}

# Proxy transparente a PhoneInfoga en el contenedor — OSINT avanzado de números
# Uso: just osint phoneinfoga version                      → versión instalada
#      just osint phoneinfoga scan -n +525512345678        → escanear número
#      just osint phoneinfoga scan -n +525512345678 --output json
#      just osint phoneinfoga serve                        → REST API en :5000
#      just osint phoneinfoga -- --help                    → ayuda completa
phoneinfoga *args:
    bash scripts/shellscript/phoneinfoga_proxy.sh {{args}}

# Debug con salida formateada (stdout/stderr/exit code separados, sin LLM)
# Uso: just osint debug               → interactivo
#      just osint debug -- -p +52...  → comando con rich output
debug *args:
    uv run --script scripts/python/phomber_debug.py {{args}}
