---
name: pr-tracker
description: "Track Casey's open PRs. Trigger for: \"my PRs\", \"show PRs\", \"PR status\", \"check PRs\", \"browse PRs\", \"refresh PRs\", updating PR priority/state/notes. Covers projectcalico/calico, tigera/operator, tigera/calico-private."
---

# PR Tracker

Track Casey's open PRs across three repos with persistent metadata that survives across conversations.

## Data file

PR data is stored at:
```
~/.claude/projects/-home-casey-repos-gopath-src-github-com-projectcalico-calico/memory/pr_tracker.yaml
```

Read this file at the start of any PR-related work. Write it back (full rewrite) after any changes.

## Data schema

```yaml
last_refreshed: "2026-03-11T17:00:00-07:00"
repos:
  - name: projectcalico/calico
    prs:
      - number: 12069
        title: "Parallelize kind-build-images for faster kind-up"
        branch: "caseydavenport/parallel-kind-build-images"
        state: draft           # needs-review | reviewed | draft | needs-work | mergeable
        priority: backburner   # active | next-up | backburner | parked
        ci: fail               # pass | fail | pending | unknown
        reviews: []            # ["user:APPROVED", "user:CHANGES_REQUESTED"]
        cherry_pick_of: ""     # "projectcalico/calico#1234" if this is a cherry-pick
        depends_on: []         # ["calico#1234", "operator#567"]
        blocks: []             # ["calico-private#890"]
        notes: "WIP infra improvement"

# PRs from others where Casey is a requested reviewer
review_requests:
  - number: 456
    title: "Add support for foo"
    repo: "projectcalico/calico"
    url: "https://github.com/projectcalico/calico/pull/456"
    author: "fasaxc"
    ci: pass               # pass | fail | pending | unknown
    draft: false

# GitHub issues assigned to Casey
assigned_issues:
  - number: 789
    title: "Bug: something broken"
    repo: "projectcalico/calico"
    url: "https://github.com/projectcalico/calico/issues/789"
    labels: ["bug", "priority/high"]
```

## Tracked repos

- `projectcalico/calico` — Casey's fork remote is `cd4`
- `tigera/operator` — Casey's fork remote is `cd4`
- `tigera/calico-private` — push to `origin`

Also track **marvin-tigera cherry-picks**: open PRs in `tigera/calico-private` authored by `marvin-tigera` with label `merge-oss-cherry-pick` that reference Casey's OSS PRs in the body (pattern: `projectcalico/calico#NNNN`). These carry the same metadata fields as regular PRs (state, priority, ci, reviews, notes).

## Mode 1: Refresh ("refresh PRs")

Triggers: "refresh PRs", "refresh my PRs", "update PR data". This fetches fresh data from GitHub and writes the data file. It does **not** display anything or open the dashboard — it's a silent background sync.

1. Read the data file (to preserve priority, notes, depends_on, blocks)
2. For each tracked repo, fetch all open PRs:
   ```bash
   gh pr list --repo <repo> --author caseydavenport --state open --json number,title,isDraft,reviewDecision,labels,headRefName,baseRefName --limit 50
   ```
3. For each PR, fetch CI and review status (same as auto-update)
4. Also fetch marvin-tigera cherry-picks:
   ```bash
   gh pr list --repo tigera/calico-private --author marvin-tigera --state open --label merge-oss-cherry-pick --json number,title,body,baseRefName --limit 20
   ```
   Parse the body for `projectcalico/calico#NNNN` references to link back to Casey's PRs. **Only include picks whose `oss_pr` matches one of Casey's open calico PRs** — discard the rest.
5. Fetch PRs where Casey is directly requested as a reviewer (excludes team-based assignments):
   ```bash
   gh search prs --state=open --json number,title,repository,url,author,isDraft --limit 50 -- 'user-review-requested:caseydavenport'
   ```
   For each review-requested PR, also fetch CI status:
   ```bash
   gh pr checks <number> --repo <repo> 2>&1 | grep -i "semaphore\|Argo"
   ```
6. Fetch GitHub issues assigned to Casey:
   ```bash
   gh search issues --assignee=caseydavenport --state=open --json number,title,repository,url,labels --limit 50
   ```
7. Merge with existing data: preserve user-set fields, update GitHub-derived fields. New PRs (not already in the data file) default to `priority: parked` — Casey will promote them manually when ready.
8. Remove PRs that are no longer open (they've been merged or closed)
9. Write the data file
10. Confirm with a one-liner: "Refreshed N PRs, M review requests, K issues across 3 repos."

## Mode 2: Show ("show PRs", "my PRs", "PR status", "check my PRs")

Triggers: "show PRs", "show my PRs", "my PRs", "PR status", "check my PRs". This displays PR data in the terminal from the local data file. Does **not** fetch from GitHub or open the browser.

1. Read the data file
2. Print a concise terminal summary grouped by priority (see Display format below)

## Mode 3: Browse ("browse PRs", "open PR dashboard")

Triggers: "browse PRs", "browse my PRs", "open PR dashboard", "PR dashboard". This starts the Go dashboard server and opens the browser.

1. Build and start the server (if not already running):
   ```bash
   cd ~/.claude/skills/pr-tracker/server && GOTOOLCHAIN=local go build -o pr-dashboard . && ./pr-dashboard
   ```
2. The server reads the YAML data file, serves the dashboard at http://127.0.0.1:48923, and opens the browser automatically.
3. The dashboard supports:
   - Drag-and-drop priority changes
   - State dropdown changes
   - "Apply Changes" button that writes edits back to the YAML file via `PATCH /api/prs`
   - "Refresh" button that fetches fresh data from GitHub via `POST /api/refresh`

## Deriving state from GitHub data

- `isDraft == true` → `draft`
- `reviewDecision == "CHANGES_REQUESTED"` → `reviewed`
- `reviewDecision == "APPROVED"` → `mergeable`
- `reviewDecision == "REVIEW_REQUIRED"` and not draft → `needs-review`
- User can always override state manually

Cherry-pick detection:
- Title starts with `[branch-name]` → likely a cherry-pick to that branch
- Has `merge-oss-cherry-pick` label → cherry-pick from OSS to enterprise
- Body contains `Cherry-pick history` and `projectcalico/calico#NNNN` → record the origin

## Display format

### Terminal display (Mode 3: Show)

Print a concise text summary grouped by priority, one line per PR. Do **not** open the browser.

```
## My PRs

### Active (3)
  calico-private#11088  Fix operator RBAC for tiered policy mgmt    mergeable       CI:unknown
  calico-private#11084  Fix three Felix FV test flakes               mergeable       CI:fail
  operator#4499         ClusterInformation write-protection webhook   needs-review    CI:pass

### Next-up (8)
  ...

## Review Requests (2)
  calico#12100  Add BGP graceful restart support   by fasaxc   CI:pass
  operator#4510 Fix webhook certificate rotation   by coutinhop CI:fail

## Assigned Issues (3)
  calico#11900  [bug] Felix crash on nftables cleanup
  calico#11850  [feature] Support for foo
  operator#4400 [bug] Operator panic on upgrade
```

### Browser dashboard (Mode 4: Browse)

Start the Go server. Do **not** print the terminal summary.

```bash
cd ~/.claude/skills/pr-tracker/server && GOTOOLCHAIN=local go build -o pr-dashboard . && ./pr-dashboard
```

The server runs on port 48923 by default. Use `--port N` to change, `--no-browse` to skip auto-opening.

API endpoints:
- `GET /api/prs` — returns full tracker data as JSON
- `PATCH /api/prs` — accepts `{"changes": [{repo, number, state?, priority?, notes?}]}` to update PRs
- `POST /api/refresh` — fetches fresh data from GitHub via `gh` CLI, updates YAML, returns updated data

Changes made in the dashboard are persisted immediately to the YAML file — no download/apply step needed.

Just confirm: "Dashboard server started."

## Updating metadata

When Casey says things like "mark #12069 as active" or "add a note to #11863", update the relevant fields and write the file. Support natural language updates:
- "park #9458" → set priority to parked
- "#11631 needs work to address fasaxc feedback" → set state to `needs-work`, update notes
- "#12010 depends on operator#4499" → add to depends_on
- "#11863 depends on #11973" → infer same repo, add to depends_on
