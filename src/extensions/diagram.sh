diagram_desc() {
  usage_entry "  " "diagram [args...]" "Render a stack as a diagram.png."
}

diagram_usage() {
  usage_title "$(basename "$0") diagram [args...]"
  usage_summary "Render a stack and its units as a PNG diagram. Requires graphviz."
  usage_section "Arguments:"
  usage_argument "  ├─" "--name <name>" "Name of the stack (required)"
  usage_argument "  └─" "--path <path>" "Output file (default: diagram.png in the stack)"
}

DIAGRAM_FILE_NAME="diagram.png"

diagram_dot() {
  local stack="$1" stack_file="$2"

  echo "digraph \"${stack}\" {"
  echo "  rankdir=LR;"
  echo "  labelloc=\"t\";"
  echo "  label=\"stack: ${stack}\";"
  echo "  fontname=\"Helvetica\";"
  echo "  node [fontname=\"Helvetica\", style=\"rounded,filled\"];"
  echo "  \"stack\" [label=\"${stack}\", shape=box3d, fillcolor=\"#dfe8f7\"];"

  local unit
  local found="false"
  while IFS= read -r unit; do
    [[ -n "$unit" ]] || continue
    found="true"
    echo "  \"unit_${unit}\" [label=\"${unit}\", shape=box, fillcolor=\"#eef7ee\"];"
    echo "  \"module_${unit}\" [label=\"modules/${unit}\", shape=component, fillcolor=\"#f7f2df\"];"
    echo "  \"stack\" -> \"unit_${unit}\";"
    echo "  \"unit_${unit}\" -> \"module_${unit}\" [style=dashed];"
  done < <(stack_unit_names "$stack_file")

  if [[ "$found" == "false" ]]; then
    echo "  \"empty\" [label=\"no units\", shape=note, fillcolor=\"#f7dfdf\"];"
    echo "  \"stack\" -> \"empty\" [style=dotted];"
  fi

  echo "}"
}

diagram_main() {
  [[ $# -lt 1 ]] && { diagram_usage; exit 1; }
  case "$1" in
    -h|--help)
      diagram_usage
      return 0
      ;;
  esac

  require_project
  parse_options "$@"
  require_option "$ARG_NAME" "--name"
  stack_require_existing "$ARG_NAME"
  ensure_command dot "Install graphviz to render diagrams."

  local directory stack_file output
  directory="$(stack_directory "$ARG_NAME")"
  stack_file="${directory}/${STACK_FILE_NAME}"
  output="${ARG_PATH:-${directory}/${DIAGRAM_FILE_NAME}}"

  diagram_dot "$ARG_NAME" "$stack_file" | dot -Tpng -o "$output" \
    || die "Could not render '${output}'."

  log_info "Rendered '${output}'."
}
