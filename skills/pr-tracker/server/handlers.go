package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"gopkg.in/yaml.v3"
)

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
	fileMu.Unlock()

	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, data)
}

// handlePatchPRs applies a set of changes (state, priority, notes) to PRs.
func handlePatchPRs(w http.ResponseWriter, r *http.Request) {
	var req PatchRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON: "+err.Error())
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

	if err := writeData(data); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, data)
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
				}
				if change.Notes != nil {
					pr.Notes = *change.Notes
				}
				return true
			}
		}
	}
	return false
}

// handleRefresh fetches fresh data from GitHub and returns the updated tracker data.
func handleRefresh(w http.ResponseWriter, r *http.Request) {
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

	fileMu.Lock()
	if err := writeData(refreshed); err != nil {
		fileMu.Unlock()
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	fileMu.Unlock()

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
