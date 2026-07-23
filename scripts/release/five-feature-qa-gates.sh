#!/usr/bin/env bash

# Shared fail-closed gates for run-five-feature-qa.sh. This file intentionally
# has no side effects so its production checks can be exercised hermetically.

verify_focused_xctest_summary() {
  local log_path="$1"
  local expected_count="${2:-50}"
  local summary
  local executed
  local failures
  local unexpected

  [[ -f "${log_path}" ]] || {
    echo "Missing focused XCTest log: ${log_path}" >&2
    return 1
  }

  summary="$(
    sed -nE 's/^[[:space:]]*Executed ([0-9]+) tests?, with ([0-9]+) failures? \(([0-9]+) unexpected\) in [0-9]+(\.[0-9]+)? \([0-9]+(\.[0-9]+)?\) seconds$/\1 \2 \3/p' \
      "${log_path}" | tail -n 1
  )"
  [[ -n "${summary}" ]] || {
    echo "Focused XCTest output did not contain an XCTest execution summary." >&2
    return 1
  }

  read -r executed failures unexpected <<< "${summary}"
  if [[ "${executed}" != "${expected_count}" ]] ||
     [[ "${failures}" != "0" ]] ||
     [[ "${unexpected}" != "0" ]]; then
    echo "Focused XCTest gate failed: expected ${expected_count} executed with 0 failures and 0 unexpected; observed ${executed} executed with ${failures} failures and ${unexpected} unexpected." >&2
    return 1
  fi

  printf 'Focused XCTest gate passed: %s executed, 0 failures.\n' "${executed}"
}

verify_qa_source_snapshot() {
  local root_dir="$1"
  local initial_commit_sha="$2"
  local current_commit_sha
  local tracked_status
  local untracked_status

  current_commit_sha="$(git -C "${root_dir}" rev-parse HEAD)"
  if [[ "${current_commit_sha}" != "${initial_commit_sha}" ]]; then
    echo "QA source HEAD changed: started at ${initial_commit_sha}, now at ${current_commit_sha}." >&2
    return 1
  fi

  tracked_status="$(
    git -C "${root_dir}" status --porcelain=v1 --untracked-files=no
  )"
  if [[ -n "${tracked_status}" ]]; then
    echo "QA source has tracked or staged changes; phase evidence cannot be attributed to ${initial_commit_sha}:" >&2
    printf '%s\n' "${tracked_status}" >&2
    return 1
  fi

  untracked_status="$(
    git -C "${root_dir}" ls-files --others --exclude-standard -- \
      . \
      ':(exclude)dist' \
      ':(exclude)dist/**' \
      ':(exclude).build' \
      ':(exclude).build/**'
  )"
  if [[ -n "${untracked_status}" ]]; then
    echo "QA source has untracked files; phase evidence cannot be attributed to ${initial_commit_sha}:" >&2
    while IFS= read -r path; do
      printf '?? %s\n' "${path}" >&2
    done <<< "${untracked_status}"
    return 1
  fi
}

write_phase_receipt() {
  local receipt_path="$1"
  shift

  (( $# > 0 )) || {
    echo "Cannot write an empty phase receipt: ${receipt_path}" >&2
    return 1
  }
  shasum -a 256 "$@" > "${receipt_path}"
}

verify_phase_receipt() {
  local receipt_path="$1"
  shift
  local expected_count=$#
  local actual_count
  local index=1
  local input
  local line

  [[ -f "${receipt_path}" ]] || {
    echo "Missing phase receipt: ${receipt_path}" >&2
    return 1
  }
  actual_count="$(wc -l < "${receipt_path}" | tr -d '[:space:]')"
  [[ "${actual_count}" == "${expected_count}" ]] || {
    echo "Phase receipt input count changed: expected ${expected_count}, observed ${actual_count}." >&2
    return 1
  }

  for input in "$@"; do
    line="$(sed -n "${index}p" "${receipt_path}")"
    [[ "${line}" == *"  ${input}" ]] || {
      echo "Phase receipt input ${index} is not the expected path: ${input}" >&2
      return 1
    }
    index=$((index + 1))
  done

  shasum -a 256 -c "${receipt_path}"
}

invalidate_phase_records() {
  local phase_dir="$1"
  shift
  local phase

  for phase in "$@"; do
    rm -f \
      "${phase_dir}/${phase}.commit" \
      "${phase_dir}/${phase}.utc" \
      "${phase_dir}/${phase}.log" \
      "${phase_dir}/${phase}.receipt.sha256"
  done
}
