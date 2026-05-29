set working-directory := "../.."

# dev.just — flujo de trabajo de desarrollo
# Llamado con: just dev <recipe>

# Verifica estilo y errores con ruff
lint:
    make lint

# Formatea el código automáticamente
format:
    make format

# Verifica formato sin modificar archivos (útil en CI)
format-check:
    make format-check

# Verifica tipos estáticos con mypy
typecheck:
    make typecheck

# Ejecuta la suite de tests
test:
    make test

# Ejecuta todos los checks de calidad de código en secuencia
ci: format-check lint typecheck test
    @echo "=== Todos los checks de CI pasaron ==="

# Itera el ciclo format → lint → typecheck
fix:
    make format
    make lint
    make typecheck

# Muestra el log de llama-server en tiempo real
logs-llama:
    tail -f /tmp/llama-server.log

# Abre shell dentro del contenedor PHOMBER
shell:
    make container-shell
