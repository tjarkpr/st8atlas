RESET=''
BOLD=''
DIM=''
RED=''
GREEN=''
YELLOW=''
BLUE=''
CYAN=''
BOLD_RED=''
BOLD_GREEN=''
BOLD_YELLOW=''
BOLD_BLUE=''
BOLD_CYAN=''

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  RESET=$'\033[0m'
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  BLUE=$'\033[34m'
  CYAN=$'\033[36m'
  BOLD_RED=$'\033[1;31m'
  BOLD_GREEN=$'\033[1;32m'
  BOLD_YELLOW=$'\033[1;33m'
  BOLD_BLUE=$'\033[1;34m'
  BOLD_CYAN=$'\033[1;36m'
fi

usage_title() {
  echo "${BOLD}Usage:${RESET} ${BOLD_CYAN}$*${RESET}"
}

usage_summary() {
  echo "$*"
}

usage_section() {
  echo
  echo "${BOLD}$*${RESET}"
}

# usage_entry <tree-prefix> <name> <description>
usage_entry() {
  local prefix="$1" name="$2" description="$3"
  printf '%s%s%s %s%-28s%s %s\n' "$DIM" "$prefix" "$RESET" "$BOLD_GREEN" "$name" "$RESET" "$description"
}

# usage_argument <tree-prefix> <flag> <description>
usage_argument() {
  local prefix="$1" flag="$2" description="$3"
  printf '%s%s%s %s%-25s%s %s%s%s\n' "$DIM" "$prefix" "$RESET" "$YELLOW" "$flag" "$RESET" "$DIM" "$description" "$RESET"
}
