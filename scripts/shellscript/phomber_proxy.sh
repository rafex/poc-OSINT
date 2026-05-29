#!/usr/bin/env bash
# Proxy transparente a PHOMBER en el contenedor.
#
# Sin argumentos  → sesión interactiva con TTY completo (phomber inicia en modo menú)
# Con argumentos  → ejecuta el comando y devuelve la salida tal cual
#
# Uso:
#   bash scripts/shellscript/phomber_proxy.sh               # interactivo
#   bash scripts/shellscript/phomber_proxy.sh -p +52551234  # consulta directa
#   bash scripts/shellscript/phomber_proxy.sh --help        # ayuda de phomber
#   bash scripts/shellscript/phomber_proxy.sh -v            # versión

CONTAINER="${CONTAINER_NAME:-phomber}"

if ! podman ps \
        --filter "name=${CONTAINER}" \
        --filter "status=running" \
        --format "{{.Names}}" 2>/dev/null \
        | grep -q "^${CONTAINER}$"; then
    printf '\033[31m[phomber]\033[0m El contenedor "%s" no está corriendo.\n' "${CONTAINER}" >&2
    printf '  Inicia el stack con: just up\n' >&2
    exit 1
fi

if [ $# -eq 0 ]; then
    # Sesión completamente interactiva: TTY + stdin
    exec podman exec -it "${CONTAINER}" phomber
else
    # Comando directo: pasa todos los args sin modificar
    exec podman exec "${CONTAINER}" phomber "$@"
fi
