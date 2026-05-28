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
    uv run scripts/download_model.py --repo "{{repo}}" --file "{{file}}"

# Configuración completa de Raspberry Pi 4B desde cero
# Ejecuta: instala deps, construye imagen, compila llama.cpp, descarga modelo
raspi model_path="$HOME/models":
    @echo "=== Setup completo Raspberry Pi 4B ==="
    make install
    make build-image
    make build-llama
    just setup download-model
    @echo "=== Setup completado. Ejecuta: just stack start ==="

# Copia .env.example a .env si no existe aún
env-init:
    #!/usr/bin/env bash
    if [ -f .env ]; then
        echo ".env ya existe — no sobreescrito."
    else
        cp .env.example .env
        echo "Creado .env desde .env.example — edita tus API keys antes de continuar."
    fi

# Verifica la configuración de API keys en el entorno actual
check-api:
    make check-api-config
