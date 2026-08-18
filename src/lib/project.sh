STATE_FILE_NAME="atlas.st8"
STACKS_DIR_NAME="stacks"
UNITS_DIR_NAME="units"
MODULES_DIR_NAME="modules"

PROJECT_DIRECTORIES=("$STACKS_DIR_NAME" "$UNITS_DIR_NAME" "$MODULES_DIR_NAME")

# Populated by require_project.
ST8_PROJECT_ROOT=""
ST8_STATE_FILE=""
ST8_STACKS_DIR=""
ST8_UNITS_DIR=""
ST8_MODULES_DIR=""

set_project_root() {
  ST8_PROJECT_ROOT="$1"
  ST8_STATE_FILE="${ST8_PROJECT_ROOT}/${STATE_FILE_NAME}"
  ST8_STACKS_DIR="${ST8_PROJECT_ROOT}/${STACKS_DIR_NAME}"
  ST8_UNITS_DIR="${ST8_PROJECT_ROOT}/${UNITS_DIR_NAME}"
  ST8_MODULES_DIR="${ST8_PROJECT_ROOT}/${MODULES_DIR_NAME}"
}

require_project() {
  [[ -f "${PWD}/${STATE_FILE_NAME}" ]] \
    || die "No '${STATE_FILE_NAME}' found in '${PWD}'. Run '$(basename "$0") init' first or change into a st8atlas project directory."

  set_project_root "$PWD"

  local directory
  for directory in "${PROJECT_DIRECTORIES[@]}"; do
    [[ -d "${ST8_PROJECT_ROOT}/${directory}" ]] || mkdir -p "${ST8_PROJECT_ROOT}/${directory}"
  done
}

# Names are used as file and directory names, so keep them strict.
validate_name() {
  local name="$1"
  [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] \
    || die "Invalid name '$name'. Use letters, digits, '-' and '_' only, starting with a letter or digit."
}

# Paths are always interpreted relative to a project directory, never outside of it.
validate_relative_path() {
  local path="$1"
  [[ "$path" =~ ^[a-zA-Z0-9][a-zA-Z0-9_/-]*$ ]] \
    || die "Invalid path '$path'. Use a relative path built from letters, digits, '-', '_' and '/'."
  [[ "$path" != *".."* ]] || die "Invalid path '$path'. Parent directory references are not allowed."
}

validate_description() {
  local description="$1"
  [[ "$description" != *"|"* ]] || die "Descriptions must not contain the '|' character."
}
