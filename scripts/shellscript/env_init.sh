#!/usr/bin/env bash
set -euo pipefail

if [ -f .env ]; then
    echo ".env ya existe — no sobreescrito."
else
    cp .env.example .env
    echo "Creado .env desde .env.example — edita tus API keys antes de continuar."
fi
