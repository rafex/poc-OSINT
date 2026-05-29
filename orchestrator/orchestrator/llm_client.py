"""LLM client con cadena de proveedores configurable.

Orden de prioridad definido por LLM_PROVIDER (pipe-separated):
  LLM_PROVIDER=groq|deepseek|local   ← default
  LLM_PROVIDER=groq|local
  LLM_PROVIDER=local

Cada proveedor se intenta en orden. Los fallos recuperables avanzan
al siguiente; los fallos de cliente (4xx no-auth) detienen la cadena.
El camino recorrido queda registrado en el logger — transparente al consumidor.
"""

import logging
import os
from dataclasses import dataclass

import openai

log = logging.getLogger(__name__)

_SYSTEM_PROMPT = (
    "You are a concise OSINT analyst assistant. "
    "Interpret the provided tool output and give a brief factual summary. "
    "Respond in the same language as the user query. "
    "Never invent data that is not present in the output. "
    "Clearly mark inferences with 'Inference:' so they are distinguishable from facts."
)

_DEFAULT_CHAIN = "groq|deepseek|local"

# Límite de caracteres enviados al LLM.
# Local (Pi): más ajustado. Remoto: más holgado — se comparte el mismo campo.
_MAX_OUTPUT_CHARS = 3000

# ── Registro de proveedores ────────────────────────────────────────────────────
_REGISTRY: dict[str, dict] = {
    "groq": {
        "base_url":      "https://api.groq.com/openai/v1",
        "api_key_env":   "GROQ_API_KEY",
        "model_env":     "GROQ_MODEL",
        "default_model": "llama-3.1-8b-instant",
        "max_tokens":    1024,
        "timeout":       30.0,
    },
    "deepseek": {
        "base_url":      "https://api.deepseek.com/v1",
        "api_key_env":   "DEEPSEEK_API_KEY",
        "model_env":     "DEEPSEEK_MODEL",
        "default_model": "deepseek-chat",
        "max_tokens":    1024,
        "timeout":       60.0,
    },
    "local": {
        "base_url":      None,  # construida en runtime desde LLAMA_SERVER_URL
        "api_key_env":   None,
        "model_env":     "LOCAL_MODEL_NAME",
        "default_model": "local",
        "max_tokens":    400,   # conservador para Pi 4B
        "timeout":       120.0,
    },
}

# Errores que permiten continuar al siguiente proveedor en la cadena.
_RECOVERABLE: tuple[type[openai.OpenAIError], ...] = (
    openai.AuthenticationError,
    openai.APIConnectionError,
    openai.APITimeoutError,
    openai.RateLimitError,
)


@dataclass
class LLMResponse:
    text: str
    provider: str  # nombre del proveedor que respondió, o "none"


# ── Construcción de la cadena ──────────────────────────────────────────────────

def _resolve_chain() -> list[dict]:
    """Construye la lista ordenada de configuraciones de proveedor."""
    names = os.getenv("LLM_PROVIDER", _DEFAULT_CHAIN).split("|")
    chain: list[dict] = []

    for raw in names:
        name = raw.strip().lower()
        if name not in _REGISTRY:
            log.warning("Proveedor desconocido '%s' en LLM_PROVIDER — omitido.", name)
            continue

        spec = _REGISTRY[name]

        # Resolver API key
        if spec["api_key_env"]:
            api_key = os.getenv(spec["api_key_env"], "").strip()
            if not api_key:
                log.debug(
                    "Proveedor '%s' omitido: %s no definida.",
                    name, spec["api_key_env"],
                )
                continue
        else:
            api_key = "local"  # llama-server no valida la key

        # Resolver base_url
        if name == "local":
            server = os.getenv("LLAMA_SERVER_URL", "http://localhost:8080").rstrip("/")
            base_url = f"{server}/v1"
        else:
            base_url = spec["base_url"]

        # Resolver modelo
        model = os.getenv(spec["model_env"], spec["default_model"]) if spec["model_env"] else spec["default_model"]

        chain.append({
            "name":       name,
            "base_url":   base_url,
            "api_key":    api_key,
            "model":      model,
            "max_tokens": spec["max_tokens"],
            "timeout":    spec["timeout"],
        })

    return chain


# ── Llamada a un proveedor ─────────────────────────────────────────────────────

def _build_messages(raw_output: str, query: str) -> list[dict]:
    truncated = raw_output[:_MAX_OUTPUT_CHARS]
    if len(raw_output) > _MAX_OUTPUT_CHARS:
        truncated += "\n[... output truncated ...]"
    return [
        {"role": "system", "content": _SYSTEM_PROMPT},
        {"role": "user",   "content": f"User query: {query}\n\nPHOMBER output:\n{truncated}"},
    ]


def _call(config: dict, messages: list[dict]) -> str:
    client = openai.OpenAI(
        api_key=config["api_key"],
        base_url=config["base_url"],
        timeout=config["timeout"],
        max_retries=0,  # los reintentos los gestiona la cadena
    )
    response = client.chat.completions.create(
        model=config["model"],
        messages=messages,  # type: ignore[arg-type]
        max_tokens=config["max_tokens"],
        temperature=0.1,
    )
    return response.choices[0].message.content.strip()


# ── API pública ────────────────────────────────────────────────────────────────

def interpret_osint(raw_output: str, original_query: str) -> LLMResponse:
    """Interpreta la salida de PHOMBER usando la cadena de proveedores configurada.

    El consumidor recibe siempre un LLMResponse. El camino recorrido
    (proveedor intentado, motivo de fallo, proveedor final) se registra
    exclusivamente en el logger — no se expone en el valor de retorno.
    """
    chain = _resolve_chain()

    if not chain:
        log.error(
            "Cadena vacía. Revisa LLM_PROVIDER y las variables de API key. "
            "Proveedores disponibles: %s",
            ", ".join(_REGISTRY),
        )
        return LLMResponse(
            text="[LLM no disponible] Sin proveedores configurados. Revisa .env y LLM_PROVIDER.",
            provider="none",
        )

    log.info(
        "Cadena de proveedores: %s",
        " → ".join(c["name"] for c in chain),
    )

    messages = _build_messages(raw_output, original_query)

    for config in chain:
        name = config["name"]
        log.info("Intentando proveedor: %s  modelo=%s  url=%s", name, config["model"], config["base_url"])

        try:
            text = _call(config, messages)
            log.info("Proveedor '%s' respondió correctamente.", name)
            return LLMResponse(text=text, provider=name)

        except openai.AuthenticationError as exc:
            log.warning(
                "Proveedor '%s': AuthenticationError — %s. Continuando cadena.",
                name, exc.message,
            )
        except openai.APIConnectionError as exc:
            log.warning(
                "Proveedor '%s': conexión fallida — %s. Continuando cadena.",
                name, str(exc),
            )
        except openai.APITimeoutError:
            log.warning("Proveedor '%s': timeout. Continuando cadena.", name)
        except openai.RateLimitError as exc:
            log.warning(
                "Proveedor '%s': rate limit — %s. Continuando cadena.",
                name, exc.message,
            )
        except openai.APIStatusError as exc:
            if exc.status_code >= 500:
                log.warning(
                    "Proveedor '%s': error de servidor HTTP %d. Continuando cadena.",
                    name, exc.status_code,
                )
            else:
                # 4xx distinto de auth/rate → problema en la petición, no reintentable
                log.error(
                    "Proveedor '%s': error de cliente HTTP %d — %s. Deteniendo cadena.",
                    name, exc.status_code, exc.message,
                )
                return LLMResponse(
                    text=f"[Error LLM] {name} devolvió HTTP {exc.status_code}. Revisa el prompt o la configuración.",
                    provider=name,
                )

    log.error("Todos los proveedores de la cadena fallaron.")
    return LLMResponse(
        text="[LLM no disponible] Todos los proveedores fallaron. Ejecuta con LOG_LEVEL=DEBUG para diagnóstico.",
        provider="none",
    )
