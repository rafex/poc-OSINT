#!/usr/bin/env bash
set -euo pipefail

key_file="$HOME/.age/key.txt"
if [ ! -f "$key_file" ]; then
    echo "No se encontró ~/.age/key.txt — ejecuta: just secrets setup"
    exit 1
fi
grep "# public key:" "$key_file"
