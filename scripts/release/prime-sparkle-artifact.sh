#!/usr/bin/env bash
# Seed SwiftPM's shared binary-artifact cache with Sparkle's XCFramework zip.
#
# SwiftPM downloads Sparkle's binary target from a github.com release-download
# URL. When that endpoint fails (on 2026-11-08 it returned HTTP 504 for every
# large release asset), `swift package resolve` fails before anything builds.
# This script fetches the same zip through the GitHub REST API asset route
# first (a different front end), then through the release-download URL, and
# installs it in the cache only when its SHA-256 matches the checksum Sparkle's
# own Package.swift declares, so a bad download is never cached. SwiftPM copies
# a cached artifact instead of downloading it and verifies the checksum again.
#
# Never fails the job: if every route fails, `swift package resolve` still runs
# and reports the real download error.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
asset="Sparkle-for-Swift-Package-Manager.zip"

read -r version revision < <(python3 - "$root/Package.resolved" <<'PY'
import json
import sys

pins = json.load(open(sys.argv[1]))["pins"]
pin = next(p for p in pins if p["identity"] == "sparkle")
print(pin["state"]["version"], pin["state"]["revision"])
PY
)

checksum="$(
  curl -fsSL --retry 3 --retry-all-errors \
    "https://raw.githubusercontent.com/sparkle-project/Sparkle/${revision}/Package.swift" |
    sed -n 's/^let checksum = "\([0-9a-f]\{64\}\)".*/\1/p'
)"
if [[ ! "$checksum" =~ ^[0-9a-f]{64}$ ]]; then
  echo "::warning::Could not read Sparkle ${version}'s artifact checksum; leaving the download to SwiftPM."
  exit 0
fi

url="https://github.com/sparkle-project/Sparkle/releases/download/${version}/${asset}"
cache_dir="$HOME/Library/Caches/org.swift.swiftpm/artifacts"
# SwiftPM keys cached artifacts by the URL with every non-identifier
# character replaced by an underscore.
cached="${cache_dir}/$(printf '%s' "$url" | sed 's/[^A-Za-z0-9_]/_/g')"

sha256() { shasum -a 256 "$1" | cut -d ' ' -f 1; }

if [[ -f "$cached" && "$(sha256 "$cached")" == "$checksum" ]]; then
  echo "Sparkle ${version} artifact already cached and verified."
  exit 0
fi
rm -rf "$cached"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

for attempt in 1 2 3 4; do
  rm -f "$work/$asset"
  if [[ -n "${GH_TOKEN:-}" ]] &&
    gh release download "$version" --repo sparkle-project/Sparkle \
      --pattern "$asset" --dir "$work" --clobber; then
    route="GitHub API"
  elif curl -fsSL -o "$work/$asset" "$url"; then
    route="release download"
  else
    echo "Attempt ${attempt}: both download routes failed."
    sleep $((attempt * 20))
    continue
  fi

  actual="$(sha256 "$work/$asset")"
  if [[ "$actual" == "$checksum" ]]; then
    mkdir -p "$cache_dir"
    mv "$work/$asset" "$cached"
    echo "Cached Sparkle ${version} artifact via ${route} (sha256 ${checksum})."
    exit 0
  fi
  echo "Attempt ${attempt}: ${route} returned a file with sha256 ${actual}, expected ${checksum}."
  sleep $((attempt * 20))
done

echo "::warning::Could not fetch Sparkle ${version}'s artifact; leaving the download to SwiftPM."
exit 0
