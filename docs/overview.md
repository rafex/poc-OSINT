# edge-osint-lab — Visión general

**PoC de Software Libre para OSINT Asistido por IA Local**

Esta prueba de concepto demuestra cómo un Small Language Model (SLM) ejecutado localmente puede actuar como interfaz inteligente sobre herramientas OSINT clásicas como PHOMBER, sin depender de la nube y funcionando en hardware accesible como una Raspberry Pi 4B.

> **Aviso:** Este proyecto es exclusivamente educativo y de investigación.
> El uso de herramientas OSINT sobre personas o entidades sin consentimiento
> puede ser ilegal según la jurisdicción. El autor no se responsabiliza del uso indebido.

---

## Arquitectura

```
┌─────────────────────────────────────────────────────────────────┐
│                    HOST  (Mac / Raspberry Pi 4B)                │
│                                                                   │
│   Usuario                                                         │
│      │                                                            │
│      ▼                                                            │
│   Orquestador Python  (uv run -m orchestrator.main)              │
│      │                                                            │
│      ├─ intent_parser.py  ──→  extrae número del prompt          │
│      │                                                            │
│      ├─ executor.py  ───────→  podman exec phomber               │
│      │                              │                             │
│      │                    ┌─────────┴──────────┐                 │
│      │                    │  PHOMBER            │                 │
│      │                    │  (contenedor Podman)│                 │
│      │                    └─────────┬──────────┘                 │
│      │                              │ stdout / stderr             │
│      │                    ──────────┘                             │
│      │                                                            │
│      └─ llm_client.py  ────→  cadena de proveedores LLM          │
│             │                                                      │
│             ├─ 1. Groq API        (groq.com)          ← rápido   │
│             ├─ 2. DeepSeek API    (deepseek.com)      ← económico│
│             └─ 3. llama-server    (localhost:8080)    ← offline  │
│                       │                                            │
│                  Qwen2 0.5B Q4_K_M (GGUF)                        │
└─────────────────────────────────────────────────────────────────┘
```

El orquestador corre **en el host**. Solo PHOMBER vive dentro de un contenedor Podman. El LLM se resuelve por orden de prioridad: primero los proveedores en la nube configurados, y si todos fallan, el modelo local.

---

## Componentes

| Componente | Tecnología | Dónde corre |
|---|---|---|
| Herramienta OSINT | PHOMBER | Contenedor Podman |
| Orquestador | Python 3.11 + uv | Host |
| LLM primario | Groq API | Nube (groq.com) |
| LLM secundario | DeepSeek API | Nube (deepseek.com) |
| LLM fallback | llama.cpp + Qwen2 0.5B Q4_K_M | Host (local) |
| Build system | Make + módulos `.mk` | Host |
| Task runner | Just + módulos `.just` | Host |
| Compose (validación) | Podman Compose | Host |

---

## Stack tecnológico

| Capa | Elección | Por qué |
|---|---|---|
| Contenedores | Podman | Sin daemon root, compatible OCI, rootless |
| Runtime LLM local | llama.cpp | Eficiente en ARM64, soporte GGUF nativo |
| Modelo local | Qwen2 0.5B Q4_K_M | ~300 MB en RAM, corre en Pi 4B con 4 GB |
| LLM API 1 | Groq (llama-3.1-8b-instant) | Latencia mínima (~200 ms), tier gratuito |
| LLM API 2 | DeepSeek (deepseek-chat) | Alta calidad, contexto 64 k, muy económico |
| Gestor paquetes | uv | 10–100× más rápido que pip, lock file |
| Build | GNU Make + módulos .mk | Estándar, sin dependencias extra |
| Tasks | Just + módulos .just | Ergonómico, puede llamar a make |

---

## Estructura del proyecto

```
poc-OSINT/
│
├── compose.yaml               ← Podman Compose para validación local
├── Makefile                   ← Build: imagen, compilación, lint
├── Justfile                   ← Tasks: setup, run, dev, compose
├── pyproject.toml             ← Proyecto Python (uv)
├── .env.example               ← Variables de entorno (plantilla)
│
├── container/
│   ├── Containerfile          ← Imagen PHOMBER
│   └── Containerfile.llama    ← Imagen llama-server (validación local)
│
├── orchestrator/
│   ├── main.py                ← Entry point CLI
│   ├── executor.py            ← Ejecución segura via podman exec
│   ├── llm_client.py          ← Cadena de proveedores LLM
│   └── intent_parser.py       ← Lenguaje natural → argumentos PHOMBER
│
├── mk/
│   ├── vars.mk                ← Variables compartidas
│   ├── container.mk           ← Targets de contenedor
│   ├── python.mk              ← Targets Python/uv
│   ├── llama.mk               ← Compilación y arranque llama.cpp
│   ├── checks.mk              ← Verificaciones y salud
│   └── compose.mk             ← Gestión Podman Compose
│
├── just/
│   ├── setup.just             ← Preparación del entorno
│   ├── dev.just               ← Flujo de desarrollo
│   ├── stack.just             ← Ciclo de vida del stack (Pi)
│   ├── osint.just             ← Consultas OSINT
│   └── compose.just           ← Stack vía Podman Compose (local)
│
├── scripts/
│   ├── check_deps.py          ← Verifica herramientas del sistema
│   ├── download_model.py      ← Descarga modelo GGUF
│   ├── health_check.py        ← Salud del stack completo
│   └── start_container.sh     ← Setup manual (alternativo)
│
└── docs/
    ├── overview.md            ← Este documento
    ├── installation.md        ← Instalación paso a paso
    ├── configuration.md       ← Variables de entorno
    ├── local-validation.md    ← Validación con Podman Compose
    ├── usage.md               ← Cómo usar la PoC
    ├── raspberry-pi.md        ← Despliegue en Raspberry Pi 4B
    └── reference.md           ← Referencia completa de comandos
```

---

## Regla de oro del build system

```
Just  ──puede llamar──►  Make
Make  ──NO llama──►      Just
```

- **Make** gestiona artefactos: construir imágenes, compilar binarios, empaquetar.
- **Just** orquesta flujos: setup, arrancar servicios, ejecutar consultas.

---

## Documentación

| Documento | Contenido |
|---|---|
| [installation.md](installation.md) | Prerrequisitos e instalación en Mac/Linux |
| [configuration.md](configuration.md) | Variables de entorno, proveedores LLM |
| [local-validation.md](local-validation.md) | Validar la PoC con Podman Compose |
| [usage.md](usage.md) | Consultas OSINT, ejemplos, debugging |
| [raspberry-pi.md](raspberry-pi.md) | Despliegue completo en Raspberry Pi 4B |
| [reference.md](reference.md) | Referencia completa `make` / `just` |
