package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os/exec"
	"regexp"
	"strings"
)

var trackedRepos = []string{
	"projectcalico/calico",
	"tigera/calico-private",
	"tigera/operator",
}

var trackedRepoSet = map[string]bool{
	"projectcalico/calico":  true,
	"tigera/calico-private": true,
	"tigera/operator":       true,
}

// refreshQuery fetches all dashboard data in a single GraphQL call:
// Casey's open PRs (with CI + reviews), cherry picks, review requests,
// assigned PRs, and assigned issues.
const refreshQuery = `
query {
  myPRs: search(query: "author:caseydavenport is:pr is:open", type: ISSUE, first: 50) {
    nodes {
      ... on PullRequest {
        number title isDraft reviewDecision headRefName baseRefName createdAt
        author { login }
        repository { nameWithOwner }
        labels(first: 10) { nodes { name } }
        commits(last: 1) { nodes { commit { statusCheckRollup {
          contexts(first: 100) { nodes {
            __typename
            ... on CheckRun { name conclusion status }
            ... on StatusContext { context state }
          }}
        }}}}
        reviews(first: 20) { nodes { state author { login } } }
      }
    }
  }
  cherryPicks: search(query: "repo:tigera/calico-private is:pr is:open label:merge-oss-cherry-pick", type: ISSUE, first: 50) {
    nodes {
      ... on PullRequest {
        number title body isDraft reviewDecision headRefName baseRefName createdAt
        author { login }
        repository { nameWithOwner }
        labels(first: 10) { nodes { name } }
        commits(last: 1) { nodes { commit { statusCheckRollup {
          contexts(first: 100) { nodes {
            __typename
            ... on CheckRun { name conclusion status }
            ... on StatusContext { context state }
          }}
        }}}}
        reviews(first: 20) { nodes { state author { login } } }
      }
    }
  }
  reviewRequested: search(query: "review-requested:caseydavenport is:pr is:open", type: ISSUE, first: 50) {
    nodes {
      ... on PullRequest {
        number title url isDraft
        author { login }
        repository { nameWithOwner }
        commits(last: 1) { nodes { commit { statusCheckRollup {
          contexts(first: 100) { nodes {
            __typename
            ... on CheckRun { name conclusion status }
            ... on StatusContext { context state }
          }}
        }}}}
      }
    }
  }
  assignedPRs: search(query: "assignee:caseydavenport is:pr is:open -author:caseydavenport", type: ISSUE, first: 50) {
    nodes {
      ... on PullRequest {
        number title url isDraft
        author { login }
        repository { nameWithOwner }
        commits(last: 1) { nodes { commit { statusCheckRollup {
          contexts(first: 100) { nodes {
            __typename
            ... on CheckRun { name conclusion status }
            ... on StatusContext { context state }
          }}
        }}}}
      }
    }
  }
  assignedIssues: search(query: "assignee:caseydavenport is:issue is:open", type: ISSUE, first: 50) {
    nodes {
      ... on Issue {
        number title url
        repository { nameWithOwner }
        labels(first: 10) { nodes { name } }
      }
    }
  }
}
`

// GraphQL response types.
type gqlResponse struct {
	Data struct {
		MyPRs           struct{ Nodes []gqlPR }    `json:"myPRs"`
		CherryPicks     struct{ Nodes []gqlPR }    `json:"cherryPicks"`
		ReviewRequested struct{ Nodes []gqlPR }    `json:"reviewRequested"`
		AssignedPRs     struct{ Nodes []gqlPR }    `json:"assignedPRs"`
		AssignedIssues  struct{ Nodes []gqlIssue } `json:"assignedIssues"`
	} `json:"data"`
	Errors []struct {
		Message string `json:"message"`
	} `json:"errors"`
}

type gqlPR struct {
	Number         int    `json:"number"`
	Title          string `json:"title"`
	Body           string `json:"body"`
	URL            string `json:"url"`
	IsDraft        bool   `json:"isDraft"`
	ReviewDecision string `json:"reviewDecision"`
	HeadRefName    string `json:"headRefName"`
	BaseRefName    string `json:"baseRefName"`
	CreatedAt      string `json:"createdAt"`

	Author     struct{ Login string } `json:"author"`
	Repository struct{ NameWithOwner string } `json:"repository"`

	Labels struct {
		Nodes []struct{ Name string } `json:"nodes"`
	} `json:"labels"`

	Commits struct {
		Nodes []struct {
			Commit struct {
				StatusCheckRollup *struct {
					Contexts struct {
						Nodes []gqlCheckContext `json:"nodes"`
					} `json:"contexts"`
				} `json:"statusCheckRollup"`
			} `json:"commit"`
		} `json:"nodes"`
	} `json:"commits"`

	Reviews struct {
		Nodes []struct {
			State  string                `json:"state"`
			Author struct{ Login string } `json:"author"`
		} `json:"nodes"`
	} `json:"reviews"`
}

type gqlCheckContext struct {
	TypeName   string `json:"__typename"`
	Name       string `json:"name"`
	Conclusion string `json:"conclusion"`
	Status     string `json:"status"`
	Context    string `json:"context"`
	State      string `json:"state"`
}

type gqlIssue struct {
	Number int    `json:"number"`
	Title  string `json:"title"`
	URL    string `json:"url"`

	Repository struct{ NameWithOwner string } `json:"repository"`

	Labels struct {
		Nodes []struct{ Name string } `json:"nodes"`
	} `json:"labels"`
}

// refreshFromGitHub fetches fresh PR data from GitHub via a single GraphQL
// query, merging with existing user-set fields (priority, notes, etc.).
func refreshFromGitHub(existing *TrackerData) (*TrackerData, []error) {
	var errs []error

	resp, err := executeRefreshQuery()
	if err != nil {
		errs = append(errs, fmt.Errorf("graphql query: %w", err))
		return existing, errs
	}
	for _, e := range resp.Errors {
		errs = append(errs, fmt.Errorf("graphql: %s", e.Message))
	}

	// Build lookup from existing data for preserving user-set fields.
	existingPRs := map[string]*PR{}
	for _, repo := range existing.Repos {
		for i := range repo.PRs {
			key := fmt.Sprintf("%s#%d", repo.Name, repo.PRs[i].Number)
			existingPRs[key] = &repo.PRs[i]
		}
	}

	result := &TrackerData{
		Repos: make([]Repo, len(trackedRepos)),
	}
	for i, name := range trackedRepos {
		result.Repos[i].Name = name
	}

	// Process Casey's open PRs, grouped by tracked repo.
	for _, gpr := range resp.Data.MyPRs.Nodes {
		repo := gpr.Repository.NameWithOwner
		if !trackedRepoSet[repo] {
			continue
		}
		pr := convertPR(gpr, repo, existingPRs)
		for i := range result.Repos {
			if result.Repos[i].Name == repo {
				result.Repos[i].PRs = append(result.Repos[i].PRs, pr)
				break
			}
		}
	}

	// Build set of Casey's open calico OSS PR numbers for cherry-pick filtering.
	caseyOSSPRs := map[string]bool{}
	for _, repo := range result.Repos {
		if repo.Name == "projectcalico/calico" {
			for _, pr := range repo.PRs {
				caseyOSSPRs[fmt.Sprintf("projectcalico/calico#%d", pr.Number)] = true
			}
		}
	}

	// Process cherry picks into the calico-private repo.
	cpIdx := -1
	for i := range result.Repos {
		if result.Repos[i].Name == "tigera/calico-private" {
			cpIdx = i
			break
		}
	}
	if cpIdx >= 0 {
		seen := map[int]bool{}
		for _, pr := range result.Repos[cpIdx].PRs {
			seen[pr.Number] = true
		}

		pickOSS := map[int]string{}
		for _, gpr := range resp.Data.CherryPicks.Nodes {
			ossPR := ""
			if m := ossPRPattern.FindStringSubmatch(gpr.Body); len(m) > 1 {
				ossPR = "projectcalico/calico#" + m[1]
			}
			pickOSS[gpr.Number] = ossPR

			if seen[gpr.Number] {
				for j := range result.Repos[cpIdx].PRs {
					if result.Repos[cpIdx].PRs[j].Number == gpr.Number {
						result.Repos[cpIdx].PRs[j].CherryPickOf = ossPR
						break
					}
				}
				continue
			}

			author := gpr.Author.Login
			include := author == "caseydavenport" || caseyOSSPRs[ossPR]
			if !include && ossPR != "" {
				include = isCaseyPR(ossPR)
			}
			if !include {
				continue
			}

			pr := convertPR(gpr, "tigera/calico-private", existingPRs)
			pr.CherryPickOf = ossPR
			pr.Author = author
			result.Repos[cpIdx].PRs = append(result.Repos[cpIdx].PRs, pr)
			seen[gpr.Number] = true
		}

		// Cross-reference CherryPickOf on Casey's own PRs.
		for j := range result.Repos[cpIdx].PRs {
			if ref, ok := pickOSS[result.Repos[cpIdx].PRs[j].Number]; ok && ref != "" {
				result.Repos[cpIdx].PRs[j].CherryPickOf = ref
			}
		}
	}

	result.Groups = existing.Groups

	// Process review requests (union of review-requested + assigned PRs).
	existingRRPriority := map[string]string{}
	for _, rr := range existing.ReviewRequests {
		existingRRPriority[fmt.Sprintf("%s#%d", rr.Repo, rr.Number)] = rr.Priority
	}

	rrSeen := map[string]bool{}
	var rrs []ReviewRequest
	for _, batch := range [][]gqlPR{resp.Data.ReviewRequested.Nodes, resp.Data.AssignedPRs.Nodes} {
		for _, gpr := range batch {
			if gpr.Author.Login == "caseydavenport" {
				continue
			}
			repo := gpr.Repository.NameWithOwner
			key := fmt.Sprintf("%s#%d", repo, gpr.Number)
			if rrSeen[key] {
				continue
			}
			rrSeen[key] = true

			rr := ReviewRequest{
				Number: gpr.Number,
				Title:  gpr.Title,
				Repo:   repo,
				URL:    gpr.URL,
				Author: gpr.Author.Login,
				CI:     deriveCI(gpr),
				Draft:  gpr.IsDraft,
			}
			if p, ok := existingRRPriority[key]; ok {
				rr.Priority = p
			}
			rrs = append(rrs, rr)
		}
	}
	result.ReviewRequests = rrs

	// Process assigned issues.
	existingIssuePriority := map[string]string{}
	for _, issue := range existing.AssignedIssues {
		existingIssuePriority[fmt.Sprintf("%s#%d", issue.Repo, issue.Number)] = issue.Priority
	}

	var issues []AssignedIssue
	for _, gi := range resp.Data.AssignedIssues.Nodes {
		repo := gi.Repository.NameWithOwner
		labels := make([]string, len(gi.Labels.Nodes))
		for i, l := range gi.Labels.Nodes {
			labels[i] = l.Name
		}
		issue := AssignedIssue{
			Number: gi.Number,
			Title:  gi.Title,
			Repo:   repo,
			URL:    gi.URL,
			Labels: labels,
		}
		key := fmt.Sprintf("%s#%d", repo, gi.Number)
		if p, ok := existingIssuePriority[key]; ok {
			issue.Priority = p
		}
		issues = append(issues, issue)
	}
	result.AssignedIssues = issues

	return result, errs
}

func executeRefreshQuery() (*gqlResponse, error) {
	cmd := exec.Command("gh", "api", "graphql", "-f", "query="+refreshQuery)
	out, err := cmd.Output()
	if err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return nil, fmt.Errorf("gh api graphql: %s: %w", string(ee.Stderr), err)
		}
		return nil, fmt.Errorf("gh api graphql: %w", err)
	}

	var resp gqlResponse
	if err := json.Unmarshal(out, &resp); err != nil {
		return nil, fmt.Errorf("parsing graphql response: %w", err)
	}
	return &resp, nil
}

// convertPR maps a GraphQL PR node to our PR model, preserving user-set
// fields from existing data.
func convertPR(gpr gqlPR, repo string, existing map[string]*PR) PR {
	state := deriveState(gpr.IsDraft, gpr.ReviewDecision)
	ci := deriveCI(gpr)
	reviews := deriveReviews(gpr)

	pr := PR{
		Number:    gpr.Number,
		Title:     gpr.Title,
		Branch:    gpr.HeadRefName,
		State:     state,
		CI:        ci,
		Reviews:   reviews,
		CreatedAt: gpr.CreatedAt,
		Author:    gpr.Author.Login,
	}

	key := fmt.Sprintf("%s#%d", repo, gpr.Number)
	if old, ok := existing[key]; ok {
		pr.Priority = old.Priority
		pr.Notes = old.Notes
		pr.DependsOn = old.DependsOn
		pr.Blocks = old.Blocks
		pr.CherryPickOf = old.CherryPickOf
		pr.Triaged = old.Triaged

		history := old.CIHistory
		if ci != "pending" {
			if len(history) == 0 || history[0] != ci {
				history = append([]string{ci}, history...)
			}
			if len(history) > 8 {
				history = history[:8]
			}
		}
		pr.CIHistory = history
	} else {
		pr.Priority = "uncategorized"
		if ci != "pending" {
			pr.CIHistory = []string{ci}
		}
	}

	return pr
}

// deriveCI extracts CI status from the GraphQL statusCheckRollup, filtering
// for Semaphore and Argo checks only.
func deriveCI(gpr gqlPR) string {
	if len(gpr.Commits.Nodes) == 0 {
		return "unknown"
	}
	rollup := gpr.Commits.Nodes[0].Commit.StatusCheckRollup
	if rollup == nil {
		return "unknown"
	}

	hasFail, hasPass, hasPending := false, false, false
	for _, ctx := range rollup.Contexts.Nodes {
		name := strings.ToLower(ctx.Name + ctx.Context)
		if !strings.Contains(name, "semaphore") && !strings.Contains(name, "argo") {
			continue
		}

		switch ctx.TypeName {
		case "CheckRun":
			if ctx.Status != "COMPLETED" {
				hasPending = true
			} else {
				switch ctx.Conclusion {
				case "SUCCESS":
					hasPass = true
				default:
					hasFail = true
				}
			}
		case "StatusContext":
			switch ctx.State {
			case "SUCCESS":
				hasPass = true
			case "PENDING":
				hasPending = true
			default:
				hasFail = true
			}
		}
	}

	switch {
	case hasFail:
		return "fail"
	case hasPending:
		return "pending"
	case hasPass:
		return "pass"
	default:
		return "unknown"
	}
}

// deriveReviews extracts reviewer verdicts from the GraphQL reviews list.
func deriveReviews(gpr gqlPR) []string {
	seen := map[string]bool{}
	var reviews []string
	for _, r := range gpr.Reviews.Nodes {
		if r.State != "APPROVED" && r.State != "CHANGES_REQUESTED" {
			continue
		}
		entry := r.Author.Login + ":" + r.State
		if !seen[entry] {
			seen[entry] = true
			reviews = append(reviews, entry)
		}
	}
	return reviews
}

func deriveState(isDraft bool, reviewDecision string) string {
	if isDraft {
		return "draft"
	}
	switch reviewDecision {
	case "CHANGES_REQUESTED":
		return "reviewed"
	case "APPROVED":
		return "mergeable"
	default:
		return "needs-review"
	}
}

var ossPRPattern = regexp.MustCompile(`projectcalico/calico#(\d+)`)

// isCaseyPR checks if a PR reference like "projectcalico/calico#12219"
// was authored by Casey. Used for cherry picks whose OSS PR is already merged.
func isCaseyPR(prRef string) bool {
	m := ossPRPattern.FindStringSubmatch(prRef)
	if len(m) < 2 {
		return false
	}
	out, err := ghJSON("pr", "view", m[1], "--repo", "projectcalico/calico", "--json", "author")
	if err != nil {
		return false
	}
	var data struct {
		Author struct {
			Login string `json:"login"`
		} `json:"author"`
	}
	if err := json.Unmarshal(out, &data); err != nil {
		return false
	}
	return data.Author.Login == "caseydavenport"
}

// ghJSON runs a gh CLI command and returns stdout bytes.
func ghJSON(args ...string) ([]byte, error) {
	cmd := exec.Command("gh", args...)
	out, err := cmd.Output()
	if err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			log.Printf("gh %s: %s", strings.Join(args[:2], " "), string(ee.Stderr))
		}
		return nil, fmt.Errorf("gh %s: %w", strings.Join(args[:2], " "), err)
	}
	return out, nil
}
