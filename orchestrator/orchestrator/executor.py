"""Podman execution layer — runs PHOMBER inside the container."""

import re
import subprocess
from dataclasses import dataclass

CONTAINER_NAME = "phomber"
# -s (silent): suprime el banner/logo de PHOMBER, necesario para ejecución
# no-interactiva desde el orquestador (sin TTY asignado al proceso).
PHOMBER_CMD = ["phomber", "-s"]

# Explicit whitelist: only these flags reach the container.
_ALLOWED_FLAGS: frozenset[str] = frozenset({
    "-p", "--phone",
    "-n", "--number",
    "--output", "-o",
})

# Targets must be phone-number-like or safe identifiers only.
_TARGET_PATTERN = re.compile(r"^\+?[\d\-\s\(\)]{7,20}$")


@dataclass
class ExecutionResult:
    stdout: str
    stderr: str
    returncode: int

    @property
    def combined(self) -> str:
        parts = []
        if self.stdout.strip():
            parts.append(self.stdout.strip())
        if self.stderr.strip():
            parts.append(f"[stderr]\n{self.stderr.strip()}")
        return "\n".join(parts)


def _sanitize(args: list[str]) -> list[str]:
    sanitized: list[str] = []
    i = 0
    while i < len(args):
        arg = args[i]
        if arg.startswith("-"):
            if arg not in _ALLOWED_FLAGS:
                raise ValueError(f"Flag not in whitelist: {arg!r}")
            sanitized.append(arg)
            # Next token is the flag's value — validate it
            i += 1
            if i < len(args):
                value = args[i]
                # Strip whitespace from phone numbers before validating
                clean = re.sub(r"[\s]", "", value)
                if not _TARGET_PATTERN.match(clean):
                    raise ValueError(f"Invalid target value: {value!r}")
                sanitized.append(clean)
        else:
            raise ValueError(f"Positional argument not allowed: {arg!r}")
        i += 1
    return sanitized


def run_phomber(args: list[str], timeout: int = 90) -> ExecutionResult:
    """Execute PHOMBER inside the Podman container with sanitized arguments."""
    safe_args = _sanitize(args)
    cmd = ["podman", "exec", CONTAINER_NAME] + PHOMBER_CMD + safe_args

    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return ExecutionResult(stdout="", stderr="Command timed out.", returncode=-1)
    except FileNotFoundError:
        return ExecutionResult(
            stdout="",
            stderr="'podman' not found. Is Podman installed?",
            returncode=-1,
        )

    return ExecutionResult(
        stdout=proc.stdout,
        stderr=proc.stderr,
        returncode=proc.returncode,
    )
