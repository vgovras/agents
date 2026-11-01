# Where each kind of item is installed, per target tool. A missing key = the target does not support the kind.
TARGETS=(claude codex)
declare -A INSTALL_DIRS=(
  [skill/claude]=$HOME/.claude/skills
  [skill/codex]=$HOME/.codex/skills
  [agent/claude]=$HOME/.claude/agents
  [mcp/claude]="claude config"
  [mcp/codex]="codex config"
  [instruction/claude]=$HOME/.claude/CLAUDE.md
  [instruction/codex]=$HOME/.codex/AGENTS.md
)

install_dir() { echo "${INSTALL_DIRS[$1/$2]:-}"; } # kind target

install_path() { # kind target name
  local dir; dir=$(install_dir "$1" "$2")
  [[ $1 == agent ]] && echo "$dir/$3.md" || echo "$dir/$3"
}

# Global instructions file per target: instructions and MCP "when to use" sections go here.
declare -A INSTRUCTION_FILES=([claude]=$HOME/.claude/CLAUDE.md [codex]=$HOME/.codex/AGENTS.md)
