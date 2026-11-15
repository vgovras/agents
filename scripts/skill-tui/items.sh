# Rows of the table: "kind|name|src". src is the repo copy; "" = installed but not in the repo (or a failed fetch).
# A cell is one row x one target: cell = row * ncols + col. STATES and SELECTED are indexed by cell.

STATES=()    # cell -> state, filled by collect_states (slow: CLI calls, diffs)
DEP_LINES=() # "kind/name kind/name ..." = an item, then what it needs (from deps.conf)

cell_of() { echo $(($1 * ${#TARGETS[@]} + $2)); } # row col -> cell
state_of() { echo "${STATES[$1]:-}"; }           # cell -> state

fetch_remote() { # skills/<name>/remote.env (REPO, DIR) -> echoes the fetched copy in ~/.cache/harness/<name>; nothing when it fails
  local REPO DIR name cache
  name=$(basename "$(dirname "$1")")
  source "$1"
  cache=~/.cache/harness/$name
  { git -C "$cache" pull -q --depth 1 || { rm -rf "$cache" && git clone -q --depth 1 "$REPO" "$cache"; }; } \
    </dev/null &>/dev/null && echo "$cache/$DIR"
}

add_row() { # kind name src; the first row per kind/name wins (repo rows are added first)
  [[ $seen != *" $1/$2 "* ]] || return 0
  seen+="$1/$2 "
  ROWS+=("$1|$2|$3")
}

collect_rows() {
  local seen=" " file name target i kind line
  local -a sorted=()
  ROWS=()
  load_codex_mcp
  while read -r file; do
    name=$(basename "$(dirname "$file")")
    if [[ $file == */remote.env ]]; then add_row skill "$name" "$(fetch_remote "$file")"
    else add_row skill "$name" "$(dirname "$file")"; fi
  done < <(find skills -name SKILL.md -o -name remote.env)
  for file in agents/*.md; do add_row agent "$(basename "$file" .md)" "$file"; done
  for file in mcp/*.env; do add_row mcp "$(basename "$file" .env)" "$file"; done
  for file in instructions/*.md; do add_row instruction "$(basename "$file" .md)" "$file"; done

  for target in "${TARGETS[@]}"; do
    for file in "$(install_dir skill "$target")"/*/SKILL.md; do [[ -f $file ]] && add_row skill "$(basename "$(dirname "$file")")" ""; done
  done
  for file in "$(install_dir agent claude)"/*.md "$(install_dir agent codex)"/*.toml; do
    [[ -f $file ]] && { name=$(basename "$file"); add_row agent "${name%.*}" ""; }
  done
  while read -r name; do [[ -n $name ]] && add_row mcp "$name" ""; done < <(installed_mcp_names)
  for target in "${TARGETS[@]}"; do
    while read -r name; do [[ -n $name ]] && add_row instruction "$name" ""; done < <(section_names instruction "$target")
  done

  while IFS= read -r line; do [[ -n $line ]] && sorted+=("$line"); done < <(printf '%s\n' "${ROWS[@]}" | sort)
  ROWS=("${sorted[@]}")
  load_deps
  collect_states
}

row_index() { # kind/name -> its index in ROWS; fails when there is no such row
  local i kind name _
  for i in "${!ROWS[@]}"; do
    IFS='|' read -r kind name _ <<<"${ROWS[i]}"
    [[ "$kind/$name" == "$1" ]] && { echo "$i"; return 0; }
  done
  return 1
}

load_deps() { # deps.conf lines "<kind>/<name>: <kind>/<name> ..." -> DEP_LINES
  local item needs
  local -a list
  DEP_LINES=()
  [[ -f deps.conf ]] || return 0
  while IFS=: read -r item needs; do
    [[ -z $item || $item == '#'* ]] && continue
    read -ra list <<<"$needs"
    DEP_LINES+=("$item ${list[*]}")
  done <deps.conf
}

deps_of() { # kind/name -> the kind/name items it needs directly, space-separated
  local line
  for line in "${DEP_LINES[@]}"; do
    if [[ ${line%% *} == "$1" ]]; then echo "${line#* }"; return; fi
  done
}

dep_closure() { # kind/name -> every kind/name it needs, transitively, once each
  local seen=" $1 " current dep
  local -a queue=("$1")
  while ((${#queue[@]})); do
    current=${queue[0]}
    queue=("${queue[@]:1}")
    for dep in $(deps_of "$current"); do
      [[ $seen == *" $dep "* ]] && continue
      seen+="$dep "
      queue+=("$dep")
      echo "$dep"
    done
  done
}

collect_states() {
  local i j kind name src
  STATES=()
  for i in "${!ROWS[@]}"; do
    IFS='|' read -r kind name src <<<"${ROWS[i]}"
    for j in "${!TARGETS[@]}"; do STATES[$(cell_of "$i" "$j")]=$(get_state "$kind" "$name" "$src" "${TARGETS[j]}"); done
  done
}

is_same() { # kind name src target installed
  if [[ $1 == mcp ]]; then [[ $5 == "$(expected_mcp_json "$3" "$4")" ]] && is_section_same "$2" "$3" "$4"
  elif [[ $1 == instruction ]]; then [[ $(installed_section "instruction:$2" "$4") == "$(<"$3")" ]]
  elif [[ $1 == agent ]]; then diff -q <(agent_file "$3" "$4") "$5" >/dev/null
  else diff -rq "$3" "$5" >/dev/null; fi
}

get_state() { # kind name src target -> same | modified | missing | local only | "" (target does not support the kind)
  local kind=$1 name=$2 src=$3 target=$4 installed
  [[ -n $(install_dir "$kind" "$target") ]] || return 0
  if [[ $kind == mcp ]]; then
    installed=$(installed_mcp_json "$name" "$target")
  elif [[ $kind == instruction ]]; then
    installed=; has_section "instruction:$name" "$target" && installed=1
  else
    installed=$(install_path "$kind" "$target" "$name")
    [[ -e $installed ]] || installed=
  fi
  if [[ -z $installed ]]; then [[ -z $src ]] || echo missing; return 0; fi
  if [[ -z $src ]]; then echo "local only"; return 0; fi
  is_same "$@" "$installed" && echo same || echo modified
}
