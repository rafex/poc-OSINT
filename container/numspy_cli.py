#!/usr/bin/env python3
"""NumSpy CLI — consulta detalles de números de teléfono vía way2sms."""
import sys
import argparse


def main() -> None:
    parser = argparse.ArgumentParser(
        prog="numspy",
        description="NumSpy — phone number OSINT via way2sms.com",
    )
    parser.add_argument("phone", nargs="?", help="Número de teléfono a investigar")
    parser.add_argument("--version", action="store_true", help="Versión instalada")
    args = parser.parse_args()

    if args.version:
        try:
            import numspy as _n
            print(f"numspy {getattr(_n, '__version__', 'installed')}")
        except ImportError:
            print("numspy: not installed")
        sys.exit(0)

    if not args.phone:
        parser.print_help()
        sys.exit(1)

    print(f"[*] NumSpy — consultando: {args.phone}")
    try:
        from numspy import Way2sms
        Way2sms().details(args.phone)
    except Exception as exc:
        print(f"[!] Error: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
