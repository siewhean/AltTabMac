#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/release/five-feature-qa-gates.sh
source "${ROOT_DIR}/scripts/release/five-feature-qa-gates.sh"
EVIDENCE_DIR="${CMDTAB_FIVE_FEATURE_EVIDENCE_DIR:-${ROOT_DIR}/dist/five-feature-evidence}"
PHASE_DIR="${EVIDENCE_DIR}/phases"
LOG_PATH="${EVIDENCE_DIR}/commands.log"
RESULT_PATH="${EVIDENCE_DIR}/result.txt"
MANUAL_PATH="${EVIDENCE_DIR}/manual-checks.md"
PHASE_MIN_FREE_DISK_MB="${CMDTAB_PHASE_MIN_FREE_DISK_MB:-2048}"
MODE="${1:-all}"
CURRENT_PHASE="startup"

write_manual_checks() {
  local automated_status="$1"
  {
    printf '# CmdTab five-feature packaged-app acceptance\n\n'
    printf '**Automated status:** %s\n\n' "${automated_status}"
    cat <<'CHECKLIST'
Complete every applicable row against the exact packaged CmdTab artifact, WindowLab fixture, WindowProbe, and commit recorded in this evidence directory. Record the observed focused `CGWindowID` for every exact-activation row; visual appearance alone is not sufficient.

Paths below are relative to the repository root.

## Test artifacts

- CmdTab: `dist/CmdTab.app`
- WindowLab: `dist/fixtures/WindowLab.app`
- WindowProbe: `dist/fixtures/WindowProbe net.cmdtab.fixture.WindowLab`
- Diagnostics: right-click the CmdTab menu-bar item → **Diagnostics…**

Terminal needs Accessibility permission for WindowProbe to report `focusedWindowID` and `mainWindowID`. The probe emits sanitized window IDs, state, bounds, and fixture titles only.

## Minimized windows

- [ ] With minimized inclusion disabled, WindowLab's minimized target is absent.
- [ ] With minimized inclusion enabled, each eligible minimized window appears exactly once with a visible **Minimized** state; no duplicate app fallback remains.
- [ ] Selecting WindowLab A2 restores and focuses A2 exactly; A1 and other sibling windows remain unchanged.
- [ ] WindowProbe reports the selected tile's PID and `CGWindowID` as focused after restoration.
- [ ] A failed restoration does not change permanent MRU.
- [ ] Screen Recording denial keeps minimized items visible with a safe placeholder and state badge.
- [ ] The global max-windows-per-app limit still applies after minimized/off-Space AX synthesis and retains the active-window anchor.

## Spaces, fullscreen, displays, and Stage Manager

- [ ] Current Space, Visible Spaces, and All Spaces produce the documented membership without duplicates.
- [ ] Diagnostics and the visible overlay distinguish exact, degraded, unavailable, and failed workspace states.
- [ ] Off-Space selection reaches the intended exact window or reports the documented degraded limitation.
- [ ] WindowProbe reports the selected exact `CGWindowID` after every off-Space selection.
- [ ] Fullscreen windows remain individually identifiable and focus correctly.
- [ ] Stage Manager active and hidden sets never silently masquerade as exact when only inferred.
- [ ] Mixed-scale multi-display placement works; disconnect/reconnect repositions or dismisses stale panels without a relaunch.
- [ ] Sleep/wake refreshes workspace and display metadata without leaving an orphaned overlay.

## Shortcut profiles

- [ ] Existing Command-Tab and Option-Tab defaults preserve their previous hold/release and reverse behaviour.
- [ ] At least three profiles retain independent style, scope, minimized policy, display placement, and app filter.
- [ ] Duplicate, reserved, unsafe Command-only, and modifierless character shortcuts are rejected.
- [ ] An enabled Include Only profile cannot be saved with an empty bundle-ID list.
- [ ] At least one profile must remain enabled.
- [ ] Shortcut recording does not trigger or swallow an existing global shortcut.
- [ ] Hold-to-release and press-to-toggle sessions both advance, reverse, commit, and cancel correctly.
- [ ] A profile's resolved style/scope/filter does not change during an already-open session; changes apply to the next session.
- [ ] Existing unambiguous legacy bundle-ID exclusions appear in newly created default profiles; unresolved name entries remain globally excluded rather than guessed.
- [ ] Import/export round-trips; malformed or unsupported-schema JSON is rejected atomically.
- [ ] Secure Input causes configured shortcuts to pass through and cancels any stale CmdTab overlay.
- [ ] When licensing disallows custom switching, the original system/native shortcut is not swallowed.
- [ ] Active CmdTab text fields and shortcut recorders do not leak typed content into the switcher.
- [ ] Closing the profile editor with unsaved changes requires Save, Discard, or Cancel; invalid drafts are never silently lost.

## Durable MRU

- [ ] Restart preserves unique high-confidence exact-window order.
- [ ] Duplicate-title windows do not receive ambiguous restored rank.
- [ ] Reused PID or `CGWindowID` does not inherit unrelated rank.
- [ ] Failed activation does not persist rank.
- [ ] Current-session activations outrank restored records.
- [ ] Reset Durable MRU clears restored order without deleting preferences or licensing state.
- [ ] The persisted JSON has mode 0600 and contains no raw title, URL, preview, search query, clipboard content, or screenshot.
- [ ] Diagnostics reports only sanitized durable-record count and a home-relative location.

## Exact-window actions

- [ ] Unsupported actions are disabled with a visible explanation.
- [ ] Restore, zoom, fullscreen, centre, move-display, half-tile, and third-tile target only the selected exact window.
- [ ] WindowProbe reports the selected target's `CGWindowID` after each non-destructive action.
- [ ] Frame actions stay within the destination visible frame on both displays.
- [ ] Fullscreen and minimized state changes are reflected after refresh.
- [ ] Force Quit requires confirmation and targets only the selected process.
- [ ] Membership and selection refresh deterministically after every action.

## Presentation and accessibility

- [ ] Classic Grid, Command Palette, and Radial Menu all expose Minimized, Fullscreen, Other Space, and inferred Hidden Set state where applicable.
- [ ] VoiceOver announces the selected window state rather than only the title.
- [ ] Workspace degradation is visible without opening Terminal.
- [ ] Exact-window actions are discoverable from every profile style.
- [ ] Diagnostics opens from the menu bar, refreshes, copies a sanitized report, and resets durable MRU safely.

## Reliability

- [ ] Accessibility denial, grant, revocation, and re-grant produce clear safe behaviour without requiring an unexplained restart.
- [ ] Rapid repeated profile shortcuts do not bleed into Apple’s native switcher.
- [ ] Event-tap timeout recovery restores configured shortcuts.
- [ ] Display topology changes, quit/relaunch, sleep/wake, and Launch at Login preserve profile and durable-history behaviour.
- [ ] No crash, deadlock, persistent high CPU, or stuck event tap occurs during a 15-minute mixed-feature stress run.
CHECKLIST
  } > "${MANUAL_PATH}"
}

usage() {
  cat <<'USAGE'
Usage: bash scripts/release/run-five-feature-qa.sh [phase]

Phases:
  source    Source contracts and deterministic WindowLab/WindowProbe fixtures
  tests     Migration, focused feature, and full Swift suites in one reused build tree
  package   Release package, bundle verification, and artifact inspection
  repro     Two-build unsigned reproducibility comparison
  finalize  Verify same-head phase markers and write AUTOMATED_PASS evidence
  all       Run every phase sequentially with scratch cleanup between phases (default)
  status    Show phase markers for the current commit
  reset     Remove five-feature evidence and phase markers

Each phase is resumable and bound to the exact Git commit. A source change invalidates
older markers automatically. The default per-phase disk floor is 2048 MB and can be
raised with CMDTAB_PHASE_MIN_FREE_DISK_MB.
USAGE
}

free_disk_mb() {
  local path="$1"
  df -Pk "${path}" | awk 'NR == 2 { printf "%d\n", $4 / 1024 }'
}

require_phase_disk_space() {
  local path="$1"
  local label="$2"
  local available_mb
  available_mb="$(free_disk_mb "${path}")"

  if [[ ! "${available_mb}" =~ ^[0-9]+$ ]]; then
    echo "Could not determine free disk space for ${label}: ${path}" >&2
    exit 1
  fi

  printf '%s free disk: %s MB (phase minimum: %s MB)\n' \
    "${label}" "${available_mb}" "${PHASE_MIN_FREE_DISK_MB}"

  if (( available_mb < PHASE_MIN_FREE_DISK_MB )); then
    cat >&2 <<EOF
Insufficient free disk space for this phased QA step.
Path: ${path}
Available: ${available_mb} MB
Required phase minimum: ${PHASE_MIN_FREE_DISK_MB} MB

This runner deletes each phase's scratch tree before the next phase, so it does not
need the former 8192 MB monolithic allowance. Free enough space for one build phase
or raise the threshold if this machine's toolchain needs more headroom.
EOF
    exit 1
  fi
}

phase_marker_path() {
  printf '%s/%s.commit\n' "${PHASE_DIR}" "$1"
}

phase_receipt_path() {
  printf '%s/%s.receipt.sha256\n' "${PHASE_DIR}" "$1"
}

set_phase_receipt_inputs() {
  local phase="$1"
  local marker
  local phase_log
  marker="$(phase_marker_path "${phase}")"
  phase_log="${PHASE_DIR}/${phase}.log"
  PHASE_RECEIPT_INPUTS=(
    "${marker}"
    "${PHASE_DIR}/${phase}.utc"
    "${phase_log}"
  )
  case "${phase}" in
    source)
      PHASE_RECEIPT_INPUTS+=(
        "${EVIDENCE_DIR}/windowlab-checksums.txt"
        "${EVIDENCE_DIR}/windowprobe-checksum.txt"
      )
      ;;
    tests)
      PHASE_RECEIPT_INPUTS+=("${EVIDENCE_DIR}/focused-xctest.log")
      ;;
    package)
      PHASE_RECEIPT_INPUTS+=(
        "${EVIDENCE_DIR}/bundle-manifest.json"
        "${EVIDENCE_DIR}/checksums.txt"
        "${ROOT_DIR}/dist/CmdTab.manifest.json"
        "${ROOT_DIR}/dist/CmdTab.sha256"
      )
      ;;
    repro) ;;
    *)
      echo "Unknown receipt phase: ${phase}" >&2
      return 1
      ;;
  esac
}

seal_phase_receipt() {
  local phase="$1"
  set_phase_receipt_inputs "${phase}"
  write_phase_receipt "$(phase_receipt_path "${phase}")" \
    "${PHASE_RECEIPT_INPUTS[@]}"
}

verify_recorded_phase() {
  local phase="$1"
  set_phase_receipt_inputs "${phase}"
  verify_phase_receipt "$(phase_receipt_path "${phase}")" \
    "${PHASE_RECEIPT_INPUTS[@]}"
}

run_recorded_phase() {
  local phase="$1"
  local phase_function="$2"
  local phase_log="${PHASE_DIR}/${phase}.log"
  CURRENT_PHASE="${phase}"
  case "${phase}" in
    source)
      invalidate_phase_records "${PHASE_DIR}" tests package repro
      ;;
    tests)
      invalidate_phase_records "${PHASE_DIR}" package repro
      ;;
    package)
      invalidate_phase_records "${PHASE_DIR}" repro
      ;;
    repro) ;;
  esac
  rm -f "${phase_log}" "$(phase_receipt_path "${phase}")"
  "${phase_function}" 2>&1 | tee "${phase_log}"
  seal_phase_receipt "${phase}"
  write_partial_result
}

record_phase() {
  local phase="$1"
  local marker
  verify_qa_source_snapshot "${ROOT_DIR}" "${COMMIT_SHA}"
  marker="$(phase_marker_path "${phase}")"
  printf '%s\n' "${COMMIT_SHA}" > "${marker}"
  date -u '+%Y-%m-%dT%H:%M:%SZ' > "${PHASE_DIR}/${phase}.utc"
  printf 'PASS phase=%s commit=%s\n' "${phase}" "${COMMIT_SHA}"
}

require_phase() {
  local phase="$1"
  local marker
  local recorded
  marker="$(phase_marker_path "${phase}")"
  [[ -f "${marker}" ]] || {
    echo "Missing prerequisite phase: ${phase}" >&2
    echo "Run: bash scripts/release/run-five-feature-qa.sh ${phase}" >&2
    exit 1
  }
  recorded="$(cat "${marker}")"
  [[ "${recorded}" == "${COMMIT_SHA}" ]] || {
    echo "Phase ${phase} belongs to ${recorded}, not current HEAD ${COMMIT_SHA}." >&2
    echo "Rerun the phase on the current commit." >&2
    exit 1
  }
  verify_recorded_phase "${phase}" || {
    echo "Phase ${phase} evidence no longer matches its receipt. Rerun the phase." >&2
    exit 1
  }
}

write_partial_result() {
  {
    printf 'PARTIAL\n'
    printf 'commit=%s\n' "${COMMIT_SHA}"
    for phase in source tests package repro; do
      local marker
      marker="$(phase_marker_path "${phase}")"
      if [[ -f "${marker}" ]] &&
         [[ "$(cat "${marker}")" == "${COMMIT_SHA}" ]] &&
         verify_recorded_phase "${phase}" >/dev/null 2>&1; then
        printf '%s=PASS\n' "${phase}"
      else
        printf '%s=PENDING\n' "${phase}"
      fi
    done
  } > "${RESULT_PATH}"
}

phase_source() {
  CURRENT_PHASE="source"
  printf '\n== Phase: source and deterministic fixtures ==\n'
  require_phase_disk_space "${ROOT_DIR}" "Repository/output volume"

  (
    local temp_root
    temp_root="$(mktemp -d /tmp/cmdtab-five-feature-source.XXXXXX)"
    trap 'rm -rf "${temp_root}"' EXIT

    python3 "${ROOT_DIR}/scripts/release/verify-five-feature-source.py"
    bash "${ROOT_DIR}/scripts/release/test-five-feature-qa-gates.sh"
    python3 "${ROOT_DIR}/scripts/release/release_config.py" verify-repository

    CMDTAB_WINDOWLAB_SCRATCH="${temp_root}/windowlab" \
      bash "${ROOT_DIR}/scripts/release/build-windowlab-fixture.sh"
    codesign --verify --strict --verbose=2 "${ROOT_DIR}/dist/fixtures/WindowLab.app"
    cp "${ROOT_DIR}/dist/fixtures/WindowLab.sha256" \
      "${EVIDENCE_DIR}/windowlab-checksums.txt"

    CMDTAB_WINDOWPROBE_SCRATCH="${temp_root}/windowprobe" \
      bash "${ROOT_DIR}/scripts/release/build-windowprobe-fixture.sh"
    cp "${ROOT_DIR}/dist/fixtures/WindowProbe.sha256" \
      "${EVIDENCE_DIR}/windowprobe-checksum.txt"
  )

  record_phase source
}

phase_tests() {
  CURRENT_PHASE="tests"
  require_phase source
  printf '\n== Phase: all Swift tests in one reused build tree ==\n'
  require_phase_disk_space "/tmp" "Temporary build volume"

  (
    local temp_root
    local scratch
    local focused_log
    temp_root="$(mktemp -d /tmp/cmdtab-five-feature-tests.XXXXXX)"
    scratch="${temp_root}/swift-tests"
    focused_log="${EVIDENCE_DIR}/focused-xctest.log"
    trap 'rm -rf "${temp_root}"' EXIT

    printf '\n-- Bundle migration tests (build once) --\n'
    swift test \
      --package-path "${ROOT_DIR}" \
      --scratch-path "${scratch}" \
      --filter BundleIdentityMigrationTests

    printf '\n-- Focused five-feature tests (reuse build) --\n'
    swift test \
      --package-path "${ROOT_DIR}" \
      --scratch-path "${scratch}" \
      --skip-build \
      --filter 'MinimizedWindowPolicyTests|WorkspaceProviderModelTests|SwitcherProfileTests|SwitcherProfileSafetyTests|SwitcherSessionConfigurationFreezeTests|DurableSwitcherHistoryTests|WindowManagementActionTests|FiveFeatureIntegrationTests|ProductionMembershipPolicyTests|ProductionVisualStateTests' \
      2>&1 | tee "${focused_log}"
    verify_focused_xctest_summary "${focused_log}" 50

    printf '\n-- Complete Swift package suite (reuse build) --\n'
    swift test \
      --package-path "${ROOT_DIR}" \
      --scratch-path "${scratch}" \
      --skip-build
  )

  record_phase tests
}

phase_package() {
  CURRENT_PHASE="package"
  require_phase tests
  printf '\n== Phase: release package and bundle verification ==\n'
  require_phase_disk_space "${ROOT_DIR}" "Repository/output volume"

  (
    local temp_root
    temp_root="$(mktemp -d /tmp/cmdtab-five-feature-package.XXXXXX)"
    trap 'rm -rf "${temp_root}"' EXIT

    CMDTAB_OUTPUT_APP="${ROOT_DIR}/dist/CmdTab.app" \
    CMDTAB_RELEASE_SCRATCH="${temp_root}/release" \
      bash "${ROOT_DIR}/scripts/release/package-app.sh"

    bash "${ROOT_DIR}/scripts/release/verify-bundle.sh" \
      "${ROOT_DIR}/dist/CmdTab.app" ad-hoc

    plutil -p "${ROOT_DIR}/dist/CmdTab.app/Contents/Info.plist"
    codesign -d --verbose=4 --entitlements :- \
      "${ROOT_DIR}/dist/CmdTab.app" 2>&1
    lipo -archs "${ROOT_DIR}/dist/CmdTab.app/Contents/MacOS/CmdTab"

    cp "${ROOT_DIR}/dist/CmdTab.manifest.json" \
      "${EVIDENCE_DIR}/bundle-manifest.json"
    cp "${ROOT_DIR}/dist/CmdTab.sha256" \
      "${EVIDENCE_DIR}/checksums.txt"
  )

  record_phase package
}

phase_repro() {
  CURRENT_PHASE="repro"
  require_phase package
  printf '\n== Phase: two-build unsigned reproducibility ==\n'
  require_phase_disk_space "/tmp" "Temporary build volume"

  bash "${ROOT_DIR}/scripts/release/reproducibility-check.sh"
  record_phase repro
}

phase_finalize() {
  CURRENT_PHASE="finalize"
  printf '\n== Phase: exact-head evidence finalization ==\n'
  verify_qa_source_snapshot "${ROOT_DIR}" "${COMMIT_SHA}"
  require_phase source
  require_phase tests
  require_phase package
  require_phase repro

  [[ -d "${ROOT_DIR}/dist/CmdTab.app" ]] || {
    echo "Missing packaged application: dist/CmdTab.app" >&2
    exit 1
  }
  [[ -f "${EVIDENCE_DIR}/bundle-manifest.json" ]] || {
    echo "Missing bundle manifest evidence." >&2
    exit 1
  }
  [[ -f "${EVIDENCE_DIR}/checksums.txt" ]] || {
    echo "Missing checksum evidence." >&2
    exit 1
  }

  cmp "${ROOT_DIR}/dist/CmdTab.manifest.json" \
    "${EVIDENCE_DIR}/bundle-manifest.json"
  cmp "${ROOT_DIR}/dist/CmdTab.sha256" \
    "${EVIDENCE_DIR}/checksums.txt"
  (
    cd "${ROOT_DIR}/dist"
    shasum -a 256 -c CmdTab.sha256
  )
  bash "${ROOT_DIR}/scripts/release/verify-bundle.sh" \
    "${ROOT_DIR}/dist/CmdTab.app" ad-hoc

  cmp "${ROOT_DIR}/dist/fixtures/WindowLab.sha256" \
    "${EVIDENCE_DIR}/windowlab-checksums.txt"
  cmp "${ROOT_DIR}/dist/fixtures/WindowProbe.sha256" \
    "${EVIDENCE_DIR}/windowprobe-checksum.txt"
  (
    cd "${ROOT_DIR}/dist/fixtures"
    shasum -a 256 -c WindowLab.sha256
  )
  shasum -a 256 -c "${ROOT_DIR}/dist/fixtures/WindowProbe.sha256"
  codesign --verify --strict --verbose=2 \
    "${ROOT_DIR}/dist/fixtures/WindowLab.app"

  verify_qa_source_snapshot "${ROOT_DIR}" "${COMMIT_SHA}"
  printf '%s\n' "${COMMIT_SHA}" > "${EVIDENCE_DIR}/commit.txt"
  sw_vers > "${EVIDENCE_DIR}/macos.txt"
  swift --version > "${EVIDENCE_DIR}/swift-version.txt"
  write_manual_checks "AUTOMATED_PASS — packaged-app matrix remains required"
  printf 'AUTOMATED_PASS\n' > "${RESULT_PATH}"

  printf '\nFive-feature automated QA passed.\n'
  printf 'Evidence: %s\n' "${EVIDENCE_DIR}"
  printf 'Manual packaged-app matrix: %s\n' "${MANUAL_PATH}"
  printf 'WindowLab: %s\n' "${ROOT_DIR}/dist/fixtures/WindowLab.app"
  printf 'WindowProbe: %s\n' "${ROOT_DIR}/dist/fixtures/WindowProbe"
}

show_status() {
  printf 'current_commit=%s\n' "${COMMIT_SHA}"
  for phase in source tests package repro; do
    local marker
    local value="PENDING"
    marker="$(phase_marker_path "${phase}")"
    if [[ -f "${marker}" ]]; then
      if [[ "$(cat "${marker}")" == "${COMMIT_SHA}" ]]; then
        if verify_recorded_phase "${phase}" >/dev/null 2>&1; then
          value="PASS"
        else
          value="TAMPERED"
        fi
      else
        value="STALE ($(cat "${marker}"))"
      fi
    fi
    printf '%s=%s\n' "${phase}" "${value}"
  done
  if [[ -f "${RESULT_PATH}" ]]; then
    printf 'result=%s\n' "$(head -n 1 "${RESULT_PATH}")"
  else
    printf 'result=PENDING\n'
  fi
}

on_exit() {
  local status=$?
  if (( status != 0 )); then
    mkdir -p "${EVIDENCE_DIR}"
    printf 'FAIL phase=%s exit=%s\n' "${CURRENT_PHASE}" "${status}" > "${RESULT_PATH}"
  fi
}

if [[ "${MODE}" == "reset" ]]; then
  rm -rf "${EVIDENCE_DIR}"
  printf 'Removed %s\n' "${EVIDENCE_DIR}"
  exit 0
fi

case "${MODE}" in
  source|tests|package|repro|finalize|all|status) ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Five-feature QA must run on macOS." >&2
  exit 1
fi

for tool in bash python3 swift swiftc git codesign lipo plutil shasum cmp df awk; do
  command -v "${tool}" >/dev/null 2>&1 || {
    echo "Missing required tool: ${tool}" >&2
    exit 1
  }
done

if [[ "${MODE}" == "all" ]]; then
  rm -rf "${EVIDENCE_DIR}"
fi
mkdir -p "${EVIDENCE_DIR}" "${PHASE_DIR}"
if [[ ! -f "${MANUAL_PATH}" ]]; then
  write_manual_checks "PENDING"
fi
if [[ ! -f "${RESULT_PATH}" ]]; then
  printf 'PENDING\n' > "${RESULT_PATH}"
fi

exec > >(tee -a "${LOG_PATH}") 2>&1
COMMIT_SHA="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
trap on_exit EXIT

printf 'CmdTab five-feature phased production QA\n'
printf 'mode=%s\n' "${MODE}"
printf 'commit=%s\n' "${COMMIT_SHA}"
printf 'macos=%s\n' "$(sw_vers -productVersion)"
printf 'architecture=%s\n' "$(uname -m)"
printf 'swift=%s\n' "$(swift --version | head -n 1)"
date -u '+utc=%Y-%m-%dT%H:%M:%SZ'

case "${MODE}" in
  source) run_recorded_phase source phase_source ;;
  tests) run_recorded_phase tests phase_tests ;;
  package) run_recorded_phase package phase_package ;;
  repro) run_recorded_phase repro phase_repro ;;
  finalize) phase_finalize ;;
  status) show_status ;;
  all)
    run_recorded_phase source phase_source
    run_recorded_phase tests phase_tests
    run_recorded_phase package phase_package
    run_recorded_phase repro phase_repro
    phase_finalize
    ;;
esac
