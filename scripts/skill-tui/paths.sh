# Where each kind of item is installed, per target tool. A missing key = the target does not support the kind.
TARGETS=(claude codex)
declare -A INSTALL_DIRS=(
  [skill/claude]=$HOME/.claude/skills
  [skill/codex]=$HOME/.codex/skills
  [agent/claude]=$HOME/.claude/agents
  [agent/codex]=$HOME/.codex/agents
  [mcp/claude]="claude config"
  [mcp/codex]="codex config"
  [instruction/claude]=$HOME/.claude/CLAUDE.md
  [instruction/codex]=$HOME/.codex/AGENTS.md
)

install_dir() { echo "${INSTALL_DIRS[$1/$2]:-}"; } # kind target

install_path() { # kind target name
  local dir; dir=$(install_dir "$1" "$2")
  if [[ $1 != agent ]]; then echo "$dir/$3"; return; fi
  [[ $2 == codex ]] && echo "$dir/$3.toml" || echo "$dir/$3.md"
}

agent_file() { # agent .md, target -> the file to install: Claude Code takes it as is, Codex gets a custom agent TOML
  if [[ $2 != codex ]]; then cat "$1"; return; fi
  local body; body=$(awk '/^---$/ && n < 2 { n++; next } n >= 2' "$1" | sed '/./,$!d')
  [[ $body != *"'''"* ]] || { echo "$1: body contains ''' (breaks the TOML literal string)" >&2; return 1; }
  # the model is left to the spawn call (backend-workflow picks one per part); a model here would override it
  printf 'name = %s\ndescription = %s\ndeveloper_instructions = '"'''"'\n%s\n'"'''"'\n' \
    "$(jq -n --arg v "$(sed -n '2,/^---$/s/^name: //p' "$1")" '$v')" \
    "$(jq -n --arg v "$(sed -n '2,/^---$/s/^description: //p' "$1")" '$v')" "$body"
}

# Global instructions file per target: instructions and MCP "when to use" sections go here.
declare -A INSTRUCTION_FILES=([claude]=$HOME/.claude/CLAUDE.md [codex]=$HOME/.codex/AGENTS.md)
