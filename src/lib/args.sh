ARG_NAME=""
ARG_DESCRIPTION=""
ARG_PATH=""
ARG_UNITS=""
ARG_BASELINE=""
ARG_OUTPUT=""
ARG_FORCE="false"
ARG_INTERACTIVE="true"

parse_options() {
  ARG_NAME=""
  ARG_DESCRIPTION=""
  ARG_PATH=""
  ARG_UNITS=""
  ARG_BASELINE=""
  ARG_OUTPUT=""
  ARG_FORCE="false"
  ARG_INTERACTIVE="true"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)
        [[ $# -ge 2 ]] || die "Missing value for '--name'."
        ARG_NAME="$2"
        shift 2
        ;;
      --description)
        [[ $# -ge 2 ]] || die "Missing value for '--description'."
        ARG_DESCRIPTION="$2"
        shift 2
        ;;
      --path)
        [[ $# -ge 2 ]] || die "Missing value for '--path'."
        ARG_PATH="$2"
        shift 2
        ;;
      --units)
        [[ $# -ge 2 ]] || die "Missing value for '--units'."
        ARG_UNITS="$2"
        shift 2
        ;;
      --baseline)
        [[ $# -ge 2 ]] || die "Missing value for '--baseline'."
        ARG_BASELINE="$2"
        shift 2
        ;;
      --output)
        [[ $# -ge 2 ]] || die "Missing value for '--output'."
        ARG_OUTPUT="$2"
        shift 2
        ;;
      --force)
        ARG_FORCE="true"
        shift
        ;;
      --no-interactive)
        ARG_INTERACTIVE="false"
        shift
        ;;
      *)
        die "Unknown argument '$1'."
        ;;
    esac
  done
}

require_option() {
  local value="$1" option="$2"
  [[ -n "$value" ]] || die "Missing required argument '${option}'."
}
