#!/usr/bin/env bash
# Shared release metadata. Callers must define ROOT_DIR before sourcing this file.

if [ -z "${ROOT_DIR:-}" ]; then
    echo "ROOT_DIR must be set before sourcing release_metadata.sh" >&2
    return 1 2>/dev/null || exit 1
fi

CMDTAB_SOURCE_PLIST="${ROOT_DIR}/Resources/Info.plist"
if [ ! -f "${CMDTAB_SOURCE_PLIST}" ]; then
    echo "Missing source Info.plist: ${CMDTAB_SOURCE_PLIST}" >&2
    return 1 2>/dev/null || exit 1
fi

release_plist_value() {
    plutil -extract "$1" raw -o - "$2"
}

CMDTAB_APP_NAME="${CMDTAB_APP_NAME:-$(release_plist_value CFBundleName "${CMDTAB_SOURCE_PLIST}")}"
CMDTAB_VERSION="${CMDTAB_VERSION:-$(release_plist_value CFBundleShortVersionString "${CMDTAB_SOURCE_PLIST}")}"
CMDTAB_BUILD_NUMBER="${CMDTAB_BUILD_NUMBER:-$(release_plist_value CFBundleVersion "${CMDTAB_SOURCE_PLIST}")}"
CMDTAB_BUNDLE_ID="${CMDTAB_BUNDLE_ID:-$(release_plist_value CFBundleIdentifier "${CMDTAB_SOURCE_PLIST}")}"
CMDTAB_MIN_MACOS_VERSION="${CMDTAB_MIN_MACOS_VERSION:-$(release_plist_value LSMinimumSystemVersion "${CMDTAB_SOURCE_PLIST}")}"
CMDTAB_RELEASE_TAG="${CMDTAB_RELEASE_TAG:-v${CMDTAB_VERSION}}"
CMDTAB_DMG_BASENAME="${CMDTAB_DMG_BASENAME:-${CMDTAB_APP_NAME}-${CMDTAB_VERSION}-universal.dmg}"

validate_release_metadata_against_source() {
    local source_app_name source_version source_build source_bundle_id source_minos
    source_app_name="$(release_plist_value CFBundleName "${CMDTAB_SOURCE_PLIST}")"
    source_version="$(release_plist_value CFBundleShortVersionString "${CMDTAB_SOURCE_PLIST}")"
    source_build="$(release_plist_value CFBundleVersion "${CMDTAB_SOURCE_PLIST}")"
    source_bundle_id="$(release_plist_value CFBundleIdentifier "${CMDTAB_SOURCE_PLIST}")"
    source_minos="$(release_plist_value LSMinimumSystemVersion "${CMDTAB_SOURCE_PLIST}")"

    [ "${CMDTAB_APP_NAME}" = "${source_app_name}" ] || return 1
    [ "${CMDTAB_VERSION}" = "${source_version}" ] || return 1
    [ "${CMDTAB_BUILD_NUMBER}" = "${source_build}" ] || return 1
    [ "${CMDTAB_BUNDLE_ID}" = "${source_bundle_id}" ] || return 1
    [ "${CMDTAB_MIN_MACOS_VERSION}" = "${source_minos}" ] || return 1
    [ "${CMDTAB_RELEASE_TAG}" = "v${source_version}" ] || return 1
    [ "${CMDTAB_DMG_BASENAME}" = "${source_app_name}-${source_version}-universal.dmg" ] || return 1
}

case "${CMDTAB_DMG_BASENAME}" in
    */*|'' )
        echo "CMDTAB_DMG_BASENAME must be a non-empty filename" >&2
        return 1 2>/dev/null || exit 1
        ;;
esac

for release_value in \
    "${CMDTAB_APP_NAME}" \
    "${CMDTAB_VERSION}" \
    "${CMDTAB_BUILD_NUMBER}" \
    "${CMDTAB_BUNDLE_ID}" \
    "${CMDTAB_MIN_MACOS_VERSION}" \
    "${CMDTAB_RELEASE_TAG}"; do
    if [ -z "${release_value}" ]; then
        echo "Release metadata values must not be empty" >&2
        return 1 2>/dev/null || exit 1
    fi
done
