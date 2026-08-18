# Stack snapshots. A snapshot is a plain text file with a pipe separated header
# followed by [section] blocks. Extensions contribute sections through the
# 'snapshot' hook, so a snapshot only carries what is actually installed.

SNAPSHOT_FILE_NAME="stack.st8"
SNAPSHOT_VERSION="1"

# Prints the header value of the given key.
snapshot_header() {
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 0
  awk -F'|' -v key="$key" '/^\[/ { exit } $1 == key { print $2; exit }' "$file"
}

# Prints the raw lines of a section, without the section header.
snapshot_section() {
  local file="$1" section="$2"
  [[ -f "$file" ]] || return 0
  awk -v header="[${section}]" '
    $0 == header  { inside = 1; next }
    /^\[[^]]*\]$/ { inside = 0 }
    inside        { print }
  ' "$file"
}

# Same as snapshot_section but without surrounding blank lines, for list sections.
snapshot_entries() {
  snapshot_section "$1" "$2" | grep -v '^[[:space:]]*$' | sort -u || true
}
