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

	// Build a set of Casey's calico OSS PR numbers so we can filter
	// cherry-picks to only those originating from Casey's PRs.
	caseyOSSPRs := map[string]bool{}
	for _, repo := range result.Repos {
		if repo.Name == "projectcalico/calico" {
			for _, pr := range repo.PRs {
				caseyOSSPRs[fmt.Sprintf("projectcalico/calico#%d", pr.Number)] = true
			}
		}
	}

	// Fetch cherry-picks (calico-private only). Promote relevant picks
	// (authored by Casey, or referencing Casey's OSS PRs with the
	// merge-oss-cherry-pick label) to full PRs in the calico-private
	// repo so they appear in "My PRs" with full CI/review/priority.
	picks, err := fetchCherryPicks()
	if err != nil {
		errs = append(errs, fmt.Errorf("cherry picks: %w", err))
	} else {
		for i := range result.Repos {
			if result.Repos[i].Name != "tigera/calico-private" {
				continue
			}
			// Build set of PR numbers already in the list to avoid duplicates.
			seen := map[int]bool{}
			for _, pr := range result.Repos[i].PRs {
				seen[pr.Number] = true
			}
			for _, pick := range picks {
				if seen[pick.Number] {
					continue
				}
				if pick.Author == "caseydavenport" || caseyOSSPRs[pick.OssPR] {
					// Casey authored the pick or the OSS PR is still open.
				} else if pick.OssPR != "" && isCaseyPR(pick.OssPR) {
					// OSS PR is merged but was authored by Casey.
				} else {
					continue
				}
				// Promote to a full PR with CI and reviews.
				ci := fetchCI("tigera/calico-private", pick.Number)
				reviews := fetchReviews("tigera/calico-private", pick.Number)
				state := deriveState(false, pick.ReviewDecision)
				pr := PR{
					Number:       pick.Number,
					Title:        pick.Title,
					Branch:       pick.Branch,
					State:        state,
					CI:           ci,
					Reviews:      reviews,
					CherryPickOf: pick.OssPR,
					CreatedAt:    pick.CreatedAt,
					Author:       pick.Author,
				}
				key := fmt.Sprintf("tigera/calico-private#%d", pick.Number)
				if old, ok := existingPRs[key]; ok {
					pr.Priority = old.Priority
					pr.Notes = old.Notes
					pr.DependsOn = old.DependsOn
					pr.Blocks = old.Blocks
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
					pr.Priority = "parked"
					if ci != "pending" {
						pr.CIHistory = []string{ci}
					}
				}
				result.Repos[i].PRs = append(result.Repos[i].PRs, pr)
			}
			// Cross-reference: set CherryPickOf on Casey's own PRs that
			// also appear in the cherry-pick list (e.g. Casey-authored
			// cherry-picks of his own OSS PRs).
			pickOSS := map[int]string{}
			for _, pick := range picks {
				if pick.OssPR != "" {
					pickOSS[pick.Number] = pick.OssPR
				}
			}
			for j := range result.Repos[i].PRs {
				if ref, ok := pickOSS[result.Repos[i].PRs[j].Number]; ok {
					result.Repos[i].PRs[j].CherryPickOf = ref
				}
			}
			break
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
		"--json", "number,title,isDraft,reviewDecision,labels,headRefName,baseRefName,createdAt", "--limit", "50")
	if err != nil {
		return nil, err
	}

	var raw []struct {
		Number         int    `json:"number"`
		Title          string `json:"title"`
		IsDraft        bool   `json:"isDraft"`
		ReviewDecision string `json:"reviewDecision"`
		HeadRefName    string `json:"headRefName"`
		CreatedAt      string `json:"createdAt"`
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
			Number:    r.Number,
			Title:     r.Title,
			Branch:    r.HeadRefName,
			State:     state,
			CI:        ci,
			Reviews:   reviews,
			CreatedAt: r.CreatedAt,
			Author:    "caseydavenport",
		}

		// Preserve user-set fields from existing data.
		key := fmt.Sprintf("%s#%d", repo, r.Number)
		if old, ok := existing[key]; ok {
			pr.Priority = old.Priority
			pr.Notes = old.Notes
			pr.DependsOn = old.DependsOn
			pr.Blocks = old.Blocks
			pr.CherryPickOf = old.CherryPickOf
			pr.Triaged = old.Triaged

			// Maintain CI history: skip "pending" entries, prepend
			// current status if it differs from the most recent, keep last 8.
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
			pr.Priority = "parked"
			if ci != "pending" {
				pr.CIHistory = []string{ci}
			}
			pr.Triaged = false
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

// isCaseyPR checks if a PR reference like "projectcalico/calico#12219"
// was authored by Casey. Used to identify merged OSS PRs that spawned
// cherry-picks.
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

func fetchCherryPicks() ([]CherryPick, error) {
	out, err := ghJSON("pr", "list", "--repo", "tigera/calico-private",
		"--state", "open", "--label", "merge-oss-cherry-pick",
		"--json", "number,title,body,baseRefName,headRefName,author,reviewDecision,createdAt", "--limit", "50")
	if err != nil {
		return nil, err
	}

	var raw []struct {
		Number         int    `json:"number"`
		Title          string `json:"title"`
		Body           string `json:"body"`
		BaseRefName    string `json:"baseRefName"`
		HeadRefName    string `json:"headRefName"`
		ReviewDecision string `json:"reviewDecision"`
		CreatedAt      string `json:"createdAt"`
		Author         struct {
			Login string `json:"login"`
		} `json:"author"`
	}
	if err := json.Unmarshal(out, &raw); err != nil {
		return nil, fmt.Errorf("parsing cherry picks: %w", err)
	}

	picks := make([]CherryPick, 0, len(raw))
	for _, r := range raw {
		ossPR := ""
		if m := ossPRPattern.FindStringSubmatch(r.Body); len(m) > 1 {
			ossPR = "projectcalico/calico#" + m[1]
		}
		picks = append(picks, CherryPick{
			Number:         r.Number,
			Title:          r.Title,
			Base:           r.BaseRefName,
			Branch:         r.HeadRefName,
			Author:         r.Author.Login,
			OssPR:          ossPR,
			ReviewDecision: r.ReviewDecision,
			CreatedAt:      r.CreatedAt,
		})
	}
	return picks, nil
}

func fetchReviewRequests() ([]ReviewRequest, error) {
	type rawPR struct {
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

	// Fetch both direct review requests and assigned PRs in parallel.
	var reviewRaw, assignedRaw []rawPR
	var reviewErr, assignedErr error
	var wg sync.WaitGroup

	wg.Add(2)
	go func() {
		defer wg.Done()
		out, err := ghJSON("search", "prs", "--state=open",
			"--json", "number,title,repository,url,author,isDraft",
			"--limit", "50", "--", "user-review-requested:caseydavenport")
		if err != nil {
			reviewErr = err
			return
		}
		reviewErr = json.Unmarshal(out, &reviewRaw)
	}()
	go func() {
		defer wg.Done()
		out, err := ghJSON("search", "prs", "--state=open",
			"--assignee=caseydavenport",
			"--json", "number,title,repository,url,author,isDraft",
			"--limit", "50")
		if err != nil {
			assignedErr = err
			return
		}
		assignedErr = json.Unmarshal(out, &assignedRaw)
	}()
	wg.Wait()

	if reviewErr != nil && assignedErr != nil {
		return nil, fmt.Errorf("review requests: %w; assigned: %w", reviewErr, assignedErr)
	}

	// Deduplicate by repo#number, preferring review-requested entries.
	seen := map[string]bool{}
	rrs := make([]ReviewRequest, 0, len(reviewRaw)+len(assignedRaw))

	for _, batch := range [][]rawPR{reviewRaw, assignedRaw} {
		for _, r := range batch {
			// Skip Casey's own PRs — they're already in "My PRs".
			if r.Author.Login == "caseydavenport" {
				continue
			}
			key := fmt.Sprintf("%s#%d", r.Repository.NameWithOwner, r.Number)
			if seen[key] {
				continue
			}
			seen[key] = true
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
	}

	if reviewErr != nil {
		log.Printf("warning: review requests fetch failed: %v", reviewErr)
	}
	if assignedErr != nil {
		log.Printf("warning: assigned PRs fetch failed: %v", assignedErr)
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
