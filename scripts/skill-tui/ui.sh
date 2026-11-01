# Table and interactive loop. Keys: up/down item, left/right target, space mark, enter install, x remove, d diff, q quit.

declare -A SELECTED # "row/col" -> 1 for cells marked to install
declare -A STATE_COLORS=([same]=32 [modified]=33 [missing]=31 ["local only"]=36)
NAME_COLUMN='%-13s%-32s'
with_spinner() { # message command... -> runs the command in this shell (its variables stay set) under a spinner
  local message=$1 spinner status; shift
  { while :; do for frame in '|' / - '\'; do printf '\r%s %s\e[K' "$frame" "$message"; sleep 0.1; done; done >/dev/tty; } &>/dev/null &
  spinner=$!
  "$@"; status=$?
  kill "$spinner" 2>/dev/null; wait "$spinner" 2>/dev/null # the spinner exits by itself when there is no terminal
  { printf '\r\e[K' >/dev/tty; } 2>/dev/null
  return $status
}

refresh() { SELECTED=(); with_spinner "loading..." collect_rows; }

item_label() { echo "${item[1]} (${item[3]})"; } # of the current item=(kind name src target)

print_source() { # kind name src
  local remote_env=skills/$2/remote.env repo
  if [[ $1 != skill || ! -f $remote_env ]]; then echo "${3:--}"; return; fi
  repo=$(sed -n 's/^REPO=//p' "$remote_env")
  [[ -n $3 ]] && echo "remote $repo" || echo "remote $repo (fetch failed)"
}

print_table() { # [selected_row selected_col]
  local selected_row=${1:--1} selected_col=${2:--1} i j kind name src state color mark
  printf "  $NAME_COLUMN %-12s %-12s%s\n" kind name "${TARGETS[@]}" source
  for i in "${!ROWS[@]}"; do
    IFS='|' read -r kind name src <<<"${ROWS[i]}"
    if [[ $i == "$selected_row" ]]; then printf "\e[7m> $NAME_COLUMN\e[0m" "$kind" "$name"; else printf "  $NAME_COLUMN" "$kind" "$name"; fi
    for j in "${!TARGETS[@]}"; do
      state=${STATES[$i/$j]:--}
      color=${STATE_COLORS[$state]:-0}
      [[ $i == "$selected_row" && $j == "$selected_col" ]] && color+=";7"
      [[ -n ${SELECTED[$i/$j]:-} ]] && mark='*' || mark=' '
      if [[ -t 1 ]]; then printf '\e[%sm%s%-11s\e[0m ' "$color" "$mark" "$state"; else printf '%s%-11s ' "$mark" "$state"; fi
    done
    print_source "$kind" "$name" "$src"
  done
}

read_key() { # one keypress, arrows as full escape sequences. bash `read -n` would re-enable Ctrl+C, so use head
  local key rest
  key=$(head -c1)
  if [[ $key == $'\e' ]]; then stty min 0 time 1; rest=$(head -c2); stty min 1 time 0; key+=$rest; fi
  printf '%s' "$key"
}

confirm() { # question -> 0 = yes. pacman-style: Enter/y yes, n/q/Esc/Ctrl+C no
  local key
  printf '\e[33;1m%s [Y/n]\e[0m ' "$1"
  while key=$(read_key); do
    case $key in ''|y|Y) return 0 ;; n|N|q|$'\e'|$'\x03') return 1 ;; esac
  done
}

cell_item() { # "row/col" -> fills item=(kind name src target)
  local kind name src
  IFS='|' read -r kind name src <<<"${ROWS[${1%/*}]}"
  item=("$kind" "$name" "$src" "${TARGETS[${1#*/}]}")
}

install_selected() { # marked cells (or the current one): missing ones, plus modified ones after one confirm -> sets message
  local cells=("${!SELECTED[@]}") cell state error installed=0
  local -a item pending=() changed=() changed_names=() errors=()
  ((${#cells[@]})) || cells=("$row/$col")
  for cell in "${cells[@]}"; do
    cell_item "$cell"
    state=${STATES[$cell]:-}
    case $state in
      missing) pending+=("$cell") ;;
      modified) changed+=("$cell"); changed_names+=("$(item_label)") ;;
    esac
  done
  ((${#changed[@]})) && confirm "Overwrite local changes in ${changed_names[*]}?" && pending+=("${changed[@]}")
  local -A asked
  for cell in "${pending[@]}"; do
    cell_item "$cell"
    [[ ${item[0]} == mcp && -z ${asked[${item[2]}]:-} ]] && { asked[${item[2]}]=1; ask_token "${item[2]}"; }
    error=$(with_spinner "installing $(item_label)" install_item "${item[@]}" </dev/null 2>&1 >/dev/null) && installed=$((installed + 1)) || errors+=("$(item_label): $error")
  done
  message="installed $installed${errors[*]:+, failed: ${errors[*]}}"
}

read_secret() { # prompt -> typed or pasted line, one * per character. Enter ends, Backspace deletes, Esc/Ctrl+C cancels
  local value="" char
  printf '%s' "$1" >&2
  while char=$(head -c1); do
    case $char in
      '') break ;; # Enter: command substitution drops the newline
      $'\x7f'|$'\b') [[ -z $value ]] || { value=${value%?}; printf '\b \b' >&2; } ;;
      $'\e'|$'\x03') value=""; break ;;
      *) value+=$char; printf '*' >&2 ;;
    esac
  done
  echo >&2
  printf '%s' "$value"
}

ask_token() { # src: an MCP server with an optional token that is not set yet -> ask once, save to .env
  local URL TOKEN_ENV TOKEN_HEADER TOKEN value; load_mcp "$1"
  [[ -n $TOKEN_ENV && -z $TOKEN ]] || return 0
  value=$(read_secret $'\e[33;1m'"$TOKEN_ENV for $(basename "$1" .env) (optional, Enter to skip): "$'\e[0m')
  [[ -z $value ]] || save_token "$TOKEN_ENV" "$value"
}

run_tui() {
  local row=0 col=0 message="" key state
  local -a item
  stty -icanon -echo -isig min 1 time 0 # Ctrl+C becomes a key
  tput civis
  trap 'stty sane; tput cnorm; clear' EXIT
  refresh
  while true; do
    cell_item "$row/$col"
    state=${STATES[$row/$col]:-}
    clear
    printf '\e[1mskill-tui  up/down item  left/right target  space mark  enter install  x remove  d diff  q quit\e[0m\n\n'
    print_table "$row" "$col"
    printf '\ntarget: %s\n\e[1m%s\e[0m\n' "$(install_dir "${item[0]}" "${item[3]}")" "$message"
    message=""
    key=$(read_key) # Enter arrives as "" (command substitution drops the newline)
    case $key in
      q|$'\e'|$'\x03') return ;;
      $'\e[A'|$'\eOA') ((row = (row + ${#ROWS[@]} - 1) % ${#ROWS[@]})) ;;
      $'\e[B'|$'\eOB') ((row = (row + 1) % ${#ROWS[@]})) ;;
      $'\e[C'|$'\eOC'|$'\e[D'|$'\eOD') ((col = 1 - col)) ;;
      ' ') [[ $state == missing || $state == modified ]] || continue
           if [[ -n ${SELECTED[$row/$col]:-} ]]; then unset "SELECTED[$row/$col]"; else SELECTED[$row/$col]=1; fi ;;
      '') install_selected; refresh ;;
      d) [[ $state == same || $state == modified ]] && show_diff "${item[@]}" | less -R ;;
      x) [[ $state == same || $state == modified || $state == "local only" ]] || continue
         confirm "Remove ${item[0]} ${item[1]} from ${item[3]}?$([[ $state == "local only" ]] && echo ' NOT in the repo: deletes the only copy.')" || continue
         message=$(with_spinner "removing $(item_label)" remove_item "${item[@]}" </dev/null 2>&1 >/dev/null) && message="removed $(item_label)" || message="failed: $message"
         refresh ;;
    esac
  done
}
