# agents — index for agents

Reusable skills and subagents. Install only what the current task needs.
Each item's full "when to use" is in its frontmatter `description` — read it there.

## Catalog

| Kind | Name | Path | Topic |
|---|---|---|---|
| skill | `clean-code` | `skills/clean-code/` | code style, any language |
| skill | `backend-module-structure` | `skills/architectures/backend-module-structure/` | backend module architecture, any language |
| skill | `rest-api-design` | `skills/rest-api-design/` | REST endpoints/controllers |
| skill | `testing` | `skills/testing/` | unit/integration/e2e tests (TS) |
| skill | `typescript` | `skills/typescript/` | tsconfig, imports, types, enums (TS) |
| skill | `nestjs` | `skills/nestjs/` | CQRS actions, controllers, DTOs, transactions |
| skill | `drizzle` | `skills/drizzle/` | Drizzle schemas, models, relations, queries |
| skill | `dev-environment` | `skills/dev-environment/` | compose + Makefile, pnpm, dependency versions |
| skill | `lint-format` | `skills/lint-format/` | oxlint + oxfmt, custom rules, import boundaries |
| skill (remote) | `ponytail` | `skills/ponytail/remote.env` | smallest complete change |
| agent | `backend-architect` | `agents/backend-architect.md` | backend design plan before non-trivial work |
| agent | `coder` | `agents/coder.md` | implement a user task (inline or `tasks/`) |
| agent | `reviewer` | `agents/reviewer.md` | review a plan before coding, a diff before reporting done |
| instruction | `backend-workflow` | `instructions/backend-workflow.md` | backend orchestrator rules: backend-architect → reviewer → coder → reviewer |
| mcp | `jira` | `mcp/jira.env` | Atlassian Rovo (Jira, Confluence), OAuth |
| mcp | `mcp-server-context7` | `mcp/mcp-server-context7.env` | library docs; optional `CONTEXT7_API_KEY` in `.env` |


## Install

A skill is a folder with `SKILL.md`; copy the whole folder, named after the skill.
A remote skill is only `remote.env` (`REPO`, `DIR`): copy `DIR` from that repo instead (`make skill tui` does it).
An agent is one `.md` file (Claude Code subagent format: `tools`, `model` in frontmatter).
An MCP server is `mcp/<name>.env` (`URL`, optional `TOKEN_ENV`/`TOKEN_HEADER`); install it with the tool's CLI or `make skill tui`.
An optional `mcp/<name>.md` is its "when to use" section: `make skill tui` adds it to `~/.claude/CLAUDE.md` / `~/.codex/AGENTS.md` between `<!-- harness:mcp:<name> -->` markers and removes it with the server.
An instruction is `instructions/<name>.md`: `make skill tui` adds it to `~/.claude/CLAUDE.md` / `~/.codex/AGENTS.md` between `<!-- harness:instruction:<name> -->` markers.
`make skill tui` shows and changes user-level installs of all four kinds.

| Tool | Skills | Agents |
|---|---|---|
| Claude Code — project | `.claude/skills/<name>/` | `.claude/agents/<name>.md` |
| Claude Code — user | `~/.claude/skills/<name>/` | `~/.claude/agents/<name>.md` |
| Codex — project | `.agents/skills/<name>/` | — |
| Codex — user | `~/.codex/skills/<name>/` | — |
| Hermes | `~/.hermes/skills/<category>/<name>/` or `skills.external_dirs` | — |

Rules:
- Prefer project level; user level only when asked.
- An item already installed → compare and ask before overwriting local changes.
- Agents are stack-agnostic and use whatever skills are installed; recommended with them:
  `backend-architect` → `backend-module-structure`, `rest-api-design`, `clean-code`;
  `coder` → `clean-code`, `testing`; `reviewer` → all four.
  Stack skills (`typescript`, `nestjs`, `drizzle`, `dev-environment`, `lint-format`) → all three agents when the project uses that stack.
- `backend-workflow` needs the agents `backend-architect`, `coder`, `reviewer`.
- After adding a skill/agent here, add its row to the catalog.
