package main

// TrackerData is the top-level structure stored in pr_tracker.yaml.
type TrackerData struct {
	LastRefreshed  string          `yaml:"last_refreshed" json:"last_refreshed"`
	Repos          []Repo          `yaml:"repos" json:"repos"`
	ReviewRequests []ReviewRequest `yaml:"review_requests" json:"review_requests"`
	AssignedIssues []AssignedIssue `yaml:"assigned_issues" json:"assigned_issues"`
}

// Repo groups PRs and marvin cherry-picks for a single GitHub repository.
type Repo struct {
	Name              string       `yaml:"name" json:"name"`
	PRs               []PR         `yaml:"prs" json:"prs"`
	MarvinCherryPicks []MarvinPick `yaml:"marvin_cherry_picks,omitempty" json:"marvin_cherry_picks,omitempty"`
}

// PR tracks a single pull request with both GitHub-derived and user-set metadata.
type PR struct {
	Number       int      `yaml:"number" json:"number"`
	Title        string   `yaml:"title" json:"title"`
	Branch       string   `yaml:"branch" json:"branch"`
	State        string   `yaml:"state" json:"state"`
	Priority     string   `yaml:"priority" json:"priority"`
	CI           string   `yaml:"ci" json:"ci"`
	Reviews      []string `yaml:"reviews" json:"reviews"`
	CherryPickOf string   `yaml:"cherry_pick_of" json:"cherry_pick_of"`
	DependsOn    []string `yaml:"depends_on" json:"depends_on"`
	Blocks       []string `yaml:"blocks" json:"blocks"`
	Notes        string   `yaml:"notes" json:"notes"`
}

// MarvinPick tracks an automated cherry-pick PR from marvin-tigera.
type MarvinPick struct {
	Number  int      `yaml:"number" json:"number"`
	Title   string   `yaml:"title" json:"title"`
	Base    string   `yaml:"base" json:"base"`
	OssPR   string   `yaml:"oss_pr" json:"oss_pr"`
	State   string   `yaml:"state,omitempty" json:"state,omitempty"`
	CI      string   `yaml:"ci,omitempty" json:"ci,omitempty"`
	Reviews []string `yaml:"reviews,omitempty" json:"reviews,omitempty"`
	Notes   string   `yaml:"notes,omitempty" json:"notes,omitempty"`
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
}

// PatchRequest is the request body for PATCH /api/prs.
type PatchRequest struct {
	Changes     []PRChange   `json:"changes"`
	ItemChanges []ItemChange `json:"item_changes,omitempty"`
}
