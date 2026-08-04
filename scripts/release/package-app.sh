#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_TOOL="${ROOT_DIR}/scripts/release/release_config.py"
BUILD_TOOL="${ROOT_DIR}/scripts/release/build-app.sh"
VERIFY_TOOL="${ROOT_DIR}/scripts/release/verify-bundle.sh"
MANIFEST_TOOL="${ROOT_DIR}/scripts/release/write-bundle-manifest.py"
PRIVACY_MANIFEST_VERIFIER="${ROOT_DIR}/scripts/release/verify-privacy-manifest.py"
OUTPUT_APP="${CMDTAB_OUTPUT_APP:-${ROOT_DIR}/dist/CmdTab.app}"
SKIP_SIGN="${CMDTAB_SKIP_ADHOC_SIGN:-0}"
SIGNING_IDENTITY="${CMDTAB_SIGNING_IDENTITY:-}"
KEEP_SCRATCH="${CMDTAB_KEEP_RELEASE_SCRATCH:-0}"
SCRATCH_ROOT="${CMDTAB_RELEASE_SCRATCH:-$(mktemp -d /tmp/cmdtab-package.XXXXXX)}"
STAGE_APP="${SCRATCH_ROOT}/CmdTab.app"

if [[ "${SKIP_SIGN}" == "1" && -n "${SIGNING_IDENTITY}" ]]; then
  echo "CMDTAB_SKIP_ADHOC_SIGN and CMDTAB_SIGNING_IDENTITY are mutually exclusive." >&2
  exit 2
fi
if [[ -n "${SIGNING_IDENTITY}" && -z "${CMDTAB_SPARKLE_PUBLIC_ED_KEY:-}" ]]; then
  echo "Developer ID packaging requires CMDTAB_SPARKLE_PUBLIC_ED_KEY." >&2
  exit 2
fi

cleanup() {
  if [[ "${KEEP_SCRATCH}" != "1" ]]; then
    rm -rf "${SCRATCH_ROOT}"
  else
    echo "Kept release scratch at ${SCRATCH_ROOT}" >&2
  fi
}
trap cleanup EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "CmdTab packaging must run on macOS." >&2
  exit 1
fi

for tool in python3 plutil codesign xattr shasum ditto; do
  command -v "${tool}" >/dev/null 2>&1 || {
    echo "Missing required tool: ${tool}" >&2
    exit 1
  }
done

python3 "${CONFIG_TOOL}" verify-repository
python3 "${PRIVACY_MANIFEST_VERIFIER}" "${ROOT_DIR}/Resources/PrivacyInfo.xcprivacy"

APP_NAME="$(python3 "${CONFIG_TOOL}" get appName)"
EXECUTABLE_NAME="$(python3 "${CONFIG_TOOL}" get executableName)"
ICON_FILE="$(python3 "${CONFIG_TOOL}" get iconFile)"
ARCHITECTURE_POLICY="$(python3 "${CONFIG_TOOL}" get architecturePolicy)"
REQUESTED_BUILD_ARCHITECTURES="${CMDTAB_BUILD_ARCHITECTURES:-}"
REQUESTED_EXPECTED_ARCHITECTURES="${CMDTAB_EXPECTED_ARCHITECTURES:-}"

case "${ARCHITECTURE_POLICY}" in
  arm64-only)
    if [[ -n "${REQUESTED_BUILD_ARCHITECTURES}" &&
          "${REQUESTED_BUILD_ARCHITECTURES}" != "arm64" ]]; then
      echo "Release architecture policy requires arm64 builds." >&2
      exit 2
    fi
    if [[ -n "${REQUESTED_EXPECTED_ARCHITECTURES}" &&
          "${REQUESTED_EXPECTED_ARCHITECTURES}" != "arm64" ]]; then
      echo "Release architecture policy requires arm64 verification." >&2
      exit 2
    fi
    BUILD_ARCHITECTURES="arm64"
    EXPECTED_ARCHITECTURES="arm64"
    ;;
  *)
    echo "Unsupported release architecture policy: ${ARCHITECTURE_POLICY}" >&2
    exit 2
    ;;
esac

BUILD_SCRATCH="${SCRATCH_ROOT}/swift-build"
BINARY_PATH="$(
  CMDTAB_BUILD_SCRATCH="${BUILD_SCRATCH}" \
  CMDTAB_BUILD_ARCHITECTURES="${BUILD_ARCHITECTURES}" \
    "${BUILD_TOOL}"
)"

rm -rf "${STAGE_APP}"
mkdir -p \
  "${STAGE_APP}/Contents/MacOS" \
  "${STAGE_APP}/Contents/Resources" \
  "${STAGE_APP}/Contents/Frameworks"

install -m 0755 "${BINARY_PATH}" "${STAGE_APP}/Contents/MacOS/${EXECUTABLE_NAME}"
SPARKLE_FRAMEWORK="$(dirname "${BINARY_PATH}")/Sparkle.framework"
[[ -d "${SPARKLE_FRAMEWORK}" ]] || {
  echo "SwiftPM did not emit Sparkle.framework beside the release executable." >&2
  exit 1
}
ditto "${SPARKLE_FRAMEWORK}" "${STAGE_APP}/Contents/Frameworks/Sparkle.framework"
python3 "${CONFIG_TOOL}" render-info-plist "${STAGE_APP}/Contents/Info.plist"
install -m 0644 "${ROOT_DIR}/Resources/${ICON_FILE}.icns" "${STAGE_APP}/Contents/Resources/${ICON_FILE}.icns"
install -m 0644 "${ROOT_DIR}/Resources/PrivacyInfo.xcprivacy" "${STAGE_APP}/Contents/Resources/PrivacyInfo.xcprivacy"
if [[ -f "${ROOT_DIR}/Resources/${ICON_FILE}.png" ]]; then
  install -m 0644 "${ROOT_DIR}/Resources/${ICON_FILE}.png" "${STAGE_APP}/Contents/Resources/${ICON_FILE}.png"
fi

find "${STAGE_APP}/Contents/MacOS" "${STAGE_APP}/Contents/Resources" \
  -type d -exec chmod 0755 {} +
find "${STAGE_APP}/Contents/Resources" -type f -exec chmod 0644 {} +
chmod 0755 "${STAGE_APP}/Contents/MacOS/${EXECUTABLE_NAME}"
xattr -cr "${STAGE_APP}" 2>/dev/null || true

if [[ -n "$(find "${STAGE_APP}" -type l ! -path "${STAGE_APP}/Contents/Frameworks/Sparkle.framework/*" -print -quit)" ]]; then
  echo "Packaged app contains a symbolic link outside Sparkle.framework." >&2
  exit 1
fi

thin_executables_to_arm64() {
  local executable_path
  while IFS= read -r executable_path; do
    local architectures
    architectures="$(lipo -archs "${executable_path}")"
    if [[ " ${architectures} " != *" arm64 "* ]]; then
      echo "Packaged executable is missing an arm64 slice: ${executable_path}" >&2
      exit 1
    fi
    if [[ " ${architectures} " == *" x86_64 "* ]]; then
      local thinned_path
      thinned_path="$(mktemp "${executable_path}.arm64.XXXXXX")"
      lipo -thin arm64 "${executable_path}" -output "${thinned_path}"
      chmod "$(stat -f '%Lp' "${executable_path}")" "${thinned_path}"
      mv "${thinned_path}" "${executable_path}"
    fi
  done < <(find "${STAGE_APP}/Contents" -type f -perm -111 | LC_ALL=C sort)
}

thin_executables_to_arm64

if [[ "${SKIP_SIGN}" == "1" ]]; then
  # Re-sign the thinned nested framework with a deterministic ad-hoc signature,
  # then remove only the outer bundle signature so the reproducibility artifact
  # remains unsigned while its embedded framework stays structurally verifiable.
  "${ROOT_DIR}/scripts/release/sign-app-bundle.sh" \
    "${STAGE_APP}" \
    - \
    "${ROOT_DIR}/Resources/CmdTab.entitlements" \
    none
  codesign --remove-signature "${STAGE_APP}"
  EXPECTED_SIGNING="unsigned"
elif [[ -n "${SIGNING_IDENTITY}" ]]; then
  plutil -lint "${ROOT_DIR}/Resources/CmdTab.entitlements" >/dev/null
  "${ROOT_DIR}/scripts/release/sign-app-bundle.sh" \
    "${STAGE_APP}" \
    "${SIGNING_IDENTITY}" \
    "${ROOT_DIR}/Resources/CmdTab.entitlements" \
    timestamp
  EXPECTED_SIGNING="developer-id"
else
  # Local acceptance packages are ad-hoc signed without Hardened Runtime. An
  # ad-hoc identity has no Apple Team ID, so enabling library validation would
  # make macOS reject the embedded Sparkle framework before main() executes.
  # Developer ID packaging above keeps Hardened Runtime enabled.
  plutil -lint "${ROOT_DIR}/Resources/CmdTab.entitlements" >/dev/null
  "${ROOT_DIR}/scripts/release/sign-app-bundle.sh" \
    "${STAGE_APP}" \
    - \
    "${ROOT_DIR}/Resources/CmdTab.entitlements" \
    none
  EXPECTED_SIGNING="ad-hoc"
fi

CMDTAB_EXPECTED_ARCHITECTURES="${EXPECTED_ARCHITECTURES}" \
  "${VERIFY_TOOL}" "${STAGE_APP}" "${EXPECTED_SIGNING}"

mkdir -p "$(dirname "${OUTPUT_APP}")"
rm -rf "${OUTPUT_APP}"
mv "${STAGE_APP}" "${OUTPUT_APP}"

ARTIFACT_BASE="${OUTPUT_APP%.app}"
MANIFEST_PATH="${ARTIFACT_BASE}.manifest.json"
CHECKSUM_PATH="${ARTIFACT_BASE}.sha256"
python3 "${MANIFEST_TOOL}" "${OUTPUT_APP}" "${MANIFEST_PATH}" >/dev/null
(
  cd "$(dirname "${OUTPUT_APP}")"
  shasum -a 256 "$(basename "${OUTPUT_APP}")/Contents/Info.plist" \
    "$(basename "${OUTPUT_APP}")/Contents/MacOS/${EXECUTABLE_NAME}" \
    "$(basename "${OUTPUT_APP}")/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle" \
    "$(basename "${OUTPUT_APP}")/Contents/Resources/${ICON_FILE}.icns"
) > "${CHECKSUM_PATH}"

printf 'Packaged %s\n' "${OUTPUT_APP}"
printf 'Manifest %s\n' "${MANIFEST_PATH}"
printf 'Checksums %s\n' "${CHECKSUM_PATH}"
printf 'Architecture policy %s\n' "${ARCHITECTURE_POLICY}"
