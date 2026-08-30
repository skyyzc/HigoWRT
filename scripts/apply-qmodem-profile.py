#!/usr/bin/env python3
"""Add the evidence-backed RG520N-CN profile without replacing upstream JSON."""

import argparse
import json
from pathlib import Path


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("support_file", type=Path)
    parser.add_argument("--profile", type=Path, required=True)
    args = parser.parse_args()

    document = load_json(args.support_file)
    profile = load_json(args.profile)
    try:
        usb = document["modem_support"]["usb"]
    except (KeyError, TypeError) as exc:
        raise SystemExit(f"unsupported modem_support schema: {exc}")

    current = usb.get("rg520n-cn")
    if current is not None:
        if current == profile:
            print("rg520n-cn profile already matches; nothing to do")
            return 0
        raise SystemExit(
            "upstream now has a different rg520n-cn profile; manual review required"
        )

    usb["rg520n-cn"] = profile
    with args.support_file.open("w", encoding="utf-8") as handle:
        json.dump(document, handle, ensure_ascii=False, indent=4)
        handle.write("\n")
    print(f"added rg520n-cn to {args.support_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
