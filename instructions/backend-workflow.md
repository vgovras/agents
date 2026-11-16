## Backend workflow: plan → coders → fix

Goal: ship backend changes fast without losing quality. You are the coordinator: you write the plan, run cheap coders in parallel and fix their output yourself.

### Pick the path

**Default: do it yourself** — no plan, no agents, no stop; run the checks, report. The workflow costs minutes per stage; it pays off only for big work.

Workflow only when **both** hold:
- the work splits into 2+ parts that can run in parallel (roughly 8+ files);
- it is a new module, a new integration, a group of new endpoints with new tables, or a flow across modules.

Do it yourself, even when it touches the DB or several files:
- a bug fix, a refactor inside one module, a rename;
- one endpoint, a field + migration, a new column or index;
- a review finding, a config value, tests for existing code.

The user says "plan" / "workflow" → workflow; "just do it" → yourself. Unsure → yourself; switch to the workflow only if the scope grows.

### Workflow

```
- [ ] 1. plan: read skill `backend-plan`, research, write .claude/plans/<name>.md yourself
- [ ] 2. hard stop: plan path + open questions; wait for the user's OK, apply their plan edits
- [ ] 3. coders: one `coder` per part `[N]`, all in one message, `haiku`, `Checks: none`
- [ ] 4. `[N after M]` parts → start when M is done
- [ ] 5. all done → make check; read the whole diff against the plan and the skills
- [ ] 6. fix everything yourself: failures, bugs, skill violations, gaps
- [ ] 7. report
```

### Coders

- Prompt: `Plan: .claude/plans/<name>.md. Part: [N]. Checks: none.` plus the answer to anything you know a coder will ask. Nothing else: the plan is the prompt.
- One part only → one coder, it runs the checks itself (omit `Checks: none`).
- A coder returns questions → answer from the plan and the project, send the answer to the same coder via SendMessage.
- A coder's output is wrong → fix it yourself; don't re-run the coder and don't spawn a reviewer.
- Codex: coder model `gpt-6-luna`, effort `medium` (unavailable → `gpt-5.6-luna`).

### Rules

- Fewest user touchpoints: one stop at step 2; questions batched in one message, each on its own lines, the default option in bold:
  ```
  1. <question>?
     a. **<default option>**
     b. <option>
  ```
- Plan changes after the OK (a gap a coder found) → edit the plan yourself, tell the affected coder.
- `reviewer` / `backend-architect` agents only when the user asks.
- Report: plan path, parts, changed files, checks, what you fixed after the coders. No commit or push unless asked.
- `coder` agent or `backend-plan` skill not installed → say so and point to `make skill tui` in the agents repo (github.com/vgovras/agents).
