package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"

	"gopkg.in/yaml.v3"
)

// gcsURI returns the full GCS URI for the tracker data file.
func gcsURI(bucket string) string {
	return fmt.Sprintf("gs://%s/casey/pr-tracker/data.yaml", bucket)
}

// gcsDownload copies the tracker data from GCS to the local file.
// Returns nil if the object does not exist (first use).
func gcsDownload(bucket, localPath string) error {
	uri := gcsURI(bucket)
	log.Printf("gcs: downloading %s to %s", uri, localPath)
	cmd := exec.Command("gcloud", "storage", "cp", uri, localPath)
	out, err := cmd.CombinedOutput()
	if err != nil {
		outStr := string(out)
		// Object-not-found patterns from gcloud storage cp.
		if strings.Contains(outStr, "NotFound") || strings.Contains(outStr, "No URLs matched") || strings.Contains(outStr, "matched no objects") {
			log.Printf("gcs: object does not exist yet, will upload on first write")
			return nil
		}
		return fmt.Errorf("gcloud storage cp download failed: %s: %w", strings.TrimSpace(outStr), err)
	}
	log.Printf("gcs: download complete")
	return nil
}

// gcsUpload copies the local tracker data file to GCS.
func gcsUpload(localPath, bucket string) error {
	uri := gcsURI(bucket)
	log.Printf("gcs: uploading %s to %s", localPath, uri)
	cmd := exec.Command("gcloud", "storage", "cp", localPath, uri)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("gcloud storage cp upload failed: %s: %w", strings.TrimSpace(string(out)), err)
	}
	log.Printf("gcs: upload complete")
	return nil
}

// gcsDownloadVersion downloads the GCS copy to a temp file and returns its version.
// Returns -1 if the object does not exist.
func gcsDownloadVersion(bucket string) (int, string, error) {
	tmp, err := os.CreateTemp("", "pr-tracker-gcs-*.yaml")
	if err != nil {
		return 0, "", fmt.Errorf("creating temp file: %w", err)
	}
	tmpPath := tmp.Name()
	tmp.Close()

	uri := gcsURI(bucket)
	cmd := exec.Command("gcloud", "storage", "cp", uri, tmpPath)
	out, err := cmd.CombinedOutput()
	if err != nil {
		os.Remove(tmpPath)
		outStr := string(out)
		if strings.Contains(outStr, "NotFound") || strings.Contains(outStr, "No URLs matched") || strings.Contains(outStr, "matched no objects") {
			return -1, "", nil
		}
		return 0, "", fmt.Errorf("gcloud storage cp download failed: %s: %w", strings.TrimSpace(outStr), err)
	}

	raw, err := os.ReadFile(tmpPath)
	if err != nil {
		os.Remove(tmpPath)
		return 0, "", fmt.Errorf("reading temp file: %w", err)
	}

	var data TrackerData
	if err := yaml.Unmarshal(raw, &data); err != nil {
		os.Remove(tmpPath)
		return 0, "", fmt.Errorf("parsing GCS data: %w", err)
	}

	return data.Version, tmpPath, nil
}

// Sync states returned by gcsSyncer.status().
const (
	gcsSynced    = "synced"
	gcsPending   = "pending"
	gcsUploading = "uploading"
	gcsError     = "error"
	gcsDisabled  = "disabled"
)

// gcsSyncer manages debounced async uploads to GCS.
type gcsSyncer struct {
	bucket    string
	localPath string

	mu        sync.Mutex
	dirty     bool
	uploading bool
	timer     *time.Timer
	debounce  time.Duration
}

func newGCSSyncer(bucket, localPath string, debounce time.Duration) *gcsSyncer {
	return &gcsSyncer{
		bucket:    bucket,
		localPath: localPath,
		debounce:  debounce,
	}
}

// status returns the current sync state.
func (s *gcsSyncer) status() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	if gcsErr != "" {
		return gcsError
	}
	if s.uploading {
		return gcsUploading
	}
	if s.dirty {
		return gcsPending
	}
	return gcsSynced
}

// markDirty signals that local data has changed and needs uploading.
// The upload fires after the debounce period; repeated calls reset the timer.
func (s *gcsSyncer) markDirty() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.dirty = true
	if s.timer != nil {
		s.timer.Stop()
	}
	s.timer = time.AfterFunc(s.debounce, s.upload)
}

func (s *gcsSyncer) upload() {
	s.mu.Lock()
	if !s.dirty {
		s.mu.Unlock()
		return
	}
	s.dirty = false
	s.uploading = true
	s.mu.Unlock()

	err := gcsUpload(s.localPath, s.bucket)

	s.mu.Lock()
	s.uploading = false
	if err != nil {
		log.Printf("gcs: async upload failed: %v", err)
		gcsErr = err.Error()
	} else if gcsErr != "" {
		log.Println("gcs: async upload succeeded, clearing previous error")
		gcsErr = ""
	}
	s.mu.Unlock()
}

// flush forces an immediate upload if dirty, blocking until complete.
func (s *gcsSyncer) flush() {
	s.mu.Lock()
	if s.timer != nil {
		s.timer.Stop()
	}
	s.mu.Unlock()
	s.upload()
}
