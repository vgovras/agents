# Where each kind of item is installed, per target tool. Empty output = the target does not support the kind.
TARGETS=(claude codex)

install_dir() { # kind target -> the directory (mcp: a label, instruction: the file); "" when not supported
  case $1/$2 in
    skill/claude) echo "$HOME/.claude/skills" ;;
    skill/codex) echo "$HOME/.codex/skills" ;;
    agent/claude) echo "$HOME/.claude/agents" ;;
    agent/codex) echo "$HOME/.codex/agents" ;;
    mcp/claude) echo "claude config" ;;
    mcp/codex) echo "codex config" ;;
    instruction/claude) echo "$HOME/.claude/CLAUDE.md" ;;
    instruction/codex) echo "$HOME/.codex/AGENTS.md" ;;
  esac
}

# Global instructions file per target: instructions and MCP "when to use" sections go here.
instruction_file() { install_dir instruction "$1"; } # target

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
