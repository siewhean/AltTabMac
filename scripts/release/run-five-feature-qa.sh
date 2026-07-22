#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_DIR="${CMDTAB_FIVE_FEATURE_EVIDENCE_DIR:-${ROOT_DIR}/dist/five-feature-evidence}"
TEMP_ROOT="$(mktemp -d /tmp/cmdtab-five-feature-qa.XXXXXX)"
LOG_PATH="${EVIDENCE_DIR}/commands.log"
RESULT_PATH="${EVIDENCE_DIR}/result.txt"
MANUAL_PATH="${EVIDENCE_DIR}/manual-checks.md"

write_manual_checks() {
  local automated_status="$1"
  cat > "${MANUAL_PATH}" <<CHECKLIST
# CmdTab five-feature packaged-app acceptance

**Automated status:** ${automated_status}

Complete every row against the exact packaged artifact and commit recorded in this evidence directory.

## Minimized windows

- [ ] With minimized inclusion disabled, minimized windows are absent.
- [ ] With minimized inclusion enabled, each eligible minimized window appears with a visible minimized state.
- [ ] Selecting A2 restores and focuses A2 exactly; A1 and other sibling windows remain unchanged.
- [ ] A failed restoration does not change permanent MRU.
- [ ] Screen Recording denial keeps minimized items visible with a safe placeholder.

## Spaces, fullscreen, displays, and Stage Manager

- [ ] Current Space, Visible Spaces, and All Spaces produce the documented membership.
- [ ] Capability diagnostics distinguish exact, degraded, unavailable, and failed workspace states.
- [ ] Off-space selection reaches the intended exact window or reports the documented degraded limitation.
- [ ] Fullscreen windows remain individually identifiable and focus correctly.
- [ ] Stage Manager active and hidden sets never silently masquerade as exact when only inferred.
- [ ] Mixed-scale multi-display placement works; disconnect/reconnect leaves no stale overlay.

## Shortcut profiles

- [ ] Existing Command-Tab and Option-Tab defaults preserve their previous behaviour.
- [ ] At least three profiles retain independent style, scope, minimized policy, display placement, and app filter.
- [ ] Duplicate or reserved shortcuts are rejected.
- [ ] Shortcut recording does not trigger an existing global shortcut.
- [ ] Hold-to-release and press-to-toggle sessions both commit and cancel correctly.
- [ ] Import/export round-trips; malformed or future-schema JSON is rejected atomically.
- [ ] Secure Input and active text fields do not leak typed content into the switcher.

## Durable MRU

- [ ] Restart preserves unique high-confidence exact-window order.
- [ ] Duplicate-title windows do not receive ambiguous restored rank.
- [ ] Reused PID or CGWindowID does not inherit unrelated rank.
- [ ] Failed activation does not persist rank.
- [ ] Reset Durable MRU clears restored order without deleting preferences or licensing state.
- [ ] The persisted JSON contains no raw title, URL, preview, search query, or screenshot.

## Exact-window actions

- [ ] Unsupported actions are disabled with a reason.
- [ ] Restore, zoom, fullscreen, centre, move-display, half-tile, and third-tile target only the selected exact window.
- [ ] Frame actions stay within the destination visible frame.
- [ ] Fullscreen and minimized state changes are reflected after refresh.
- [ ] Force Quit requires confirmation and targets only the selected process.
- [ ] Membership and selection refresh deterministically after every action.

## Reliability

- [ ] Accessibility denial, grant, revocation, and re-grant produce clear safe behaviour without requiring an unexplained restart.
- [ ] Rapid repeated profile shortcuts do not bleed into Apple’s native switcher.
- [ ] Event-tap timeout recovery restores configured shortcuts.
- [ ] Quit/relaunch, sleep/wake, and Launch at Login preserve profile and durable-history behaviour.
CHECKLIST
}

cleanup() {
  local status=$?
  mkdir -p "${EVIDENCE_DIR}"
  if [[ "${status}" == "0" ]]; then
    printf 'AUTOMATED_PASS\n' > "${RESULT_PATH}"
    write_manual_checks "AUTOMATED_PASS — packaged-app matrix remains required"
  else
    printf 'FAIL (exit %s)\n' "${status}" > "${RESULT_PATH}"
    write_manual_checks "FAIL — automated checks stopped before completion"
  fi
  rm -rf "${TEMP_ROOT}"
}
trap cleanup EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Five-feature QA must run on macOS." >&2
  exit 1
fi

for tool in bash python3 swift git codesign lipo plutil shasum; do
  command -v "${tool}" >/dev/null 2>&1 || {
    echo "Missing required tool: ${tool}" >&2
    exit 1
  }
done

rm -rf "${EVIDENCE_DIR}"
mkdir -p "${EVIDENCE_DIR}"
write_manual_checks "PENDING"
exec > >(tee "${LOG_PATH}") 2>&1

COMMIT_SHA="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
printf 'CmdTab five-feature production QA\n'
printf 'commit=%s\n' "${COMMIT_SHA}"
printf 'macos=%s\n' "$(sw_vers -productVersion)"
printf 'architecture=%s\n' "$(uname -m)"
printf 'swift=%s\n' "$(swift --version | head -n 1)"
date -u '+utc=%Y-%m-%dT%H:%M:%SZ'

printf '\n== Five-feature source contract ==\n'
python3 "${ROOT_DIR}/scripts/release/verify-five-feature-source.py"
python3 "${ROOT_DIR}/scripts/release/release_config.py" verify-repository

printf '\n== Focused five-feature tests ==\n'
swift test \
  --package-path "${ROOT_DIR}" \
  --scratch-path "${TEMP_ROOT}/focused-tests" \
  --filter 'MinimizedWindowPolicyTests|WorkspaceProviderModelTests|SwitcherProfileTests|DurableSwitcherHistoryTests|WindowManagementActionTests|FiveFeatureIntegrationTests'

printf '\n== Complete Swift package suite ==\n'
swift test \
  --package-path "${ROOT_DIR}" \
  --scratch-path "${TEMP_ROOT}/full-tests"

printf '\n== Phase 1 packaging regression gate ==\n'
CMDTAB_PHASE1_EVIDENCE_DIR="${EVIDENCE_DIR}/phase1-regression" \
  bash "${ROOT_DIR}/scripts/release/run-phase1-qa.sh"
[[ "$(cat "${EVIDENCE_DIR}/phase1-regression/result.txt")" == "PASS" ]] || {
  echo "Phase 1 regression gate did not pass." >&2
  exit 1
}

printf '\n== Evidence capture ==\n'
printf '%s\n' "${COMMIT_SHA}" > "${EVIDENCE_DIR}/commit.txt"
sw_vers > "${EVIDENCE_DIR}/macos.txt"
swift --version > "${EVIDENCE_DIR}/swift-version.txt"
cp "${ROOT_DIR}/dist/CmdTab.manifest.json" "${EVIDENCE_DIR}/bundle-manifest.json"
cp "${ROOT_DIR}/dist/CmdTab.sha256" "${EVIDENCE_DIR}/checksums.txt"

printf '\nFive-feature automated QA passed.\n'
printf 'Evidence: %s\n' "${EVIDENCE_DIR}"
printf 'Manual packaged-app matrix: %s\n' "${MANUAL_PATH}"
