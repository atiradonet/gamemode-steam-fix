#!/usr/bin/env bash
# uninstall.sh — remove staged GameMode libraries
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

Removes the GameMode staging directory at:
  ~/.steam-runtime-libs/gamemode/

The parent directory (~/.steam-runtime-libs/) is left intact if it contains
other content. No root privileges required.

After running this script, remove the LD_LIBRARY_PATH line from each game's
Steam launch options.

Options:
  --help    Show this message and exit
EOF
}

if [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
DEST_BASE="${HOME}/.steam-runtime-libs/gamemode"
PARENT_DIR="${HOME}/.steam-runtime-libs"

# ---------------------------------------------------------------------------
# Check staging dir exists
# ---------------------------------------------------------------------------
if [[ ! -d "${DEST_BASE}" ]]; then
    warn "Staging directory ${DEST_BASE} does not exist. Nothing to remove."
    exit 0
fi

# ---------------------------------------------------------------------------
# Remove staging directory
# ---------------------------------------------------------------------------
info "Removing ${DEST_BASE} ..."
rm -rf "${DEST_BASE}"
info "Done."

# ---------------------------------------------------------------------------
# Warn if parent directory has other content
# ---------------------------------------------------------------------------
if [[ -d "${PARENT_DIR}" ]]; then
    remaining="$(ls -A "${PARENT_DIR}" 2>/dev/null || true)"
    if [[ -n "${remaining}" ]]; then
        warn "${PARENT_DIR} still contains other content — leaving it in place."
        warn "Contents:"
        ls -la "${PARENT_DIR}"
    else
        info "${PARENT_DIR} is now empty. You may remove it manually if desired:"
        info "  rmdir \"${PARENT_DIR}\""
    fi
fi

# ---------------------------------------------------------------------------
# Remind user to clean up Steam launch options
# ---------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}[REMINDER]${NC} Remove the following from each game's Steam launch options:"
echo ""
# shellcheck disable=SC2016
echo '  LD_LIBRARY_PATH="$HOME/.steam-runtime-libs/gamemode/Lib:$HOME/.steam-runtime-libs/gamemode/Lib64:$LD_LIBRARY_PATH" MANGOHUD=1 gamemoderun %command%'
echo ""
echo "Steam → Library → Right-click game → Properties → Launch Options"
echo ""
