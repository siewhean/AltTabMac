#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/release/five-feature-qa-gates.sh
source "${ROOT_DIR}/scripts/release/five-feature-qa-gates.sh"

TEMP_ROOT="$(mktemp -d /tmp/cmdtab-five-feature-gates.XXXXXX)"
trap 'rm -rf "${TEMP_ROOT}"' EXIT

pass_count=0

expect_pass() {
  local label="$1"
  shift
  if "$@"; then
    printf 'PASS: %s\n' "${label}"
    pass_count=$((pass_count + 1))
  else
    echo "Expected pass: ${label}" >&2
    exit 1
  fi
}

expect_fail() {
  local label="$1"
  shift
  if "$@"; then
    echo "Expected failure: ${label}" >&2
    exit 1
  else
    printf 'PASS: %s rejected\n' "${label}"
    pass_count=$((pass_count + 1))
  fi
}

printf "Test Suite 'FocusedFiveFeatureTests' passed.\nExecuted 50 tests, with 0 failures (0 unexpected) in 1.000 (1.001) seconds\n" \
  > "${TEMP_ROOT}/focused-pass.log"
printf "Test Suite 'FocusedFiveFeatureTests' passed.\nExecuted 49 tests, with 0 failures (0 unexpected) in 1.000 (1.001) seconds\n" \
  > "${TEMP_ROOT}/focused-wrong-count.log"
printf "Test Suite 'FocusedFiveFeatureTests' failed.\nExecuted 50 tests, with 1 failure (0 unexpected) in 1.000 (1.001) seconds\n" \
  > "${TEMP_ROOT}/focused-failure.log"
printf "Executed 50 tests, with 0 failures (1 unexpected) in 1.000 (1.001) seconds\n" \
  > "${TEMP_ROOT}/focused-unexpected.log"
printf "prefix Executed 50 tests, with 0 failures (0 unexpected) in 1.000 (1.001) seconds suffix\n" \
  > "${TEMP_ROOT}/focused-noncanonical.log"

expect_pass "exact focused XCTest count" \
  verify_focused_xctest_summary "${TEMP_ROOT}/focused-pass.log" 50
expect_fail "wrong focused XCTest count" \
  verify_focused_xctest_summary "${TEMP_ROOT}/focused-wrong-count.log" 50
expect_fail "focused XCTest failure" \
  verify_focused_xctest_summary "${TEMP_ROOT}/focused-failure.log" 50
expect_fail "focused XCTest unexpected failure" \
  verify_focused_xctest_summary "${TEMP_ROOT}/focused-unexpected.log" 50
expect_fail "noncanonical focused XCTest summary" \
  verify_focused_xctest_summary "${TEMP_ROOT}/focused-noncanonical.log" 50

TEST_REPO="${TEMP_ROOT}/repo"
mkdir -p "${TEST_REPO}"
git -C "${TEST_REPO}" init -q
git -C "${TEST_REPO}" config user.name "CmdTab QA"
git -C "${TEST_REPO}" config user.email "qa@cmdtab.invalid"
printf 'baseline\n' > "${TEST_REPO}/tracked.txt"
mkdir -p "${TEST_REPO}/dist" "${TEST_REPO}/.build"
printf 'tracked dist\n' > "${TEST_REPO}/dist/tracked.txt"
printf 'tracked build\n' > "${TEST_REPO}/.build/tracked.txt"
git -C "${TEST_REPO}" add -f tracked.txt dist/tracked.txt .build/tracked.txt
git -C "${TEST_REPO}" commit -qm "baseline"
INITIAL_SHA="$(git -C "${TEST_REPO}" rev-parse HEAD)"

expect_pass "clean source snapshot" \
  verify_qa_source_snapshot "${TEST_REPO}" "${INITIAL_SHA}"

printf 'generated\n' > "${TEST_REPO}/dist/evidence.txt"
printf 'generated\n' > "${TEST_REPO}/.build/cache.txt"
expect_pass "generated evidence allowances" \
  verify_qa_source_snapshot "${TEST_REPO}" "${INITIAL_SHA}"

printf 'dirty\n' >> "${TEST_REPO}/dist/tracked.txt"
expect_fail "tracked dist change" \
  verify_qa_source_snapshot "${TEST_REPO}" "${INITIAL_SHA}"
git -C "${TEST_REPO}" checkout -q -- dist/tracked.txt

printf 'dirty\n' >> "${TEST_REPO}/.build/tracked.txt"
expect_fail "tracked build change" \
  verify_qa_source_snapshot "${TEST_REPO}" "${INITIAL_SHA}"
git -C "${TEST_REPO}" checkout -q -- .build/tracked.txt

printf 'dirty\n' >> "${TEST_REPO}/tracked.txt"
expect_fail "dirty tracked worktree" \
  verify_qa_source_snapshot "${TEST_REPO}" "${INITIAL_SHA}"
git -C "${TEST_REPO}" checkout -q -- tracked.txt

printf 'untracked\n' > "${TEST_REPO}/untracked.txt"
expect_fail "dirty untracked worktree" \
  verify_qa_source_snapshot "${TEST_REPO}" "${INITIAL_SHA}"
rm "${TEST_REPO}/untracked.txt"

printf 'next\n' >> "${TEST_REPO}/tracked.txt"
git -C "${TEST_REPO}" add tracked.txt
git -C "${TEST_REPO}" commit -qm "head drift"
expect_fail "HEAD drift" \
  verify_qa_source_snapshot "${TEST_REPO}" "${INITIAL_SHA}"

RECEIPT_DIR="${TEMP_ROOT}/receipts"
mkdir -p "${RECEIPT_DIR}"
for name in marker artifact manifest checksum; do
  printf '%s baseline\n' "${name}" > "${RECEIPT_DIR}/${name}"
done
RECEIPT_PATH="${RECEIPT_DIR}/phase.receipt.sha256"
RECEIPT_INPUTS=(
  "${RECEIPT_DIR}/marker"
  "${RECEIPT_DIR}/artifact"
  "${RECEIPT_DIR}/manifest"
  "${RECEIPT_DIR}/checksum"
)
write_phase_receipt "${RECEIPT_PATH}" "${RECEIPT_INPUTS[@]}"
expect_pass "intact phase receipt" \
  verify_phase_receipt "${RECEIPT_PATH}" "${RECEIPT_INPUTS[@]}"

for name in marker artifact manifest checksum; do
  printf 'mutated\n' >> "${RECEIPT_DIR}/${name}"
  expect_fail "mutated phase ${name}" \
    verify_phase_receipt "${RECEIPT_PATH}" "${RECEIPT_INPUTS[@]}"
  printf '%s baseline\n' "${name}" > "${RECEIPT_DIR}/${name}"
done

PHASE_RECORD_DIR="${TEMP_ROOT}/phase-records"
mkdir -p "${PHASE_RECORD_DIR}"
for phase in source tests package repro; do
  for suffix in commit utc log receipt.sha256; do
    printf 'record\n' > "${PHASE_RECORD_DIR}/${phase}.${suffix}"
  done
done
invalidate_phase_records "${PHASE_RECORD_DIR}" tests package repro
if [[ -f "${PHASE_RECORD_DIR}/source.commit" ]] &&
   [[ ! -e "${PHASE_RECORD_DIR}/tests.commit" ]] &&
   [[ ! -e "${PHASE_RECORD_DIR}/package.utc" ]] &&
   [[ ! -e "${PHASE_RECORD_DIR}/repro.receipt.sha256" ]]; then
  printf 'PASS: earlier phase rerun invalidates downstream records\n'
  pass_count=$((pass_count + 1))
else
  echo "Earlier phase rerun did not invalidate downstream records." >&2
  exit 1
fi

[[ "${pass_count}" == "18" ]] || {
  echo "Expected 18 regression checks, observed ${pass_count}." >&2
  exit 1
}
printf 'Five-feature QA gate regressions passed: %s/18\n' "${pass_count}"
