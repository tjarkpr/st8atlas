stack_desc() {
  usage_entry "  " "stack <capability>" "Manage the state atlas stacks."
}

stack_usage() {
  usage_title "$(basename "$0") stack <capability> [args...]"
  usage_summary "Manage the state atlas stacks."
  usage_section "Capabilities:"
  usage_entry "  ├─" "sync" "Synchronize the stacks with the file system"
  usage_entry "  ├─" "list" "List the stacks"
  usage_entry "  ├─" "add [args...]" "Add a new stack"
  usage_argument "  │  ├─" "--name <name>" "Name of the stack (required)"
  usage_argument "  │  ├─" "--description <text>" "Description of the stack"
  usage_argument "  │  ├─" "--path <path>" "Path below 'stacks/' (default: the name)"
  usage_argument "  │  ├─" "--units <a,b>" "Units to include, skips the prompt"
  usage_argument "  │  └─" "--no-interactive" "Never prompt for a unit selection"
  usage_entry "  ├─" "units [args...]" "Manage the units of a stack interactively"
  usage_argument "  │  ├─" "--name <name>" "Name of the stack (required)"
  usage_argument "  │  ├─" "--units <a,b>" "Units to include, skips the prompt"
  usage_argument "  │  └─" "--no-interactive" "Never prompt for a unit selection"
  usage_entry "  ├─" "remove [args...]" "Remove an existing stack"
  usage_argument "  │  └─" "--name <name>" "Name of the stack (required)"
  usage_entry "  ├─" "init [args...]" "Generate and initialize the stack"
  usage_argument "  │  └─" "--name <name>" "Name of the stack (required)"
  usage_entry "  ├─" "plan [args...]" "Plan the stack"
  usage_argument "  │  └─" "--name <name>" "Name of the stack (required)"
  usage_entry "  ├─" "apply [args...]" "Apply the stack"
  usage_argument "  │  └─" "--name <name>" "Name of the stack (required)"
  usage_entry "  ├─" "destroy [args...]" "Destroy the stack"
  usage_argument "  │  └─" "--name <name>" "Name of the stack (required)"
  usage_entry "  ├─" "validate [args...]" "Validate the stack"
  usage_argument "  │  └─" "--name <name>" "Name of the stack (required)"
  usage_entry "  └─" "format" "Format the stack configuration files"
}

STACK_FILE_NAME="terragrunt.stack.hcl"
STACK_ROOT_FILE_NAME="root.hcl"

# Terragrunt resolves root.hcl through find_in_parent_folders, so every level from the
# stacks directory down to the parent of the stack gets one. The stack directory itself
# stays free of a root.hcl, the stack file references the one above instead. Every level
# except the topmost inherits the level above, which chains all upper root files together.
stack_ensure_root_files() {
  local relative_path="$1"
  local directory="$ST8_STACKS_DIR"

  mkdir -p "$directory"
  [[ -f "${directory}/${STACK_ROOT_FILE_NAME}" ]] || template_root_terragrunt false > "${directory}/${STACK_ROOT_FILE_NAME}"

  local segments=()
  local IFS='/'
  local segment
  for segment in $relative_path; do
    [[ -n "$segment" ]] || continue
    segments+=("$segment")
  done

  local index
  for (( index = 0; index < ${#segments[@]} - 1; index++ )); do
    directory="${directory}/${segments[$index]}"
    mkdir -p "$directory"
    [[ -f "${directory}/${STACK_ROOT_FILE_NAME}" ]] || template_root_terragrunt true > "${directory}/${STACK_ROOT_FILE_NAME}"
  done
}

stack_file() {
  local name="$1"
  echo "$(stack_directory "$name")/${STACK_FILE_NAME}"
}

# Resolves the unit selection from --units or an interactive prompt into SELECTION.
stack_select_units() {
  local title="$1" preselected="$2"
  SELECTION=()

  local unit
  if [[ -n "$ARG_UNITS" ]]; then
    local IFS=','
    for unit in $ARG_UNITS; do
      [[ -n "$unit" ]] || continue
      state_exists "unit" "$unit" || die "Unknown unit '${unit}'. Run '$(basename "$0") unit list' to see the known units."
      SELECTION+=("$unit")
    done
    return 0
  fi

  local available=()
  while IFS= read -r unit; do
    [[ -n "$unit" ]] || continue
    available+=("$unit")
  done < <(state_names "unit")

  if [[ ${#available[@]} -eq 0 ]]; then
    log_warn "No units available yet. Add one with '$(basename "$0") unit add --name <name>'."
    return 0
  fi

  if ! interactive_available; then
    local IFS=','
    for unit in $preselected; do
      [[ -n "$unit" ]] || continue
      SELECTION+=("$unit")
    done
    return 0
  fi

  prompt_multi_select "$title" "$preselected" "${available[@]}"
}

stack_relative_path() {
  local name="$1"
  state_field "stack" "$name" 3
}

stack_directory() {
  local name="$1"
  echo "${ST8_PROJECT_ROOT}/$(stack_relative_path "$name")"
}

stack_require_existing() {
  local name="$1"
  state_exists "stack" "$name" || die "Unknown stack '${name}'. Run '$(basename "$0") stack list' to see the known stacks."
}

stack_add() {
  parse_options "$@"
  require_option "$ARG_NAME" "--name"
  validate_name "$ARG_NAME"
  validate_description "$ARG_DESCRIPTION"

  local relative_path="${ARG_PATH:-$ARG_NAME}"
  validate_relative_path "$relative_path"

  state_exists "stack" "$ARG_NAME" && die "Stack '${ARG_NAME}' already exists."

  local relative_directory="${STACKS_DIR_NAME}/${relative_path}"
  local directory="${ST8_PROJECT_ROOT}/${relative_directory}"
  local file="${directory}/${STACK_FILE_NAME}"

  [[ -e "$file" ]] && die "'${file}' already exists."

  mkdir -p "$directory"
  stack_ensure_root_files "$relative_path"
  stack_select_units "Select the units for stack '${ARG_NAME}':" ""
  template_stack "$ARG_NAME" "$ARG_DESCRIPTION" ${SELECTION[@]+"${SELECTION[@]}"} > "$file"
  state_upsert "stack" "$ARG_NAME" "$relative_directory" "$ARG_DESCRIPTION"

  log_info "Added stack '${ARG_NAME}' at '${relative_directory}' with ${#SELECTION[@]} unit(s)."

  run_hook stack_created "$ARG_NAME" "$directory"
}

# Rewrites the stack file from the template, so manual edits to it are lost.
stack_units() {
  parse_options "$@"
  require_option "$ARG_NAME" "--name"
  stack_require_existing "$ARG_NAME"

  local file current description
  file="$(stack_file "$ARG_NAME")"
  current="$(stack_unit_names "$file" | tr '\n' ',' | sed 's/,$//')"
  description="$(state_field "stack" "$ARG_NAME" 4)"

  stack_select_units "Select the units for stack '${ARG_NAME}':" "$current"
  template_stack "$ARG_NAME" "$description" ${SELECTION[@]+"${SELECTION[@]}"} > "$file"

  log_info "Stack '${ARG_NAME}' now uses ${#SELECTION[@]} unit(s)."
}

stack_remove() {
  parse_options "$@"
  require_option "$ARG_NAME" "--name"
  stack_require_existing "$ARG_NAME"

  local directory
  directory="$(stack_directory "$ARG_NAME")"
  rm -rf "$directory"
  state_remove "stack" "$ARG_NAME"

  log_info "Removed stack '${ARG_NAME}'."
}

stack_list() {
  local records
  records="$(state_records "stack")"

  if [[ -z "$records" ]]; then
    log_info "No stacks registered."
    return 0
  fi

  printf '%s%-24s %-36s %5s  %s%s\n' "$BOLD" "NAME" "PATH" "UNITS" "DESCRIPTION" "$RESET"
  local name path description count
  while IFS='|' read -r _ name path description; do
    count="$(stack_unit_count "${ST8_PROJECT_ROOT}/${path}/${STACK_FILE_NAME}")"
    printf '%s%-24s%s %s%-36s%s %s%5s%s  %s%s%s\n' \
      "$BOLD_GREEN" "$name" "$RESET" \
      "$CYAN" "$path" "$RESET" \
      "$YELLOW" "$count" "$RESET" \
      "$DIM" "$description" "$RESET"
  done <<< "$records"
}

stack_sync() {
  [[ $# -eq 0 ]] || die "'sync' does not take any arguments."

  local discovered=()
  local file
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    local directory relative name
    directory="$(dirname "$file")"
    relative="${directory#"${ST8_PROJECT_ROOT}/"}"
    name="$(basename "$directory")"
    discovered+=("$name")
    stack_ensure_root_files "${relative#"${STACKS_DIR_NAME}/"}"

    if state_exists "stack" "$name"; then
      local description
      description="$(state_field "stack" "$name" 4)"
      state_upsert "stack" "$name" "$relative" "$description"
    else
      state_upsert "stack" "$name" "$relative" "Discovered by sync"
      log_info "Registered stack '${name}' found at '${relative}'."
    fi
  done < <(find "$ST8_STACKS_DIR" -type f -name "$STACK_FILE_NAME" | sort)

  local name
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    if [[ ! " ${discovered[*]-} " == *" ${name} "* ]]; then
      state_remove "stack" "$name"
      log_info "Removed stack '${name}' from the state, its ${STACK_FILE_NAME} is gone."
    fi
  done < <(state_names "stack")

  log_info "Stacks synchronized."
}

stack_terragrunt() {
  local capability="$1"
  shift
  parse_options "$@"
  require_option "$ARG_NAME" "--name"
  stack_require_existing "$ARG_NAME"

  local directory
  directory="$(stack_directory "$ARG_NAME")"

  case "$capability" in
    init)
      run_in_directory "$directory" terragrunt stack generate
      run_in_directory "$directory" terragrunt stack run init
      ;;
    *)
      run_in_directory "$directory" terragrunt stack run "$capability"
      ;;
  esac
}

stack_format() {
  [[ $# -eq 0 ]] || die "'format' does not take any arguments."
  run_in_directory "$ST8_STACKS_DIR" terragrunt hclfmt
}

stack_main() {
  [[ $# -lt 1 ]] && { stack_usage; exit 1; }

  local capability="$1"
  shift

  case "$capability" in
    -h|--help)
      stack_usage
      ;;
    add)
      require_project
      stack_add "$@"
      ;;
    units)
      require_project
      stack_units "$@"
      ;;
    remove)
      require_project
      stack_remove "$@"
      ;;
    list)
      require_project
      stack_list "$@"
      ;;
    sync)
      require_project
      stack_sync "$@"
      ;;
    init|plan|apply|destroy|validate)
      require_project
      stack_terragrunt "$capability" "$@"
      ;;
    format)
      require_project
      stack_format "$@"
      ;;
    *)
      log_error "Unknown capability '${capability}'."
      stack_usage
      exit 1
      ;;
  esac
}