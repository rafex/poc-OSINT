#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-phomber}"
PODMAN="${PODMAN:-podman}"
GREEN=$'\033[32m'; RED=$'\033[31m'; RESET=$'\033[0m'

if "${PODMAN}" ps \
    --filter "name=${CONTAINER_NAME}" \
    --filter "status=running" \
    --format "{{.Names}}" \
    | grep -q "${CONTAINER_NAME}"; then
    printf "%b[checks]%b Contenedor '%s' ACTIVO.\n" "${GREEN}" "${RESET}" "${CONTAINER_NAME}"
else
    printf "%b[checks]%b Contenedor '%s' INACTIVO.\n" "${RED}" "${RESET}" "${CONTAINER_NAME}"
fi
