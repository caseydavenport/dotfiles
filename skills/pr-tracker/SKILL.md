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

# PRs from others where Casey is a requested reviewer or has left a review
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

Also track **cherry-picks**: open PRs in `tigera/calico-private` with label `merge-oss-cherry-pick` that are either authored by Casey or reference one of Casey's open OSS PRs in the body (pattern: `projectcalico/calico#NNNN`). These carry the same metadata fields as regular PRs (state, priority, ci, reviews, notes).

## Mode 1: Show ("show PRs", "my PRs", "PR status", "check my PRs")

Triggers: "show PRs", "show my PRs", "my PRs", "PR status", "check my PRs". This displays PR data in the terminal from the local data file. Does **not** fetch from GitHub or open the browser.

1. Read the data file
2. Print a concise terminal summary grouped by priority (see Display format below)

## Mode 2: Browse / Start / Refresh ("browse PRs", "open PR dashboard", "start pr-tracker", "refresh PRs")

Triggers: "browse PRs", "browse my PRs", "open PR dashboard", "PR dashboard", "start pr-tracker", "start my pr-tracker", "refresh PRs", "refresh my PRs", "update PR data". This starts the dashboard in a Docker container and opens the browser. Refreshing is handled by the dashboard's Go server — do **not** run `gh` commands manually.

1. Check if the container is already running:
   ```bash
   docker ps --filter name=pr-dashboard --format '{{.ID}}'
   ```
   If running, just open the browser and confirm.

2. Build the image (if needed) and start the container:
   ```bash
   docker build -t pr-dashboard ~/.claude/skills/pr-tracker/server
   docker run -d --rm --name pr-dashboard \
     -p 48923:48923 \
     -e GITHUB_TOKEN="$GITHUB_TOKEN" \
     -e GCS_BUCKET=caseys-stuff \
     -v ~/.claude/projects/-home-casey-repos-gopath-src-github-com-projectcalico-calico/memory:/data \
     -v ~/.config/gcloud/application_default_credentials.json:/etc/gcs/adc.json:ro \
     pr-dashboard
   ```

3. Open the browser from the host:
   ```bash
   xdg-open http://127.0.0.1:48923
   ```

4. The dashboard supports:
   - Drag-and-drop priority changes
   - State dropdown changes
   - "Apply Changes" button that writes edits back to the YAML file via `PATCH /api/prs`
   - "Refresh" button that fetches fresh data from GitHub via `POST /api/refresh`

To stop the dashboard: `docker stop pr-dashboard`

Just confirm: "Dashboard server started."

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

### Terminal display (Mode 1: Show)

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

### Browser dashboard (Mode 2: Browse)

Start the Docker container. Do **not** print the terminal summary.

API endpoints:
- `GET /api/prs` — returns full tracker data as JSON
- `PATCH /api/prs` — accepts `{"changes": [{repo, number, state?, priority?, notes?}]}` to update PRs
- `POST /api/refresh` — fetches fresh data from GitHub via `gh` CLI, updates YAML, returns updated data

Changes made in the dashboard are persisted immediately to the YAML file — no download/apply step needed.

## Updating metadata

When Casey says things like "mark #12069 as active" or "add a note to #11863", update the relevant fields and write the file. Support natural language updates:
- "park #9458" → set priority to parked
- "#11631 needs work to address fasaxc feedback" → set state to `needs-work`, update notes
- "#12010 depends on operator#4499" → add to depends_on
- "#11863 depends on #11973" → infer same repo, add to depends_on
