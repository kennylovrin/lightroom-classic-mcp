#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import sys
from pathlib import Path


def sha256_for_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: update_homebrew_formula.py <release-url> <source-zip-path>", file=sys.stderr)
        return 1

    release_url = sys.argv[1]
    source_zip = Path(sys.argv[2]).resolve()
    formula_path = Path(__file__).resolve().parent.parent / "Formula" / "lightroom-classic-mcp.rb"

    if not source_zip.exists():
        print(f"Source zip not found: {source_zip}", file=sys.stderr)
        return 1

    text = formula_path.read_text(encoding="utf-8")
    text = text.replace(
        'url "https://github.com/4xiomdev/lightroom-classic-mcp/archive/refs/tags/v0.4.0.tar.gz"',
        f'url "{release_url}"',
    )
    text = text.replace("__REPLACE_WITH_RELEASE_SHA256__", sha256_for_file(source_zip))
    formula_path.write_text(text, encoding="utf-8")
    print(f"Updated {formula_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
