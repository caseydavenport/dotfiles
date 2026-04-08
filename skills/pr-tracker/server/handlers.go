package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

// defaultGroups returns the initial set of groups when none exist in the YAML.
func defaultGroups() []Group {
	return []Group{
		{Name: "active", Color: "#cf222e"},
		{Name: "next-up", Color: "#bf8700"},
		{Name: "backburner", Color: "#768390"},
		{Name: "parked", Color: "#484f58"},
		{Name: "uncategorized", Color: "#6e7681"},
	}
}

// groupNames returns the set of valid group names.
func groupNames(groups []Group) map[string]bool {
	names := make(map[string]bool, len(groups))
	for _, g := range groups {
		names[g.Name] = true
	}
	return names
}

// ensureGroups seeds default groups if none exist and reassigns orphaned PRs.
func ensureGroups(data *TrackerData) {
	if len(data.Groups) == 0 {
		data.Groups = defaultGroups()
	}
	valid := groupNames(data.Groups)
	for i := range data.Repos {
		for j := range data.Repos[i].PRs {
			if !valid[data.Repos[i].PRs[j].Priority] {
				data.Repos[i].PRs[j].Priority = "uncategorized"
			}
		}
	}
}

func readData() (*TrackerData, error) {
	raw, err := os.ReadFile(*yamlPath)
	if err != nil {
		return nil, fmt.Errorf("reading %s: %w", *yamlPath, err)
	}
	var data TrackerData
	if err := yaml.Unmarshal(raw, &data); err != nil {
		return nil, fmt.Errorf("parsing %s: %w", *yamlPath, err)
	}
	return &data, nil
}

func writeData(data *TrackerData) error {
	raw, err := yaml.Marshal(data)
	if err != nil {
		return fmt.Errorf("marshaling yaml: %w", err)
	}
	if err := os.WriteFile(*yamlPath, raw, 0644); err != nil {
		return fmt.Errorf("writing %s: %w", *yamlPath, err)
	}
	return nil
}

// gcsUploadIfEnabled uploads the YAML to GCS if a bucket is configured.
// Updates gcsErr on failure, clears it on success.
func gcsUploadIfEnabled() {
	if *gcsBucket == "" {
		return
	}
	if err := gcsUpload(*yamlPath, *gcsBucket); err != nil {
		log.Printf("gcs: upload failed: %v", err)
		gcsErr = err.Error()
	} else if gcsErr != "" {
		log.Println("gcs: upload succeeded, clearing previous error")
		gcsErr = ""
	}
}

// gcsReadOnlyGuard returns true (and writes a 503 response) if GCS sync is in a failed state.
// Mutating handlers should call this before processing.
func gcsReadOnlyGuard(w http.ResponseWriter) bool {
	if gcsErr != "" {
		writeError(w, http.StatusServiceUnavailable,
			fmt.Sprintf("GCS sync unavailable: %s. Changes disabled until sync is restored.", gcsErr))
		return true
	}
	return false
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

// handleGetPRs returns the full tracker data as JSON.
func handleGetPRs(w http.ResponseWriter, r *http.Request) {
	fileMu.Lock()
	data, err := readData()
	if err != nil {
		fileMu.Unlock()
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if len(data.Groups) == 0 {
		ensureGroups(data)
		if writeErr := writeData(data); writeErr != nil {
			fileMu.Unlock()
			writeError(w, http.StatusInternalServerError, writeErr.Error())
			return
		}
		gcsUploadIfEnabled()
	}
	fileMu.Unlock()
	resp := struct {
		*TrackerData
		GCSError string `json:"gcs_error,omitempty"`
	}{
		TrackerData: data,
		GCSError:    gcsErr,
	}
	writeJSON(w, http.StatusOK, resp)
}

// handlePatchPRs applies a set of changes (state, priority, notes, triaged) to PRs.
func handlePatchPRs(w http.ResponseWriter, r *http.Request) {
	var req PatchRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON: "+err.Error())
		return
	}

	if gcsReadOnlyGuard(w) {
		return
	}

	fileMu.Lock()
	defer fileMu.Unlock()

	data, err := readData()
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	for _, change := range req.Changes {
		if !applyChange(data, change) {
			writeError(w, http.StatusNotFound, fmt.Sprintf("PR %s#%d not found", change.Repo, change.Number))
			return
		}
	}
	for _, ic := range req.ItemChanges {
		applyItemChange(data, ic)
	}

	if req.GroupChanges != nil {
		if errMsg := applyGroupChanges(data, req.GroupChanges); errMsg != "" {
			writeError(w, http.StatusBadRequest, errMsg)
			return
		}
	}

	if err := writeData(data); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	gcsUploadIfEnabled()
	if gcsErr != "" {
		writeError(w, http.StatusInternalServerError,
			fmt.Sprintf("changes saved locally but GCS sync failed: %s", gcsErr))
		return
	}

	writeJSON(w, http.StatusOK, data)
}

// applyGroupChanges validates and applies group mutations to the tracker data.
// Returns an error message if validation fails, empty string on success.
func applyGroupChanges(data *TrackerData, gc *GroupChanges) string {
	// Apply add.
	if gc.Add != nil {
		name := strings.TrimSpace(gc.Add.Name)
		if name == "" {
			return "group name cannot be empty"
		}
		for _, g := range data.Groups {
			if strings.EqualFold(g.Name, name) {
				return fmt.Sprintf("group %q already exists", name)
			}
		}
		pos := gc.Add.Position
		if pos < 0 {
			pos = 0
		}
		if pos > len(data.Groups) {
			pos = len(data.Groups)
		}
		newGroup := Group{Name: name, Color: gc.Add.Color}
		data.Groups = append(data.Groups[:pos], append([]Group{newGroup}, data.Groups[pos:]...)...)
	}

	// Apply remove.
	if gc.Remove != "" {
		if strings.EqualFold(gc.Remove, "uncategorized") {
			return "cannot delete the uncategorized group"
		}
		found := false
		for _, repo := range data.Repos {
			for _, pr := range repo.PRs {
				if pr.Priority == gc.Remove {
					return fmt.Sprintf("cannot delete group %q: it contains PRs", gc.Remove)
				}
			}
		}
		for i, g := range data.Groups {
			if g.Name == gc.Remove {
				data.Groups = append(data.Groups[:i], data.Groups[i+1:]...)
				found = true
				break
			}
		}
		if !found {
			return fmt.Sprintf("group %q not found", gc.Remove)
		}
	}

	// Apply reorder.
	if len(gc.Reorder) > 0 {
		if len(gc.Reorder) != len(data.Groups) {
			return fmt.Sprintf("reorder list has %d entries but there are %d groups", len(gc.Reorder), len(data.Groups))
		}
		byName := make(map[string]Group, len(data.Groups))
		for _, g := range data.Groups {
			byName[g.Name] = g
		}
		reordered := make([]Group, 0, len(gc.Reorder))
		for _, name := range gc.Reorder {
			g, ok := byName[name]
			if !ok {
				return fmt.Sprintf("reorder references unknown group %q", name)
			}
			reordered = append(reordered, g)
			delete(byName, name)
		}
		if len(byName) > 0 {
			missing := make([]string, 0, len(byName))
			for name := range byName {
				missing = append(missing, name)
			}
			return fmt.Sprintf("reorder is missing groups: %s", strings.Join(missing, ", "))
		}
		data.Groups = reordered
	}

	// Apply updates (collapsed state).
	for _, u := range gc.Updates {
		for i := range data.Groups {
			if data.Groups[i].Name == u.Name {
				if u.Collapsed != nil {
					data.Groups[i].Collapsed = *u.Collapsed
				}
				break
			}
		}
	}

	return ""
}

func applyItemChange(data *TrackerData, ic ItemChange) {
	if ic.Priority == nil {
		return
	}
	switch ic.Type {
	case "review_request":
		for i := range data.ReviewRequests {
			if data.ReviewRequests[i].Repo == ic.Repo && data.ReviewRequests[i].Number == ic.Number {
				data.ReviewRequests[i].Priority = *ic.Priority
				return
			}
		}
	case "assigned_issue":
		for i := range data.AssignedIssues {
			if data.AssignedIssues[i].Repo == ic.Repo && data.AssignedIssues[i].Number == ic.Number {
				data.AssignedIssues[i].Priority = *ic.Priority
				return
			}
		}
	}
}

func applyChange(data *TrackerData, change PRChange) bool {
	for i := range data.Repos {
		if data.Repos[i].Name != change.Repo {
			continue
		}
		for j := range data.Repos[i].PRs {
			if data.Repos[i].PRs[j].Number == change.Number {
				pr := &data.Repos[i].PRs[j]
				if change.State != nil {
					pr.State = *change.State
				}
				if change.Priority != nil {
					pr.Priority = *change.Priority
					pr.Triaged = true
				}
				if change.Notes != nil {
					pr.Notes = *change.Notes
				}
				if change.Triaged != nil {
					pr.Triaged = *change.Triaged
				}
				return true
			}
		}
	}
	return false
}

// handleRefresh fetches fresh data from GitHub and returns the updated tracker data.
func handleRefresh(w http.ResponseWriter, r *http.Request) {
	if gcsReadOnlyGuard(w) {
		return
	}

	log.Println("refresh: starting GitHub sync")

	fileMu.Lock()
	existing, err := readData()
	fileMu.Unlock()
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	// Run refresh outside the lock (slow network calls).
	refreshed, errs := refreshFromGitHub(existing)
	refreshed.LastRefreshed = time.Now().Format("2006-01-02T15:04:05-07:00")
	ensureGroups(refreshed)

	fileMu.Lock()
	if err := writeData(refreshed); err != nil {
		fileMu.Unlock()
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	fileMu.Unlock()

	gcsUploadIfEnabled()

	if len(errs) > 0 {
		log.Printf("refresh: completed with %d errors", len(errs))
		for _, e := range errs {
			log.Printf("  - %s", e)
		}
	} else {
		log.Println("refresh: completed successfully")
	}

	writeJSON(w, http.StatusOK, refreshed)
}

// handleGCSRetry re-attempts the GCS download and clears the error state on success.
func handleGCSRetry(w http.ResponseWriter, r *http.Request) {
	if *gcsBucket == "" {
		writeError(w, http.StatusBadRequest, "GCS sync is not configured")
		return
	}

	fileMu.Lock()
	defer fileMu.Unlock()

	if err := gcsDownload(*gcsBucket, *yamlPath); err != nil {
		gcsErr = err.Error()
		writeError(w, http.StatusServiceUnavailable,
			fmt.Sprintf("GCS sync still unavailable: %s", gcsErr))
		return
	}

	gcsErr = ""
	data, err := readData()
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	ensureGroups(data)
	writeJSON(w, http.StatusOK, data)
}
