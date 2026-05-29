#!/usr/bin/env bash
# Proxy transparente a NumSpy en el contenedor.
#
# Uso:
#   bash scripts/shellscript/numspy_proxy.sh                  # ayuda
#   bash scripts/shellscript/numspy_proxy.sh +525512345678    # consultar número
#   bash scripts/shellscript/numspy_proxy.sh --version        # versión instalada

CONTAINER="${NUMSPY_CONTAINER:-numspy}"

if ! podman ps \
        --filter "name=${CONTAINER}" \
        --filter "status=running" \
        --format "{{.Names}}" 2>/dev/null \
        | grep -q "^${CONTAINER}$"; then
    printf '\033[31m[numspy]\033[0m El contenedor "%s" no está corriendo.\n' "${CONTAINER}" >&2
    printf '  Inicia con: just compose up\n' >&2
    exit 1
fi

if [ $# -eq 0 ]; then
    exec podman exec "${CONTAINER}" numspy --help
else
    exec podman exec "${CONTAINER}" numspy "$@"
fi
