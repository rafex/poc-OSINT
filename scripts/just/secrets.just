set working-directory := "../.."

# secrets.just — gestión de secretos con SOPS + age
# Llamado con: just secrets <recipe>
#
# Flujo:
#   1. just secrets setup   → genera clave age + crea secrets.enc.yaml
#   2. just secrets edit    → vim: descifra → edita → valida → re-cifra
#   3. just secrets export  → exporta a .env (no commitear .env)
#
# Clave privada : ~/.age/key.txt             ← NUNCA en el repositorio
# Secretos      : secrets/secrets.enc.yaml  ← commitable (cifrado)

_age_key := env_var("HOME") + "/.age/key.txt"

# Setup inicial: genera clave age en ~/.age/key.txt y crea secrets.enc.yaml
setup:
    uv run --script scripts/python/setup_age.py

# Edita secretos con vim (decrypt → valida schema → re-cifra)
edit:
    SOPS_AGE_KEY_FILE="{{_age_key}}" uv run --script scripts/python/edit_secrets.py

# Exporta secretos descifrados a .env (formato KEY=value)
# .env está en .gitignore — NUNCA commitear
export:
    bash scripts/shellscript/secrets_export.sh

# Muestra los secretos descifrados en terminal (solo lectura, no guarda)
view:
    SOPS_AGE_KEY_FILE="{{_age_key}}" sops --decrypt secrets/secrets.enc.yaml

# Verifica que el archivo de secretos puede descifrarse con la clave actual
check:
    bash scripts/shellscript/secrets_check.sh

# Muestra la clave pública age registrada en el sistema actual
pubkey:
    bash scripts/shellscript/secrets_pubkey.sh
