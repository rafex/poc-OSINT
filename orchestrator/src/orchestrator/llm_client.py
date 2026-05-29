"""LLM client con cadena de proveedores configurable.

Dos proveedores disponibles:

  openai-compat  — cualquier API compatible con el SDK de OpenAI
                   (Groq, DeepSeek, OpenRouter, Together AI, Ollama, etc.)
                   Requiere: PROVIDER_LLM_BASE_URL + PROVIDER_LLM_API_KEY

  local          — llama-server corriendo localmente (llama.cpp)
                   No requiere API key. URL configurada por LLAMA_SERVER_URL.

Orden de prioridad:
  LLM_PROVIDER=openai-compat|local   ← default
  LLM_PROVIDER=local                 ← solo local, sin APIs externas
  LLM_PROVIDER=openai-compat         ← solo remoto, sin fallback

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

_DEFAULT_CHAIN = "openai-compat|local"

# Límite de caracteres enviados al LLM.
# Local (Pi): más ajustado. Remoto: más holgado — se comparte el mismo campo.
_MAX_OUTPUT_CHARS = 3000

# ── Registro de proveedores ────────────────────────────────────────────────────
_REGISTRY: dict[str, dict] = {
    "openai-compat": {
        "api_key_env":   "PROVIDER_LLM_API_KEY",   # requerida
        "base_url_env":  "PROVIDER_LLM_BASE_URL",  # requerida (ej: https://api.groq.com/openai/v1)
        "model_env":     "PROVIDER_LLM_MODEL",
        "default_model": "llama-3.1-8b-instant",
        "max_tokens":    1024,
        "timeout":       60.0,
    },
    "local": {
        "api_key_env":   None,
        "base_url_env":  None,  # construida en runtime desde LLAMA_SERVER_URL
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

        if name == "openai-compat":
            api_key = os.getenv("PROVIDER_LLM_API_KEY", "").strip()
            base_url = os.getenv("PROVIDER_LLM_BASE_URL", "").strip()
            if not api_key or not base_url:
                log.debug(
                    "Proveedor 'openai-compat' omitido: "
                    "PROVIDER_LLM_API_KEY o PROVIDER_LLM_BASE_URL no definidas."
                )
                continue
            model = os.getenv("PROVIDER_LLM_MODEL", spec["default_model"])

        elif name == "local":
            api_key = "local"
            server = os.getenv("LLAMA_SERVER_URL", "http://localhost:8080").rstrip("/")
            base_url = f"{server}/v1"
            model = os.getenv("LOCAL_MODEL_NAME", spec["default_model"])

        else:
            continue  # inalcanzable dado el check en _REGISTRY

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
            "Cadena vacía. Revisa LLM_PROVIDER y las variables de configuración. "
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
