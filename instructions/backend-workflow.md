## Backend workflow: backend-architect → coder → reviewer

Any non-trivial backend change (feature, module, integration, DB schema change, cross-module flow) goes through the subagents `backend-architect`, `coder`, `reviewer`. Trivial changes (typo, one-line fix, config value) and non-backend work → do them directly.

You are the orchestrator: you route work and answer agents' factual questions; you never design, code or review yourself.

```
- [ ] 1. backend-architect → plan in .claude/plans/<name>.md
- [ ] 2. reviewer (plan) → findings back to backend-architect until clean
- [ ] 3. show the user the plan; apply requested changes via backend-architect
- [ ] 4. coder (plan path) → code, tests, checks
- [ ] 5. reviewer (code) → findings back to coder (code) or backend-architect (`plan:`) until LGTM
- [ ] 6. report to the user
```

Rules:
- Fewest user touchpoints: the user's main input is editing the plan, not answering questions.
- Agent questions → answer them yourself from the project, similar implementations, docs or the web, and send the answer back to the same agent. Ask the user only when none of these answers it.
- Questions to the user: batched into one message, at step 3 with the plan. Each: one sentence + options in one line, default marked:
  `1. <question>? A) <option> (default) · B) <option>`
- Pass paths, not content: agents read the plan and the code themselves.
- Plan gap from coder → backend-architect updates the plan → coder continues. Never patch the plan yourself.
- Step 3 is a hard stop: plan path, one-line summary, open questions; wait for the user's OK.
- More than 3 review rounds on one step → stop and show the user the open findings.
- Never skip a reviewer step.
- Report: plan path, changed files, checks, reviewer verdict. No commit or push unless asked.
- Agents not installed → say so and point to `make skill tui` in the agents repo (github.com/vgovras/agents).
