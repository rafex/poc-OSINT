"""Entry point for the OSINT-SLM orchestrator."""

import logging
import os
import sys

from .executor import run_phomber
from .intent_parser import parse_intent
from .llm_client import interpret_osint


def _setup_logging() -> None:
    level = os.getenv("LOG_LEVEL", "WARNING").upper()
    logging.basicConfig(
        level=level,
        format="%(asctime)s [%(levelname)-8s] %(name)s — %(message)s",
        datefmt="%H:%M:%S",
        stream=sys.stderr,  # separado de la salida al usuario
    )


def _banner() -> None:
    provider_chain = os.getenv("LLM_PROVIDER", "groq|deepseek|local")
    print("╔══════════════════════════════════════════╗")
    print("║   OSINT-SLM PoC  │  edge-osint-lab       ║")
    print(f"║   PHOMBER + [{provider_chain:<12}] + Podman  ║")
    print("╚══════════════════════════════════════════╝")
    print()


def run(query: str) -> None:
    print(f"[*] Query: {query}\n")

    # 1. Parse intent → PHOMBER args
    try:
        args = parse_intent(query)
    except ValueError as exc:
        print(f"[!] {exc}")
        sys.exit(1)

    print(f"[*] PHOMBER args: {' '.join(args)}")

    # 2. Execute inside container
    result = run_phomber(args)

    print("\n─── Raw output ──────────────────────────────")
    print(result.combined if result.combined else "(empty)")
    print("─────────────────────────────────────────────\n")

    if result.returncode not in (0, None) and not result.stdout:
        print("[!] PHOMBER returned a non-zero exit code with no stdout.")
        print("    Check that the container is running: podman ps")
        sys.exit(1)

    # 3. Interpret via LLM provider chain
    print("[*] Sending to LLM for interpretation…\n")
    interpretation = interpret_osint(result.combined, query)

    print(f"─── LLM interpretation  [{interpretation.provider}] ─────────")
    print(interpretation.text)
    print("─────────────────────────────────────────────")


def main() -> None:
    _setup_logging()
    _banner()

    if len(sys.argv) > 1:
        query = " ".join(sys.argv[1:])
    else:
        try:
            query = input("Query: ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            sys.exit(0)

    if not query:
        print("[!] Empty query.")
        sys.exit(1)

    run(query)


if __name__ == "__main__":
    main()
