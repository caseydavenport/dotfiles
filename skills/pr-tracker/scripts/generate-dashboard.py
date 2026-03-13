#!/usr/bin/env python3
"""Generate an HTML dashboard from pr_tracker.yaml data."""

import json
import yaml
import sys
import os


REPO_URLS = {
    "projectcalico/calico": "https://github.com/projectcalico/calico/pull",
    "tigera/operator": "https://github.com/tigera/operator/pull",
    "tigera/calico-private": "https://github.com/tigera/calico-private/pull",
}

ISSUE_URLS = {
    "projectcalico/calico": "https://github.com/projectcalico/calico/issues",
    "tigera/operator": "https://github.com/tigera/operator/issues",
    "tigera/calico-private": "https://github.com/tigera/calico-private/issues",
}

SHORT_REPO = {
    "projectcalico/calico": "calico",
    "tigera/operator": "operator",
    "tigera/calico-private": "calico-private",
}


def short_repo(repo_name):
    return SHORT_REPO.get(repo_name, repo_name.split("/")[-1])


def build_pr_list(data):
    """Flatten YAML data into a list of PR dicts for the JS side."""
    prs = []
    for repo in data.get("repos", []):
        repo_name = repo["name"]
        for pr in repo.get("prs", []):
            reviews = pr.get("reviews", [])
            has_approved = any("APPROVED" in r for r in reviews)
            has_changes_requested = any("CHANGES_REQUESTED" in r for r in reviews)
            review_state = "none"
            if has_approved:
                review_state = "approved"
            elif has_changes_requested:
                review_state = "changes-requested"

            prs.append({
                "number": pr["number"],
                "title": pr.get("title", ""),
                "repo": repo_name,
                "short_repo": SHORT_REPO.get(repo_name, repo_name),
                "url": f"{REPO_URLS.get(repo_name, '')}/{pr['number']}",
                "state": pr.get("state", ""),
                "priority": pr.get("priority", "backburner"),
                "ci": pr.get("ci", "unknown"),
                "reviews": reviews,
                "review_state": review_state,
                "notes": pr.get("notes", ""),
                "cherry_pick_of": pr.get("cherry_pick_of", ""),
                "depends_on": pr.get("depends_on", []),
                "blocks": pr.get("blocks", []),
                "is_marvin": False,
            })

    for pick in data.get("marvin_cherry_picks", []):
        repo_name = pick.get("repo", "tigera/calico-private")
        reviews = pick.get("reviews", [])
        has_approved = any("APPROVED" in r for r in reviews)
        has_changes_requested = any("CHANGES_REQUESTED" in r for r in reviews)
        review_state = "none"
        if has_approved:
            review_state = "approved"
        elif has_changes_requested:
            review_state = "changes-requested"

        prs.append({
            "number": pick["number"],
            "title": pick.get("title", ""),
            "repo": repo_name,
            "short_repo": SHORT_REPO.get(repo_name, repo_name),
            "url": f"{REPO_URLS.get(repo_name, '')}/{pick['number']}",
            "state": pick.get("state", ""),
            "priority": pick.get("priority", "active"),
            "ci": pick.get("ci", "unknown"),
            "reviews": reviews,
            "review_state": review_state,
            "notes": pick.get("notes", ""),
            "cherry_pick_of": "",
            "depends_on": [],
            "blocks": [],
            "is_marvin": True,
            "origin": pick.get("origin", ""),
        })

    return prs


def build_review_requests(data):
    """Build list of PRs where Casey is a requested reviewer."""
    items = []
    for rr in data.get("review_requests", []):
        repo_name = rr.get("repo", "")
        items.append({
            "number": rr["number"],
            "title": rr.get("title", ""),
            "repo": repo_name,
            "short_repo": short_repo(repo_name),
            "url": rr.get("url", f"{REPO_URLS.get(repo_name, '')}/{rr['number']}"),
            "author": rr.get("author", ""),
            "ci": rr.get("ci", "unknown"),
            "draft": rr.get("draft", False),
        })
    return items


def build_assigned_issues(data):
    """Build list of issues assigned to Casey."""
    items = []
    for issue in data.get("assigned_issues", []):
        repo_name = issue.get("repo", "")
        items.append({
            "number": issue["number"],
            "title": issue.get("title", ""),
            "repo": repo_name,
            "short_repo": short_repo(repo_name),
            "url": issue.get("url", f"{ISSUE_URLS.get(repo_name, '')}/{issue['number']}"),
            "labels": issue.get("labels", []),
        })
    return items


def generate_html(data):
    last_refreshed = data.get("last_refreshed", "unknown")
    prs = build_pr_list(data)
    review_requests = build_review_requests(data)
    assigned_issues = build_assigned_issues(data)
    prs_json = json.dumps(prs)
    rr_json = json.dumps(review_requests)
    issues_json = json.dumps(assigned_issues)

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PR Dashboard</title>
<style>
  :root {{
    --bg: #0d1117;
    --surface: #161b22;
    --surface-hover: #1c2128;
    --border: #30363d;
    --text: #e6edf3;
    --text-muted: #8b949e;
    --link: #58a6ff;
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    background: var(--bg);
    color: var(--text);
    padding: 20px;
    line-height: 1.4;
  }}
  a {{ color: var(--link); text-decoration: none; font-weight: 600; }}
  a:hover {{ text-decoration: underline; }}

  /* Header */
  .header {{
    display: flex;
    align-items: baseline;
    gap: 16px;
    margin-bottom: 16px;
    flex-wrap: wrap;
  }}
  .header h1 {{ font-size: 22px; }}
  .header .subtitle {{ color: var(--text-muted); font-size: 13px; }}

  /* Tabs */
  .tabs {{
    display: flex;
    gap: 2px;
    margin-bottom: 16px;
    border-bottom: 1px solid var(--border);
  }}
  .tab {{
    padding: 8px 16px;
    font-size: 14px;
    font-weight: 500;
    color: var(--text-muted);
    cursor: pointer;
    border: 1px solid transparent;
    border-bottom: none;
    border-radius: 6px 6px 0 0;
    background: transparent;
    transition: color 0.15s, background 0.15s;
    user-select: none;
    position: relative;
    bottom: -1px;
  }}
  .tab:hover {{
    color: var(--text);
    background: var(--surface);
  }}
  .tab.active {{
    color: var(--text);
    background: var(--bg);
    border-color: var(--border);
    border-bottom-color: var(--bg);
  }}
  .tab .tab-count {{
    font-size: 11px;
    font-weight: normal;
    color: var(--text-muted);
    background: var(--surface);
    padding: 1px 6px;
    border-radius: 10px;
    margin-left: 6px;
  }}
  .tab-panel {{
    display: none;
  }}
  .tab-panel.active {{
    display: block;
  }}

  /* Kanban board */
  .board {{
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 12px;
    margin-bottom: 24px;
    min-height: 200px;
  }}
  .column {{
    background: var(--surface);
    border: 2px solid var(--border);
    border-radius: 8px;
    display: flex;
    flex-direction: column;
    min-height: 200px;
    transition: border-color 0.15s;
  }}
  .column.drag-over {{
    border-color: var(--link);
    background: #161b2280;
  }}
  .column-header {{
    padding: 10px 12px;
    border-bottom: 1px solid var(--border);
    font-size: 13px;
    font-weight: 600;
    display: flex;
    justify-content: space-between;
    align-items: center;
    user-select: none;
  }}
  .column-header .count {{
    font-weight: normal;
    color: var(--text-muted);
    font-size: 12px;
  }}
  .column-cards {{
    flex: 1;
    padding: 8px;
    display: flex;
    flex-direction: column;
    gap: 6px;
    overflow-y: auto;
    min-height: 60px;
  }}

  /* PR cards */
  .card {{
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 8px 10px;
    cursor: grab;
    transition: border-color 0.15s, box-shadow 0.15s;
    font-size: 13px;
  }}
  .card:hover {{
    border-color: var(--text-muted);
  }}
  .card.dragging {{
    opacity: 0.4;
    cursor: grabbing;
  }}
  .card.changed {{
    border-color: var(--link);
    box-shadow: 0 0 0 1px var(--link);
  }}
  .card.no-drag {{
    cursor: default;
  }}
  .card-top {{
    display: flex;
    align-items: center;
    gap: 6px;
    margin-bottom: 4px;
  }}
  .card-top a {{ font-size: 12px; }}
  .card-repo {{ color: var(--text-muted); font-size: 11px; }}
  .card-title {{
    font-size: 13px;
    line-height: 1.3;
    margin-bottom: 6px;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }}
  .card-badges {{
    display: flex;
    gap: 4px;
    flex-wrap: wrap;
    align-items: center;
  }}
  .badge {{
    display: inline-block;
    padding: 1px 6px;
    border-radius: 10px;
    font-size: 11px;
    font-weight: 500;
    color: #fff;
    white-space: nowrap;
  }}
  .card-state {{
    background: transparent;
    border: 1px solid transparent;
    border-radius: 4px;
    padding: 1px 4px;
    font-size: 11px;
    font-weight: 500;
    cursor: pointer;
    appearance: none;
    -webkit-appearance: none;
    color: var(--text-muted);
  }}
  .card-state:hover {{
    border-color: var(--border);
    background: var(--surface);
  }}
  .card-state:focus {{
    outline: none;
    border-color: var(--link);
  }}
  .card-state option {{
    background: var(--surface);
    color: var(--text);
  }}
  .card-meta {{
    font-size: 11px;
    color: var(--text-muted);
    margin-top: 4px;
  }}
  .card-meta .cherry {{ color: #a371f7; }}
  .card-meta .review {{ color: #bf8700; }}
  .card-meta .review.approved {{ color: #2da44e; }}
  .marvin-tag {{
    background: #a371f7;
    color: #fff;
    font-size: 10px;
    padding: 0 4px;
    border-radius: 3px;
    font-weight: 600;
  }}
  .author-tag {{
    color: var(--text-muted);
    font-size: 11px;
    font-style: italic;
  }}
  .draft-tag {{
    background: #768390;
    color: #fff;
    font-size: 10px;
    padding: 0 4px;
    border-radius: 3px;
    font-weight: 600;
  }}

  /* Marvin section */
  .marvin-section {{
    margin-top: 8px;
  }}
  .marvin-section h2 {{
    font-size: 16px;
    color: #a371f7;
    margin-bottom: 8px;
    display: flex;
    align-items: center;
    gap: 8px;
  }}
  .marvin-section h2 .count {{
    font-size: 12px;
    color: var(--text-muted);
    font-weight: normal;
  }}
  .marvin-cards {{
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }}
  .marvin-cards .card {{
    width: 280px;
    cursor: default;
  }}

  /* List view for reviews and issues */
  .list-view {{
    display: flex;
    flex-direction: column;
    gap: 6px;
    max-width: 900px;
  }}
  .list-view .card {{
    cursor: default;
  }}
  .list-group {{
    margin-bottom: 20px;
  }}
  .list-group h3 {{
    font-size: 14px;
    color: var(--text-muted);
    margin-bottom: 8px;
    padding-bottom: 4px;
    border-bottom: 1px solid var(--border);
  }}
  .label-tag {{
    display: inline-block;
    padding: 0 6px;
    border-radius: 10px;
    font-size: 10px;
    font-weight: 500;
    color: #fff;
    background: var(--border);
    white-space: nowrap;
  }}
  .label-tag.bug {{ background: #cf222e; }}
  .label-tag.feature {{ background: #1f6feb; }}
  .label-tag.priority {{ background: #bf8700; }}
  .empty-state {{
    color: var(--text-muted);
    font-size: 14px;
    padding: 40px 20px;
    text-align: center;
    background: var(--surface);
    border-radius: 8px;
    border: 1px solid var(--border);
  }}

  /* Apply bar */
  #apply-bar {{
    display: none;
    position: fixed;
    bottom: 20px;
    left: 50%;
    transform: translateX(-50%);
    background: var(--surface);
    border: 1px solid var(--link);
    border-radius: 8px;
    padding: 10px 20px;
    align-items: center;
    gap: 14px;
    box-shadow: 0 4px 16px rgba(0,0,0,0.5);
    z-index: 100;
  }}
  #apply-bar .change-count {{ font-size: 13px; }}
  #apply-bar button {{
    border: none;
    border-radius: 6px;
    padding: 6px 14px;
    font-size: 13px;
    font-weight: 500;
    cursor: pointer;
  }}
  .apply-btn {{ background: #238636; color: #fff; }}
  .apply-btn:hover {{ background: #2ea043; }}
  .discard-btn {{
    background: transparent;
    color: var(--text-muted);
    border: 1px solid var(--border) !important;
  }}
  .discard-btn:hover {{ background: var(--bg); color: var(--text); }}

  /* Refresh button */
  .refresh-btn {{
    background: transparent;
    border: 1px solid var(--border);
    border-radius: 6px;
    color: var(--text-muted);
    padding: 4px 12px;
    font-size: 13px;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 6px;
    transition: color 0.15s, border-color 0.15s;
  }}
  .refresh-btn:hover {{
    color: var(--text);
    border-color: var(--text-muted);
  }}
  .refresh-btn.spinning svg {{
    animation: spin 0.8s linear infinite;
  }}
  @keyframes spin {{
    from {{ transform: rotate(0deg); }}
    to {{ transform: rotate(360deg); }}
  }}
</style>
</head>
<body>

<div class="header">
  <h1>PR Dashboard</h1>
  <span class="subtitle">Last refreshed: {last_refreshed}</span>
  <button class="refresh-btn" onclick="refreshDashboard(this)" title="Reload dashboard">
    <svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor">
      <path d="M8 3a5 5 0 1 0 4.546 2.914.5.5 0 1 1 .908-.418A6 6 0 1 1 8 2v1z"/>
      <path d="M8 4.466V.534a.25.25 0 0 1 .41-.192l2.36 1.966c.12.1.12.284 0 .384L8.41 4.658A.25.25 0 0 1 8 4.466z"/>
    </svg>
    Reload
  </button>
</div>

<div class="tabs" id="tabs">
  <div class="tab active" data-tab="my-prs" onclick="switchTab('my-prs')">
    My PRs <span class="tab-count" id="my-prs-count"></span>
  </div>
  <div class="tab" data-tab="review-requests" onclick="switchTab('review-requests')">
    Review Requests <span class="tab-count" id="review-requests-count"></span>
  </div>
  <div class="tab" data-tab="assigned-issues" onclick="switchTab('assigned-issues')">
    Assigned Issues <span class="tab-count" id="assigned-issues-count"></span>
  </div>
</div>

<div class="tab-panel active" id="panel-my-prs">
  <div class="board" id="board"></div>
  <div class="marvin-section" id="marvin-section"></div>
</div>

<div class="tab-panel" id="panel-review-requests">
  <div class="list-view" id="review-requests-list"></div>
</div>

<div class="tab-panel" id="panel-assigned-issues">
  <div class="list-view" id="assigned-issues-list"></div>
</div>

<div id="apply-bar">
  <span id="change-count" class="change-count"></span>
  <button class="apply-btn" onclick="downloadChanges()">Download Changes</button>
  <button class="discard-btn" onclick="discardChanges()">Discard</button>
</div>

<script>
const ALL_PRS = {prs_json};
const REVIEW_REQUESTS = {rr_json};
const ASSIGNED_ISSUES = {issues_json};

const PRIORITY_ORDER = ["active", "next-up", "backburner", "parked"];
const PRIORITY_LABELS = {{
  "active": "Active",
  "next-up": "Next Up",
  "backburner": "Backburner",
  "parked": "Parked",
}};
const PRIORITY_COLORS = {{
  "active": "#cf222e",
  "next-up": "#bf8700",
  "backburner": "#768390",
  "parked": "#484f58",
}};
const STATE_COLORS = {{
  "ready-for-review": "#2da44e",
  "reviewed-pending-updates": "#bf8700",
  "ready-to-merge": "#1f6feb",
  "draft": "#768390",
  "needs-work": "#cf222e",
}};
const CI_COLORS = {{
  "pass": "#2da44e",
  "fail": "#cf222e",
  "pending": "#bf8700",
  "unknown": "#768390",
}};

// Mutable priority map: prKey -> current priority (including drag changes)
const currentPriority = {{}};
ALL_PRS.forEach(pr => {{
  currentPriority[prKey(pr)] = pr.priority;
}});

// Track pending changes
const pendingChanges = {{}};

function prKey(pr) {{
  return `${{pr.short_repo}}#${{pr.number}}`;
}}

function markChanged(pr, field, value) {{
  const key = prKey(pr);
  if (!pendingChanges[key]) pendingChanges[key] = {{repo: pr.repo, number: pr.number}};
  if (value === pr[field]) {{
    delete pendingChanges[key][field];
    if (Object.keys(pendingChanges[key]).length <= 2) delete pendingChanges[key];
  }} else {{
    pendingChanges[key][field] = value;
  }}
  updateApplyBar();
}}

function updateApplyBar() {{
  const bar = document.getElementById("apply-bar");
  const count = Object.keys(pendingChanges).length;
  if (count > 0) {{
    bar.style.display = "flex";
    document.getElementById("change-count").textContent =
      count === 1 ? "1 PR changed" : `${{count}} PRs changed`;
  }} else {{
    bar.style.display = "none";
  }}
}}

function downloadChanges() {{
  const changes = Object.values(pendingChanges).map(c => {{
    const entry = {{repo: c.repo, number: c.number}};
    if (c.state) entry.state = c.state;
    if (c.priority) entry.priority = c.priority;
    if (c.notes !== undefined) entry.notes = c.notes;
    return entry;
  }});
  const blob = new Blob([JSON.stringify({{changes}}, null, 2)], {{type: "application/json"}});
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "pr_changes.json";
  a.click();
  URL.revokeObjectURL(a.href);
}}

function discardChanges() {{
  Object.keys(pendingChanges).forEach(k => delete pendingChanges[k]);
  ALL_PRS.forEach(pr => {{ currentPriority[prKey(pr)] = pr.priority; }});
  updateApplyBar();
  renderMyPrs();
}}

// --- Tab switching ---
function switchTab(tabId) {{
  document.querySelectorAll(".tab").forEach(t => t.classList.remove("active"));
  document.querySelectorAll(".tab-panel").forEach(p => p.classList.remove("active"));
  document.querySelector(`.tab[data-tab="${{tabId}}"]`).classList.add("active");
  document.getElementById(`panel-${{tabId}}`).classList.add("active");
}}

// --- Drag and drop ---
let draggedPrKey = null;

function handleDragStart(e) {{
  const card = e.target.closest(".card");
  if (!card) return;
  draggedPrKey = card.dataset.prkey;
  card.classList.add("dragging");
  e.dataTransfer.effectAllowed = "move";
  e.dataTransfer.setData("text/plain", draggedPrKey);
}}

function handleDragEnd(e) {{
  const card = e.target.closest(".card");
  if (card) card.classList.remove("dragging");
  document.querySelectorAll(".column.drag-over").forEach(c => c.classList.remove("drag-over"));
  draggedPrKey = null;
}}

function handleDragOver(e) {{
  e.preventDefault();
  e.dataTransfer.dropEffect = "move";
  const col = e.target.closest(".column");
  if (col) col.classList.add("drag-over");
}}

function handleDragLeave(e) {{
  const col = e.target.closest(".column");
  if (col && !col.contains(e.relatedTarget)) {{
    col.classList.remove("drag-over");
  }}
}}

function handleDrop(e) {{
  e.preventDefault();
  const col = e.target.closest(".column");
  if (!col) return;
  col.classList.remove("drag-over");
  const newPriority = col.dataset.priority;
  const key = e.dataTransfer.getData("text/plain");
  if (!key || !newPriority) return;

  const pr = ALL_PRS.find(p => prKey(p) === key);
  if (!pr) return;

  currentPriority[key] = newPriority;
  markChanged(pr, "priority", newPriority);
  renderMyPrs();
}}

// --- State change handler ---
function handleStateChange(el) {{
  const key = el.dataset.prkey;
  const pr = ALL_PRS.find(p => prKey(p) === key);
  if (!pr) return;
  el.style.color = STATE_COLORS[el.value] || "#768390";
  markChanged(pr, "state", el.value);
  const card = el.closest(".card");
  if (card) {{
    const k = prKey(pr);
    card.classList.toggle("changed", !!pendingChanges[k]);
  }}
}}

// --- Rendering: My PRs ---
function renderCard(pr) {{
  const key = prKey(pr);
  const isChanged = !!pendingChanges[key];
  const ciBg = CI_COLORS[pr.ci] || "#768390";
  const currentState = pendingChanges[key]?.state || pr.state;
  const stateColor = STATE_COLORS[currentState] || "#768390";

  const states = ["ready-for-review", "reviewed-pending-updates", "ready-to-merge", "draft", "needs-work"];
  const stateOpts = states.map(s =>
    `<option value="${{s}}" ${{s === currentState ? "selected" : ""}}>${{s}}</option>`
  ).join("");

  let meta = [];
  if (pr.reviews.length) {{
    const isApproved = pr.reviews.some(r => r.includes("APPROVED"));
    meta.push(`<span class="review ${{isApproved ? "approved" : ""}}">${{pr.reviews.join(", ")}}</span>`);
  }}
  if (pr.cherry_pick_of) meta.push(`<span class="cherry">cherry-pick of ${{pr.cherry_pick_of}}</span>`);
  if (pr.depends_on?.length) meta.push(`depends on: ${{pr.depends_on.join(", ")}}`);
  if (pr.blocks?.length) meta.push(`blocks: ${{pr.blocks.join(", ")}}`);
  if (pr.notes) meta.push(pr.notes);

  const marvinTag = pr.is_marvin ? `<span class="marvin-tag">MARVIN</span>` : "";
  const originTag = pr.origin ? `<span class="cherry">from ${{pr.origin}}</span>` : "";

  return `<div class="card ${{isChanged ? "changed" : ""}}" draggable="true"
    data-prkey="${{key}}"
    ondragstart="handleDragStart(event)"
    ondragend="handleDragEnd(event)">
    <div class="card-top">
      <a href="${{pr.url}}" target="_blank">#${{pr.number}}</a>
      <span class="card-repo">${{pr.short_repo}}</span>
      ${{marvinTag}}
    </div>
    <div class="card-title">${{pr.title}}</div>
    <div class="card-badges">
      <select class="card-state" style="color:${{stateColor}}"
        data-prkey="${{key}}" onchange="handleStateChange(this)">
        ${{stateOpts}}
      </select>
      <span class="badge" style="background:${{ciBg}}">CI:${{pr.ci}}</span>
    </div>
    ${{meta.length || originTag ? `<div class="card-meta">${{originTag}}${{meta.length ? (originTag ? "<br>" : "") + meta.join(" &middot; ") : ""}}</div>` : ""}}
  </div>`;
}}

function renderMyPrs() {{
  const board = document.getElementById("board");
  const regular = ALL_PRS.filter(pr => !pr.is_marvin);
  const marvin = ALL_PRS.filter(pr => pr.is_marvin);

  // Group by current priority
  const grouped = {{}};
  PRIORITY_ORDER.forEach(p => grouped[p] = []);
  regular.forEach(pr => {{
    const p = currentPriority[prKey(pr)] || pr.priority;
    if (grouped[p]) grouped[p].push(pr);
    else grouped["backburner"].push(pr);
  }});

  board.innerHTML = PRIORITY_ORDER.map(p => {{
    const color = PRIORITY_COLORS[p];
    const label = PRIORITY_LABELS[p];
    const cards = grouped[p].map(renderCard).join("");
    return `<div class="column" data-priority="${{p}}"
      ondragover="handleDragOver(event)"
      ondragleave="handleDragLeave(event)"
      ondrop="handleDrop(event)">
      <div class="column-header" style="color:${{color}}">
        ${{label}} <span class="count">${{grouped[p].length}}</span>
      </div>
      <div class="column-cards">${{cards}}</div>
    </div>`;
  }}).join("");

  // Marvin section
  const marvinSection = document.getElementById("marvin-section");
  if (marvin.length) {{
    marvinSection.innerHTML = `
      <h2>Marvin Cherry-picks <span class="count">(${{marvin.length}})</span></h2>
      <div class="marvin-cards">${{marvin.map(renderCard).join("")}}</div>`;
  }} else {{
    marvinSection.innerHTML = "";
  }}

  // Update tab count
  document.getElementById("my-prs-count").textContent = ALL_PRS.length;
}}

// --- Rendering: Review Requests ---
function renderReviewRequests() {{
  const list = document.getElementById("review-requests-list");
  document.getElementById("review-requests-count").textContent = REVIEW_REQUESTS.length;

  if (!REVIEW_REQUESTS.length) {{
    list.innerHTML = `<div class="empty-state">No pending review requests</div>`;
    return;
  }}

  // Group by repo
  const grouped = {{}};
  REVIEW_REQUESTS.forEach(rr => {{
    if (!grouped[rr.short_repo]) grouped[rr.short_repo] = [];
    grouped[rr.short_repo].push(rr);
  }});

  list.innerHTML = Object.entries(grouped).map(([repo, items]) => {{
    const cards = items.map(rr => {{
      const ciBg = CI_COLORS[rr.ci] || "#768390";
      const draftTag = rr.draft ? `<span class="draft-tag">DRAFT</span>` : "";
      return `<div class="card no-drag">
        <div class="card-top">
          <a href="${{rr.url}}" target="_blank">#${{rr.number}}</a>
          <span class="card-repo">${{rr.short_repo}}</span>
          ${{draftTag}}
        </div>
        <div class="card-title">${{rr.title}}</div>
        <div class="card-badges">
          <span class="author-tag">by ${{rr.author}}</span>
          <span class="badge" style="background:${{ciBg}}">CI:${{rr.ci}}</span>
        </div>
      </div>`;
    }}).join("");
    return `<div class="list-group"><h3>${{repo}} (${{items.length}})</h3>${{cards}}</div>`;
  }}).join("");
}}

// --- Rendering: Assigned Issues ---
function labelClass(label) {{
  const l = label.toLowerCase();
  if (l.includes("bug")) return "bug";
  if (l.includes("feature") || l.includes("enhancement")) return "feature";
  if (l.includes("priority")) return "priority";
  return "";
}}

function renderAssignedIssues() {{
  const list = document.getElementById("assigned-issues-list");
  document.getElementById("assigned-issues-count").textContent = ASSIGNED_ISSUES.length;

  if (!ASSIGNED_ISSUES.length) {{
    list.innerHTML = `<div class="empty-state">No assigned issues</div>`;
    return;
  }}

  // Group by repo
  const grouped = {{}};
  ASSIGNED_ISSUES.forEach(issue => {{
    if (!grouped[issue.short_repo]) grouped[issue.short_repo] = [];
    grouped[issue.short_repo].push(issue);
  }});

  list.innerHTML = Object.entries(grouped).map(([repo, items]) => {{
    const cards = items.map(issue => {{
      const labels = (issue.labels || []).map(l =>
        `<span class="label-tag ${{labelClass(l)}}">${{l}}</span>`
      ).join(" ");
      return `<div class="card no-drag">
        <div class="card-top">
          <a href="${{issue.url}}" target="_blank">#${{issue.number}}</a>
          <span class="card-repo">${{issue.short_repo}}</span>
        </div>
        <div class="card-title">${{issue.title}}</div>
        ${{labels ? `<div class="card-badges">${{labels}}</div>` : ""}}
      </div>`;
    }}).join("");
    return `<div class="list-group"><h3>${{repo}} (${{items.length}})</h3>${{cards}}</div>`;
  }}).join("");
}}

function refreshDashboard(btn) {{
  btn.classList.add("spinning");
  btn.disabled = true;
  location.reload();
}}

// Initial render
renderMyPrs();
renderReviewRequests();
renderAssignedIssues();
</script>
</body>
</html>"""


def main():
    yaml_path = os.path.expanduser(
        "~/.claude/projects/-home-casey-repos-gopath-src-github-com-projectcalico-calico/memory/pr_tracker.yaml"
    )
    output_path = "/tmp/pr-dashboard.html"

    if len(sys.argv) > 1:
        yaml_path = sys.argv[1]
    if len(sys.argv) > 2:
        output_path = sys.argv[2]

    with open(yaml_path) as f:
        data = yaml.safe_load(f)

    html = generate_html(data)

    with open(output_path, "w") as f:
        f.write(html)

    print(f"Dashboard written to {output_path}")


if __name__ == "__main__":
    main()
