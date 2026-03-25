package main

// TrackerData is the top-level structure stored in pr_tracker.yaml.
type TrackerData struct {
	LastRefreshed  string          `yaml:"last_refreshed" json:"last_refreshed"`
	Repos          []Repo          `yaml:"repos" json:"repos"`
	ReviewRequests []ReviewRequest `yaml:"review_requests" json:"review_requests"`
	AssignedIssues []AssignedIssue `yaml:"assigned_issues" json:"assigned_issues"`
}

// Repo groups PRs for a single GitHub repository.
type Repo struct {
	Name string `yaml:"name" json:"name"`
	PRs  []PR   `yaml:"prs" json:"prs"`
}

// PR tracks a single pull request with both GitHub-derived and user-set metadata.
type PR struct {
	Number       int      `yaml:"number" json:"number"`
	Title        string   `yaml:"title" json:"title"`
	Branch       string   `yaml:"branch" json:"branch"`
	State        string   `yaml:"state" json:"state"`
	Priority     string   `yaml:"priority" json:"priority"`
	CI           string   `yaml:"ci" json:"ci"`
	CIHistory    []string `yaml:"ci_history,omitempty" json:"ci_history,omitempty"`
	Reviews      []string `yaml:"reviews" json:"reviews"`
	CherryPickOf string   `yaml:"cherry_pick_of" json:"cherry_pick_of"`
	DependsOn    []string `yaml:"depends_on" json:"depends_on"`
	Blocks       []string `yaml:"blocks" json:"blocks"`
	Notes        string   `yaml:"notes" json:"notes"`
	CreatedAt    string   `yaml:"created_at,omitempty" json:"created_at,omitempty"`
	Author       string   `yaml:"author,omitempty" json:"author,omitempty"`
	Triaged      bool     `yaml:"triaged" json:"triaged"`
}

// CherryPick tracks an OSS-to-enterprise cherry-pick PR in calico-private.
// Used as an intermediate struct during refresh; relevant picks are promoted
// to full PR entries in the calico-private repo.
type CherryPick struct {
	Number         int    `yaml:"number" json:"number"`
	Title          string `yaml:"title" json:"title"`
	Base           string `yaml:"base" json:"base"`
	Branch         string `yaml:"branch" json:"branch"`
	Author         string `yaml:"author" json:"author"`
	OssPR          string `yaml:"oss_pr" json:"oss_pr"`
	ReviewDecision string `yaml:"-" json:"-"`
	CreatedAt      string `yaml:"-" json:"-"`
}

// ReviewRequest tracks a PR where Casey is a requested reviewer.
type ReviewRequest struct {
	Number   int    `yaml:"number" json:"number"`
	Title    string `yaml:"title" json:"title"`
	Repo     string `yaml:"repo" json:"repo"`
	URL      string `yaml:"url" json:"url"`
	Author   string `yaml:"author" json:"author"`
	CI       string `yaml:"ci" json:"ci"`
	Draft    bool   `yaml:"draft" json:"draft"`
	Priority string `yaml:"priority,omitempty" json:"priority,omitempty"`
}

// AssignedIssue tracks a GitHub issue assigned to Casey.
type AssignedIssue struct {
	Number   int      `yaml:"number" json:"number"`
	Title    string   `yaml:"title" json:"title"`
	Repo     string   `yaml:"repo" json:"repo"`
	URL      string   `yaml:"url" json:"url"`
	Labels   []string `yaml:"labels" json:"labels"`
	Priority string   `yaml:"priority,omitempty" json:"priority,omitempty"`
}

// ItemChange represents a priority update for a review request or assigned issue.
type ItemChange struct {
	Type     string  `json:"type"`
	Repo     string  `json:"repo"`
	Number   int     `json:"number"`
	Priority *string `json:"priority,omitempty"`
}

// PRChange represents a single PR update from the frontend.
type PRChange struct {
	Repo     string  `json:"repo"`
	Number   int     `json:"number"`
	State    *string `json:"state,omitempty"`
	Priority *string `json:"priority,omitempty"`
	Notes    *string `json:"notes,omitempty"`
	Triaged  *bool   `json:"triaged,omitempty"`
}

// PatchRequest is the request body for PATCH /api/prs.
type PatchRequest struct {
	Changes     []PRChange   `json:"changes"`
	ItemChanges []ItemChange `json:"item_changes,omitempty"`
}
