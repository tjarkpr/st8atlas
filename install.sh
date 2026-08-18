#!/usr/bin/env bash
set -euo pipefail

REPOSITORY="tjarkpr/st8atlas"
COMMAND_NAME="st8atlas"

VERSION="latest"
INSTALL_DIR="${ST8ATLAS_INSTALL_DIR:-${HOME}/.local/share/st8atlas}"
BIN_DIR="${ST8ATLAS_BIN_DIR:-${HOME}/.local/bin}"
UNINSTALL="false"
UPDATE_PROFILE="true"

usage() {
  cat <<EOF
Usage: install.sh [options]

Downloads a st8atlas release from GitHub and puts '${COMMAND_NAME}' on your PATH.

Options:
  --version <tag>       Release tag to install (default: latest)
  --install-dir <dir>   Where the sources are installed (default: ${INSTALL_DIR})
  --bin-dir <dir>       Where the launcher is linked (default: ${BIN_DIR})
  --no-profile          Do not touch your shell profile
  --uninstall           Remove a previous installation
  -h, --help            Show this help
EOF
}

log() { echo "[install] $*"; }
die() { echo "[install] error: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)      [[ $# -ge 2 ]] || die "Missing value for '--version'."; VERSION="$2"; shift 2 ;;
    --install-dir)  [[ $# -ge 2 ]] || die "Missing value for '--install-dir'."; INSTALL_DIR="$2"; shift 2 ;;
    --bin-dir)      [[ $# -ge 2 ]] || die "Missing value for '--bin-dir'."; BIN_DIR="$2"; shift 2 ;;
    --no-profile)   UPDATE_PROFILE="false"; shift ;;
    --uninstall)    UNINSTALL="true"; shift ;;
    -h|--help)      usage; exit 0 ;;
    *)              echo "[install] error: Unknown argument '$1'." >&2; usage; exit 1 ;;
  esac
done

if [[ "$UNINSTALL" == "true" ]]; then
  rm -f "${BIN_DIR}/${COMMAND_NAME}"
  rm -rf "$INSTALL_DIR"
  log "Removed '${INSTALL_DIR}' and '${BIN_DIR}/${COMMAND_NAME}'."
  log "The PATH entry in your shell profile was left untouched."
  exit 0
fi

command -v tar > /dev/null 2>&1 || die "'tar' is required."

download() {
  local url="$1" target="$2"
  if command -v curl > /dev/null 2>&1; then
    curl -fsSL "$url" -o "$target"
  elif command -v wget > /dev/null 2>&1; then
    wget -qO "$target" "$url"
  else
    die "Either 'curl' or 'wget' is required."
  fi
}

resolve_latest_version() {
  local api="https://api.github.com/repos/${REPOSITORY}/releases/latest"
  local payload
  payload="$(mktemp)"
  download "$api" "$payload" || die "Could not query the latest release of '${REPOSITORY}'."
  local tag
  tag="$(grep -m 1 '"tag_name"' "$payload" | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
  rm -f "$payload"
  [[ -n "$tag" ]] || die "Could not determine the latest release tag."
  echo "$tag"
}

[[ "$VERSION" == "latest" ]] && VERSION="$(resolve_latest_version)"

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

TARBALL="${TEMP_DIR}/st8atlas.tar.gz"
ASSET_URL="https://github.com/${REPOSITORY}/releases/download/${VERSION}/st8atlas-${VERSION}.tar.gz"
SOURCE_URL="https://github.com/${REPOSITORY}/archive/refs/tags/${VERSION}.tar.gz"

log "Installing st8atlas ${VERSION}."
if ! download "$ASSET_URL" "$TARBALL" 2> /dev/null; then
  log "No release asset found, falling back to the source tarball."
  download "$SOURCE_URL" "$TARBALL" || die "Could not download release '${VERSION}'."
fi

tar -xzf "$TARBALL" -C "$TEMP_DIR" || die "Could not extract the downloaded archive."

# The layout differs between a release asset and the generated source tarball,
# so locate the entry point instead of assuming a fixed path.
ENTRY_POINT="$(find "$TEMP_DIR" -type f -name "${COMMAND_NAME}.sh" -print -quit)"
[[ -n "$ENTRY_POINT" ]] || die "The archive does not contain '${COMMAND_NAME}.sh'."
SOURCE_DIR="$(dirname "$ENTRY_POINT")"
[[ -d "${SOURCE_DIR}/lib" && -d "${SOURCE_DIR}/commands" ]] || die "The archive is incomplete, 'lib' or 'commands' is missing."

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -R "${SOURCE_DIR}/." "$INSTALL_DIR/"
chmod +x "${INSTALL_DIR}/${COMMAND_NAME}.sh"
echo "$VERSION" > "${INSTALL_DIR}/VERSION"

mkdir -p "$BIN_DIR"
ln -sf "${INSTALL_DIR}/${COMMAND_NAME}.sh" "${BIN_DIR}/${COMMAND_NAME}"

log "Installed to '${INSTALL_DIR}'."
log "Linked '${BIN_DIR}/${COMMAND_NAME}'."

if [[ ":${PATH}:" == *":${BIN_DIR}:"* ]]; then
  log "Run '${COMMAND_NAME} --help' to get started."
  exit 0
fi

if [[ "$UPDATE_PROFILE" != "true" ]]; then
  log "'${BIN_DIR}' is not on your PATH. Add it manually to use '${COMMAND_NAME}'."
  exit 0
fi

case "${SHELL:-}" in
  */zsh) PROFILE="${HOME}/.zshrc" ;;
  */bash) PROFILE="${HOME}/.bashrc" ;;
  *) PROFILE="${HOME}/.profile" ;;
esac

PATH_LINE="export PATH=\"${BIN_DIR}:\$PATH\""
if [[ -f "$PROFILE" ]] && grep -Fq "$PATH_LINE" "$PROFILE"; then
  log "'${PROFILE}' already exports '${BIN_DIR}'."
else
  {
    echo ""
    echo "# Added by the st8atlas installer."
    echo "$PATH_LINE"
  } >> "$PROFILE"
  log "Added '${BIN_DIR}' to the PATH in '${PROFILE}'."
fi

log "Open a new shell or run 'source ${PROFILE}', then '${COMMAND_NAME} --help'."
