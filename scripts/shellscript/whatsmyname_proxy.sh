#!/usr/bin/env bash
# Proxy transparente a WhatsMyName en el contenedor.
#
# Uso:
#   bash scripts/shellscript/whatsmyname_proxy.sh                       # ayuda
#   bash scripts/shellscript/whatsmyname_proxy.sh usuario               # buscar username
#   bash scripts/shellscript/whatsmyname_proxy.sh usuario --all         # todos los sitios
#   bash scripts/shellscript/whatsmyname_proxy.sh usuario --category social
#   bash scripts/shellscript/whatsmyname_proxy.sh --list-categories     # categorías disponibles
#   bash scripts/shellscript/whatsmyname_proxy.sh --version             # versión e info datos

CONTAINER="${WHATSMYNAME_CONTAINER:-whatsmyname}"

if ! podman ps \
        --filter "name=${CONTAINER}" \
        --filter "status=running" \
        --format "{{.Names}}" 2>/dev/null \
        | grep -q "^${CONTAINER}$"; then
    printf '\033[31m[whatsmyname]\033[0m El contenedor "%s" no está corriendo.\n' "${CONTAINER}" >&2
    printf '  Inicia con: just compose up\n' >&2
    exit 1
fi

if [ $# -eq 0 ]; then
    exec podman exec "${CONTAINER}" whatsmyname --help
else
    exec podman exec "${CONTAINER}" whatsmyname "$@"
fi
