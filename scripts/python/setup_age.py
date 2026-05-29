#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["rich>=13"]
# ///
"""
Setup de secretos para edge-osint-lab.
Genera clave age en ~/.age/key.txt, actualiza .sops.yaml con la clave pública
y crea el archivo inicial secrets/secrets.enc.yaml cifrado.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from rich.console import Console

console = Console()

AGE_DIR      = Path.home() / ".age"
AGE_KEY_FILE = AGE_DIR / "key.txt"
SOPS_CONFIG  = Path(".sops.yaml")
SECRETS_DIR  = Path("secrets")
SECRETS_FILE = SECRETS_DIR / "secrets.enc.yaml"
PLACEHOLDER  = "PLACEHOLDER_AGE_PUBLIC_KEY"

_SECRETS_TEMPLATE = """\
# edge-osint-lab — secretos del proyecto
# Editado con:  just secrets edit
# Cifrado con:  SOPS + age
# NUNCA commitear la versión descifrada de este archivo.

LLM_PROVIDER: "openai-compat|local"

# Proveedor remoto compatible con OpenAI SDK (Groq, DeepSeek, OpenRouter, etc.)
# Ejemplos de BASE_URL:
#   Groq     → https://api.groq.com/openai/v1
#   DeepSeek → https://api.deepseek.com/v1
PROVIDER_LLM_BASE_URL: ""
PROVIDER_LLM_API_KEY: ""
PROVIDER_LLM_MODEL: "llama-3.1-8b-instant"

# llama.cpp local (fallback sin internet)
LLAMA_SERVER_URL: "http://localhost:8080"
LOCAL_MODEL_NAME: "qwen2-0.5b-instruct-q4_k_m"

MODEL_DIR: "$HOME/models"
MODEL_FILE: "qwen2-0_5b-instruct-q4_k_m.gguf"
LLAMA_PORT: "8080"
LLAMA_CTX: "2048"
LLAMA_THREADS: "4"

CONTAINER_NAME: "phomber"

LOG_LEVEL: "WARNING"
"""


def check_tools() -> bool:
    missing = [t for t in ("age-keygen", "sops") if not shutil.which(t)]
    if missing:
        console.print(f"[red]Error:[/] herramientas no encontradas: {', '.join(missing)}")
        console.print("\nInstala con:")
        console.print("  macOS : [cyan]brew install age sops[/]")
        console.print("  Linux : https://github.com/FiloSottile/age/releases")
        console.print("          https://github.com/getsops/sops/releases")
        return False
    return True


def generate_age_key() -> str:
    """Genera keypair age. Devuelve la clave pública."""
    AGE_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)

    if AGE_KEY_FILE.exists():
        console.print(f"[yellow]Clave age ya existe:[/] {AGE_KEY_FILE}")
    else:
        console.print(f"[cyan]Generando clave age en[/] {AGE_KEY_FILE} …")
        result = subprocess.run(
            ["age-keygen", "-o", str(AGE_KEY_FILE)],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            console.print(f"[red]Error al generar clave:[/] {result.stderr.strip()}")
            sys.exit(1)
        AGE_KEY_FILE.chmod(0o600)
        console.print("[green]✓ Clave generada[/]")

    content = AGE_KEY_FILE.read_text()
    match = re.search(r"# public key: (age1\S+)", content)
    if not match:
        console.print("[red]Error:[/] no se pudo extraer la clave pública.")
        sys.exit(1)

    pub_key = match.group(1)
    console.print(f"[bold]Clave pública:[/] [cyan]{pub_key}[/]")
    return pub_key


def update_sops_config(pub_key: str) -> None:
    if not SOPS_CONFIG.exists():
        console.print(f"[red]Error:[/] {SOPS_CONFIG} no encontrado.")
        sys.exit(1)

    content = SOPS_CONFIG.read_text()
    if pub_key in content:
        console.print(f"[yellow]{SOPS_CONFIG} ya tiene la clave pública.[/]")
        return

    if PLACEHOLDER in content:
        SOPS_CONFIG.write_text(content.replace(PLACEHOLDER, pub_key))
        console.print(f"[green]✓[/] {SOPS_CONFIG} actualizado.")
    else:
        console.print(f"[yellow]Aviso:[/] placeholder no encontrado en {SOPS_CONFIG}.")
        console.print(f"  Agrega manualmente: [cyan]{pub_key}[/]")


def create_secrets_file(pub_key: str) -> None:
    SECRETS_DIR.mkdir(parents=True, exist_ok=True)

    if SECRETS_FILE.exists():
        console.print(f"[yellow]{SECRETS_FILE} ya existe.[/] Ejecuta [cyan]just secrets edit[/] para modificarlo.")
        return

    console.print(f"[cyan]Creando[/] {SECRETS_FILE} con plantilla cifrada …")

    # El temp file debe estar dentro de secrets/ para que coincida
    # con path_regex de .sops.yaml y SOPS pueda encontrar la regla.
    fd, tmp = tempfile.mkstemp(suffix=".yaml", prefix=".edge-osint-tmp-", dir=str(SECRETS_DIR))
    tmp_path = Path(tmp)
    os.close(fd)
    tmp_path.chmod(0o600)

    try:
        tmp_path.write_text(_SECRETS_TEMPLATE)
        env = {**os.environ, "SOPS_AGE_KEY_FILE": str(AGE_KEY_FILE)}
        # No pasar --age aquí: SOPS lo lee de .sops.yaml usando el path del archivo.
        result = subprocess.run(
            ["sops", "--encrypt", "--output", str(SECRETS_FILE), str(tmp_path)],
            capture_output=True, text=True, env=env,
        )
        if result.returncode != 0:
            console.print(f"[red]Error al cifrar:[/] {result.stderr.strip()}")
            sys.exit(1)
        console.print(f"[green]✓[/] {SECRETS_FILE} creado.")
    finally:
        tmp_path.write_bytes(b"\x00" * tmp_path.stat().st_size)
        tmp_path.unlink(missing_ok=True)


def main() -> None:
    console.rule("[bold]edge-osint-lab — Setup de secretos[/]")

    if not check_tools():
        sys.exit(1)

    pub_key = generate_age_key()
    update_sops_config(pub_key)
    create_secrets_file(pub_key)

    console.rule()
    console.print(f"\n  Clave [red]privada[/] : [dim]{AGE_KEY_FILE}[/]  ← [bold red]NUNCA en el repo[/]")
    console.print(f"  Secretos cifrados: [dim]{SECRETS_FILE}[/]  ← [bold green]commitable[/]")
    console.print(f"\nSiguiente paso → [cyan]just secrets edit[/]")


if __name__ == "__main__":
    main()
