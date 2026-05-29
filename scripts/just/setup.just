set working-directory := "../.."

# setup.just — preparación del entorno
# Llamado con: just setup <recipe>

# Instala dependencias de producción
install:
    make install

# Instala dependencias incluyendo herramientas de desarrollo
install-dev:
    make install-dev

# Descarga el modelo GGUF especificado
# Uso: just setup download-model
# Uso con modelo custom: just setup download-model "Qwen/Qwen2-0.5B-Instruct-GGUF" "qwen2-0_5b-instruct-q4_k_m.gguf"
download-model repo="Qwen/Qwen2-0.5B-Instruct-GGUF" file="qwen2-0_5b-instruct-q4_k_m.gguf":
    uv run --script scripts/python/download_model.py --repo "{{repo}}" --file "{{file}}"

# Configuración completa de Raspberry Pi 4B desde cero
# Ejecuta: instala deps, construye imagen, compila llama.cpp, descarga modelo
raspi model_path="$HOME/models":
    @echo "=== Setup completo Raspberry Pi 4B ==="
    make install
    make build-all-images
    make build-llama
    just setup download-model
    @echo "=== Setup completado. Ejecuta: just stack start ==="

# Copia .env.example a .env si no existe aún
env-init:
    bash scripts/shellscript/env_init.sh

# Verifica la configuración de API keys en el entorno actual
check-api:
    make check-api-config
