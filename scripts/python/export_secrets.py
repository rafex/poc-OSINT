#!/usr/bin/env python3
"""
Lee secretos descifrados (YAML plano) desde stdin y los escribe en formato
KEY=value a stdout. Llamado desde: just secrets export / make secrets-export

No requiere dependencias externas — usa solo stdlib.
"""
import sys

for raw in sys.stdin:
    line = raw.rstrip()
    if not line or line.startswith("#"):
        continue
    if ":" not in line:
        continue
    key, _, val = line.partition(":")
    key = key.strip()
    val = val.strip().strip('"').strip("'")
    if key and not key.startswith("sops"):
        print(f"{key}={val}")
