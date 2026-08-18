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

# DOT node ids must not contain arbitrary characters from a config path.
diagram_node_id() {
  echo "$1" | sed 's/[^a-zA-Z0-9_]/_/g'
}

diagram_dot() {
  local stack="$1" stack_file="$2"

  local units=() unit
  while IFS= read -r unit; do
    [[ -n "$unit" ]] || continue
    units+=("$unit")
  done < <(stack_unit_names "$stack_file")

  echo "digraph \"${stack}\" {"
  echo "  rankdir=LR;"
  echo "  labelloc=\"t\";"
  echo "  label=\"stack: ${stack}\";"
  echo "  fontname=\"Helvetica\";"
  echo "  node [fontname=\"Helvetica\", style=\"rounded,filled\"];"
  echo "  edge [fontname=\"Helvetica\", fontsize=10];"
  echo "  \"stack\" [label=\"${stack}\", shape=box3d, fillcolor=\"#dfe8f7\"];"

  if [[ ${#units[@]} -eq 0 ]]; then
    echo "  \"empty\" [label=\"no units\", shape=note, fillcolor=\"#f7dfdf\"];"
    echo "  \"stack\" -> \"empty\" [style=dotted];"
    echo "}"
    return 0
  fi

  for unit in "${units[@]}"; do
    echo "  \"unit_${unit}\" [label=\"${unit}\", shape=box, fillcolor=\"#eef7ee\"];"
    echo "  \"module_${unit}\" [label=\"modules/${unit}\", shape=component, fillcolor=\"#f7f2df\"];"
    echo "  \"stack\" -> \"unit_${unit}\";"
    echo "  \"unit_${unit}\" -> \"module_${unit}\" [style=dashed, color=\"#888888\"];"
  done

  local dependency node
  for unit in "${units[@]}"; do
    while IFS= read -r dependency; do
      [[ -n "$dependency" ]] || continue
      [[ "$dependency" != "$unit" ]] || continue

      if [[ " ${units[*]} " == *" ${dependency} "* ]]; then
        echo "  \"unit_${unit}\" -> \"unit_${dependency}\" [color=\"#b05a00\", fontcolor=\"#b05a00\", label=\"depends on\"];"
      else
        node="external_$(diagram_node_id "$dependency")"
        echo "  \"${node}\" [label=\"${dependency}\\n(outside the stack)\", shape=box, style=\"rounded,filled,dashed\", fillcolor=\"#f0f0f0\"];"
        echo "  \"unit_${unit}\" -> \"${node}\" [color=\"#b05a00\", fontcolor=\"#b05a00\", style=dashed, label=\"depends on\"];"
      fi
    done < <(unit_dependency_names "${ST8_UNITS_DIR}/${unit}/${UNIT_FILE_NAME}")
  done

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

# Contributes the raw DOT source to the stack snapshot. Graphviz is not needed for this.
diagram_hook_snapshot() {
  local name="$1" directory="$2"
  echo "[diagram]"
  diagram_dot "$name" "${directory}/${STACK_FILE_NAME}"
  echo ""
}
