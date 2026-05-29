#!/usr/bin/env bash
set -euo pipefail

export SOPS_AGE_KEY_FILE="$HOME/.age/key.txt"

if sops --decrypt secrets/secrets.enc.yaml > /dev/null 2>&1; then
    echo "✓ Secretos verificados."
else
    echo "✗ No se pudo descifrar. Verifica ~/.age/key.txt y .sops.yaml"
    exit 1
fi
