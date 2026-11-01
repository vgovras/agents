## Backend workflow: backend-architect → coder → reviewer

Goal: ship backend changes fast without losing quality. You are the orchestrator: you pick the path, split work, run agents in parallel and pick a model per agent.

### Pick the path

- **Large** — a new feature, module, integration, DB schema change, cross-module flow, or more than a few files → the full workflow below.
- **Small** — clear, local change (a fix, a field, a rename, a config value, a review finding) → do it yourself, run the checks, report. No agents.
- In between → your call; prefer the cheaper path while the outcome is the same.

### Full workflow

```
- [ ] 1. backend-architect (opus) → plan in .claude/plans/<name>.md, split into Parts
- [ ] 2. reviewer (plan) → findings back to backend-architect until clean; catches design and split problems before any code
- [ ] 3. show the user the plan; apply requested changes via backend-architect
- [ ] 4. coders per the plan's Parts, in parallel where `After` allows
- [ ] 5. all parts done → make check once; failures → a coder for the failing part
- [ ] 6. reviewer (code) → findings back to coder (code) or backend-architect (`plan:`) until LGTM
- [ ] 7. report to the user
```

### Parallel work

- The split is part of the plan (**Parts**: files, `After`, Level), so the plan review checks it; don't re-split, send split problems back to backend-architect.
- Start every part whose `After` parts are done in one message, so the coders run concurrently.
- Give each coder the plan path and its part number; its files are its own, every other file belongs to another part and must not be touched.
- Parallel coders don't run the full checks (other parts are unfinished): tell them `Checks: none`; you run `make check` once at step 5.
- One part only → one coder, it runs the checks itself.

### Models

Pass the model (Codex: and the reasoning effort) with each agent call:

| Agent | Claude Code | Codex |
|---|---|---|
| backend-architect | `opus` | `gpt-6.1-sol`, `high` |
| coder: part with Level `simple`, a review fix | `haiku` | `gpt-6-luna`, `medium` |
| coder: part with Level `complex`, failing checks, a non-obvious bug | `sonnet` | `gpt-6.1-sol`, `medium` |
| reviewer | its default | `gpt-6.1-sol`, `high` |

- Codex: a model the account cannot use → the next available one: `gpt-6.1-sol` → `gpt-6-sol` → `gpt-5.6-sol` → `gpt-5.6-terra`; `gpt-6-luna` → `gpt-5.6-luna`.
- A cheap coder (`haiku` / `gpt-6-luna`) that returns questions, fails the checks twice or gets the same review finding twice → retry the part with the `complex` model.

### Rules

- Fewest user touchpoints: the user's main input is editing the plan, not answering questions.
- Agent questions → answer them yourself from the project, similar implementations, docs or the web, and send the answer back to the same agent. Ask the user only when none of these answers it.
- Questions to the user: batched into one message, at step 3 with the plan. Each: one sentence + options in one line, default marked:
  `1. <question>? A) <option> (default) · B) <option>`
- Step 3 is a hard stop: plan path, one-line summary, open questions; wait for the user's OK.
- Pass paths, not content: agents read the plan and the code themselves.
- Agents by name: Claude Code subagents `backend-architect`, `coder`, `reviewer`; in Codex the custom agents with the same names (`~/.codex/agents/`).
- Plan gap from a coder → backend-architect updates the plan → the coder continues. A small, obvious gap (a missing import path, a typo in a name) → fix the plan yourself and tell the coder.
- More than 3 review rounds on one step → stop and show the user the open findings.
- In the full workflow never skip a reviewer step.
- Report: plan path, parts and their agents/models, changed files, checks, reviewer verdict. No commit or push unless asked.
- Agents not installed → say so and point to `make skill tui` in the agents repo (github.com/vgovras/agents).
