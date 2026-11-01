#!/usr/bin/env bash
# skill-tui: user-level install state of the skills, agents, MCP servers and instructions in Claude Code and Codex.
# Usage: skill-tui.sh [tui|list]
set -u
LIB_DIR=$(dirname "$(realpath "$0")")
cd "$LIB_DIR/../.." || exit 1
for lib in paths sections mcp items actions ui; do source "$LIB_DIR/$lib.sh"; done

if [[ ${1:-tui} == list || ! -t 1 ]]; then refresh; print_table; else run_tui; fi
