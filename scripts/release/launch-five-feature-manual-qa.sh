#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_PATH="${ROOT_DIR}/dist/CmdTab.app"
CHECKLIST_PATH="${ROOT_DIR}/dist/five-feature-evidence/manual-checks.md"
EVIDENCE_COMMIT_PATH="${ROOT_DIR}/dist/five-feature-evidence/commit.txt"
RESULT_PATH="${ROOT_DIR}/dist/five-feature-evidence/result.txt"
CHECKSUM_PATH="${ROOT_DIR}/dist/CmdTab.sha256"
EXPECTED_COMMIT="${CMDTAB_EXPECTED_QA_COMMIT:-}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Five-feature packaged-app QA must run on macOS." >&2
  exit 1
fi

actual_commit="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
if [[ -n "${EXPECTED_COMMIT}" && "${actual_commit}" != "${EXPECTED_COMMIT}" ]]; then
  echo "Unexpected QA commit: ${actual_commit}" >&2
  echo "Expected: ${EXPECTED_COMMIT}" >&2
  exit 1
fi

if [[ -n "$(git -C "${ROOT_DIR}" status --porcelain)" ]]; then
  echo "The repository worktree is not clean; packaged-app observations would not be attributable to one exact source state." >&2
  git -C "${ROOT_DIR}" status >&2
  exit 1
fi

[[ -d "${APP_PATH}" ]] || {
  echo "Missing packaged app: ${APP_PATH}" >&2
  echo "Run the package and finalize QA phases first." >&2
  exit 1
}

[[ -f "${CHECKLIST_PATH}" ]] || {
  echo "Missing manual checklist: ${CHECKLIST_PATH}" >&2
  echo "Run the finalize QA phase first." >&2
  exit 1
}

[[ -f "${EVIDENCE_COMMIT_PATH}" && -f "${RESULT_PATH}" ]] || {
  echo "Missing exact-head automated evidence. Run the finalize QA phase first." >&2
  exit 1
}

evidence_commit="$(cat "${EVIDENCE_COMMIT_PATH}")"
automated_result="$(head -n 1 "${RESULT_PATH}")"
if [[ "${evidence_commit}" != "${actual_commit}" ]]; then
  echo "Packaged-app evidence belongs to ${evidence_commit}, not current HEAD ${actual_commit}." >&2
  echo "Rerun source, tests, package, repro, and finalize before manual QA." >&2
  exit 1
fi
if [[ "${automated_result}" != "AUTOMATED_PASS" ]]; then
  echo "Automated result is ${automated_result}, not AUTOMATED_PASS." >&2
  exit 1
fi

[[ -f "${CHECKSUM_PATH}" ]] || {
  echo "Missing package checksum manifest: ${CHECKSUM_PATH}" >&2
  exit 1
}
(
  cd "${ROOT_DIR}/dist"
  shasum -a 256 -c "$(basename "${CHECKSUM_PATH}")"
)

# LaunchServices can briefly return -600 when an old LSUIElement instance is
# still terminating. Ask the app to terminate, wait for the process table to
# settle, and use -n so LaunchServices creates the exact packaged instance.
pkill -TERM -x CmdTab 2>/dev/null || true
for _ in $(seq 1 50); do
  if ! pgrep -x CmdTab >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

if pgrep -x CmdTab >/dev/null 2>&1; then
  echo "CmdTab did not terminate within five seconds. Quit it from the menu bar or inspect the process before continuing." >&2
  pgrep -fl CmdTab >&2 || true
  exit 1
fi

open -n "${APP_PATH}"
open -a TextEdit "${CHECKLIST_PATH}"

printf 'Launched exact packaged app for commit: %s\n' "${actual_commit}"
printf 'Opened checklist: %s\n' "${CHECKLIST_PATH}"
printf 'Do not execute the Markdown path directly; edit it in TextEdit and keep tester observations at the end.\n'
