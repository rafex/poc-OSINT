#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "rich>=13",
#     "questionary>=2.0",
# ]
# ///
"""
Wizard interactivo para configurar .env en edge-osint-lab.

Detecta hardware (CPU, RAM), descubre modelos GGUF y llama-server,
y guía al usuario paso a paso para generar una configuración adaptada.

Uso:
    uv run --script scripts/python/setup_wizard.py
    just wizard
"""

import os
import platform
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

import questionary
from rich import box
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

console = Console()

# ── Rutas de búsqueda ─────────────────────────────────────────────────────────

_MODEL_SEARCH_DIRS: list[Path] = [
    Path("/srv/models/gguf"),
    Path("/srv/models"),
    Path.home() / "models",
    Path.home() / ".local" / "share" / "models",
    Path("/opt/models"),
    Path("/data/models"),
    Path("/mnt/models"),
]

_LLAMA_BIN_CANDIDATES: list[Path] = [
    Path("/usr/local/bin/llama-server"),
    Path("/usr/bin/llama-server"),
    Path.home() / "llama.cpp" / "build" / "bin" / "llama-server",
    Path("/opt/llama.cpp/build/bin/llama-server"),
]

_PROVIDER_PRESETS: dict[str, dict] = {
    "Groq  (rapido, tier gratuito)": {
        "base_url": "https://api.groq.com/openai/v1",
        "models":   ["llama-3.1-8b-instant", "llama-3.3-70b-versatile", "gemma2-9b-it"],
        "key_hint": "console.groq.com/keys",
    },
    "DeepSeek  (economico, alta calidad)": {
        "base_url": "https://api.deepseek.com/v1",
        "models":   ["deepseek-chat", "deepseek-reasoner"],
        "key_hint": "platform.deepseek.com/api_keys",
    },
    "OpenRouter  (multiples modelos)": {
        "base_url": "https://openrouter.ai/api/v1",
        "models":   ["meta-llama/llama-3.1-8b-instruct:free", "openai/gpt-4o-mini"],
        "key_hint": "openrouter.ai/keys",
    },
    "URL personalizada": {
        "base_url": "",
        "models":   [],
        "key_hint": "",
    },
}

# Orden y comentarios para el .env generado
_ENV_ORDER = [
    "LLM_PROVIDER",
    "PROVIDER_LLM_BASE_URL", "PROVIDER_LLM_API_KEY", "PROVIDER_LLM_MODEL",
    "LLAMA_SERVER_URL", "LOCAL_MODEL_NAME",
    "MODEL_DIR", "MODEL_FILE",
    "LLAMA_BIN",
    "LLAMA_PORT", "LLAMA_THREADS", "LLAMA_CTX",
    "CONTAINER_NAME",
    "LOG_LEVEL",
]

_ENV_COMMENTS: dict[str, str] = {
    "LLM_PROVIDER":          "Cadena de proveedores: openai-compat|local, local, openai-compat",
    "PROVIDER_LLM_BASE_URL": "URL base del API compatible con OpenAI",
    "PROVIDER_LLM_API_KEY":  "API key del proveedor remoto",
    "PROVIDER_LLM_MODEL":    "Modelo a usar en el proveedor remoto",
    "LLAMA_SERVER_URL":      "URL de llama-server local",
    "LOCAL_MODEL_NAME":      "Nombre descriptivo del modelo local (solo logs)",
    "MODEL_DIR":             "Directorio donde residen los archivos GGUF",
    "MODEL_FILE":            "Archivo GGUF dentro de MODEL_DIR",
    "LLAMA_BIN":             "Ruta explicita a llama-server (opcional, auto-descubierto si no se define)",
    "LLAMA_PORT":            "Puerto de llama-server",
    "LLAMA_THREADS":         "Hilos de CPU para llama-server",
    "LLAMA_CTX":             "Tamano de contexto en tokens",
    "CONTAINER_NAME":        "Nombre del contenedor PHOMBER",
    "LOG_LEVEL":             "Nivel de log: DEBUG | INFO | WARNING | ERROR",
}


# ── Hardware ──────────────────────────────────────────────────────────────────

@dataclass
class HardwareInfo:
    cpu_cores: int
    ram_gb:    int
    os_name:   str


def _detect_hardware() -> HardwareInfo:
    return HardwareInfo(
        cpu_cores=os.cpu_count() or 1,
        ram_gb=_detect_ram_gb(),
        os_name=_detect_os_name(),
    )


def _detect_ram_gb() -> int:
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            if line.startswith("MemTotal:"):
                return int(line.split()[1]) // 1024 // 1024
    except Exception:
        pass
    try:
        out = subprocess.run(
            ["sysctl", "-n", "hw.memsize"],
            capture_output=True, text=True, timeout=5,
        ).stdout.strip()
        return int(out) // (1024 ** 3)
    except Exception:
        pass
    return 0


def _detect_os_name() -> str:
    if platform.system() == "Darwin":
        return f"macOS {platform.mac_ver()[0]}"
    try:
        info = {
            k: v.strip('"')
            for line in Path("/etc/os-release").read_text().splitlines()
            if "=" in line
            for k, _, v in [line.partition("=")]
        }
        return info.get("PRETTY_NAME", "Linux")
    except Exception:
        return platform.system()


# ── Model discovery ───────────────────────────────────────────────────────────

@dataclass
class GGUFModel:
    path:       Path
    size_bytes: int

    @property
    def filename(self) -> str:
        return self.path.name

    @property
    def directory(self) -> Path:
        return self.path.parent

    @property
    def size_str(self) -> str:
        mb = self.size_bytes / (1024 ** 2)
        return f"{mb / 1024:.1f} GB" if mb >= 1024 else f"{mb:.0f} MB"

    def fits_in_ram(self, ram_gb: int) -> bool:
        needed_gb = (self.size_bytes / (1024 ** 2)) * 1.3 / 1024
        return ram_gb > 0 and needed_gb <= ram_gb * 0.7

    def ram_needed_str(self) -> str:
        gb = (self.size_bytes / (1024 ** 2)) * 1.3 / 1024
        return f"~{gb:.1f} GB RAM"


def _discover_models() -> list[GGUFModel]:
    search_dirs = list(_MODEL_SEARCH_DIRS)
    if env_dir := os.getenv("MODEL_DIR", ""):
        search_dirs.insert(0, Path(env_dir))

    models, seen = [], set()
    for base in search_dirs:
        if not base.exists():
            continue
        for pattern in ("*.gguf", "*/*.gguf"):
            for p in sorted(base.glob(pattern)):
                if p in seen:
                    continue
                seen.add(p)
                try:
                    size = p.stat().st_size
                    if size > 100_000:
                        models.append(GGUFModel(path=p, size_bytes=size))
                except OSError:
                    pass
    return sorted(models, key=lambda m: m.size_bytes)


def _discover_llama_server() -> Path | None:
    if found := shutil.which("llama-server"):
        return Path(found)
    for candidate in _LLAMA_BIN_CANDIDATES:
        if candidate.exists() and os.access(candidate, os.X_OK):
            return candidate
    return None


# ── .env helpers ──────────────────────────────────────────────────────────────

def _load_env(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    result = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        result[key.strip()] = val.strip()
    return result


def _mask_key(val: str) -> str:
    if len(val) <= 8:
        return "●" * len(val)
    return val[:4] + "●●●●●●●●" + val[-4:]


# ── Smart defaults ────────────────────────────────────────────────────────────

def _suggest_threads(hw: HardwareInfo) -> int:
    c = hw.cpu_cores
    if c <= 4:
        return c
    if c <= 8:
        return c - 1
    return max(c - 2, 6)


def _suggest_ctx(hw: HardwareInfo) -> int:
    if hw.ram_gb >= 32:
        return 8192
    if hw.ram_gb >= 16:
        return 4096
    if hw.ram_gb >= 8:
        return 2048
    return 1024


# ── UI helpers ────────────────────────────────────────────────────────────────

def _ask(prompt: str, default: str = "", password: bool = False) -> str:
    fn = questionary.password if password else questionary.text
    val = fn(prompt, default="" if password else default).ask()
    if val is None:
        console.print("\n[yellow]Cancelado.[/]")
        sys.exit(0)
    return val.strip()


def _confirm(prompt: str, default: bool = True) -> bool:
    val = questionary.confirm(prompt, default=default).ask()
    if val is None:
        console.print("\n[yellow]Cancelado.[/]")
        sys.exit(0)
    return val


def _select(prompt: str, choices: list) -> str:
    val = questionary.select(prompt, choices=choices).ask()
    if val is None:
        console.print("\n[yellow]Cancelado.[/]")
        sys.exit(0)
    return val


# ── Wizard ────────────────────────────────────────────────────────────────────

def run_wizard() -> dict[str, str]:
    env: dict[str, str] = {}

    # ── Bienvenida ────────────────────────────────────────────────────────────
    console.print(Panel.fit(
        "[bold cyan]edge-osint-lab[/] — Wizard de configuración\n"
        "[dim]Genera .env adaptado a tu sistema detectando hardware y rutas disponibles[/]",
        border_style="cyan",
    ))
    console.print()

    # ── Hardware ──────────────────────────────────────────────────────────────
    hw = _detect_hardware()
    hw_table = Table(box=box.SIMPLE, show_header=False, padding=(0, 2))
    hw_table.add_column(style="dim", width=8)
    hw_table.add_column(style="cyan")
    hw_table.add_row("CPU",  f"{hw.cpu_cores} cores")
    hw_table.add_row("RAM",  f"{hw.ram_gb} GB" if hw.ram_gb else "desconocida")
    hw_table.add_row("OS",   hw.os_name)
    console.print("[bold]Hardware detectado[/]")
    console.print(hw_table)

    # ── llama-server ──────────────────────────────────────────────────────────
    llama_bin = _discover_llama_server()
    if llama_bin:
        console.print(f"[green]✓[/] llama-server: [cyan]{llama_bin}[/]")
    else:
        console.print("[yellow]–[/] llama-server: no encontrado (se buscará al arrancar)")
    console.print()

    # ── Cargar .env existente ─────────────────────────────────────────────────
    existing = _load_env(Path(".env"))
    if existing:
        console.print(f"[dim].env existente cargado — se usará como base para los valores por defecto[/]\n")

    def ex(key: str, fallback: str = "") -> str:
        return existing.get(key, fallback)

    step = 1

    # ═══════════════════════════════════════════════════════════════════════
    # Paso 1 — Cadena de proveedores
    # ═══════════════════════════════════════════════════════════════════════
    console.rule(f"[bold]Paso {step} — Cadena de proveedores LLM[/]")
    step += 1

    chain = _select(
        "Proveedores a usar:",
        choices=[
            questionary.Choice(
                "Remoto (openai-compat) + Local fallback  [recomendado]",
                value="openai-compat|local",
            ),
            questionary.Choice(
                "Solo local — llama.cpp sin APIs externas",
                value="local",
            ),
            questionary.Choice(
                "Solo remoto — sin fallback local",
                value="openai-compat",
            ),
        ],
    )
    env["LLM_PROVIDER"] = chain
    use_remote = "openai-compat" in chain
    use_local  = "local" in chain

    # ═══════════════════════════════════════════════════════════════════════
    # Paso 2 — Proveedor remoto
    # ═══════════════════════════════════════════════════════════════════════
    if use_remote:
        console.rule(f"[bold]Paso {step} — Proveedor remoto (openai-compat)[/]")
        step += 1

        preset_name = _select("Selecciona el proveedor:", choices=list(_PROVIDER_PRESETS.keys()))
        preset = _PROVIDER_PRESETS[preset_name]

        if preset["base_url"]:
            base_url = preset["base_url"]
            console.print(f"  [dim]BASE_URL: {base_url}[/]")
        else:
            base_url = _ask(
                "BASE_URL del API (incluye la version, ej: https://api.groq.com/openai/v1):",
                default=ex("PROVIDER_LLM_BASE_URL"),
            )
        env["PROVIDER_LLM_BASE_URL"] = base_url

        if preset["key_hint"]:
            console.print(f"  [dim]Obtén tu key en: {preset['key_hint']}[/]")

        current_key = ex("PROVIDER_LLM_API_KEY")
        if current_key:
            console.print(f"  [dim]API key actual: {_mask_key(current_key)}[/]")
            if _confirm("  ¿Cambiar la API key?", default=False):
                env["PROVIDER_LLM_API_KEY"] = _ask("Nueva API key:", password=True)
            else:
                env["PROVIDER_LLM_API_KEY"] = current_key
        else:
            env["PROVIDER_LLM_API_KEY"] = _ask("API key:", password=True)

        if preset["models"]:
            model_choices = preset["models"] + ["Escribir manualmente"]
            model_sel = _select("Modelo:", choices=model_choices)
            if model_sel == "Escribir manualmente":
                model_sel = _ask("Nombre del modelo:", default=ex("PROVIDER_LLM_MODEL", preset["models"][0]))
        else:
            model_sel = _ask(
                "Nombre del modelo:",
                default=ex("PROVIDER_LLM_MODEL", "llama-3.1-8b-instant"),
            )
        env["PROVIDER_LLM_MODEL"] = model_sel

    # ═══════════════════════════════════════════════════════════════════════
    # Paso N — llama.cpp local
    # ═══════════════════════════════════════════════════════════════════════
    if use_local:
        console.rule(f"[bold]Paso {step} — llama.cpp local[/]")
        step += 1

        env["LLAMA_SERVER_URL"] = _ask(
            "URL de llama-server:",
            default=ex("LLAMA_SERVER_URL", "http://localhost:8080"),
        )

        # ── Descubrimiento de modelos ─────────────────────────────────────
        console.print("[dim]Buscando modelos GGUF…[/]")
        models = _discover_models()

        if models:
            console.print(f"[green]✓[/] {len(models)} modelo(s) encontrado(s)\n")

            model_choices = []
            for m in models:
                fits   = m.fits_in_ram(hw.ram_gb)
                star   = " ★" if fits else ""
                label  = f"{m.filename}  ({m.size_str}, {m.ram_needed_str()}){star}"
                model_choices.append(questionary.Choice(title=label, value=m))
            model_choices.append(questionary.Choice("Introducir ruta manualmente", value=None))

            if hw.ram_gb:
                console.print(f"  [dim](★ = cabe cómodamente en {hw.ram_gb} GB RAM)[/]\n")

            selected: GGUFModel | None = _select("Selecciona el modelo GGUF:", choices=model_choices)
        else:
            console.print("[yellow]–[/] No se encontraron modelos GGUF en rutas comunes.")
            selected = None

        if selected is None:
            model_dir  = _ask("Directorio de modelos (MODEL_DIR):", default=ex("MODEL_DIR", str(Path.home() / "models")))
            model_file = _ask("Nombre del archivo GGUF (MODEL_FILE):", default=ex("MODEL_FILE", ""))
            default_name = Path(model_file).stem if model_file else ""
            local_name = _ask("Nombre descriptivo (LOCAL_MODEL_NAME):", default=ex("LOCAL_MODEL_NAME", default_name))
        else:
            model_dir  = str(selected.directory)
            model_file = selected.filename
            local_name = ex("LOCAL_MODEL_NAME", selected.path.stem)
            console.print(f"  [dim]MODEL_DIR  → {model_dir}[/]")
            console.print(f"  [dim]MODEL_FILE → {model_file}[/]")

        env["MODEL_DIR"]       = model_dir
        env["MODEL_FILE"]      = model_file
        env["LOCAL_MODEL_NAME"] = local_name

        env["LLAMA_PORT"] = _ask(
            "Puerto de llama-server (LLAMA_PORT):",
            default=ex("LLAMA_PORT", "8080"),
        )

        suggested_threads = str(_suggest_threads(hw))
        env["LLAMA_THREADS"] = _ask(
            f"Hilos de CPU (LLAMA_THREADS) — {hw.cpu_cores} cores detectados:",
            default=ex("LLAMA_THREADS", suggested_threads),
        )

        suggested_ctx = str(_suggest_ctx(hw))
        ram_label = f"{hw.ram_gb} GB RAM" if hw.ram_gb else "RAM desconocida"
        env["LLAMA_CTX"] = _ask(
            f"Contexto en tokens (LLAMA_CTX) — sugerido para {ram_label}:",
            default=ex("LLAMA_CTX", suggested_ctx),
        )

        # ── LLAMA_BIN opcional ────────────────────────────────────────────
        if llama_bin:
            default_paths = {
                Path.home() / "llama.cpp" / "build" / "bin" / "llama-server",
            } | {p for p in _LLAMA_BIN_CANDIDATES if shutil.which("llama-server")}

            if llama_bin not in default_paths:
                console.print(f"\n  [dim]llama-server en:[/] [cyan]{llama_bin}[/]")
                console.print("  [dim](el script lo descubrirá vía PATH automáticamente)[/]")
                if _confirm("  ¿Fijar LLAMA_BIN en .env de todas formas?", default=False):
                    env["LLAMA_BIN"] = str(llama_bin)
            else:
                console.print(f"\n  [dim]llama-server: {llama_bin} — auto-descubierto, no se fija en .env[/]")

    # ═══════════════════════════════════════════════════════════════════════
    # Paso final — Opciones generales
    # ═══════════════════════════════════════════════════════════════════════
    console.rule(f"[bold]Paso {step} — Opciones generales[/]")

    env["CONTAINER_NAME"] = _ask(
        "Nombre del contenedor PHOMBER:",
        default=ex("CONTAINER_NAME", "phomber"),
    )

    env["LOG_LEVEL"] = _select(
        "Nivel de log:",
        choices=[
            questionary.Choice("WARNING — solo errores y avisos  [recomendado]", value="WARNING"),
            questionary.Choice("INFO    — incluye cadena de proveedores",         value="INFO"),
            questionary.Choice("DEBUG   — todo: fallbacks, URLs, tiempos",       value="DEBUG"),
        ],
    )

    return env


# ── Resumen y escritura ───────────────────────────────────────────────────────

def _print_summary(env: dict[str, str]) -> None:
    console.rule("[bold]Resumen[/]")
    t = Table(box=box.SIMPLE, show_header=False, padding=(0, 1))
    t.add_column(style="cyan", no_wrap=True)
    t.add_column()
    for key in _ENV_ORDER:
        if key not in env:
            continue
        val = env[key]
        display = _mask_key(val) if "KEY" in key else val
        t.add_row(key, display)
    console.print(t)


def _write_env(env: dict[str, str], dest: Path) -> None:
    if dest.exists():
        backup = dest.with_name(".env.bak")
        dest.rename(backup)
        console.print(f"[dim]Backup guardado: {backup}[/]")

    lines: list[str] = [
        "# edge-osint-lab — generado por setup_wizard.py\n",
        "# Edita manualmente o vuelve a ejecutar: just wizard\n",
        "\n",
    ]
    prev_group = ""
    group_map = {
        "LLM_PROVIDER": "providers",
        "PROVIDER_LLM_BASE_URL": "remote", "PROVIDER_LLM_API_KEY": "remote", "PROVIDER_LLM_MODEL": "remote",
        "LLAMA_SERVER_URL": "local", "LOCAL_MODEL_NAME": "local",
        "MODEL_DIR": "model", "MODEL_FILE": "model",
        "LLAMA_BIN": "llama",
        "LLAMA_PORT": "llama", "LLAMA_THREADS": "llama", "LLAMA_CTX": "llama",
        "CONTAINER_NAME": "container",
        "LOG_LEVEL": "log",
    }
    group_headers = {
        "providers": "# ── Cadena de proveedores LLM ───────────────────────────────────────",
        "remote":    "# ── Proveedor remoto (openai-compat) ────────────────────────────────",
        "local":     "# ── llama.cpp local ─────────────────────────────────────────────────",
        "model":     "# ── Modelo GGUF ─────────────────────────────────────────────────────",
        "llama":     "# ── Parametros de llama-server ──────────────────────────────────────",
        "container": "# ── Contenedor ──────────────────────────────────────────────────────",
        "log":       "# ── Logging ─────────────────────────────────────────────────────────",
    }

    for key in _ENV_ORDER:
        if key not in env:
            continue
        group = group_map.get(key, "")
        if group != prev_group:
            if prev_group:
                lines.append("\n")
            lines.append(f"{group_headers.get(group, '')}\n")
            prev_group = group
        comment = _ENV_COMMENTS.get(key, "")
        if comment:
            lines.append(f"# {comment}\n")
        lines.append(f"{key}={env[key]}\n")

    dest.write_text("".join(lines))
    console.print(f"\n[bold green]✓[/] Configuración guardada en [cyan]{dest}[/]")
    console.print("\nPróximos pasos:")
    console.print("  [cyan]make check-deps[/]          — verificar herramientas")
    console.print("  [cyan]make build-image-phomber[/] — construir imagen PHOMBER")
    console.print("  [cyan]just up[/]                  — levantar el stack")
    console.print("  [cyan]just q \"+52 55 1234 5678\"[/] — primera consulta")


# ── Entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    if not sys.stdin.isatty():
        console.print("[red]Error:[/] el wizard requiere una terminal interactiva.")
        sys.exit(1)

    try:
        env = run_wizard()
        console.print()
        _print_summary(env)
        console.print()

        if not _confirm("¿Escribir .env con esta configuración?", default=True):
            console.print("[yellow]Cancelado — no se escribió ningún archivo.[/]")
            return

        _write_env(env, Path(".env"))

    except KeyboardInterrupt:
        console.print("\n[yellow]Cancelado.[/]")
        sys.exit(0)


if __name__ == "__main__":
    main()
