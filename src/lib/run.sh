run_in_directory() {
  local directory="$1"
  shift
  [[ -d "$directory" ]] || die "Directory '$directory' does not exist."
  log_info "Running '$*' in '${directory}'"
  (cd "$directory" && "$@")
}
