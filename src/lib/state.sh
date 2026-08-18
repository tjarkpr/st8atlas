STATE_VERSION="1"

state_initialize() {
  local file="$1"
  {
    echo "# st8atlas state file"
    echo "# Managed by st8atlas. Records are pipe separated."
    echo "version|${STATE_VERSION}"
  } > "$file"
}

state_require() {
  [[ -f "$ST8_STATE_FILE" ]] || die "State file '$ST8_STATE_FILE' is missing."
}

# Prints all records of the given kind, one per line.
state_records() {
  local kind="$1"
  state_require
  awk -F'|' -v kind="$kind" '$1 == kind' "$ST8_STATE_FILE"
}

state_names() {
  local kind="$1"
  state_records "$kind" | cut -d'|' -f2
}

state_exists() {
  local kind="$1" name="$2"
  state_records "$kind" | cut -d'|' -f2 | grep -Fxq -- "$name"
}

# state_field <kind> <name> <field-index> where index 3 is the first payload field.
state_field() {
  local kind="$1" name="$2" index="$3"
  state_records "$kind" | awk -F'|' -v name="$name" -v field="$index" '$2 == name { print $field; exit }'
}

state_remove() {
  local kind="$1" name="$2"
  state_require
  local temporary
  temporary="$(mktemp)"
  awk -F'|' -v kind="$kind" -v name="$name" '!($1 == kind && $2 == name)' "$ST8_STATE_FILE" > "$temporary"
  mv "$temporary" "$ST8_STATE_FILE"
}

# state_upsert <kind> <name> [fields...]
state_upsert() {
  local kind="$1" name="$2"
  shift 2
  state_remove "$kind" "$name"

  local record="${kind}|${name}"
  local field
  for field in "$@"; do
    record+="|${field}"
  done

  echo "$record" >> "$ST8_STATE_FILE"
  state_sort
}

state_sort() {
  local temporary
  temporary="$(mktemp)"
  {
    grep -E '^(#|version\|)' "$ST8_STATE_FILE" || true
    grep -Ev '^(#|version\||[[:space:]]*$)' "$ST8_STATE_FILE" | sort || true
  } > "$temporary"
  mv "$temporary" "$ST8_STATE_FILE"
}
