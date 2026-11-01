---
name: jira-branches
description: Git branches and draft PRs from Jira issues — release, story and feature branches named by issue key. Use any time the user gives a Jira issue link or key to start work on, or asks to create a branch or PR for a Jira task.
---

# Jira branches

```
RC-<n>  →  story/<STORY-KEY>  →  feat/<SUBTASK-KEY>
                 ↑ draft PR ─────────────┘
```

## Branches

| Branch | Created from | Name |
|---|---|---|
| release | — (exists) | `RC-<n>` |
| story | the release branch | `story/<STORY-KEY>` (`story/PROJ-12`) |
| feature | the story branch | `feat/<SUBTASK-KEY>` (`feat/PROJ-34`) |

- Names hold only the issue key, uppercase as in Jira; no summary slug.
- Release branch: the newest remote `RC-*` (`git branch -r --list 'origin/RC-*' --sort=-version:refname`).
- An existing branch is reused, never recreated or reset; its base stays as it is.

## Process

```
- [ ] 1. Issue: key from the link (…/browse/<KEY> or selectedIssue=<KEY>); Jira MCP getJiraIssue(cloudId, <KEY>) → type, summary, parent (cloudId: getAccessibleAtlassianResources, the site of the link)
- [ ] 2. Parent: getJiraIssue(parent) → type Story → go on; no parent or another type → stop and ask the user
- [ ] 3. git fetch; clean working tree, else stop and ask
- [ ] 4. story/<STORY-KEY>: exists (origin or local) → check it out, push -u if origin lacks it; else create from origin/RC-<n> and push -u
- [ ] 5. feat/<SUBTASK-KEY>: exists → check it out; else create from story/<STORY-KEY>
- [ ] 6. No commits ahead of the story branch → git commit --allow-empty -m "<SUBTASK-KEY>: <subtask summary>" (GitHub refuses a PR without commits)
- [ ] 7. git push -u origin feat/<SUBTASK-KEY>
- [ ] 8. Draft PR, unless one exists for the branch (gh pr list --head feat/<SUBTASK-KEY>)
- [ ] 9. Report: branches (created / reused), base RC, PR link
```

## Draft PR

```sh
gh pr create --draft --base story/<STORY-KEY> --head feat/<SUBTASK-KEY> \
  --title "<SUBTASK-KEY>: <subtask summary>" --body "<body>"
```

Body: links to the subtask and to its story (`<site>/browse/<KEY>`), then the subtask's summary line. No other text.

## Stop and ask when

- The parent is not a Story, or the issue has no parent.
- No remote `RC-*` branch exists.
- The working tree has uncommitted changes.
- A local story or feature branch has diverged from its origin copy.
