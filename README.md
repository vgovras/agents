# agents

My skills, subagents, MCP server definitions and global instructions for Claude Code and Codex,
plus `make skill tui`: a bash TUI that shows what is installed at user level and installs, removes or diffs it.

| Folder | What |
|---|---|
| `skills/` | Agent skills (`SKILL.md` folders; `remote.env` = fetched from another repo) |
| `agents/` | Subagents (backend-architect, coder, reviewer) |
| `instructions/` | Sections for the global `CLAUDE.md` / `AGENTS.md` (backend-workflow) |
| `mcp/` | MCP server definitions (jira, context7) |
| `scripts/skill-tui/` | The TUI |

## Usage

```sh
cp env.example .env   # optional: CONTEXT7_API_KEY
make skill tui        # arrows, space = mark, enter = install marked (+ missing deps from deps.conf), x = remove, d = diff, q = quit
make skill list       # plain table
```

Needs bash, git, jq, and the `claude` / `codex` CLIs for MCP servers.
See `AGENTS.md` for the catalog and manual install paths.
