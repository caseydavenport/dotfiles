package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sync"
	"time"

	"gopkg.in/yaml.v3"
)

var (
	yamlPath  = flag.String("data", defaultYAMLPath(), "path to pr_tracker.yaml")
	port      = flag.Int("port", 48923, "HTTP server port")
	noBrowse  = flag.Bool("no-browse", false, "don't open browser on start")
	gcsBucket = flag.String("gcs-bucket", "", "GCS bucket for syncing tracker data (empty disables sync)")
)

// fileMu serializes reads and writes to the YAML file.
var fileMu sync.Mutex

// gcsErr tracks GCS sync failures. When non-empty, mutations are blocked.
var gcsErr string

// syncer is the async GCS upload manager. Nil when GCS is disabled.
var syncer *gcsSyncer

func defaultYAMLPath() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return "pr_tracker.yaml"
	}
	return filepath.Join(home, ".claude/projects/-home-casey-repos-gopath-src-github-com-projectcalico-calico/memory/pr_tracker.yaml")
}

func main() {
	flag.Parse()

	if *gcsBucket != "" {
		resolveGCSConflict(*gcsBucket, *yamlPath)
		syncer = newGCSSyncer(*gcsBucket, *yamlPath, 5*time.Second)
	}

	if _, err := os.Stat(*yamlPath); os.IsNotExist(err) {
		log.Printf("data file not found, creating empty tracker: %s", *yamlPath)
		if err := os.MkdirAll(filepath.Dir(*yamlPath), 0755); err != nil {
			log.Fatalf("failed to create data directory: %v", err)
		}
		empty := &TrackerData{}
		ensureGroups(empty)
		raw, err := yaml.Marshal(empty)
		if err != nil {
			log.Fatalf("failed to marshal default data: %v", err)
		}
		if err := os.WriteFile(*yamlPath, raw, 0644); err != nil {
			log.Fatalf("failed to write default data file: %v", err)
		}
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/api/prs", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			handleGetPRs(w, r)
		case http.MethodPatch:
			handlePatchPRs(w, r)
		default:
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})
	mux.HandleFunc("/api/refresh", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		handleRefresh(w, r)
	})
	mux.HandleFunc("/api/gcs-retry", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		handleGCSRetry(w, r)
	})
	mux.HandleFunc("/api/gcs-status", func(w http.ResponseWriter, r *http.Request) {
		status := gcsDisabled
		if syncer != nil {
			status = syncer.status()
		}
		writeJSON(w, http.StatusOK, map[string]string{"status": status})
	})
	mux.HandleFunc("/", handleDashboard)

	listenAddr := "127.0.0.1"
	if os.Getenv("LISTEN_ALL") != "" {
		listenAddr = "0.0.0.0"
	}
	addr := fmt.Sprintf("%s:%d", listenAddr, *port)
	url := fmt.Sprintf("http://%s", addr)

	if !*noBrowse {
		openBrowser(url)
	}

	log.Printf("PR dashboard server listening on %s (data: %s)", url, *yamlPath)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatal(err)
	}
}

// resolveGCSConflict compares local and GCS versions on startup and uses the
// higher-versioned copy. If local is newer (e.g., crash before upload), it
// gets pushed to GCS. If GCS is newer (e.g., another machine synced), it
// overwrites the local file.
func resolveGCSConflict(bucket, localPath string) {
	gcsVersion, tmpPath, err := gcsDownloadVersion(bucket)
	if err != nil {
		log.Printf("gcs: failed to download for version check: %v", err)
		gcsErr = err.Error()
		return
	}

	// GCS object doesn't exist yet.
	if gcsVersion < 0 {
		log.Printf("gcs: no remote data yet")
		if tmpPath != "" {
			os.Remove(tmpPath)
		}
		return
	}
	defer os.Remove(tmpPath)

	// Read local version.
	localVersion := -1
	if raw, err := os.ReadFile(localPath); err == nil {
		var data TrackerData
		if err := yaml.Unmarshal(raw, &data); err == nil {
			localVersion = data.Version
		}
	}

	log.Printf("gcs: local version=%d, remote version=%d", localVersion, gcsVersion)

	if localVersion > gcsVersion {
		// Local is newer (crash recovery). Push local to GCS.
		log.Printf("gcs: local is newer, pushing to GCS")
		if err := gcsUpload(localPath, bucket); err != nil {
			log.Printf("gcs: push failed: %v", err)
			gcsErr = err.Error()
		}
	} else {
		// GCS is newer or equal. Use the downloaded copy.
		log.Printf("gcs: using remote copy")
		if err := os.MkdirAll(filepath.Dir(localPath), 0755); err != nil {
			log.Printf("gcs: failed to create data directory: %v", err)
			gcsErr = err.Error()
			return
		}
		if err := os.Rename(tmpPath, localPath); err != nil {
			// Rename can fail across filesystems; fall back to copy.
			src, readErr := os.ReadFile(tmpPath)
			if readErr != nil {
				log.Printf("gcs: failed to read temp file: %v", readErr)
				gcsErr = readErr.Error()
				return
			}
			if writeErr := os.WriteFile(localPath, src, 0644); writeErr != nil {
				log.Printf("gcs: failed to write local file: %v", writeErr)
				gcsErr = writeErr.Error()
				return
			}
		}
	}
}

func openBrowser(url string) {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "linux":
		cmd = exec.Command("xdg-open", url)
	case "darwin":
		cmd = exec.Command("open", url)
	default:
		return
	}
	cmd.Start()
}
