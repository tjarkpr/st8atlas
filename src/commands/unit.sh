unit_desc() {
  usage_entry "  " "unit <capability>" "Manage the state atlas units."
}

unit_usage() {
  usage_title "$(basename "$0") unit <capability> [args...]"
  usage_summary "Manage the state atlas units."
  usage_section "Capabilities:"
  usage_entry "  ├─" "sync" "Synchronize the units with the file system"
  usage_entry "  ├─" "list" "List the units"
  usage_entry "  ├─" "add [args...]" "Add a new unit and its module"
  usage_argument "  │  ├─" "--name <name>" "Name of the unit (required)"
  usage_argument "  │  └─" "--description <text>" "Description of the unit"
  usage_entry "  ├─" "remove [args...]" "Remove an existing unit and its module"
  usage_argument "  │  ├─" "--name <name>" "Name of the unit (required)"
  usage_argument "  │  └─" "--force" "Remove even while stacks still use it"
  usage_entry "  ├─" "validate [args...]" "Validate the unit"
  usage_argument "  │  └─" "--name <name>" "Name of the unit (required)"
  usage_entry "  └─" "format" "Format the unit and module files"
}

UNIT_FILE_NAME="terragrunt.hcl"

unit_require_existing() {
  local name="$1"
  state_exists "unit" "$name" || die "Unknown unit '${name}'. Run '$(basename "$0") unit list' to see the known units."
}

unit_add() {
  parse_options "$@"
  require_option "$ARG_NAME" "--name"
  validate_name "$ARG_NAME"
  validate_description "$ARG_DESCRIPTION"

  state_exists "unit" "$ARG_NAME" && die "Unit '${ARG_NAME}' already exists."

  local relative_unit="${UNITS_DIR_NAME}/${ARG_NAME}"
  local relative_module="${MODULES_DIR_NAME}/${ARG_NAME}"
  local unit_directory="${ST8_PROJECT_ROOT}/${relative_unit}"
  local module_directory="${ST8_PROJECT_ROOT}/${relative_module}"

  [[ -e "${unit_directory}/${UNIT_FILE_NAME}" ]] && die "'${unit_directory}/${UNIT_FILE_NAME}' already exists."
  [[ -d "$module_directory" ]] && die "'${module_directory}' already exists."

  mkdir -p "$unit_directory" "$module_directory"
  template_unit "$ARG_NAME" "$ARG_DESCRIPTION" > "${unit_directory}/${UNIT_FILE_NAME}"
  template_module_main "$ARG_NAME" "$ARG_DESCRIPTION" > "${module_directory}/main.tf"
  template_module_variables "$ARG_NAME" > "${module_directory}/variables.tf"
  template_module_outputs > "${module_directory}/outputs.tf"

  state_upsert "unit" "$ARG_NAME" "$relative_unit" "$relative_module" "$ARG_DESCRIPTION"

  log_info "Added unit '${ARG_NAME}' at '${relative_unit}' with module '${relative_module}'."
}

unit_remove() {
  parse_options "$@"
  require_option "$ARG_NAME" "--name"
  unit_require_existing "$ARG_NAME"

  local stacks
  stacks="$(unit_stack_names "$ARG_NAME" | tr '\n' ' ' | sed 's/ *$//')"
  if [[ -n "$stacks" ]]; then
    [[ "$ARG_FORCE" == "true" ]] \
      || die "Unit '${ARG_NAME}' is still used by: ${stacks}. Use '--force' to remove it anyway."
    log_warn "Removing unit '${ARG_NAME}' leaves dangling references in: ${stacks}"
  fi

  local relative_unit relative_module
  relative_unit="$(state_field "unit" "$ARG_NAME" 3)"
  relative_module="$(state_field "unit" "$ARG_NAME" 4)"

  rm -rf "${ST8_PROJECT_ROOT}/${relative_unit}"
  rm -rf "${ST8_PROJECT_ROOT}/${relative_module}"
  state_remove "unit" "$ARG_NAME"

  log_info "Removed unit '${ARG_NAME}' and its module."
}

unit_list() {
  local records
  records="$(state_records "unit")"

  if [[ -z "$records" ]]; then
    log_info "No units registered."
    return 0
  fi

  printf '%s%-20s %-28s %-28s %6s  %s%s\n' "$BOLD" "NAME" "UNIT" "MODULE" "STACKS" "DESCRIPTION" "$RESET"
  local name unit_path module_path description count
  while IFS='|' read -r _ name unit_path module_path description; do
    count="$(unit_stack_count "$name")"
    printf '%s%-20s%s %s%-28s %-28s%s %s%6s%s  %s%s%s\n' \
      "$BOLD_GREEN" "$name" "$RESET" \
      "$CYAN" "$unit_path" "$module_path" "$RESET" \
      "$YELLOW" "$count" "$RESET" \
      "$DIM" "$description" "$RESET"
  done <<< "$records"
}

unit_sync() {
  [[ $# -eq 0 ]] || die "'sync' does not take any arguments."

  local discovered=()
  local file
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    local directory relative name relative_module
    directory="$(dirname "$file")"
    relative="${directory#"${ST8_PROJECT_ROOT}/"}"
    name="$(basename "$directory")"
    relative_module="${MODULES_DIR_NAME}/${name}"
    discovered+=("$name")

    if [[ ! -d "${ST8_PROJECT_ROOT}/${relative_module}" ]]; then
      log_warn "Unit '${name}' has no matching module at '${relative_module}'."
    fi

    if state_exists "unit" "$name"; then
      local description
      description="$(state_field "unit" "$name" 5)"
      state_upsert "unit" "$name" "$relative" "$relative_module" "$description"
    else
      state_upsert "unit" "$name" "$relative" "$relative_module" "Discovered by sync"
      log_info "Registered unit '${name}' found at '${relative}'."
    fi
  done < <(find "$ST8_UNITS_DIR" -type f -name "$UNIT_FILE_NAME" | sort)

  local name
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    if [[ ! " ${discovered[*]-} " == *" ${name} "* ]]; then
      state_remove "unit" "$name"
      log_info "Removed unit '${name}' from the state, its ${UNIT_FILE_NAME} is gone."
    fi
  done < <(state_names "unit")

  log_info "Units synchronized."
}

unit_validate() {
  parse_options "$@"
  require_option "$ARG_NAME" "--name"
  unit_require_existing "$ARG_NAME"

  local relative_unit
  relative_unit="$(state_field "unit" "$ARG_NAME" 3)"
  run_in_directory "${ST8_PROJECT_ROOT}/${relative_unit}" terragrunt validate
}

unit_format() {
  [[ $# -eq 0 ]] || die "'format' does not take any arguments."
  run_in_directory "$ST8_UNITS_DIR" terragrunt hclfmt
  run_in_directory "$ST8_MODULES_DIR" terraform fmt -recursive
}

unit_main() {
  [[ $# -lt 1 ]] && { unit_usage; exit 1; }

  local capability="$1"
  shift

  case "$capability" in
    -h|--help)
      unit_usage
      ;;
    add)
      require_project
      unit_add "$@"
      ;;
    remove)
      require_project
      unit_remove "$@"
      ;;
    list)
      require_project
      unit_list "$@"
      ;;
    sync)
      require_project
      unit_sync "$@"
      ;;
    validate)
      require_project
      unit_validate "$@"
      ;;
    format)
      require_project
      unit_format "$@"
      ;;
    *)
      log_error "Unknown capability '${capability}'."
      unit_usage
      exit 1
      ;;
  esac
}