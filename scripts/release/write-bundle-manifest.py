#!/usr/bin/env python3
"""Write a deterministic manifest for a packaged CmdTab.app bundle."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import plistlib
import stat
import subprocess
from pathlib import Path
from typing import Any


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def command_output(args: list[str]) -> str | None:
    result = subprocess.run(args, text=True, capture_output=True, check=False)
    if result.returncode != 0:
        return None
    return result.stdout.strip() or result.stderr.strip() or None


def signing_state(app: Path) -> dict[str, Any]:
    result = subprocess.run(
        ["codesign", "-d", "--verbose=4", str(app)],
        text=True,
        capture_output=True,
        check=False,
    )
    report = f"{result.stdout}\n{result.stderr}"
    if result.returncode != 0:
        return {"mode": "unsigned"}
    if "Signature=adhoc" in report:
        return {"mode": "ad-hoc"}
    authorities = [
        line.split("=", 1)[1]
        for line in report.splitlines()
        if line.startswith("Authority=")
    ]
    return {"mode": "identity", "authorities": authorities}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("app", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    app = args.app.resolve()
    info_path = app / "Contents" / "Info.plist"
    if not info_path.is_file():
        raise SystemExit(f"Missing Info.plist: {info_path}")

    with info_path.open("rb") as handle:
        info = plistlib.load(handle)

    executable = app / "Contents" / "MacOS" / info["CFBundleExecutable"]
    architecture_text = command_output(["lipo", "-archs", str(executable)])
    architectures = architecture_text.split() if architecture_text else []

    files: list[dict[str, Any]] = []
    for path in sorted(app.rglob("*"), key=lambda item: item.relative_to(app).as_posix()):
        relative = path.relative_to(app).as_posix()
        metadata = path.lstat()
        if path.is_symlink():
            files.append(
                {
                    "path": relative,
                    "type": "symlink",
                    "target": os.readlink(path),
                    "mode": stat.S_IMODE(metadata.st_mode),
                }
            )
        elif path.is_file():
            files.append(
                {
                    "path": relative,
                    "type": "file",
                    "bytes": metadata.st_size,
                    "mode": stat.S_IMODE(metadata.st_mode),
                    "sha256": sha256(path),
                }
            )

    payload = {
        "schemaVersion": 1,
        "appName": info["CFBundleName"],
        "bundleIdentifier": info["CFBundleIdentifier"],
        "marketingVersion": info["CFBundleShortVersionString"],
        "buildNumber": info["CFBundleVersion"],
        "minimumSystemVersion": info["LSMinimumSystemVersion"],
        "architectures": architectures,
        "signing": signing_state(app),
        "files": files,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(args.output)


if __name__ == "__main__":
    main()
