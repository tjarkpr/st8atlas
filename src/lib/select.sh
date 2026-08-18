# Interactive multi selection. Results are written to the SELECTION array.

SELECTION=()

interactive_available() {
  [[ "$ARG_INTERACTIVE" == "true" && -t 0 && -t 1 ]]
}

# prompt_multi_select <title> <preselected-csv> <option>...
prompt_multi_select() {
  local title="$1" preselected="$2"
  shift 2
  local options=("$@")
  SELECTION=()

  local states=()
  local option
  for option in "${options[@]}"; do
    if [[ ",${preselected}," == *",${option},"* ]]; then
      states+=("true")
    else
      states+=("false")
    fi
  done

  local input index
  while true; do
    echo
    echo "${BOLD}${title}${RESET}"
    for index in "${!options[@]}"; do
      if [[ "${states[$index]}" == "true" ]]; then
        printf '  %s[x]%s %2d) %s%s%s\n' "$BOLD_GREEN" "$RESET" "$((index + 1))" "$BOLD_GREEN" "${options[$index]}" "$RESET"
      else
        printf '  %s[ ]%s %2d) %s\n' "$DIM" "$RESET" "$((index + 1))" "${options[$index]}"
      fi
    done
    echo "${DIM}Toggle with numbers (e.g. '1 3'), 'a' for all, 'n' for none, empty to confirm.${RESET}"
    printf '%s> %s' "$BOLD_CYAN" "$RESET"

    read -r input || input=""

    case "$input" in
      "")
        break
        ;;
      a|A)
        for index in "${!states[@]}"; do states[$index]="true"; done
        ;;
      n|N)
        for index in "${!states[@]}"; do states[$index]="false"; done
        ;;
      *)
        local token
        for token in $input; do
          if [[ "$token" =~ ^[0-9]+$ ]] && (( token >= 1 && token <= ${#options[@]} )); then
            index=$((token - 1))
            if [[ "${states[$index]}" == "true" ]]; then
              states[$index]="false"
            else
              states[$index]="true"
            fi
          else
            log_warn "Ignoring invalid selection '${token}'."
          fi
        done
        ;;
    esac
  done

  for index in "${!options[@]}"; do
    if [[ "${states[$index]}" == "true" ]]; then
      SELECTION+=("${options[$index]}")
    fi
  done
}
