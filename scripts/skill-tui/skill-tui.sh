#!/usr/bin/env bash
# skill-tui: user-level install state of the skills, agents, MCP servers and instructions in Claude Code and Codex.
# Usage: skill-tui.sh [tui|list]
# Runs on bash 3.2 (macOS /bin/bash) and bash 4+ (Linux): no associative arrays, mapfile or realpath.
LIB_DIR=$(cd "$(dirname "$0")" && pwd -P)
cd "$LIB_DIR/../.." || exit 1
for lib in paths sections mcp items actions ui; do source "$LIB_DIR/$lib.sh"; done

if [[ ${1:-tui} == list || ! -t 1 ]]; then refresh; print_table; else run_tui; fi
