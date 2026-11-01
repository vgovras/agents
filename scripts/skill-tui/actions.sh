# Install / remove / diff one item. All take: kind name src target.

install_item() {
  if [[ $1 == mcp ]]; then install_mcp "$2" "$3" "$4"; return; fi
  if [[ $1 == instruction ]]; then add_section "instruction:$2" "$3" "$4"; return; fi
  local path; path=$(install_path "$1" "$4" "$2")
  mkdir -p "$(dirname "$path")"
  # the old copy goes only after the new one is complete
  rm -rf "$path.installing" && cp -r "$3" "$path.installing" && rm -rf "$path" && mv "$path.installing" "$path"
}

remove_item() {
  case $1 in
    mcp) remove_mcp "$2" "$4" ;;
    instruction) remove_section "instruction:$2" "$4" ;;
    *) rm -rf "$(install_path "$1" "$4" "$2")" ;;
  esac
}

show_diff() {
  if [[ $1 == instruction ]]; then
    diff -u --label repo --label installed "$3" <(installed_section "instruction:$2" "$4"); return
  fi
  if [[ $1 != mcp ]]; then diff -ru "$3" "$(install_path "$1" "$4" "$2")"; return; fi
  printf 'repo:      %s\ninstalled: %s\n' "$(expected_mcp_json "$3" "$4")" "$(installed_mcp_json "$2" "$4")" \
    | sed 's/"headers":{[^}]*}/"headers":"***"/g' # hide tokens
  [[ -f $(section_text_file "$3") ]] && diff -u --label "repo section" --label "installed section" \
    "$(section_text_file "$3")" <(installed_section "mcp:$2" "$4")
}
