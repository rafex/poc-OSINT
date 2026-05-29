# Uso de la PoC

Esta guía asume que el stack está activo (contenedor PHOMBER corriendo
y al menos un proveedor LLM disponible).

Para levantar el stack: ver [local-validation.md](local-validation.md)
o [raspberry-pi.md](raspberry-pi.md).

---

## Consulta rápida

```bash
just q "+52 55 1234 5678"
```

Alias de alto nivel para `just osint query`. Acepta el número en cualquier
formato estándar internacional.

---

## Comandos de consulta

### Consulta directa

```bash
just osint query "+52 55 1234 5678"
just osint query "+34 91 000 0000"
just osint query "+1 800 555 0199"
```

El número puede incluir espacios, guiones o paréntesis. El orquestador
los normaliza antes de pasárselos a PHOMBER.

### Modo interactivo

```bash
just osint interactive
```

Abre un prompt donde puedes escribir la consulta en lenguaje natural:

```
╔══════════════════════════════════════════╗
║   OSINT-SLM PoC  │  edge-osint-lab       ║
║   PHOMBER + [openai-compat|local] + Podman ║
╚══════════════════════════════════════════╝

Query: busca información sobre el número +52 55 1234 5678
```

### Salida raw de PHOMBER (sin LLM)

Útil para depurar o ver exactamente qué devuelve PHOMBER:

```bash
just osint raw "-p +525512345678"
```

---

## Ejemplo de flujo completo

```bash
$ just q "+52 55 1234 5678"

╔══════════════════════════════════════════╗
║   OSINT-SLM PoC  │  edge-osint-lab       ║
║   PHOMBER + [openai-compat|local] + Podman ║
╚══════════════════════════════════════════╝

[*] Query: +52 55 1234 5678

[*] PHOMBER args: -p +525512345678

─── Raw output ──────────────────────────────
[+] Country: Mexico
[+] Carrier: Telcel
[+] Line type: mobile
[+] Location: Ciudad de México
─────────────────────────────────────────────

[*] Sending to LLM for interpretation…

─── LLM interpretation  [openai-compat] ────
El número pertenece a México y corresponde a una línea
móvil operada por Telcel, con origen en la Ciudad de México.

Inference: podría tratarse de un número activo en la red
GSM/LTE de Telcel en el área metropolitana.
─────────────────────────────────────────────
```

El campo entre corchetes indica qué proveedor respondió: `[openai-compat]`, `[local]` o `[none]` si todos fallaron.

---

## Forzar un proveedor específico

```bash
# Solo proveedor remoto (openai-compat)
LLM_PROVIDER=openai-compat just q "+52 55 1234 5678"

# Solo modelo local (sin APIs externas)
LLM_PROVIDER=local just q "+52 55 1234 5678"

# Remoto con fallback local (default)
LLM_PROVIDER=openai-compat|local just q "+52 55 1234 5678"
```

La variable en la línea de comando tiene prioridad sobre el `.env`.

---

## Ver el camino de fallback

Con `LOG_LEVEL=DEBUG` los logs muestran exactamente qué proveedores
se intentaron y por qué se pasó al siguiente:

```bash
LOG_LEVEL=DEBUG just q "+52 55 1234 5678"
```

Los logs van a `stderr`. Para verlos separados:

```bash
# Solo logs (stderr)
LOG_LEVEL=DEBUG just q "+52 55 1234 5678" 2>/tmp/osint-debug.log
cat /tmp/osint-debug.log

# Logs y salida juntos
LOG_LEVEL=DEBUG just q "+52 55 1234 5678" 2>&1
```

Ejemplo con proveedor remoto caído:

```
12:34:56 [INFO    ] orchestrator.llm_client — Cadena de proveedores: openai-compat → local
12:34:56 [INFO    ] orchestrator.llm_client — Intentando proveedor: openai-compat  modelo=llama-3.1-8b-instant
12:34:57 [WARNING ] orchestrator.llm_client — 'openai-compat': APIConnectionError. Continuando cadena.
12:34:57 [INFO    ] orchestrator.llm_client — Intentando proveedor: local  modelo=qwen2-0.5b-instruct-q4_k_m
12:34:59 [INFO    ] orchestrator.llm_client — 'local' respondió correctamente.
```

---

## Verificar el stack antes de consultar

```bash
just osint check
```

Ejecuta `make check-container` y `make check-health`:
- Verifica que el contenedor PHOMBER esté activo.
- Verifica que llama-server esté respondiendo (si `local` está en la cadena).
- Muestra el estado de las variables del proveedor remoto.

---

## Instalar el comando `osint` globalmente

El `pyproject.toml` define un script de entrada:

```bash
uv tool install .
```

Después puedes usarlo directamente:
```bash
osint "+52 55 1234 5678"
osint  # modo interactivo
```

---

## Flujo de desarrollo

Si estás modificando el código:

```bash
make install-dev
just dev fix        # format → lint → typecheck
just dev ci         # pipeline completo
just dev logs-llama # logs de llama-server en tiempo real
just dev shell      # shell en el contenedor PHOMBER
```

---

## Notas sobre el formato de números

| Entrada | Normalizado | Válido |
|---|---|---|
| `+52 55 1234 5678` | `+525512345678` | ✓ |
| `+34-91-000-0000` | `+34910000000` | ✓ |
| `(800) 555-0199` | No detectado | ✗ (falta prefijo de país) |
| `+1 800 555 0199` | `+18005550199` | ✓ |

Siempre incluye el prefijo de país (`+52`, `+34`, `+1`, etc.) para mejores resultados.

---

## Consideraciones éticas

- Usa esta herramienta solo sobre números propios o con consentimiento explícito.
- Los resultados dependen de fuentes públicas disponibles en el momento.
- PHOMBER no realiza intrusión ni accede a sistemas privados.
- El SLM puede cometer errores de interpretación; las inferencias están
  marcadas explícitamente con `Inference:` en la respuesta.
