# edge-osint-lab

PoC de Software Libre / Open Source para OSINT Asistido por IA Local.

**Stack:** PHOMBER + Qwen2 0.5B Q4_K_M (llama.cpp) + Podman + Raspberry Pi 4B

---

## Arquitectura

```
Usuario → Orquestador Python → podman exec → PHOMBER (contenedor)
                    ↑                                ↓
              llama-server  ←──────── stdout/stderr ─┘
              (Qwen2 0.5B)
                    ↓
              Respuesta resumida → Usuario
```

---

## Estructura

```
poc-OSINT/
├── container/
│   └── Containerfile          # Imagen PHOMBER para Podman
├── orchestrator/
│   ├── main.py                # CLI principal
│   ├── executor.py            # Ejecución segura via podman exec
│   ├── llm_client.py          # Cliente HTTP para llama-server
│   └── intent_parser.py       # Lenguaje natural → argumentos PHOMBER
├── scripts/
│   └── start_container.sh     # Iniciar contenedor + llama-server
└── pyproject.toml
```

---

## Requisitos

| Componente | Versión mínima |
|---|---|
| Python | 3.11 |
| Podman | 4.x |
| llama.cpp (`llama-server`) | compilado para ARM64 |
| Modelo | `qwen2-0_5b-instruct-q4_k_m.gguf` |

Hardware recomendado: Raspberry Pi 4B con 8 GB RAM y SSD por USB 3.0.

---

## Instalación

### 1. Clonar y preparar entorno

```bash
git clone https://github.com/rafex/poc-OSINT
cd poc-OSINT
python -m venv .venv && source .venv/bin/activate
pip install -e .
```

### 2. Descargar modelo

```bash
mkdir -p ~/models
# Descarga desde Hugging Face (ejemplo con huggingface-cli):
huggingface-cli download Qwen/Qwen2-0.5B-Instruct-GGUF \
    qwen2-0_5b-instruct-q4_k_m.gguf \
    --local-dir ~/models
```

### 3. Compilar llama.cpp (ARM64)

```bash
git clone https://github.com/ggml-org/llama.cpp ~/llama.cpp
cd ~/llama.cpp
cmake -B build -DGGML_NATIVE=ON
cmake --build build --config Release -j$(nproc)
```

### 4. Iniciar el stack

```bash
chmod +x scripts/start_container.sh
./scripts/start_container.sh ~/models/qwen2-0_5b-instruct-q4_k_m.gguf
```

---

## Uso

```bash
# Con argumento directo
python -m orchestrator.main "busca info sobre +52 55 1234 5678"

# O con el script instalado
osint "información pública sobre +34 91 000 0000"

# Modo interactivo
osint
```

### Ejemplo de salida

```
[*] Query: busca info sobre +52 55 1234 5678

[*] PHOMBER args: -p +525512345678

─── Raw output ──────────────────────────────
[+] Country: Mexico
[+] Carrier: Telcel
[+] Line type: mobile
─────────────────────────────────────────────

[*] Sending to SLM for interpretation…

─── SLM interpretation ──────────────────────
El número pertenece a México, operado por Telcel,
y corresponde a una línea móvil.

Inference: podría tratarse de un número activo en la
red GSM de Telcel en la Ciudad de México.
─────────────────────────────────────────────
```

---

## Seguridad

- El contenedor corre con `--read-only` y `--security-opt no-new-privileges`.
- Los argumentos pasan por una **whitelist estricta** antes de llegar a `podman exec`.
- El orquestador **nunca ejecuta comandos arbitrarios** del usuario.
- llama-server escucha solo en `127.0.0.1`.

---

## Variables de entorno

| Variable | Default | Descripción |
|---|---|---|
| `LLAMA_SERVER_URL` | `http://localhost:8080` | URL del servidor llama.cpp |
| `LLAMA_SERVER_BIN` | `~/llama.cpp/llama-server` | Ruta al binario llama-server |

---

## Licencia

MIT — ver [LICENSE](LICENSE).

Esta PoC es exclusivamente para uso educativo y demostrativo.
El uso responsable de herramientas OSINT es responsabilidad del usuario.
