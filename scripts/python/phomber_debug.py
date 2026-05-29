#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "rich>=13",
# ]
# ///
"""
Wrapper con salida formateada para PHOMBER.

Ejecuta cualquier comando de PHOMBER en el contenedor y muestra stdout,
stderr y metadatos claramente separados. Útil para revisar salidas raw
y ajustar cómo las procesa el orquestador.

Para sesión interactiva completa usa: just phomber  (sin este wrapper)

Uso:
    just osint debug                         # interactivo
    just osint debug -- -p +52551234567      # consulta directa
    just osint debug -- --help               # ayuda de PHOMBER
    just osint debug -- -v                   # versión
"""

import os
import subprocess
import sys
import time

from rich.console import Console
from rich.panel import Panel
from rich.rule import Rule
from rich.table import Table
from rich import box

console = Console()
CONTAINER = os.getenv("CONTAINER_NAME", "phomber")


def _container_running() -> bool:
    try:
        out = subprocess.run(
            ["podman", "ps", "--filter", f"name={CONTAINER}",
             "--filter", "status=running", "--format", "{{.Names}}"],
            capture_output=True, text=True, timeout=5, stdin=subprocess.DEVNULL,
        ).stdout
        return CONTAINER in out
    except Exception:
        return False


def _run(args: list[str]) -> tuple[str, str, int, float]:
    cmd = ["podman", "exec", CONTAINER, "phomber"] + args
    console.print(f"  [dim]$ {' '.join(cmd)}[/]\n")
    t0 = time.monotonic()
    try:
        p = subprocess.run(
            cmd, capture_output=True, text=True,
            timeout=60, stdin=subprocess.DEVNULL,
        )
        return p.stdout, p.stderr, p.returncode, time.monotonic() - t0
    except subprocess.TimeoutExpired:
        return "", "Timeout (60s)", -1, time.monotonic() - t0
    except FileNotFoundError:
        return "", "'podman' no encontrado", -2, 0.0


def _show(stdout: str, stderr: str, rc: int, elapsed: float) -> None:
    if stdout.strip():
        console.print(Rule("[bold green]stdout[/]", style="green"))
        console.print(stdout.rstrip())
    else:
        console.print(Rule("[dim]stdout — vacío[/]", style="dim"))

    # Mostrar stderr filtrando solo el warning conocido de TTY (ya corregido)
    filtered = [l for l in stderr.splitlines()
                if "Input is not a terminal" not in l]
    if filtered:
        console.print(Rule("[bold yellow]stderr[/]", style="yellow"))
        for line in filtered:
            console.print(f"[yellow]{line}[/]")

    t = Table(box=box.SIMPLE, show_header=False, padding=(0, 1))
    t.add_column(style="dim")
    t.add_column()
    t.add_row("exit", f"[{'green' if rc == 0 else 'red'}]{rc}[/]")
    t.add_row("tiempo", f"{elapsed:.2f}s")
    console.print()
    console.print(t)


def _interactive() -> None:
    console.print(Panel(
        "[bold cyan]PHOMBER debug — modo interactivo[/]\n\n"
        "[dim]Escribe argumentos de phomber tal cual los usarías en la CLI.\n"
        "Ejemplos:  -p +525512345678   --help   -v   -s -p +525512345678\n"
        "Escribe [bold]exit[/] o Ctrl+C para salir.[/]",
        border_style="cyan", expand=False,
    ))

    if not _container_running():
        console.print(f"[red]✗[/] Contenedor [cyan]{CONTAINER}[/] no está corriendo — ejecuta [cyan]just up[/]")
        return

    console.print(f"[green]✓[/] Contenedor [cyan]{CONTAINER}[/] activo\n")

    import shlex
    while True:
        try:
            line = console.input("[bold cyan]phomber>[/] ").strip()
        except (EOFError, KeyboardInterrupt):
            console.print("\n[dim]Saliendo.[/]")
            break

        if not line or line.lower() in ("exit", "quit", "q", "salir"):
            break

        args = shlex.split(line)
        stdout, stderr, rc, elapsed = _run(args)
        _show(stdout, stderr, rc, elapsed)
        console.print()


def main() -> None:
    # Argumentos tras -- se pasan directo a phomber
    args = sys.argv[1:]

    if args:
        stdout, stderr, rc, elapsed = _run(args)
        console.print(Panel.fit(
            f"[bold cyan]PHOMBER[/]  [dim]phomber {' '.join(args)}[/]",
            border_style="cyan",
        ))
        console.print()
        _show(stdout, stderr, rc, elapsed)
        sys.exit(rc)
    else:
        _interactive()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        console.print("\n[dim]Cancelado.[/]")
        sys.exit(0)
