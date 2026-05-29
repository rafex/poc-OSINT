#!/usr/bin/env python3
"""
WhatsMyName checker — busca usernames en 600+ sitios usando wmn-data.json.
Data: https://github.com/WebBreacher/WhatsMyName
"""
import argparse
import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

try:
    import requests
    from requests.adapters import HTTPAdapter
    from urllib3.util.retry import Retry
except ImportError:
    print("Error: requests no instalado", file=sys.stderr)
    sys.exit(1)

DATA_FILE = Path("/opt/whatsmyname/wmn-data.json")
VERSION   = "1.0.0"

GREEN  = "\033[32m"
RED    = "\033[31m"
YELLOW = "\033[33m"
CYAN   = "\033[36m"
BOLD   = "\033[1m"
RESET  = "\033[0m"


def _make_session() -> requests.Session:
    s = requests.Session()
    retry = Retry(total=1, backoff_factor=0.3, status_forcelist=[429, 500, 502, 503])
    s.mount("https://", HTTPAdapter(max_retries=retry, pool_maxsize=50))
    s.mount("http://",  HTTPAdapter(max_retries=retry, pool_maxsize=50))
    s.headers["User-Agent"] = "Mozilla/5.0 (compatible; WMN-checker/1.0)"
    return s


def _check(site: dict, username: str, timeout: int, session: requests.Session) -> dict:
    url = site["uri_check"].replace("{account}", username)
    try:
        r = session.get(url, timeout=timeout, allow_redirects=True)
        found = (
            r.status_code == site.get("e_code", 200)
            and site.get("e_string", "") in r.text
            and site.get("m_string", "") not in r.text
        )
        return {"name": site["name"], "url": url, "found": found, "error": None,
                "category": site.get("category", "")}
    except requests.exceptions.Timeout:
        return {"name": site["name"], "url": url, "found": False, "error": "timeout",
                "category": site.get("category", "")}
    except Exception as exc:
        return {"name": site["name"], "url": url, "found": False,
                "error": str(exc)[:60], "category": site.get("category", "")}


def main() -> None:
    parser = argparse.ArgumentParser(
        prog="whatsmyname",
        description="WhatsMyName — username checker across 600+ sites",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos:
  whatsmyname rafex
  whatsmyname rafex --all
  whatsmyname rafex --category social
  whatsmyname --list-categories
        """,
    )
    parser.add_argument("username",         nargs="?",    help="Username a buscar")
    parser.add_argument("--timeout",        type=int,     default=10,
                        help="Timeout por request en segundos (default: 10)")
    parser.add_argument("--workers",        type=int,     default=30,
                        help="Workers concurrentes (default: 30)")
    parser.add_argument("--all",            action="store_true",
                        help="Mostrar todos los resultados (no solo encontrados)")
    parser.add_argument("--category",       default=None,
                        help="Filtrar por categoría (ej: social, tech, gaming)")
    parser.add_argument("--list-categories", action="store_true",
                        help="Listar categorías disponibles")
    parser.add_argument("--version",        action="store_true",
                        help="Versión e información del archivo de datos")
    args = parser.parse_args()

    if not DATA_FILE.exists():
        print(f"{RED}Error:{RESET} archivo de datos no encontrado: {DATA_FILE}",
              file=sys.stderr)
        sys.exit(1)

    data  = json.loads(DATA_FILE.read_text())
    sites = data.get("sites", [])

    if args.version:
        cats = sorted({s.get("category", "unknown") for s in sites})
        print(f"WMN checker {VERSION}")
        print(f"Datos: {DATA_FILE}")
        print(f"Sitios: {len(sites)}  |  Categorías: {len(cats)}")
        sys.exit(0)

    if args.list_categories:
        cats = sorted({s.get("category", "unknown") for s in sites})
        print("Categorías disponibles:")
        for c in cats:
            count = sum(1 for s in sites if s.get("category", "unknown") == c)
            print(f"  {CYAN}{c:<20}{RESET} {count} sitios")
        sys.exit(0)

    if not args.username:
        parser.print_help()
        sys.exit(1)

    username = args.username
    pool = sites

    if args.category:
        pool = [s for s in sites if s.get("category", "").lower() == args.category.lower()]
        if not pool:
            print(f"{YELLOW}Sin sitios para categoría: {args.category}{RESET}")
            sys.exit(1)

    print(f"\n{BOLD}WhatsMyName{RESET} — '{CYAN}{username}{RESET}' "
          f"en {BOLD}{len(pool)}{RESET} sitios\n")

    t0      = time.monotonic()
    found   = []
    errors  = 0
    session = _make_session()

    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        futures = {ex.submit(_check, s, username, args.timeout, session): s for s in pool}
        for fut in as_completed(futures):
            res = fut.result()
            if res["found"]:
                found.append(res)
                cat = f"[{res['category']}]" if res["category"] else ""
                print(f"  {GREEN}[+]{RESET} {BOLD}{res['name']:<28}{RESET} "
                      f"{CYAN}{cat:<12}{RESET} {res['url']}")
            elif res["error"]:
                errors += 1
                if args.all:
                    print(f"  {YELLOW}[!]{RESET} {res['name']} ({res['error']})")
            elif args.all:
                print(f"  {RED}[-]{RESET} {res['name']}")

    elapsed = time.monotonic() - t0
    print(f"\n{BOLD}Encontrados:{RESET} {GREEN}{len(found)}{RESET}  "
          f"Errores: {YELLOW}{errors}{RESET}  "
          f"Tiempo: {elapsed:.1f}s")

    if found:
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
