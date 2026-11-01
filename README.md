# agents

## Quick start

```sh
make                  # list commands
make skill tui        # creates .env from env.example (optional CONTEXT7_API_KEY); arrows, space = mark, enter = install marked (+ missing deps from deps.conf), a = install all, x = remove, d = diff, q = quit
make skill list       # plain table
```

Needs bash, git, jq, and the `claude` / `codex` CLIs for MCP servers.
See `AGENTS.md` for the catalog and manual install paths.
