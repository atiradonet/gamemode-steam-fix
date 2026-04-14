#!/usr/bin/env bash
# update-gamemode-libs.sh — re-stage GameMode libraries after a dnf upgrade
# https://github.com/atiradonet/gamemode-steam-fix
set -euo pipefail

# ---------------------------------------------------------------------------
# Colour helpers
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: $(basename "$0") [--help]

Re-stages GameMode client libraries after a 'dnf upgrade' that updates gamemode.
Compares the installed version against the staged version and updates if needed.

Run this manually after: sudo dnf upgrade

Options:
  --help    Show this message and exit

No root privileges required.
EOF
}

if [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SRC_LIB32="/usr/lib"
SRC_LIB64="/usr/lib64"
DEST_BASE="${HOME}/.steam-runtime-libs/gamemode"
DEST_LIB32="${DEST_BASE}/Lib"
DEST_LIB64="${DEST_BASE}/Lib64"
VERSION_FILE="${DEST_BASE}/.version"

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
if ! command -v gamemoded &>/dev/null; then
    error "GameMode is not installed (gamemoded not found in PATH)."
    error "Install it with: sudo dnf install gamemode gamemode.i686"
    exit 1
fi

if [[ ! -d "${DEST_BASE}" ]]; then
    warn "Staging directory ${DEST_BASE} does not exist."
    warn "Run install.sh first to perform the initial setup."
    exit 1
fi

# ---------------------------------------------------------------------------
# Version comparison
# ---------------------------------------------------------------------------
INSTALLED_VERSION="$(rpm -q --queryformat '%{VERSION}' gamemode 2>/dev/null || echo "unknown")"

STAGED_VERSION="unknown"
if [[ -f "${VERSION_FILE}" ]]; then
    STAGED_VERSION="$(cat "${VERSION_FILE}")"
fi

info "Installed GameMode version : ${INSTALLED_VERSION}"
info "Staged GameMode version    : ${STAGED_VERSION}"

if [[ "${INSTALLED_VERSION}" == "${STAGED_VERSION}" ]]; then
    info "GameMode libs already current (v${INSTALLED_VERSION}). Nothing to do."
    exit 0
fi

info "Version mismatch detected — re-staging libraries..."

# ---------------------------------------------------------------------------
# Stage a library set into a destination directory
# $1 = source directory  $2 = destination directory  $3 = label (32/64)
# ---------------------------------------------------------------------------
stage_libs() {
    local src="$1"
    local dest="$2"
    local label="$3"

    info "Staging ${label}-bit libraries from ${src} → ${dest}"
    mkdir -p "${dest}"

    cp -avL "${src}"/libgamemode.so* "${dest}/"

    (
        cd "${dest}"
        # shellcheck disable=SC2012
        real="$(ls -1 libgamemode.so.* 2>/dev/null | sort -V | tail -n 1)"
        if [[ -z "${real}" ]]; then
            error "No versioned libgamemode.so.* file found in ${dest} after staging."
            exit 1
        fi
        ln -sf "${real}" libgamemode.so.0
        ln -sf libgamemode.so.0 libgamemode.so
        info "  symlinks: libgamemode.so → libgamemode.so.0 → ${real}"
    )
}

# Check source libraries exist before attempting to stage
if ! ls "${SRC_LIB32}"/libgamemode.so* &>/dev/null; then
    error "32-bit GameMode library not found in ${SRC_LIB32}."
    exit 1
fi
if ! ls "${SRC_LIB64}"/libgamemode.so* &>/dev/null; then
    error "64-bit GameMode library not found in ${SRC_LIB64}."
    exit 1
fi

stage_libs "${SRC_LIB32}" "${DEST_LIB32}" "32"
stage_libs "${SRC_LIB64}" "${DEST_LIB64}" "64"

# ---------------------------------------------------------------------------
# ELF verification
# ---------------------------------------------------------------------------
verify_elf() {
    local path="$1"
    local expected_bits="$2"

    local output
    output="$(file -L "${path}")"
    if echo "${output}" | grep -q "ELF ${expected_bits}-bit"; then
        info "  OK  ${path} is ELF ${expected_bits}-bit"
    else
        error "ELF mismatch for ${path}: ${output}"
        exit 1
    fi
}

verify_elf "${DEST_LIB32}/libgamemode.so.0" "32"
verify_elf "${DEST_LIB64}/libgamemode.so.0" "64"

# ---------------------------------------------------------------------------
# Record new version
# ---------------------------------------------------------------------------
echo "${INSTALLED_VERSION}" > "${VERSION_FILE}"

echo ""
if [[ "${STAGED_VERSION}" == "unknown" ]]; then
    info "GameMode libs staged at v${INSTALLED_VERSION}."
else
    info "GameMode libs updated from ${STAGED_VERSION} to ${INSTALLED_VERSION}."
fi
echo ""
