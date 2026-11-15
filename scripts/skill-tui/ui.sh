# Table and interactive loop. Keys: up/down item, left/right target, space mark, enter install, a install all, x remove, d diff, q quit.

SELECTED=() # cell -> 1 for cells marked to install
NAME_COLUMN='%-13s%-32s'

state_color() { # state -> ANSI color code
  case $1 in
    same) echo 32 ;;
    modified) echo 33 ;;
    missing) echo 31 ;;
    "local only") echo 36 ;;
    *) echo 0 ;;
  esac
}

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
  local selected_row=${1:--1} selected_col=${2:--1} i j kind name src state color mark cell
  printf "  $NAME_COLUMN %-12s %-12s%s\n" kind name "${TARGETS[@]}" source
  for i in "${!ROWS[@]}"; do
    IFS='|' read -r kind name src <<<"${ROWS[i]}"
    if [[ $i == "$selected_row" ]]; then printf "\e[7m> $NAME_COLUMN\e[0m" "$kind" "$name"; else printf "  $NAME_COLUMN" "$kind" "$name"; fi
    for j in "${!TARGETS[@]}"; do
      cell=$(cell_of "$i" "$j")
      state=$(state_of "$cell"); state=${state:--}
      color=$(state_color "$state")
      [[ $i == "$selected_row" && $j == "$selected_col" ]] && color+=";7"
      [[ -n ${SELECTED[$cell]:-} ]] && mark='*' || mark=' '
      if [[ -n ${USE_COLOR:-} ]]; then printf '\e[%sm%s%-11s\e[0m ' "$color" "$mark" "$state"; else printf '%s%-11s ' "$mark" "$state"; fi
    done
    print_source "$kind" "$name" "$src"
  done
}

# One byte per read: `head -c` reads ahead on macOS and swallows the rest of an arrow key (or of a pasted token),
# so dd with bs=1 is used. bash `read -n` would re-enable Ctrl+C, hence not `read`.
read_key() { # one keypress, arrows as full escape sequences
  local key rest
  key=$(dd bs=1 count=1 2>/dev/null)
  if [[ $key == $'\e' ]]; then stty min 0 time 1; rest=$(dd bs=1 count=2 2>/dev/null); stty min 1 time 0; key+=$rest; fi
  printf '%s' "$key"
}

confirm() { # question -> 0 = yes. pacman-style: Enter/y yes, n/q/Esc/Ctrl+C no
  local key
  printf '\e[33;1m%s [Y/n]\e[0m ' "$1"
  while key=$(read_key); do
    case $key in ''|y|Y) return 0 ;; n|N|q|$'\e'|$'\x03') return 1 ;; esac
  done
}

cell_item() { # cell -> fills item=(kind name src target)
  local kind name src ncols=${#TARGETS[@]}
  IFS='|' read -r kind name src <<<"${ROWS[$1 / ncols]}"
  item=("$kind" "$name" "$src" "${TARGETS[$1 % ncols]}")
}

with_deps() { # cells... -> the same cells, then cells of the missing items they need in the same target column
  local cell col dep i dep_cell seen=" " ncols=${#TARGETS[@]}
  local -a item
  for cell in "$@"; do seen+="$cell "; echo "$cell"; done
  for cell in "$@"; do
    cell_item "$cell"
    col=$((cell % ncols))
    for dep in $(dep_closure "${item[0]}/${item[1]}"); do
      i=$(row_index "$dep") || continue
      dep_cell=$((i * ncols + col))
      [[ $(state_of "$dep_cell") == missing && $seen != *" $dep_cell "* ]] || continue
      seen+="$dep_cell "
      echo "$dep_cell"
    done
  done
}

install_selected() { # marked cells (or the current one): missing ones, plus modified ones after one confirm, plus missing deps -> sets message
  local cells=() cell state error installed=0 chosen asked=" " k
  local -a item pending=() changed=() changed_names=() errors=() expanded=()
  for k in "${!SELECTED[@]}"; do cells+=("$k"); done
  ((${#cells[@]})) || cells=("$(cell_of "$row" "$col")")
  for cell in "${cells[@]}"; do
    cell_item "$cell"
    state=$(state_of "$cell")
    case $state in
      missing) pending+=("$cell") ;;
      modified) changed+=("$cell"); changed_names+=("$(item_label)") ;;
    esac
  done
  ((${#changed[@]})) && confirm "Overwrite local changes in ${changed_names[*]}?" && pending+=("${changed[@]}")
  chosen=${#pending[@]}
  if ((chosen)); then
    while read -r cell; do expanded+=("$cell"); done < <(with_deps "${pending[@]}")
    pending=("${expanded[@]}")
  fi
  for cell in "${pending[@]}"; do
    cell_item "$cell"
    if [[ ${item[0]} == mcp && $asked != *" ${item[2]} "* ]]; then asked+="${item[2]} "; ask_token "${item[2]}"; fi
    error=$(with_spinner "installing $(item_label)" install_item "${item[@]}" </dev/null 2>&1 >/dev/null) && installed=$((installed + 1)) || errors+=("$(item_label): $error")
  done
  message="installed $installed$(((${#pending[@]} > chosen)) && echo " (with $((${#pending[@]} - chosen)) dependencies)")${errors[*]:+, failed: ${errors[*]}}"
}

read_secret() { # prompt -> typed or pasted line, one * per character. Enter ends, Backspace deletes, Esc/Ctrl+C cancels
  local value="" char
  printf '%s' "$1" >&2
  while char=$(dd bs=1 count=1 2>/dev/null); do
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

select_all() { # every missing or modified cell, all targets -> SELECTED; returns 1 when there is none
  local cell
  SELECTED=()
  for cell in "${!STATES[@]}"; do
    case $(state_of "$cell") in missing|modified) SELECTED[$cell]=1 ;; esac
  done
  ((${#SELECTED[@]}))
}

run_tui() {
  local row=0 col=0 message="" key state needs cell frame screen line
  local -a item
  USE_COLOR=1
  stty -icanon -echo -isig min 1 time 0 # Ctrl+C becomes a key
  tput civis
  trap 'stty sane; tput cnorm; clear' EXIT
  refresh
  clear
  while true; do
    cell=$(cell_of "$row" "$col")
    cell_item "$cell"
    state=$(state_of "$cell")
    needs=$(deps_of "${item[0]}/${item[1]}")
    # the whole frame is built first, then drawn over the previous one: no clear, so no flicker
    frame=$( {
      printf '\e[1mskill-tui  up/down item  left/right target  space mark  enter install  a install all  x remove  d diff  q quit\e[0m\n\n'
      print_table "$row" "$col"
      printf '\ntarget: %s\nneeds:  %s\n\e[1m%s\e[0m\n' "$(install_dir "${item[0]}" "${item[3]}")" "${needs:--}" "$message"
    } )
    screen=$(while IFS= read -r line; do printf '%s\e[K\n' "$line"; done <<<"$frame")
    printf '\e[H%s\e[J' "$screen" # one write per frame; \e[K clears each line's tail, \e[J the rest below

    message=""
    key=$(read_key) # Enter arrives as "" (command substitution drops the newline)
    case $key in
      q|$'\e'|$'\x03') return ;;
      $'\e[A'|$'\eOA') ((row = (row + ${#ROWS[@]} - 1) % ${#ROWS[@]})) ;;
      $'\e[B'|$'\eOB') ((row = (row + 1) % ${#ROWS[@]})) ;;
      $'\e[C'|$'\eOC'|$'\e[D'|$'\eOD') ((col = 1 - col)) ;;
      ' ') [[ $state == missing || $state == modified ]] || continue
           if [[ -n ${SELECTED[$cell]:-} ]]; then unset "SELECTED[$cell]"; else SELECTED[$cell]=1; fi ;;
      '') install_selected; refresh ;;
      a) if ! select_all; then message="nothing to install"; continue; fi
         if confirm "Install all ${#SELECTED[@]} missing or modified items in every target?"; then install_selected; refresh; else SELECTED=(); fi ;;
      d) [[ $state == same || $state == modified ]] && show_diff "${item[@]}" | less -R ;;
      x) [[ $state == same || $state == modified || $state == "local only" ]] || continue
         confirm "Remove ${item[0]} ${item[1]} from ${item[3]}?$([[ $state == "local only" ]] && echo ' NOT in the repo: deletes the only copy.')" || continue
         message=$(with_spinner "removing $(item_label)" remove_item "${item[@]}" </dev/null 2>&1 >/dev/null) && message="removed $(item_label)" || message="failed: $message"
         refresh ;;
    esac
  done
}
