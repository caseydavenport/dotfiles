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
		if err := gcsDownload(*gcsBucket, *yamlPath); err != nil {
			log.Printf("gcs: download failed: %v", err)
			gcsErr = err.Error()
		}
	}

	if _, err := os.Stat(*yamlPath); os.IsNotExist(err) {
		log.Fatalf("data file not found: %s", *yamlPath)
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
