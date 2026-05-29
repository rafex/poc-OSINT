#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "rich>=13",
# ]
# ///
"""
Herramienta de debug para PHOMBER — interactúa directamente con el contenedor
sin pasar por el LLM. Útil para ver la salida raw, ajustar flags y diagnosticar.

Uso:
    uv run --script scripts/python/phomber_debug.py                     # modo interactivo
    uv run --script scripts/python/phomber_debug.py "+52 55 1234 5678"  # un número
    uv run --script scripts/python/phomber_debug.py --help

    just osint debug
    just osint debug "+52 55 1234 5678"
"""

import argparse
import os
import subprocess
import sys
import time

from rich import box
from rich.console import Console
from rich.panel import Panel
from rich.rule import Rule
from rich.table import Table
from rich.text import Text

console = Console()

CONTAINER   = os.getenv("CONTAINER_NAME", "phomber")
DEFAULT_FLAGS: list[str] = ["-s"]   # -s suprime el banner de PHOMBER


# ── Ejecución ─────────────────────────────────────────────────────────────────

def _run(args: list[str], *, silent: bool, timeout: int) -> tuple[str, str, int, float]:
    """Ejecuta PHOMBER en el contenedor y devuelve (stdout, stderr, returncode, elapsed)."""
    flags = DEFAULT_FLAGS if silent else []
    cmd = ["podman", "exec", CONTAINER, "phomber"] + flags + args

    console.print(f"[dim]$ {' '.join(cmd)}[/]")

    start = time.monotonic()
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            stdin=subprocess.DEVNULL,
        )
        elapsed = time.monotonic() - start
        return proc.stdout, proc.stderr, proc.returncode, elapsed

    except subprocess.TimeoutExpired:
        elapsed = time.monotonic() - start
        return "", f"Timeout después de {timeout}s", -1, elapsed

    except FileNotFoundError:
        return "", "'podman' no encontrado en PATH", -2, 0.0


def _check_container() -> bool:
    """Devuelve True si el contenedor está corriendo."""
    try:
        result = subprocess.run(
            ["podman", "ps", "--filter", f"name={CONTAINER}",
             "--filter", "status=running", "--format", "{{.Names}}"],
            capture_output=True, text=True, timeout=5, stdin=subprocess.DEVNULL,
        )
        return CONTAINER in result.stdout
    except Exception:
        return False


# ── Renderizado ───────────────────────────────────────────────────────────────

def _render_output(stdout: str, stderr: str, returncode: int, elapsed: float) -> None:
    # Stdout
    if stdout.strip():
        console.print(Rule("[bold green]stdout[/]", style="green"))
        console.print(stdout.rstrip())
    else:
        console.print(Rule("[dim]stdout vacío[/]", style="dim"))

    # Stderr
    if stderr.strip():
        # Filtrar la advertencia conocida de TTY (ya corregida en executor.py)
        lines = [l for l in stderr.splitlines()
                 if "Input is not a terminal" not in l]
        if lines:
            console.print(Rule("[bold yellow]stderr[/]", style="yellow"))
            for line in lines:
                console.print(f"[yellow]{line}[/]")

    # Metadata
    rc_color = "green" if returncode == 0 else "red"
    console.print()
    t = Table(box=box.SIMPLE, show_header=False, padding=(0, 1))
    t.add_column(style="dim")
    t.add_column()
    t.add_row("exit code", f"[{rc_color}]{returncode}[/]")
    t.add_row("tiempo",    f"{elapsed:.2f}s")
    console.print(t)


def _run_and_show(raw_args: list[str], silent: bool, timeout: int) -> None:
    stdout, stderr, rc, elapsed = _run(raw_args, silent=silent, timeout=timeout)
    _render_output(stdout, stderr, rc, elapsed)


# ── Modos ────────────────────────────────────────────────────────────────────

def _single(target: str, silent: bool, timeout: int) -> None:
    """Ejecuta una consulta de número de teléfono."""
    phone = target.replace(" ", "").replace("-", "").replace("(", "").replace(")", "")
    if not phone.startswith("+") and not phone.startswith("00"):
        console.print("[yellow]Aviso:[/] el número no tiene prefijo de país (+XX). Puede que PHOMBER no retorne datos.")

    console.print()
    console.print(Panel.fit(
        f"[bold cyan]PHOMBER raw[/]  →  [white]{target}[/]  [dim](normalizado: {phone})[/]",
        border_style="cyan",
    ))
    _run_and_show(["-p", phone], silent=silent, timeout=timeout)


def _exec_args(raw_args: list[str], silent: bool, timeout: int) -> None:
    """Ejecuta PHOMBER con los args exactos proporcionados."""
    console.print()
    console.print(Panel.fit(
        f"[bold cyan]PHOMBER raw[/]  →  [white]{' '.join(raw_args)}[/]",
        border_style="cyan",
    ))
    _run_and_show(raw_args, silent=silent, timeout=timeout)


def _interactive(silent: bool, timeout: int) -> None:
    """Modo interactivo: solicita números en bucle."""
    console.print(Panel(
        "[bold cyan]PHOMBER Debug — modo interactivo[/]\n\n"
        "[dim]Escribe un número de teléfono (con prefijo de país: +52 55 1234 5678)\n"
        "o un comando PHOMBER completo (ej: -p +525512345678)\n"
        "Escribe [bold]exit[/bold] o presiona Ctrl+C para salir.[/]",
        border_style="cyan",
        expand=False,
    ))

    # Estado del contenedor
    if _check_container():
        console.print(f"[green]✓[/] Contenedor [cyan]{CONTAINER}[/] activo\n")
    else:
        console.print(f"[red]✗[/] Contenedor [cyan]{CONTAINER}[/] no está corriendo.")
        console.print("  Ejecuta [cyan]just up[/] primero.\n")
        return

    while True:
        try:
            raw = console.input("[bold cyan]phomber>[/] ").strip()
        except (EOFError, KeyboardInterrupt):
            console.print("\n[dim]Saliendo.[/]")
            break

        if not raw or raw.lower() in ("exit", "quit", "q", "salir"):
            break

        # Determinar si es un número o args directos
        if raw.startswith("-"):
            # Flags directas: -p +52... o --help
            parts = raw.split()
            _exec_args(parts, silent=silent, timeout=timeout)
        else:
            # Tratar como número de teléfono
            _single(raw, silent=silent, timeout=timeout)

        console.print()


# ── CLI ───────────────────────────────────────────────────────────────────────

def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Debug directo de PHOMBER sin LLM.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos:
  # Modo interactivo
  just osint debug

  # Número directo
  just osint debug "+52 55 1234 5678"

  # Flags explícitas de PHOMBER
  just osint debug -- -p +525512345678

  # Ver ayuda de PHOMBER
  uv run --script scripts/python/phomber_debug.py -- --help

  # Sin flag -s (muestra el banner de PHOMBER)
  uv run --script scripts/python/phomber_debug.py --no-silent "+52 55 1234 5678"
        """,
    )
    parser.add_argument(
        "target",
        nargs="*",
        help="Número de teléfono o args de PHOMBER (tras --)",
    )
    parser.add_argument(
        "--container", default=CONTAINER,
        help=f"Nombre del contenedor (default: {CONTAINER})",
    )
    parser.add_argument(
        "--no-silent", action="store_true",
        help="No pasar -s a PHOMBER (muestra banner completo)",
    )
    parser.add_argument(
        "--timeout", type=int, default=30,
        help="Timeout en segundos (default: 30)",
    )
    return parser.parse_args()


def main() -> None:
    args = _parse_args()

    # Override container si se especificó
    global CONTAINER
    CONTAINER = args.container

    silent = not args.no_silent

    if args.target:
        joined = " ".join(args.target)
        # Si empieza con -, son flags directas de PHOMBER
        if joined.strip().startswith("-"):
            _exec_args(args.target, silent=silent, timeout=args.timeout)
        else:
            _single(joined, silent=silent, timeout=args.timeout)
    else:
        _interactive(silent=silent, timeout=args.timeout)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        console.print("\n[dim]Cancelado.[/]")
        sys.exit(0)
