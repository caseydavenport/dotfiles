package main

import (
	"fmt"
	"log"
	"os/exec"
	"strings"
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
