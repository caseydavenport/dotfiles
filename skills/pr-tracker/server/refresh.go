package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os/exec"
	"regexp"
	"strings"
	"sync"
)

var trackedRepos = []string{
	"projectcalico/calico",
	"tigera/calico-private",
	"tigera/operator",
}

// refreshFromGitHub fetches fresh PR data from GitHub, merging with existing
// user-set fields (priority, notes, depends_on, blocks). Returns the merged
// data and any non-fatal errors encountered.
func refreshFromGitHub(existing *TrackerData) (*TrackerData, []error) {
	var mu sync.Mutex
	var wg sync.WaitGroup
	var errs []error

	result := &TrackerData{
		Repos: make([]Repo, len(trackedRepos)),
	}
	for i, name := range trackedRepos {
		result.Repos[i].Name = name
	}

	// Build a lookup from existing data for preserving user-set fields.
	existingPRs := map[string]*PR{}
	for _, repo := range existing.Repos {
		for i := range repo.PRs {
			key := fmt.Sprintf("%s#%d", repo.Name, repo.PRs[i].Number)
			existingPRs[key] = &repo.PRs[i]
		}
	}

	// Fetch PRs for each repo in parallel.
	for i, repoName := range trackedRepos {
		wg.Add(1)
		go func(idx int, repo string) {
			defer wg.Done()
			prs, err := fetchRepoPRs(repo, existingPRs)
			mu.Lock()
			defer mu.Unlock()
			if err != nil {
				errs = append(errs, fmt.Errorf("%s: %w", repo, err))
				// Keep existing PRs for this repo on failure.
				for _, existing := range existing.Repos {
					if existing.Name == repo {
						result.Repos[idx].PRs = existing.PRs
						break
					}
				}
				return
			}
			result.Repos[idx].PRs = prs
		}(i, repoName)
	}
	wg.Wait()

	// Build a set of Casey's calico OSS PR numbers so we can filter marvin
	// cherry-picks to only those originating from Casey's PRs.
	caseyOSSPRs := map[string]bool{}
	for _, repo := range result.Repos {
		if repo.Name == "projectcalico/calico" {
			for _, pr := range repo.PRs {
				caseyOSSPRs[fmt.Sprintf("projectcalico/calico#%d", pr.Number)] = true
			}
		}
	}

	// Fetch marvin cherry-picks (calico-private only), filtered to Casey's PRs.
	picks, err := fetchMarvinPicks()
	if err != nil {
		errs = append(errs, fmt.Errorf("marvin picks: %w", err))
		// Preserve existing picks on failure.
		for _, repo := range existing.Repos {
			if repo.Name == "tigera/calico-private" {
				for i := range result.Repos {
					if result.Repos[i].Name == "tigera/calico-private" {
						result.Repos[i].MarvinCherryPicks = repo.MarvinCherryPicks
					}
				}
			}
		}
	} else {
		var caseyPicks []MarvinPick
		for _, pick := range picks {
			if caseyOSSPRs[pick.OssPR] {
				caseyPicks = append(caseyPicks, pick)
			}
		}
		for i := range result.Repos {
			if result.Repos[i].Name == "tigera/calico-private" {
				result.Repos[i].MarvinCherryPicks = caseyPicks
			}
		}
	}

	// Build lookups for preserving user-set priority on review requests and issues.
	existingRRPriority := map[string]string{}
	for _, rr := range existing.ReviewRequests {
		existingRRPriority[fmt.Sprintf("%s#%d", rr.Repo, rr.Number)] = rr.Priority
	}
	existingIssuePriority := map[string]string{}
	for _, issue := range existing.AssignedIssues {
		existingIssuePriority[fmt.Sprintf("%s#%d", issue.Repo, issue.Number)] = issue.Priority
	}

	// Fetch review requests.
	rrs, err := fetchReviewRequests()
	if err != nil {
		errs = append(errs, fmt.Errorf("review requests: %w", err))
		result.ReviewRequests = existing.ReviewRequests
	} else {
		for i := range rrs {
			key := fmt.Sprintf("%s#%d", rrs[i].Repo, rrs[i].Number)
			if p, ok := existingRRPriority[key]; ok {
				rrs[i].Priority = p
			}
		}
		result.ReviewRequests = rrs
	}

	// Fetch assigned issues.
	issues, err := fetchAssignedIssues()
	if err != nil {
		errs = append(errs, fmt.Errorf("assigned issues: %w", err))
		result.AssignedIssues = existing.AssignedIssues
	} else {
		for i := range issues {
			key := fmt.Sprintf("%s#%d", issues[i].Repo, issues[i].Number)
			if p, ok := existingIssuePriority[key]; ok {
				issues[i].Priority = p
			}
		}
		result.AssignedIssues = issues
	}

	return result, errs
}

func fetchRepoPRs(repo string, existing map[string]*PR) ([]PR, error) {
	out, err := ghJSON("pr", "list", "--repo", repo, "--author", "caseydavenport", "--state", "open",
		"--json", "number,title,isDraft,reviewDecision,labels,headRefName,baseRefName", "--limit", "50")
	if err != nil {
		return nil, err
	}

	var raw []struct {
		Number         int    `json:"number"`
		Title          string `json:"title"`
		IsDraft        bool   `json:"isDraft"`
		ReviewDecision string `json:"reviewDecision"`
		HeadRefName    string `json:"headRefName"`
		Labels         []struct {
			Name string `json:"name"`
		} `json:"labels"`
	}
	if err := json.Unmarshal(out, &raw); err != nil {
		return nil, fmt.Errorf("parsing PR list: %w", err)
	}

	prs := make([]PR, 0, len(raw))
	for _, r := range raw {
		state := deriveState(r.IsDraft, r.ReviewDecision)
		ci := fetchCI(repo, r.Number)
		reviews := fetchReviews(repo, r.Number)

		pr := PR{
			Number:  r.Number,
			Title:   r.Title,
			Branch:  r.HeadRefName,
			State:   state,
			CI:      ci,
			Reviews: reviews,
		}

		// Preserve user-set fields from existing data.
		key := fmt.Sprintf("%s#%d", repo, r.Number)
		if old, ok := existing[key]; ok {
			pr.Priority = old.Priority
			pr.Notes = old.Notes
			pr.DependsOn = old.DependsOn
			pr.Blocks = old.Blocks
			pr.CherryPickOf = old.CherryPickOf
		} else {
			pr.Priority = "parked"
		}

		prs = append(prs, pr)
	}
	return prs, nil
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

func fetchCI(repo string, number int) string {
	out, err := exec.Command("gh", "pr", "checks", fmt.Sprint(number), "--repo", repo).CombinedOutput()
	if err != nil && len(out) == 0 {
		return "unknown"
	}

	lines := strings.Split(string(out), "\n")
	hasFail, hasPass, hasPending := false, false, false
	for _, line := range lines {
		lower := strings.ToLower(line)
		if !strings.Contains(lower, "semaphore") && !strings.Contains(lower, "argo") {
			continue
		}
		if strings.Contains(lower, "fail") {
			hasFail = true
		} else if strings.Contains(lower, "pass") {
			hasPass = true
		} else if strings.Contains(lower, "pending") {
			hasPending = true
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

func fetchReviews(repo string, number int) []string {
	out, err := exec.Command("gh", "api", fmt.Sprintf("repos/%s/pulls/%d/reviews", repo, number)).CombinedOutput()
	if err != nil {
		return nil
	}

	var raw []struct {
		State string `json:"state"`
		User  struct {
			Login string `json:"login"`
		} `json:"user"`
	}
	if err := json.Unmarshal(out, &raw); err != nil {
		return nil
	}

	seen := map[string]bool{}
	var reviews []string
	for _, r := range raw {
		if r.State != "APPROVED" && r.State != "CHANGES_REQUESTED" {
			continue
		}
		entry := r.User.Login + ":" + r.State
		if !seen[entry] {
			seen[entry] = true
			reviews = append(reviews, entry)
		}
	}
	return reviews
}

var ossPRPattern = regexp.MustCompile(`projectcalico/calico#(\d+)`)

func fetchMarvinPicks() ([]MarvinPick, error) {
	out, err := ghJSON("pr", "list", "--repo", "tigera/calico-private", "--author", "marvin-tigera",
		"--state", "open", "--label", "merge-oss-cherry-pick",
		"--json", "number,title,body,baseRefName", "--limit", "20")
	if err != nil {
		return nil, err
	}

	var raw []struct {
		Number      int    `json:"number"`
		Title       string `json:"title"`
		Body        string `json:"body"`
		BaseRefName string `json:"baseRefName"`
	}
	if err := json.Unmarshal(out, &raw); err != nil {
		return nil, fmt.Errorf("parsing marvin picks: %w", err)
	}

	picks := make([]MarvinPick, 0, len(raw))
	for _, r := range raw {
		ossPR := ""
		if m := ossPRPattern.FindStringSubmatch(r.Body); len(m) > 1 {
			ossPR = "projectcalico/calico#" + m[1]
		}
		picks = append(picks, MarvinPick{
			Number: r.Number,
			Title:  r.Title,
			Base:   r.BaseRefName,
			OssPR:  ossPR,
		})
	}
	return picks, nil
}

func fetchReviewRequests() ([]ReviewRequest, error) {
	out, err := ghJSON("search", "prs", "--state=open",
		"--json", "number,title,repository,url,author,isDraft",
		"--limit", "50", "--", "user-review-requested:caseydavenport")
	if err != nil {
		return nil, err
	}

	var raw []struct {
		Number int    `json:"number"`
		Title  string `json:"title"`
		URL    string `json:"url"`
		Author struct {
			Login string `json:"login"`
		} `json:"author"`
		IsDraft    bool `json:"isDraft"`
		Repository struct {
			NameWithOwner string `json:"nameWithOwner"`
		} `json:"repository"`
	}
	if err := json.Unmarshal(out, &raw); err != nil {
		return nil, fmt.Errorf("parsing review requests: %w", err)
	}

	rrs := make([]ReviewRequest, 0, len(raw))
	for _, r := range raw {
		ci := fetchCI(r.Repository.NameWithOwner, r.Number)
		rrs = append(rrs, ReviewRequest{
			Number: r.Number,
			Title:  r.Title,
			Repo:   r.Repository.NameWithOwner,
			URL:    r.URL,
			Author: r.Author.Login,
			CI:     ci,
			Draft:  r.IsDraft,
		})
	}
	return rrs, nil
}

func fetchAssignedIssues() ([]AssignedIssue, error) {
	out, err := ghJSON("search", "issues", "--assignee=caseydavenport", "--state=open",
		"--json", "number,title,repository,url,labels", "--limit", "50")
	if err != nil {
		return nil, err
	}

	var raw []struct {
		Number int    `json:"number"`
		Title  string `json:"title"`
		URL    string `json:"url"`
		Labels []struct {
			Name string `json:"name"`
		} `json:"labels"`
		Repository struct {
			NameWithOwner string `json:"nameWithOwner"`
		} `json:"repository"`
	}
	if err := json.Unmarshal(out, &raw); err != nil {
		return nil, fmt.Errorf("parsing assigned issues: %w", err)
	}

	issues := make([]AssignedIssue, 0, len(raw))
	for _, r := range raw {
		labels := make([]string, len(r.Labels))
		for i, l := range r.Labels {
			labels[i] = l.Name
		}
		issues = append(issues, AssignedIssue{
			Number: r.Number,
			Title:  r.Title,
			Repo:   r.Repository.NameWithOwner,
			URL:    r.URL,
			Labels: labels,
		})
	}
	return issues, nil
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
