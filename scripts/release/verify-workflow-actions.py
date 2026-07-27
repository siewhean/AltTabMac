#!/usr/bin/env python3
"""Fail when a GitHub Actions workflow uses a mutable action reference."""

from __future__ import annotations

import re
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
        return (
            f"{value} is not pinned to a 40-character commit SHA"
        )
    return None


def main() -> None:
    failures: list[str] = []
    checked = 0

    for workflow in sorted((*WORKFLOWS.glob("*.yml"), *WORKFLOWS.glob("*.yaml"))):
        for line_number, line in enumerate(workflow.read_text(encoding="utf-8").splitlines(), 1):
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
                    f"{workflow.relative_to(ROOT)}:{line_number}: "
                    f"{failure}"
                )

    if failures:
        raise SystemExit("\n".join(failures))
    if checked == 0:
        raise SystemExit("No GitHub Action references were found")

    print(f"Workflow action pin verification passed ({checked} references)")


if __name__ == "__main__":
    main()
