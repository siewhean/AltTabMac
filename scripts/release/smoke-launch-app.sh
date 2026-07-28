#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-}"
HOLD_SECONDS="${CMDTAB_SMOKE_HOLD_SECONDS:-5}"
LOG_PATH="${CMDTAB_SMOKE_LOG_PATH:-}"

if [[ -z "${APP_PATH}" ]]; then
  echo "Usage: $0 /path/to/CmdTab.app" >&2
  exit 2
fi
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Packaged launch smoke testing must run on macOS." >&2
  exit 1
fi
for tool in codesign lsof pgrep plutil; do
  command -v "${tool}" >/dev/null 2>&1 || {
    echo "Missing required tool: ${tool}" >&2
    exit 1
  }
done
[[ "${HOLD_SECONDS}" =~ ^[1-9][0-9]*$ ]] || {
  echo "CMDTAB_SMOKE_HOLD_SECONDS must be a positive integer." >&2
  exit 2
}
[[ -d "${APP_PATH}" ]] || {
  echo "App bundle does not exist: ${APP_PATH}" >&2
  exit 1
}

EXECUTABLE_NAME="$(plutil -extract CFBundleExecutable raw "${APP_PATH}/Contents/Info.plist")"
EXECUTABLE_PATH="${APP_PATH}/Contents/MacOS/${EXECUTABLE_NAME}"
[[ -x "${EXECUTABLE_PATH}" ]] || {
  echo "App executable does not exist: ${EXECUTABLE_PATH}" >&2
  exit 1
}

if pgrep -x "${EXECUTABLE_NAME}" >/dev/null 2>&1; then
  echo "Another ${EXECUTABLE_NAME} process is already running. Stop it before the exact-bundle launch smoke test." >&2
  pgrep -af "${EXECUTABLE_NAME}" >&2 || true
  exit 1
fi

if [[ -z "${LOG_PATH}" ]]; then
  LOG_PATH="$(mktemp /tmp/cmdtab-launch-smoke.XXXXXX.log)"
else
  mkdir -p "$(dirname "${LOG_PATH}")"
fi
: > "${LOG_PATH}"

codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

"${EXECUTABLE_PATH}" >"${LOG_PATH}" 2>&1 &
PID=$!

cleanup() {
  if kill -0 "${PID}" >/dev/null 2>&1; then
    kill -TERM "${PID}" >/dev/null 2>&1 || true
    for _ in $(seq 1 30); do
      kill -0 "${PID}" >/dev/null 2>&1 || break
      sleep 0.1
    done
    kill -KILL "${PID}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

sleep "${HOLD_SECONDS}"
if ! kill -0 "${PID}" >/dev/null 2>&1; then
  set +e
  wait "${PID}"
  STATUS=$?
  set -e
  echo "Packaged app exited during launch smoke test (status=${STATUS})." >&2
  echo "Launch output (${LOG_PATH}):" >&2
  cat "${LOG_PATH}" >&2
  exit 1
fi

LOADED_EXECUTABLE="$(
  lsof -a -p "${PID}" -d txt -Fn 2>/dev/null |
    sed -n 's/^n//p' |
    grep -Fx "${EXECUTABLE_PATH}" |
    head -1 || true
)"
[[ "${LOADED_EXECUTABLE}" == "${EXECUTABLE_PATH}" ]] || {
  echo "Could not prove that the exact packaged executable is running." >&2
  echo "Expected: ${EXECUTABLE_PATH}" >&2
  echo "Loaded:   ${LOADED_EXECUTABLE:-none}" >&2
  exit 1
}

printf 'Packaged launch smoke test passed\n'
printf '  app: %s\n' "${APP_PATH}"
printf '  executable: %s\n' "${LOADED_EXECUTABLE}"
printf '  pid: %s\n' "${PID}"
printf '  hold-seconds: %s\n' "${HOLD_SECONDS}"
printf '  log: %s\n' "${LOG_PATH}"
