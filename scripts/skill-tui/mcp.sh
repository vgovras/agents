# MCP servers: mcp/<name>.env holds URL and an optional TOKEN_ENV (variable name) / TOKEN_HEADER.
# An optional mcp/<name>.md ("when to use") is kept as a marked section in the target's global instructions file.

load_mcp() { # src -> sets URL TOKEN_ENV TOKEN_HEADER TOKEN; callers declare them local
  URL= TOKEN_ENV= TOKEN_HEADER= TOKEN=
  source "$1"
  [[ -n $TOKEN_ENV ]] || return 0
  TOKEN=${!TOKEN_ENV:-$(sed -n "s/^$TOKEN_ENV=//p" .env 2>/dev/null)} # environment first, then the git-ignored .env
}

save_token() { # variable value -> the git-ignored .env (replaces an old value)
  touch .env && chmod 600 .env
  sed -i "/^$1=/d" .env
  printf '%s=%s\n' "$1" "$2" >>.env
}

load_codex_mcp() { CODEX_MCP=$(codex mcp list --json </dev/null 2>/dev/null || echo '[]'); }

installed_mcp_names() {
  jq -r '.mcpServers // {} | keys[]' ~/.claude.json 2>/dev/null
  jq -r '.[].name' <<<"$CODEX_MCP"
}

expected_mcp_json() { # src target -> canonical JSON of what the repo wants installed
  local URL TOKEN_ENV TOKEN_HEADER TOKEN; load_mcp "$1"
  if [[ $2 == claude ]]; then
    jq -Scn --arg url "$URL" --arg header "$TOKEN_HEADER" --arg token "$TOKEN" \
      '{type: "http", url: $url} + (if $token != "" then {headers: {($header): $token}} else {} end)'
  else # codex reads the token from the env var at runtime
    jq -Scn --arg url "$URL" --arg var "${TOKEN:+$TOKEN_ENV}" \
      '{url: $url, bearer_token_env_var: (if $var != "" then $var else null end)}'
  fi
}

installed_mcp_json() { # name target -> canonical JSON of the installed server, "" when not installed
  if [[ $2 == claude ]]; then jq -Sc --arg name "$1" '.mcpServers[$name] // empty' ~/.claude.json 2>/dev/null
  else jq -Sc --arg name "$1" '.[] | select(.name == $name).transport | {url, bearer_token_env_var}' <<<"$CODEX_MCP"; fi
}

install_mcp() { # name src target
  local URL TOKEN_ENV TOKEN_HEADER TOKEN; load_mcp "$2"
  remove_mcp "$1" "$3" 2>/dev/null
  if [[ $3 == claude ]]; then
    claude mcp add --transport http -s user "$1" "$URL" ${TOKEN:+-H "$TOKEN_HEADER: $TOKEN"} || return
  else # written directly: `codex mcp add` blocks on an OAuth browser login (do it later: codex mcp login <name>)
    mkdir -p ~/.codex
    printf '\n[mcp_servers.%s]\nurl = "%s"\n' "$1" "$URL" >>~/.codex/config.toml
    [[ -z $TOKEN ]] || printf 'bearer_token_env_var = "%s"\n' "$TOKEN_ENV" >>~/.codex/config.toml
  fi
  [[ ! -f $(section_text_file "$2") ]] || add_section "mcp:$1" "$(section_text_file "$2")" "$3"
}

remove_mcp() { # name target
  remove_section "mcp:$1" "$2"
  if [[ $2 == claude ]]; then claude mcp remove -s user "$1"; else codex mcp remove "$1"; fi
}

section_text_file() { echo "${1%.env}.md"; } # src

is_section_same() { # name src target; true when the repo has no section for this server
  local text_file; text_file=$(section_text_file "$2")
  [[ ! -f $text_file || $(installed_section "mcp:$1" "$3") == "$(<"$text_file")" ]]
}
