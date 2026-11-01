# Rows of the table: "kind|name|src". src is the repo copy; "" = installed but not in the repo (or a failed fetch).

declare -A STATES      # "row/col" -> state, filled by collect_rows (slow: CLI calls, diffs)
declare -A REMOTE_DIRS # skill name -> fetched copy, filled once per run

fetch_remote() { # skills/<name>/remote.env (REPO, DIR) -> fills REMOTE_DIRS[name] from ~/.cache/harness/<name>
  local REPO DIR name cache
  name=$(basename "$(dirname "$1")")
  [[ -z ${REMOTE_DIRS[$name]+set} ]] || return 0
  source "$1"
  cache=~/.cache/harness/$name
  REMOTE_DIRS[$name]=
  { git -C "$cache" pull -q --depth 1 || { rm -rf "$cache" && git clone -q --depth 1 "$REPO" "$cache"; }; } \
    </dev/null &>/dev/null && REMOTE_DIRS[$name]=$cache/$DIR
}

add_row() { # kind name src; the first row per kind/name wins (repo rows are added first)
  [[ -z ${seen[$1/$2]:-} ]] || return 0
  seen[$1/$2]=1
  ROWS+=("$1|$2|$3")
}

collect_rows() {
  local -A seen
  local file name target
  ROWS=()
  load_codex_mcp
  while read -r file; do
    name=$(basename "$(dirname "$file")")
    if [[ $file == */remote.env ]]; then fetch_remote "$file"; add_row skill "$name" "${REMOTE_DIRS[$name]}"
    else add_row skill "$name" "$(dirname "$file")"; fi
  done < <(find skills -name SKILL.md -o -name remote.env)
  for file in agents/*.md; do add_row agent "$(basename "$file" .md)" "$file"; done
  for file in mcp/*.env; do add_row mcp "$(basename "$file" .env)" "$file"; done
  for file in instructions/*.md; do add_row instruction "$(basename "$file" .md)" "$file"; done

  for target in "${TARGETS[@]}"; do
    for file in "$(install_dir skill "$target")"/*/SKILL.md; do [[ -f $file ]] && add_row skill "$(basename "$(dirname "$file")")" ""; done
  done
  for file in "$(install_dir agent claude)"/*.md; do [[ -f $file ]] && add_row agent "$(basename "$file" .md)" ""; done
  while read -r name; do [[ -n $name ]] && add_row mcp "$name" ""; done < <(installed_mcp_names)
  for target in "${TARGETS[@]}"; do
    while read -r name; do [[ -n $name ]] && add_row instruction "$name" ""; done < <(section_names instruction "$target")
  done

  mapfile -t ROWS < <(printf '%s\n' "${ROWS[@]}" | sort)
  collect_states
}

collect_states() {
  local i j kind name src
  STATES=()
  for i in "${!ROWS[@]}"; do
    IFS='|' read -r kind name src <<<"${ROWS[i]}"
    for j in "${!TARGETS[@]}"; do STATES[$i/$j]=$(get_state "$kind" "$name" "$src" "${TARGETS[j]}"); done
  done
}

is_same() { # kind name src target installed
  if [[ $1 == mcp ]]; then [[ $5 == "$(expected_mcp_json "$3" "$4")" ]] && is_section_same "$2" "$3" "$4"
  elif [[ $1 == instruction ]]; then [[ $(installed_section "instruction:$2" "$4") == "$(<"$3")" ]]
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
