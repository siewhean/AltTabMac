#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_EXECUTABLE="${CMDTAB_RUNTIME_QA_EXECUTABLE:-${ROOT_DIR}/CmdTab.app/Contents/MacOS/CmdTab}"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <runtime-qa.jsonl> [validator options]" >&2
  exit 64
fi

if [[ ! -x "${APP_EXECUTABLE}" ]]; then
  echo "CmdTab executable not found: ${APP_EXECUTABLE}" >&2
  echo "Run ./build.sh or set CMDTAB_RUNTIME_QA_EXECUTABLE." >&2
  exit 69
fi

exec "${APP_EXECUTABLE}" --validate-runtime-qa "$@"
