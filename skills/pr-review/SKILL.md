---
name: pr-review
description: Review a GitHub pull request against the repo's own rules, its Jira task and the frontend contract; write short one-sentence comments to a file and post them as inline PR comments once the user approves. Use any time the user gives a PR link or number and asks for a review, or runs /pr-review.
argument-hint: <pr-link | pr-number>
---

# PR review

Target: `$ARGUMENTS` (a PR link or number; no argument → the PR of the current branch).

Write everything (chat, file, PR comments) in the language the user writes in.

## 1. Checkout

1. `git status --porcelain`. Not empty → stop and ask once:
   ```
   The working tree has changes: <short list>. What to do?
     a. **Keep them (git stash push -u -m "pr-review <pr>")**
     b. Discard them (git reset --hard && git clean -fd)
   ```
   Never discard without an explicit answer.
2. `gh pr checkout <pr>`, then `git pull`.
3. Kept a stash → tell the user its name at the end of the report; do not pop it yourself.

## 1a. Existing comments (before the review)

1. Unresolved threads:
   ```
   gh api graphql -f owner=<owner> -f repo=<repo> -F n=<n> -f query='
     query($owner:String!,$repo:String!,$n:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$n){
       reviewThreads(first:100){nodes{id isResolved isOutdated path line
         comments(first:20){nodes{author{login} body}}}}}}}'
   ```
2. For each thread with `isResolved: false`: read the comment and the current code at `path` (and wherever the fix may have moved). Resolved only when the code now does what the comment asked, or the replies settled it; `isOutdated` alone is not proof.
3. Resolved → `gh api graphql -f id=<thread id> -f query='mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}'`.
4. Not resolved → leave it open; do not repeat it as a new comment.
5. Chat: a short table thread → resolved / still open (one-line reason for open ones).

## 2. Collect

- PR: `gh pr view <pr> --json title,body,author,baseRefName,headRefName,headRefOid,files`, then `git fetch origin <base>`.
- Diff: `git diff "origin/<base>...HEAD" -- src ':!*.spec.ts'`; read files from the checked-out tree.
- Large diffs: skip lockfiles and migration snapshots; read tests only to check what they prove.
- Rules: the repo's `CLAUDE.md` / `AGENTS.md` and **every skill they list**, read in full now. They are the criteria; memory of them is not.
- Task: every Jira key or link in the PR body → the issue and its parent story (Atlassian MCP), especially Acceptance Criteria.

## 3. Review

Check each change against:

- **Repo rules and skills.** Before calling something a violation, find the rule's text and check how existing code does the same thing.
- **The task.** The PR does what the Jira issue says: every AC, the described behaviour, names, statuses, error cases and edge cases the issue spells out; nothing missing, nothing extra the issue did not ask for. Frontend-only ACs are skipped.
  - Deviation from Jira → a comment: `Return 409 when the session is already closed (AC3).`
  - Jira describes a worse solution (insecure, breaks the FE contract, contradicts repo rules, reinvents what the framework has, needlessly complex) → do not ask to follow it; flag it as a separate `—` line marked `Jira:` with the better option, and list it first in chat so the user decides: `Jira: store the IP from @Ip() via trust proxy instead of reading X-Forwarded-For (AC4).`
- **Frontend contract.** The FE can build the screen with no workarounds: needed item first or flagged, formats documented in Swagger (ISO codes, enums, nullability), stable error codes the FE can act on, a backend signal for every AC that needs one.
- **Names.** Read every new or renamed name (file, class, method, variable, field, endpoint, DTO, error code) and check it against what the code actually does:
  - it tells the truth: `getUser` that also creates one, `validate` that saves, `isActive` that also checks expiry → misleading;
  - it says what and which, not just the kind of thing: no `data`, `info`, `item`, `handle`, `process`, `manager`, `helper`, `utils`, `listLive`, `getCurrentIdOrFail`, `deleteOne`;
  - one name per concept across the PR and the existing code (decorator and its type match; the same entity is not `session` here and `token` there);
  - name the replacement in the comment: `Rename getUser to findOrCreateUser.`
- **Less code (ponytail).** The best code is the code not written. For every added file, class, method, abstraction, option and dependency, ask whether the task works without it:
  - no wrappers, layers, interfaces, factories or config for a single use;
  - no code "for later", unused params, dead branches, defensive checks the types already guarantee;
  - a simple ORM query is not wrapped in a method; it stays inline where it is used. A service method with one caller moves into that caller;
  - no single-field finders (`findOneById`, `deleteByRefreshToken`): one `findOneBy({ … })`.
- **No reinvented wheels.** Before accepting custom code, check whether the framework, ORM, language or an installed library already does it (Context7, then `node_modules`): `@Ip()` before a custom decorator, built-in pipes/guards/validators, ORM relations and relation filters before the query builder (the query builder only for writes and bulk operations), `Intl`/`Date` before hand-made formatting. Found one → the comment names it: `Use ParseUUIDPipe instead of the custom check.`
- **Reuse of project code.** For each new helper, type, constant, decorator, guard, error, DTO or query, search the repo (`libs/`, `common/`, `shared/`, other modules) for an existing one (`rg` by name and by behaviour). Exists → comment points to it with its path; near-duplicate → extend the existing one, do not copy it.
- **Domain rules:**
  - Tokens and secrets never reach commands or services: a guard or pipe resolves them to ids at the edge. "Is the caller a live user/session" is checked by a guard, not repeated in every command.
  - Records with history (sessions, links) are closed with a timestamp (`closedAt`), not deleted; every "live" check then includes it.
  - Values from request headers are trusted only through the proxy config.
- **Correctness and security.** Spoofable inputs, missing filters, races, broken flows next to the change.

Verify before you claim:

- Library behaviour → Context7, then the installed source in `node_modules`.
- Doubtful runtime behaviour (ESM/CJS import, parsing) → run a minimal script in a temp dir.
- Problems that existed before this PR are not comments; mention them in chat only.

## 4. Comments

The best comment is the one not written. Write a comment only when something must change; skip nits, praise and questions you can answer yourself.

Each comment:

- **one sentence**, an imperative: what to do, nothing else;
- no reasons, no rule citations, no explanations, no "because", no "consider", no code blocks — we don't teach;
- names the exact thing (function, field, file) so the author needs no context.

```
✗ Here findOneById is a single-field finder, which our rules discourage because it adds an unnecessary method — consider replacing it with findOneBy.
✓ Replace findOneById with an inline findOneBy({ id }).

✗ It would be better to close the session with a timestamp so history is kept.
✓ Set closedAt instead of deleting the session.

✗ AC2 says the list must be sorted, but I don't see sorting here.
✓ Sort sessions by lastActiveAt desc (AC2).
```

## 5. File

`.agents/plans/<task-key>-<task-slug>-review.md` in the repo (`.claude/plans/` when the repo has no `.agents/`): lowercase key, a short English slug of the task title (`<key>-active-sessions-review.md`). No task → the head branch name instead of the key. Create the folder if missing. Not committed.

Format — a numbered list, one comment per line, nothing else:

```
1. `src/sessions/sessions.service.ts:42` Replace findOneById with an inline findOneBy({ id }).
2. `src/sessions/sessions.controller.ts:18` Take the IP from @Ip().
3. `—` Sort sessions by lastActiveAt desc (AC2).
```

`—` = no single line (goes to the review body). Lines must be inside the diff.

Chat: the path to the file and the same list; nothing found → say it is all fine. Then wait.

User edits ("add", "rename", "drop") → apply to the file and renumber.

## 6. Post (only after the user approves the file)

One review, event `COMMENT`, via `gh api -X POST repos/<owner>/<repo>/pulls/<n>/reviews --input <json>`:

- `commit_id` = `headRefOid`;
- each line with `path:line` = an inline comment `{ path, line, side: "RIGHT", body }`;
- `—` lines go to `body`, one per line;
- build the JSON from the file with a script so the text matches it exactly;
- no `@mentions`.

Report the review URL.

## Checklist

```
- [ ] Working tree clean, or user chose stash/discard; PR checked out and pulled
- [ ] Every unresolved thread checked against current code; fixed ones resolved
- [ ] Repo rules + every listed skill read in full
- [ ] Jira task and parent story AC read
- [ ] PR does what Jira says; worse Jira solutions flagged as `Jira:` lines
- [ ] Rules, FE contract checked
- [ ] Every new name read against what the code does
- [ ] Every addition questioned: needed at all? framework/library has it? libs/common has it?
- [ ] Domain rules, correctness, security checked
- [ ] Claims verified (rule text, Context7, node_modules, a run)
- [ ] File: numbered one-sentence imperatives with path:line; chat shows it; wait
- [ ] Posted only after approval: inline comments + body, COMMENT
```
