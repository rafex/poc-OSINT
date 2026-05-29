#!/usr/bin/env bash
# Proxy transparente a Sherlock en el contenedor.
#
# Sin argumentos  → muestra la ayuda de Sherlock
# Con argumentos  → ejecuta el comando y devuelve la salida tal cual
#
# Uso:
#   bash scripts/shellscript/sherlock_proxy.sh                        # ayuda
#   bash scripts/shellscript/sherlock_proxy.sh usuario                # buscar username
#   bash scripts/shellscript/sherlock_proxy.sh user1 user2 user3      # varios usernames
#   bash scripts/shellscript/sherlock_proxy.sh --print-all usuario    # todos los sitios
#   bash scripts/shellscript/sherlock_proxy.sh --timeout 10 usuario   # timeout custom
#   bash scripts/shellscript/sherlock_proxy.sh --version              # versión
#   bash scripts/shellscript/sherlock_proxy.sh --help                 # ayuda completa

CONTAINER="${SHERLOCK_CONTAINER:-sherlock}"

if ! podman ps \
        --filter "name=${CONTAINER}" \
        --filter "status=running" \
        --format "{{.Names}}" 2>/dev/null \
        | grep -q "^${CONTAINER}$"; then
    printf '\033[31m[sherlock]\033[0m El contenedor "%s" no está corriendo.\n' "${CONTAINER}" >&2
    printf '  Inicia el stack con: just up  o  just compose up\n' >&2
    exit 1
fi

if [ $# -eq 0 ]; then
    exec podman exec "${CONTAINER}" sherlock --help
else
    exec podman exec "${CONTAINER}" sherlock "$@"
fi
