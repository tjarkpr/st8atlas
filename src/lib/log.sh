log_info() {
  echo "${BOLD_CYAN}[st8atlas]${RESET} $*"
}

log_warn() {
  echo "${BOLD_YELLOW}[st8atlas] warning:${RESET} $*" >&2
}

log_error() {
  echo "${BOLD_RED}[st8atlas] error:${RESET} $*" >&2
}

die() {
  log_error "$*"
  exit 1
}
