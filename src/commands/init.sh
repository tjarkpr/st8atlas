init_desc() {
  usage_entry "  " "init" "Initialize the state atlas."
}

init_usage() {
  usage_title "$(basename "$0") init [args...]"
  usage_summary "Initialize the state atlas."
  usage_section "Arguments:"
  usage_argument "  ├─" "--path <path>" "Directory to initialize (default: current directory)"
  usage_argument "  └─" "--force" "Force re-initialization"
}

init_main() {
  local path="."
  local force="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --path)
        [[ $# -ge 2 ]] || die "Missing value for '--path'."
        path="$2"
        shift 2
        ;;
      --force)
        force="true"
        shift
        ;;
      -h|--help)
        init_usage
        return 0
        ;;
      *)
        log_error "Unknown argument '$1'."
        init_usage
        exit 1
        ;;
    esac
  done

  mkdir -p "$path"
  local root
  root="$(cd "$path" && pwd)"
  set_project_root "$root"

  if [[ -f "$ST8_STATE_FILE" && "$force" != "true" ]]; then
    die "'${STATE_FILE_NAME}' already exists in '${root}'. Use '--force' to re-initialize."
  fi

  local directory
  for directory in "${PROJECT_DIRECTORIES[@]}"; do
    mkdir -p "${root}/${directory}"
  done

  state_initialize "$ST8_STATE_FILE"

  [[ -f "${root}/.gitignore" ]] || template_gitignore > "${root}/.gitignore"

  log_info "Initialized st8atlas project in '${root}'."
}