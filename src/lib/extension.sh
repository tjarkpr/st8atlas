ST8_EXTENSIONS=()

load_extensions() {
  local directory="$1"
  [[ -d "$directory" ]] || return 0

  local file name
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    name="$(basename "$file" .sh)"
    source "$file"
    ST8_EXTENSIONS+=("$name")
  done < <(find "$directory" -maxdepth 1 -type f -name '*.sh' | sort)
}

extension_installed() {
  [[ " ${ST8_EXTENSIONS[*]-} " == *" $1 "* ]]
}

run_hook() {
  local hook="$1"
  shift

  local extension
  for extension in ${ST8_EXTENSIONS[@]+"${ST8_EXTENSIONS[@]}"}; do
    if declare -f "${extension}_hook_${hook}" > /dev/null; then
      "${extension}_hook_${hook}" "$@"
    fi
  done
}
