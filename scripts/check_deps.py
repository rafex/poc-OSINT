#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["rich>=13"]
# ///
"""Verifica que todas las herramientas requeridas estén instaladas."""

import shutil
import subprocess
import sys
from dataclasses import dataclass

from rich.console import Console
from rich.table import Table

console = Console()


@dataclass
class Tool:
    name: str
    cmd: str
    required: bool
    version_flag: str = "--version"
    description: str = ""


TOOLS: list[Tool] = [
    Tool("uv",     "uv",     required=True,  description="Gestor de paquetes Python"),
    Tool("podman", "podman", required=True,  description="Runtime de contenedores"),
    Tool("make",   "make",   required=True,  description="Sistema de build"),
    Tool("just",   "just",   required=True,  description="Task runner"),
    Tool("git",    "git",    required=True,  description="Control de versiones"),
    Tool("curl",   "curl",   required=True,  description="HTTP client (health checks)"),
    Tool("cmake",  "cmake",  required=False, description="Necesario para compilar llama.cpp"),
    Tool("nohup",  "nohup",  required=False, description="Ejecutar procesos en background"),
    Tool("lsof",   "lsof",   required=False, description="Inspección de puertos"),
]


def check_tool(tool: Tool) -> tuple[bool, str]:
    """Returns (found, version_or_error)."""
    if not shutil.which(tool.cmd):
        return False, "no encontrado en PATH"
    try:
        result = subprocess.run(
            [tool.cmd, tool.version_flag],
            capture_output=True, text=True, timeout=5,
        )
        first_line = (result.stdout or result.stderr).strip().splitlines()[0]
        return True, first_line[:60]
    except Exception as exc:
        return True, f"(instalado, versión desconocida: {exc})"


def main() -> None:
    table = Table(title="Verificación de dependencias — edge-osint-lab", show_lines=False)
    table.add_column("Herramienta", style="cyan", no_wrap=True)
    table.add_column("Descripción", style="dim")
    table.add_column("Estado", no_wrap=True)
    table.add_column("Versión / Info", style="dim", overflow="fold")

    missing_required: list[str] = []

    for tool in TOOLS:
        found, info = check_tool(tool)
        tag = "[bold red]REQUERIDA[/]" if tool.required else "[dim]opcional[/]"
        if found:
            status = "[bold green]✓ OK[/]"
        else:
            status = "[bold red]✗ FALTA[/]" if tool.required else "[yellow]– ausente[/]"
            if tool.required:
                missing_required.append(tool.name)
        table.add_row(tool.name, tool.description, f"{status} {tag}", info)

    console.print(table)

    if missing_required:
        console.print(
            f"\n[bold red]Error:[/] {len(missing_required)} herramienta(s) requerida(s) no encontrada(s): "
            + ", ".join(missing_required)
        )
        sys.exit(1)
    else:
        console.print("\n[bold green]Todas las herramientas requeridas están disponibles.[/]")


if __name__ == "__main__":
    main()
