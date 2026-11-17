#!/usr/bin/env python3
"""Build a new BobberTally archive with matching license and source files."""

import argparse
import hashlib
import re
import tempfile
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag", help="release tag, for example v0.12.0")
    parser.add_argument("--output", type=Path, help="override the default ZIP path")
    args = parser.parse_args()
    if not re.fullmatch(r"v\d+\.\d+\.\d+", args.tag):
        parser.error("expected a tag of the form vX.Y.Z")

    root = Path(__file__).resolve().parents[1]
    source = root / "addons/WowfFishing"
    manifest_name = "WowfFishing.toc"
    manifest = (source / manifest_name).read_text(encoding="utf-8-sig").splitlines()
    if f"## Version: {args.tag[1:]}" not in manifest:
        parser.error("release tag does not match the add-on manifest version")

    for name in ("LICENSE", "NOTICE"):
        if (root / name).read_bytes() != (source / name).read_bytes():
            parser.error(f"root and add-on {name} differ; synchronize them first")

    files = [line.strip() for line in manifest if line.strip() and not line.lstrip().startswith("#")]
    files.extend((manifest_name, "README.md", "LICENSE", "NOTICE", "LICENSING.md", "THIRD_PARTY_LICENSES.txt"))
    if len(set(files)) != len(files) or any(Path(name).name != name for name in files):
        parser.error("expected unique files in the add-on directory")
    files.sort()
    entries = {f"WowfFishing/{name}": source / name for name in files}
    for entry, path in entries.items():
        if not path.is_file() or path.is_symlink():
            parser.error(f"missing or symlinked package input: {entry}")

    output = args.output or root / "docs/downloads" / f"BobberTally-{args.tag}.zip"
    if output.exists():
        parser.error("output already exists; preserve released archives and use a new version or output path")
    if not output.parent.is_dir():
        parser.error("output directory does not exist")

    with tempfile.TemporaryDirectory(dir=output.parent) as directory:
        staged = Path(directory) / "package.zip"
        with ZipFile(staged, "w", ZIP_DEFLATED, compresslevel=9) as package:
            for entry, path in entries.items():
                package.write(path, entry)
        with ZipFile(staged) as package:
            if package.testzip() or package.namelist() != list(entries) or any(
                package.read(entry) != path.read_bytes() for entry, path in entries.items()
            ):
                raise RuntimeError("the ZIP differs from the add-on source")
        # Exclusive creation also protects against a concurrent release build.
        with output.open("xb") as target:
            target.write(staged.read_bytes())

    data = output.read_bytes()
    print(f"{output}  {len(entries)} files  {len(data)} bytes  SHA-256 {hashlib.sha256(data).hexdigest()}")


if __name__ == "__main__":
    main()
