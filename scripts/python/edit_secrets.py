#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml>=6", "rich>=13"]
# ///
"""
Editor de secretos para edge-osint-lab.
Flujo: descifra con SOPS → abre vim → valida → re-cifra.
Los archivos temporales descifrados se borran de forma segura al terminar.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

import yaml
from rich.console import Console
from rich.table import Table

console = Console(stderr=True)   # UI → stderr; stdout limpio para pipelines

SECRETS_FILE = Path("secrets/secrets.enc.yaml")
AGE_KEY_FILE = Path.home() / ".age" / "key.txt"
EDITOR       = os.getenv("EDITOR", "vim")

# ── Schema de claves permitidas ───────────────────────────────────────────────

SCHEMA: dict[str, dict[str, Any]] = {
    "LLM_PROVIDER": {
        "required": True,
        "validate": lambda v: all(
            p.strip() in {"openai-compat", "local"} for p in str(v).split("|")
        ),
        "hint": "separado por | con valores: openai-compat, local",
    },
    "PROVIDER_LLM_BASE_URL": {
        "required": False,
        "validate": lambda v: not v or str(v).startswith("http"),
        "hint": "URL base del API (ej: https://api.groq.com/openai/v1)",
    },
    "PROVIDER_LLM_API_KEY": {
        "required": False,
        "validate": lambda v: True,
        "hint": "API key del proveedor remoto",
    },
    "PROVIDER_LLM_MODEL": {
        "required": False,
        "validate": lambda v: True,
        "hint": "nombre del modelo (ej: llama-3.1-8b-instant, deepseek-chat)",
    },
    "LLAMA_SERVER_URL": {
        "required": False,
        "validate": lambda v: not v or str(v).startswith("http"),
        "hint": "e.g. http://localhost:8080",
    },
    "LOCAL_MODEL_NAME": {
        "required": False,
        "validate": lambda v: True,
        "hint": "nombre descriptivo del modelo local",
    },
    "MODEL_DIR": {
        "required": False,
        "validate": lambda v: True,
        "hint": "directorio de modelos GGUF",
    },
    "MODEL_FILE": {
        "required": False,
        "validate": lambda v: not v or str(v).endswith(".gguf"),
        "hint": "nombre del archivo .gguf",
    },
    "LLAMA_PORT": {
        "required": False,
        "validate": lambda v: not v or str(v).isdigit(),
        "hint": "número de puerto (e.g. 8080)",
    },
    "LLAMA_CTX": {
        "required": False,
        "validate": lambda v: not v or str(v).isdigit(),
        "hint": "tamaño de contexto en tokens",
    },
    "LLAMA_THREADS": {
        "required": False,
        "validate": lambda v: not v or str(v).isdigit(),
        "hint": "número de hilos CPU",
    },
    "CONTAINER_NAME": {
        "required": False,
        "validate": lambda v: not v or bool(re.fullmatch(r"[a-z0-9_-]+", str(v))),
        "hint": "solo lowercase, dígitos, guiones y guiones bajos",
    },
    "LOG_LEVEL": {
        "required": True,
        "validate": lambda v: str(v).upper() in {"DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"},
        "hint": "uno de: DEBUG  INFO  WARNING  ERROR  CRITICAL",
    },
}

# ── Patrones prohibidos (claves privadas que jamás deben aparecer) ─────────────

FORBIDDEN: list[tuple[str, str]] = [
    (r"-----BEGIN .{0,30}PRIVATE KEY-----", "clave privada PEM"),
    (r"AGE-SECRET-KEY-1",                   "clave privada age"),
    (r"-----BEGIN OPENSSH PRIVATE KEY-----", "clave privada OpenSSH"),
    (r"(?i)password\s*[=:]\s*\S{8,}",       "posible contraseña en texto plano"),
]


# ── Validación ────────────────────────────────────────────────────────────────

def validate(content: str) -> list[str]:
    errors: list[str] = []

    # 1. Patrones prohibidos (revisión sobre texto crudo antes de parsear)
    for pattern, label in FORBIDDEN:
        if re.search(pattern, content):
            errors.append(f"Patrón prohibido detectado: [bold red]{label}[/]")

    # 2. Parseo YAML
    try:
        data = yaml.safe_load(content)
    except yaml.YAMLError as exc:
        errors.append(f"YAML inválido: {exc}")
        return errors

    if not isinstance(data, dict):
        errors.append("El archivo debe ser un mapa YAML (clave: valor).")
        return errors

    # 3. Claves no permitidas
    allowed = set(SCHEMA.keys())
    extra = {k for k in data if k not in allowed}
    if extra:
        errors.append(f"Claves no permitidas: {', '.join(sorted(extra))}")

    # 4. Claves requeridas
    for key, spec in SCHEMA.items():
        if spec["required"] and not data.get(key):
            errors.append(f"Clave requerida ausente o vacía: [bold]{key}[/]")

    # 5. Validación de valores
    for key, spec in SCHEMA.items():
        value = data.get(key)
        if value is not None and value != "" and not spec["validate"](value):
            errors.append(f"[bold]{key}[/] = '{value}'  →  {spec['hint']}")

    return errors


# ── Borrado seguro ────────────────────────────────────────────────────────────

def secure_delete(path: Path) -> None:
    """Sobreescribe con ceros antes de eliminar."""
    try:
        size = path.stat().st_size
        if size:
            path.write_bytes(b"\x00" * size)
    except Exception:
        pass
    path.unlink(missing_ok=True)


# ── Bucle de edición ──────────────────────────────────────────────────────────

def edit_loop(tmp_path: Path) -> bool:
    """Abre el editor en un bucle hasta que el contenido sea válido o el usuario aborte."""
    while True:
        # Abrir editor (hereda terminal del proceso padre)
        subprocess.run([EDITOR, str(tmp_path)])

        content = tmp_path.read_text()
        errors = validate(content)

        if not errors:
            return True

        # Mostrar errores
        console.print()
        console.rule("[bold red]Errores de validación[/]")
        for err in errors:
            console.print(f"  [red]✗[/] {err}")

        # Mostrar schema de referencia si el usuario lo pide
        console.print("\n[bold]¿Qué deseas hacer?[/]")
        console.print("  [cyan]e[/] — corregir en el editor")
        console.print("  [cyan]s[/] — ver schema de referencia")
        console.print("  [red]a[/] — abortar (no guarda cambios)")

        try:
            choice = input("\nOpción [e/s/a]: ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            console.print()
            return False

        if choice == "s":
            _print_schema()
        elif choice != "e":
            console.print("[yellow]Abortado. Sin cambios.[/]")
            return False

    return False  # inalcanzable


def _print_schema() -> None:
    table = Table(title="Schema de secretos", show_lines=False)
    table.add_column("Clave",     style="cyan", no_wrap=True)
    table.add_column("Requerida", justify="center")
    table.add_column("Regla / Ejemplo", style="dim")
    for key, spec in SCHEMA.items():
        req = "[bold green]✓[/]" if spec["required"] else ""
        table.add_row(key, req, spec["hint"])
    console.print(table)
    console.print()


# ── Verificación de prerequisitos ────────────────────────────────────────────

def check_prereqs() -> bool:
    ok = True
    if not shutil.which(EDITOR):
        console.print(f"[red]Editor no encontrado:[/] {EDITOR}  (ajusta $EDITOR)")
        ok = False
    if not shutil.which("sops"):
        console.print("[red]sops no encontrado.[/] Instala con: brew install sops")
        ok = False
    if not AGE_KEY_FILE.exists():
        console.print(f"[red]Clave age no encontrada:[/] {AGE_KEY_FILE}")
        console.print("  Ejecuta: [cyan]just secrets setup[/]")
        ok = False
    if not SECRETS_FILE.exists() and not Path(".sops.yaml").exists():
        console.print("[red].sops.yaml no encontrado.[/] Ejecuta: [cyan]just secrets setup[/]")
        ok = False
    return ok


# ── Punto de entrada ──────────────────────────────────────────────────────────

def main() -> None:
    if not check_prereqs():
        sys.exit(1)

    sops_env = {**os.environ, "SOPS_AGE_KEY_FILE": str(AGE_KEY_FILE)}

    # Archivo temporal descifrado
    fd, tmp_str = tempfile.mkstemp(suffix=".yaml", prefix="edge-osint-secrets-")
    tmp_path = Path(tmp_str)
    os.close(fd)
    tmp_path.chmod(0o600)

    try:
        if SECRETS_FILE.exists():
            console.print(f"[cyan]Descifrando[/] {SECRETS_FILE} …")
            result = subprocess.run(
                ["sops", "--decrypt", str(SECRETS_FILE)],
                capture_output=True, text=True, env=sops_env,
            )
            if result.returncode != 0:
                console.print(f"[red]Error al descifrar:[/] {result.stderr.strip()}")
                sys.exit(1)
            tmp_path.write_text(result.stdout)
        else:
            # Primera vez: crear desde plantilla
            console.print("[yellow]Creando secretos desde plantilla (primera vez) …[/]")
            from setup_age import _SECRETS_TEMPLATE  # type: ignore[import]
            tmp_path.write_text(_SECRETS_TEMPLATE)

        console.print(f"[dim]Editor: {EDITOR}  |  Archivo: {tmp_path}[/]")
        console.print("[dim]Cierra el editor para continuar. Los cambios se validan automáticamente.[/]\n")

        if not edit_loop(tmp_path):
            sys.exit(0)

        # Re-cifrar
        console.print("[cyan]Cifrando[/] con SOPS + age …")
        result = subprocess.run(
            ["sops", "--encrypt", "--output", str(SECRETS_FILE), str(tmp_path)],
            capture_output=True, text=True, env=sops_env,
        )
        if result.returncode != 0:
            console.print(f"[red]Error al cifrar:[/] {result.stderr.strip()}")
            console.print(f"[dim]Archivo temporal sin cifrar: {tmp_path} — bórralo manualmente.[/]")
            sys.exit(1)

        console.print(f"[bold green]✓ Secretos guardados en[/] {SECRETS_FILE}")
        console.print("[dim]git add secrets/secrets.enc.yaml && git commit -m 'chore: update secrets'[/]")

    finally:
        secure_delete(tmp_path)


if __name__ == "__main__":
    main()
