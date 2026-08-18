#!/usr/bin/env bash
set -euo pipefail

ensure_artifacts() {
  local directory="$1"
  if [[ ! -d "$directory" || ! -r "$directory" || ! -x "$directory" || -z "$(ls -A "$directory")" ]]; then
    echo "[st8atlas] error: Required directory '$directory' is missing, not readable, not executable, or empty. Please ensure that the installation is complete and that the directory exists and is accessible." >&2
    exit 1
  fi
}

source_artifacts() {
  local directory="$1"
  shift
  local artifacts=("$@")
  for artifact in "${artifacts[@]}"; do
    local artifact_path="$directory/$artifact.sh"
    if [[ -f "$artifact_path" ]]; then
      source "$artifact_path"
    else
      echo "[st8atlas] error: Required artifact '$artifact' is missing. Please ensure that the installation is complete and that the artifact exists." >&2
      exit 1
    fi
  done
}

SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do
  SOURCE_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" == /* ]] || SOURCE="${SOURCE_DIR}/${SOURCE}"
done

INSTALL_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
COMMANDS_DIR="${INSTALL_DIR}/commands"
LIB_DIR="${INSTALL_DIR}/lib"
EXTENSIONS_DIR="${ST8ATLAS_EXTENSIONS_DIR:-${INSTALL_DIR}/extensions}"

ensure_artifacts "$LIB_DIR"
ensure_artifacts "$COMMANDS_DIR"

AVAILABLE_LIBS=($(ls "${LIB_DIR}"/*.sh | xargs -n 1 basename | sed 's/\.sh$//' | sort))
AVAILABLE_COMMANDS=($(ls "${COMMANDS_DIR}"/*.sh | xargs -n 1 basename | sed 's/\.sh$//' | sort))

source_artifacts "$LIB_DIR" "${AVAILABLE_LIBS[@]}"
source_artifacts "$COMMANDS_DIR" "${AVAILABLE_COMMANDS[@]}"

load_extensions "$EXTENSIONS_DIR"

usage() {
  usage_title "$(basename "$0") <command> [args...]"
  usage_section "Commands:"
  for cmd in "${AVAILABLE_COMMANDS[@]}"; do
    if declare -f "${cmd}_desc" > /dev/null; then
      "${cmd}_desc"
    fi
  done

  if [[ ${#ST8_EXTENSIONS[@]} -gt 0 ]]; then
    usage_section "Extensions:"
    for cmd in "${ST8_EXTENSIONS[@]}"; do
      if declare -f "${cmd}_desc" > /dev/null; then
        "${cmd}_desc"
      fi
    done
  fi

  echo
  echo "${DIM}Run '$(basename "$0") <command> --help' for details.${RESET}"
}

[[ $# -lt 1 ]] && { usage; exit 1; }

COMMAND="$1"
shift

KNOWN_COMMANDS=("${AVAILABLE_COMMANDS[@]}" ${ST8_EXTENSIONS[@]+"${ST8_EXTENSIONS[@]}"})

if [[ " ${KNOWN_COMMANDS[*]} " == *" $COMMAND "* ]]; then
  if declare -f "${COMMAND}_main" > /dev/null; then
    ensure_dependencies
    "${COMMAND}_main" "$@"
  else
    log_error "Command '$COMMAND' is not implemented."
    exit 1
  fi
else
  log_error "Unknown command '$COMMAND'."
  usage
  exit 1
fi