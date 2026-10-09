#!/usr/bin/env python3
"""Validate one signed Sparkle appcast against its beta or stable manifest."""

from __future__ import annotations

import argparse
import json
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urlparse

from release_manifest import validate_manifest

SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("appcast", type=Path)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--current-build", type=int)
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    if not isinstance(manifest, dict):
        raise SystemExit("release manifest root must be an object")
    try:
        validate_manifest(manifest)
    except ValueError as error:
        raise SystemExit(str(error)) from error
    root = ET.parse(args.appcast).getroot()
    items = root.findall("./channel/item")
    matching = [
        item for item in items
        if item.findtext(f"{{{SPARKLE}}}version") == str(manifest["build"])
    ]
    if len(matching) != 1:
        raise SystemExit("appcast must contain exactly one item for the manifest build")
    item = matching[0]
    channel = manifest.get("channel")
    # Each channel has its own feed URL; a named Sparkle channel would hide
    # the item from clients, which never declare allowedChannels(for:).
    if item.find(f"{{{SPARKLE}}}channel") is not None:
        raise SystemExit(f"{channel} update item must use Sparkle's default channel")
    if channel not in {"beta", "stable"}:
        raise SystemExit("appcast manifest channel must be beta or stable")
    enclosure = item.find("enclosure")
    if enclosure is None:
        raise SystemExit("stable update item is missing an enclosure")
    if enclosure.get("url") != manifest["dmgURL"]:
        raise SystemExit("appcast enclosure URL does not match the release manifest")
    if enclosure.get("length") != str(manifest["bytes"]):
        raise SystemExit("appcast enclosure length does not match the release manifest")
    signature = enclosure.get(f"{{{SPARKLE}}}edSignature", "")
    if len(signature) < 80:
        raise SystemExit("appcast enclosure is missing an EdDSA signature")
    if item.findtext(f"{{{SPARKLE}}}minimumSystemVersion") != manifest["minimumMacOS"]:
        raise SystemExit("appcast minimum macOS does not match the release manifest")
    if args.current_build is not None and int(manifest["build"]) <= args.current_build:
        raise SystemExit("equal or lower update builds are not eligible")
    if urlparse(manifest["dmgURL"]).scheme != "https":
        raise SystemExit("appcast enclosure URL must use HTTPS")
    print(f"Signed {channel} appcast validation passed")


if __name__ == "__main__":
    main()
