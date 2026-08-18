# Relations between stacks and units are derived from the generated stack files,
# so the file system stays the single source of truth.

# Prints the unit names referenced by the given terragrunt.stack.hcl file.
stack_unit_names() {
  local stack_file="$1"
  [[ -f "$stack_file" ]] || return 0
  grep -oE "${UNITS_DIR_NAME}/[a-zA-Z0-9][a-zA-Z0-9_-]*" "$stack_file" \
    | sed "s|^${UNITS_DIR_NAME}/||" \
    | sort -u || true
}

stack_unit_count() {
  stack_unit_names "$1" | grep -c . || true
}

# Prints the names of the stacks that reference the given unit.
unit_stack_names() {
  local unit_name="$1"
  local name path
  while IFS='|' read -r _ name path _; do
    [[ -n "$name" ]] || continue
    if stack_unit_names "${ST8_PROJECT_ROOT}/${path}/${STACK_FILE_NAME}" | grep -Fxq -- "$unit_name"; then
      echo "$name"
    fi
  done < <(state_records "stack")
}

unit_stack_count() {
  unit_stack_names "$1" | grep -c . || true
}
