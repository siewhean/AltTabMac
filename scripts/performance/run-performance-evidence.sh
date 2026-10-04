#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODE="readiness"
OUTPUT_DIR=""
CMDTAB_APP=""
SKIP_BUILD=0

usage() {
  cat <<'EOF'
Usage: scripts/performance/run-performance-evidence.sh [options]

Options:
  --mode readiness|acceptance  Smoke harness or full release gate (default: readiness)
  --output-dir PATH            Evidence directory (default: /tmp/cmdtab-performance-<SHA>)
  --cmdtab-app PATH            Signed candidate app required for acceptance
  --skip-build                 Use --cmdtab-app instead of local-QA packaging
  --help                       Show this help

Acceptance runs require a clean worktree and an explicit Developer ID-signed
candidate app. They collect 100 sessions at each of 10, 25, and 50 windows plus
a separate 1,000-session 50-window soak.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --cmdtab-app)
      CMDTAB_APP="${2:-}"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[[ "${MODE}" == "readiness" || "${MODE}" == "acceptance" ]] || {
  echo "--mode must be readiness or acceptance" >&2
  exit 2
}

for tool in git python3; do
  command -v "${tool}" >/dev/null 2>&1 || {
    echo "Missing required tool: ${tool}" >&2
    exit 1
  }
done

SOURCE_SHA="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
SOURCE_CLEAN=true
if [[ -n "$(git -C "${ROOT_DIR}" status --porcelain --untracked-files=all)" ]]; then
  SOURCE_CLEAN=false
fi
if [[ "${MODE}" == "acceptance" && "${SOURCE_CLEAN}" != "true" ]]; then
  echo "Acceptance requires a clean worktree; no performance claim was produced." >&2
  exit 1
fi
if [[ "${MODE}" == "acceptance" && "${SKIP_BUILD}" != "1" ]]; then
  echo "Acceptance requires --skip-build --cmdtab-app with the exact signed candidate." >&2
  exit 1
fi

if [[ -z "${OUTPUT_DIR}" ]]; then
  OUTPUT_DIR="/tmp/cmdtab-performance-${SOURCE_SHA}"
fi
mkdir -p "${OUTPUT_DIR}/raw" "${OUTPUT_DIR}/candidate" "${OUTPUT_DIR}/fixture"

if [[ "${SKIP_BUILD}" == "1" ]]; then
  [[ -n "${CMDTAB_APP}" ]] || {
    echo "--skip-build requires --cmdtab-app" >&2
    exit 2
  }
else
  CMDTAB_APP="${OUTPUT_DIR}/candidate/CmdTab.app"
  CMDTAB_OUTPUT_APP="${CMDTAB_APP}" \
    bash "${ROOT_DIR}/scripts/release/package-app.sh"
fi

[[ -d "${CMDTAB_APP}" ]] || {
  echo "Missing CmdTab app: ${CMDTAB_APP}" >&2
  exit 1
}

if [[ "${MODE}" == "acceptance" ]]; then
  command -v codesign >/dev/null 2>&1 || {
    echo "Acceptance requires codesign to validate the supplied candidate." >&2
    exit 1
  }
  CODESIGN_DETAILS="$(codesign -dvv "${CMDTAB_APP}" 2>&1)"
  if ! grep -q '^Authority=Developer ID Application:' <<<"${CODESIGN_DETAILS}" ||
     ! grep -q 'flags=.*runtime' <<<"${CODESIGN_DETAILS}" ||
     ! grep -q '^Timestamp=' <<<"${CODESIGN_DETAILS}"; then
    echo "Acceptance requires a timestamped Hardened Runtime Developer ID candidate." >&2
    exit 1
  fi
fi

WINDOWLAB_APP="${OUTPUT_DIR}/fixture/WindowLab.app"
PERFORMANCE_PROBE="${OUTPUT_DIR}/fixture/PerformanceProbe"
CMDTAB_WINDOWLAB_OUTPUT_APP="${WINDOWLAB_APP}" \
  bash "${ROOT_DIR}/scripts/release/build-windowlab-fixture.sh"
CMDTAB_PERFORMANCE_PROBE_OUTPUT="${PERFORMANCE_PROBE}" \
  "${ROOT_DIR}/scripts/performance/build-performance-probe.sh"

if [[ "${MODE}" == "acceptance" ]]; then
  MATRIX_SESSIONS=100
  SOAK_SESSIONS=1000
else
  MATRIX_SESSIONS=3
  SOAK_SESSIONS=10
fi

RAW_RESULTS=()
for WINDOW_COUNT in 10 25 50; do
  RESULT="${OUTPUT_DIR}/raw/matrix-${WINDOW_COUNT}.json"
  "${PERFORMANCE_PROBE}" \
    --cmdtab-app "${CMDTAB_APP}" \
    --windowlab-app "${WINDOWLAB_APP}" \
    --window-count "${WINDOW_COUNT}" \
    --sessions "${MATRIX_SESSIONS}" \
    --source-sha "${SOURCE_SHA}" \
    --run-kind "${MODE}" \
    --output "${RESULT}"
  RAW_RESULTS+=("${RESULT}")
done

SOAK_RESULT="${OUTPUT_DIR}/raw/soak-50.json"
"${PERFORMANCE_PROBE}" \
  --cmdtab-app "${CMDTAB_APP}" \
  --windowlab-app "${WINDOWLAB_APP}" \
  --window-count 50 \
  --sessions "${SOAK_SESSIONS}" \
  --source-sha "${SOURCE_SHA}" \
  --run-kind "${MODE}" \
  --output "${SOAK_RESULT}"
RAW_RESULTS+=("${SOAK_RESULT}")

python3 "${ROOT_DIR}/scripts/performance/evaluate-performance-evidence.py" \
  --mode "${MODE}" \
  --source-sha "${SOURCE_SHA}" \
  --source-clean "${SOURCE_CLEAN}" \
  --output "${OUTPUT_DIR}/manifest.json" \
  "${RAW_RESULTS[@]}"

printf 'Hash-bound performance evidence: %s\n' "${OUTPUT_DIR}/manifest.json"
