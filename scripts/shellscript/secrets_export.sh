#!/usr/bin/env bash
set -euo pipefail

SOPS_AGE_KEY_FILE="$HOME/.age/key.txt" \
    sops --decrypt secrets/secrets.enc.yaml \
    | python3 scripts/python/export_secrets.py \
    > .env
echo "Exportado → .env  (no commitear)"
