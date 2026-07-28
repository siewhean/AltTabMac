#!/usr/bin/env python3
"""Fail on mutable workflow actions or tracked private secret directories."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github" / "workflows"
USE_PATTERN = re.compile(r"^\s*(?:-\s*)?uses:\s*([^\s#]+)")
USES_KEY_PATTERN = re.compile(r"""(?:^|[\s{,-])["']?uses["']?\s*:""")
IMMUTABLE_SHA = re.compile(r"^[0-9a-f]{40}$")
IMMUTABLE_DOCKER_DIGEST = re.compile(
    r"^docker://[^@\s]+@sha256:[0-9a-f]{64}$"
)


def validate_reference(value: str) -> str | None:
    if value.startswith("./"):
        return None
    if value.startswith("docker://"):
        if IMMUTABLE_DOCKER_DIGEST.fullmatch(value):
            return None
        return f"{value} is not pinned to a sha256 container digest"
    if "@" not in value:
        return f"{value} is missing an immutable action reference"
    action, reference = value.rsplit("@", 1)
    if not action or not IMMUTABLE_SHA.fullmatch(reference):
        return f"{value} is not pinned to a 40-character commit SHA"
    return None


def is_private_secret_path(path: str) -> bool:
    return ".secrets" in Path(path).parts


def tracked_private_secret_paths() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    )
    return sorted(
        path
        for path in result.stdout.decode("utf-8").split("\0")
        if path and is_private_secret_path(path)
    )


def main() -> None:
    failures: list[str] = []
    checked = 0

    for workflow in sorted((*WORKFLOWS.glob("*.yml"), *WORKFLOWS.glob("*.yaml"))):
        for line_number, line in enumerate(
            workflow.read_text(encoding="utf-8").splitlines(),
            1,
        ):
            if line.lstrip().startswith("#"):
                continue
            match = USE_PATTERN.match(line)
            if not match:
                if USES_KEY_PATTERN.search(line):
                    failures.append(
                        f"{workflow.relative_to(ROOT)}:{line_number}: "
                        "uses references must use the supported block-key form"
                    )
                continue
            checked += 1
            value = match.group(1)
            failure = validate_reference(value)
            if failure:
                failures.append(
                    f"{workflow.relative_to(ROOT)}:{line_number}: {failure}"
                )

    for secret_path in tracked_private_secret_paths():
        failures.append(
            f"{secret_path}: private .secrets directories must never be tracked"
        )

    if failures:
        raise SystemExit("\n".join(failures))
    if checked == 0:
        raise SystemExit("No GitHub Action references were found")

    print(
        "Workflow action and private-secret verification passed "
        f"({checked} action references)"
    )


if __name__ == "__main__":
    main()
