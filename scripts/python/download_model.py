#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "huggingface-hub>=0.23",
#     "rich>=13",
# ]
# ///
"""Descarga un modelo GGUF desde Hugging Face Hub al directorio local de modelos."""

import argparse
import os
import sys
from pathlib import Path

from huggingface_hub import hf_hub_download
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, DownloadColumn

console = Console()

DEFAULT_REPO = "Qwen/Qwen2-0.5B-Instruct-GGUF"
DEFAULT_FILE = "qwen2-0_5b-instruct-q4_k_m.gguf"
DEFAULT_DIR  = Path.home() / "models"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo",  default=DEFAULT_REPO, help="ID del repositorio HuggingFace")
    parser.add_argument("--file",  default=DEFAULT_FILE, help="Nombre del archivo GGUF")
    parser.add_argument("--dir",   default=str(DEFAULT_DIR), help="Directorio destino")
    parser.add_argument("--token", default=os.getenv("HF_TOKEN"),
                        help="Token HuggingFace (o variable HF_TOKEN)")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    dest_dir = Path(args.dir)
    dest_file = dest_dir / args.file

    if dest_file.exists():
        size_mb = dest_file.stat().st_size / (1024 ** 2)
        console.print(f"[yellow]Ya existe:[/] {dest_file} ({size_mb:.0f} MB)")
        console.print("Usa [bold]--file[/] con otro nombre para descargar una versión diferente.")
        return

    dest_dir.mkdir(parents=True, exist_ok=True)

    console.print(f"[cyan]Descargando[/] {args.repo}/{args.file}")
    console.print(f"[dim]Destino:[/] {dest_file}")

    try:
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            DownloadColumn(),
            console=console,
            transient=False,
        ):
            path = hf_hub_download(
                repo_id=args.repo,
                filename=args.file,
                local_dir=str(dest_dir),
                token=args.token,
            )

        size_mb = Path(path).stat().st_size / (1024 ** 2)
        console.print(f"\n[bold green]Descargado:[/] {path} ({size_mb:.0f} MB)")
        console.print(
            f"\nPara usarlo:\n"
            f"  [cyan]export MODEL_PATH={path}[/]\n"
            f"  [cyan]just stack start[/]"
        )

    except Exception as exc:
        console.print(f"[bold red]Error al descargar:[/] {exc}")
        console.print(
            "\nAlternativas:\n"
            "  • Descarga manual desde https://huggingface.co/Qwen/Qwen2-0.5B-Instruct-GGUF\n"
            "  • Usa un token HF: [cyan]HF_TOKEN=... just setup download-model[/]"
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
