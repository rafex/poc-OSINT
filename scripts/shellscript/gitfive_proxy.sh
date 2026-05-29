#!/usr/bin/env bash
# Proxy transparente a GitFive en el contenedor.
#
# Sin argumentos  → muestra la ayuda de GitFive
# Con argumentos  → ejecuta el comando y devuelve la salida tal cual
#
# Primera vez — autenticación:
#   bash scripts/shellscript/gitfive_proxy.sh init
#   (abre sesión interactiva para guardar el token de GitHub)
#
# Uso:
#   bash scripts/shellscript/gitfive_proxy.sh                       # ayuda
#   bash scripts/shellscript/gitfive_proxy.sh init                  # configurar token (primera vez)
#   bash scripts/shellscript/gitfive_proxy.sh user <username>       # investigar usuario GitHub
#   bash scripts/shellscript/gitfive_proxy.sh email <email>         # investigar por email
#   bash scripts/shellscript/gitfive_proxy.sh --version             # versión instalada
#   bash scripts/shellscript/gitfive_proxy.sh --help                # ayuda completa

CONTAINER="${GITFIVE_CONTAINER:-gitfive}"

if ! podman ps \
        --filter "name=${CONTAINER}" \
        --filter "status=running" \
        --format "{{.Names}}" 2>/dev/null \
        | grep -q "^${CONTAINER}$"; then
    printf '\033[31m[gitfive]\033[0m El contenedor "%s" no está corriendo.\n' "${CONTAINER}" >&2
    printf '  Inicia con: just compose up\n' >&2
    exit 1
fi

if [ $# -eq 0 ]; then
    exec podman exec "${CONTAINER}" gitfive --help
elif [ "$1" = "init" ]; then
    # init es interactivo: necesita TTY + stdin
    exec podman exec -it "${CONTAINER}" gitfive init
else
    exec podman exec "${CONTAINER}" gitfive "$@"
fi
