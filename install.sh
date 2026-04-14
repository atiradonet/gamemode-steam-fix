#!/usr/bin/env bash
# install.sh — stage GameMode libraries so Steam's pressure-vessel container can find them
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

Stages GameMode client libraries into ~/.steam-runtime-libs/gamemode/
so that Steam's pressure-vessel container can dlopen them.

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
info "GameMode detected: $(gamemoded --version 2>&1 | head -n 1)"

if ! command -v steam &>/dev/null; then
    warn "Steam not found in PATH. Make sure Steam is installed before using the fix."
fi

# ---------------------------------------------------------------------------
# Check source libraries exist
# ---------------------------------------------------------------------------
if ! ls "${SRC_LIB32}"/libgamemode.so* &>/dev/null; then
    error "32-bit GameMode library not found in ${SRC_LIB32}."
    error "Install it with: sudo dnf install gamemode.i686"
    exit 1
fi
if ! ls "${SRC_LIB64}"/libgamemode.so* &>/dev/null; then
    error "64-bit GameMode library not found in ${SRC_LIB64}."
    error "Install it with: sudo dnf install gamemode"
    exit 1
fi

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

    # Copy all libgamemode.so* resolving symlinks at copy time
    cp -avL "${src}"/libgamemode.so* "${dest}/"

    # Re-create symlinks that resolve *within* the staging directory
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

# ---------------------------------------------------------------------------
# Stage both bitnesses
# ---------------------------------------------------------------------------
stage_libs "${SRC_LIB32}" "${DEST_LIB32}" "32"
stage_libs "${SRC_LIB64}" "${DEST_LIB64}" "64"

# ---------------------------------------------------------------------------
# ELF class verification
# ---------------------------------------------------------------------------
info "Verifying ELF classes..."

verify_elf() {
    local path="$1"
    local expected_bits="$2"

    local output
    output="$(file -L "${path}")"
    if echo "${output}" | grep -q "ELF ${expected_bits}-bit"; then
        info "  OK  ${path} is ELF ${expected_bits}-bit"
    else
        error "ELF mismatch for ${path}: ${output}"
        error "Expected ELF ${expected_bits}-bit. Check that the correct package is installed."
        exit 1
    fi
}

verify_elf "${DEST_LIB32}/libgamemode.so.0" "32"
verify_elf "${DEST_LIB64}/libgamemode.so.0" "64"

# ---------------------------------------------------------------------------
# Record installed version for update-gamemode-libs.sh
# ---------------------------------------------------------------------------
GAMEMODE_VERSION="$(rpm -q --queryformat '%{VERSION}' gamemode 2>/dev/null || echo "unknown")"
echo "${GAMEMODE_VERSION}" > "${VERSION_FILE}"
info "Recorded staged GameMode version: ${GAMEMODE_VERSION}"

# ---------------------------------------------------------------------------
# Success — print Steam launch options
# ---------------------------------------------------------------------------
echo ""
info "Installation complete."
echo ""
echo -e "${GREEN}Add the following line to each game's Steam launch options:${NC}"
echo ""
# Intentionally use single quotes so $HOME is NOT expanded — user pastes it as-is
# shellcheck disable=SC2016
echo '  LD_LIBRARY_PATH="$HOME/.steam-runtime-libs/gamemode/Lib:$HOME/.steam-runtime-libs/gamemode/Lib64:$LD_LIBRARY_PATH" MANGOHUD=1 gamemoderun %command%'
echo ""
echo -e "${YELLOW}How to set launch options:${NC}"
echo "  Steam → Library → Right-click game → Properties → Launch Options"
echo ""
