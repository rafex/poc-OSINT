#!/usr/bin/env bash
# Proxy transparente a PhoneInfoga en el contenedor.
#
# Sin argumentos  → muestra la ayuda de phoneinfoga
# Con argumentos  → ejecuta el comando y devuelve la salida tal cual
#
# Uso:
#   bash scripts/shellscript/phoneinfoga_proxy.sh                         # ayuda
#   bash scripts/shellscript/phoneinfoga_proxy.sh version                 # versión instalada
#   bash scripts/shellscript/phoneinfoga_proxy.sh scan -n +525512345678   # escanear número
#   bash scripts/shellscript/phoneinfoga_proxy.sh scan -n +525512345678 --output json
#   bash scripts/shellscript/phoneinfoga_proxy.sh serve                   # REST API en :5000

CONTAINER="${PHONEINFOGA_CONTAINER:-phoneinfoga}"

if ! podman ps \
        --filter "name=${CONTAINER}" \
        --filter "status=running" \
        --format "{{.Names}}" 2>/dev/null \
        | grep -q "^${CONTAINER}$"; then
    printf '\033[31m[phoneinfoga]\033[0m El contenedor "%s" no está corriendo.\n' "${CONTAINER}" >&2
    printf '  Inicia con: just compose up\n' >&2
    exit 1
fi

if [ $# -eq 0 ]; then
    exec podman exec "${CONTAINER}" phoneinfoga --help
else
    exec podman exec "${CONTAINER}" phoneinfoga "$@"
fi
