#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "httpx>=0.27",
#     "rich>=13",
# ]
# ///
"""Verifica que el stack completo (contenedor + LLM providers) esté operativo."""

import os
import subprocess
import sys

import httpx
from rich.console import Console
from rich.table import Table

console = Console()

LLAMA_URL      = os.getenv("LLAMA_SERVER_URL", "http://127.0.0.1:8080")
CONTAINER_NAME = os.getenv("CONTAINER_NAME", "phomber")
LLM_PROVIDER   = os.getenv("LLM_PROVIDER", "openai-compat|local")


# ── Checks de infraestructura ─────────────────────────────────────────────────

def check_container() -> tuple[bool, str]:
    try:
        result = subprocess.run(
            ["podman", "ps", "--filter", f"name={CONTAINER_NAME}",
             "--filter", "status=running", "--format", "{{.Names}}"],
            capture_output=True, text=True, timeout=5,
        )
        running = CONTAINER_NAME in result.stdout
        return running, "en ejecución" if running else "detenido o inexistente"
    except FileNotFoundError:
        return False, "podman no encontrado"
    except Exception as exc:
        return False, str(exc)


def check_phomber_exec() -> tuple[bool, str]:
    try:
        result = subprocess.run(
            ["podman", "exec", CONTAINER_NAME, "python3", "--version"],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode == 0:
            return True, result.stdout.strip() or result.stderr.strip()
        return False, f"exit {result.returncode}"
    except FileNotFoundError:
        return False, "podman no encontrado"
    except Exception as exc:
        return False, str(exc)


def check_llama_server() -> tuple[bool, str]:
    try:
        with httpx.Client(timeout=5.0) as client:
            response = client.get(f"{LLAMA_URL}/health")
            if response.status_code == 200:
                status = response.json().get("status", "ok")
                return True, f"HTTP 200 — {status}"
            return False, f"HTTP {response.status_code}"
    except httpx.ConnectError:
        return False, f"sin conexión en {LLAMA_URL}"
    except Exception as exc:
        return False, str(exc)


# ── Checks de API keys ────────────────────────────────────────────────────────

def _mask_key(key: str) -> str:
    if len(key) > 12:
        return key[:6] + "…" + key[-4:]
    return "***"


def check_remote_provider() -> tuple[bool, str]:
    key      = os.getenv("PROVIDER_LLM_API_KEY", "").strip()
    base_url = os.getenv("PROVIDER_LLM_BASE_URL", "").strip()
    if not key and not base_url:
        return False, "PROVIDER_LLM_API_KEY y PROVIDER_LLM_BASE_URL no definidas"
    if not key:
        return False, "PROVIDER_LLM_API_KEY no definida"
    if not base_url:
        return False, "PROVIDER_LLM_BASE_URL no definida"
    return True, f"key={_mask_key(key)}  url={base_url}"


# ── Tabla de resultados ───────────────────────────────────────────────────────

def main() -> None:
    active_providers = [p.strip() for p in LLM_PROVIDER.split("|")]

    infra_checks = [
        ("Podman container", "PHOMBER activo",                    check_container,    True),
        ("PHOMBER exec",     "Python alcanzable dentro del ctr.", check_phomber_exec, True),
    ]

    llm_checks = []
    if "local" in active_providers:
        llm_checks.append(("llama-server", f"API en {LLAMA_URL}", check_llama_server, False))
    if "openai-compat" in active_providers:
        llm_checks.append(("openai-compat", "API key + base URL presentes", check_remote_provider, False))

    table = Table(
        title=f"Health Check — edge-osint-lab  [LLM_PROVIDER={LLM_PROVIDER}]",
        show_lines=False,
    )
    table.add_column("Componente",   style="cyan",  no_wrap=True)
    table.add_column("Descripción",  style="dim")
    table.add_column("Estado",       no_wrap=True)
    table.add_column("Detalle",      style="dim",   overflow="fold")

    infra_ok = True
    for name, desc, fn, required in infra_checks + llm_checks:
        ok, detail = fn()
        if not ok and required:
            infra_ok = False
        status = "[bold green]✓ OK[/]" if ok else (
            "[bold red]✗ FALLA[/]" if required else "[yellow]– ausente[/]"
        )
        table.add_row(name, desc, status, detail)

    console.print(table)

    # Resumen de cadena LLM activa
    configured = []
    if "openai-compat" in active_providers \
            and os.getenv("PROVIDER_LLM_API_KEY", "").strip() \
            and os.getenv("PROVIDER_LLM_BASE_URL", "").strip():
        configured.append("openai-compat")
    if "local" in active_providers:
        configured.append("local")

    chain_str = " → ".join(configured) if configured else "[red]ninguno[/]"
    console.print(f"\n[dim]Cadena LLM efectiva:[/] {chain_str}")

    if not infra_ok:
        console.print(
            "\n[bold yellow]Stack incompleto.[/] "
            "Ejecuta [cyan]just stack start[/] para levantar los componentes faltantes."
        )
        sys.exit(1)
    else:
        console.print("\n[bold green]Stack operativo.[/] Usa: [cyan]just osint query <número>[/]")


if __name__ == "__main__":
    main()
