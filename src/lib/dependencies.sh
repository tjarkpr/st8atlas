REQUIRED_DEPENDENCIES=(terraform terragrunt)

ensure_dependencies() {
  local missing=()
  for dependency in "${REQUIRED_DEPENDENCIES[@]}"; do
    command -v "$dependency" > /dev/null 2>&1 || missing+=("$dependency")
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing required dependencies: ${missing[*]}"
    log_error "Install them and make sure they are available on your PATH."
    exit 1
  fi
}
