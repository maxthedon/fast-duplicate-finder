package fastdupefinder

import (
	"log"
	"os"
	"strconv"
	"strings"
	"sync"

	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/helpers"
	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/status"
	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/types"
)

// Phase3FindDuplicatesByFullHash is the final confirmation step. It calculates the full
// hash for the remaining candidates.
func Phase3FindDuplicatesByFullHash(Candidates map[string][]string, NumWorkers int) map[string][]string {
	// Count total files
	var totalFiles int
	for _, paths := range Candidates {
		totalFiles += len(paths)
	}

	duplicates := make(map[string][]string)
	var mu sync.Mutex
	var processedFiles int

	var wg sync.WaitGroup
	jobs := make(chan types.FileInfo, NumWorkers)

	for i := 0; i < NumWorkers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for job := range jobs {
				currentInfo, err := os.Stat(job.Path)
				if err != nil {
					log.Printf("Error stating file %s before full hash: %v", job.Path, err)
					processedFiles++
					continue
				}
				if currentInfo.Size() != job.Size {
					log.Printf("File changed size during scan, skipping: %s", job.Path)
					processedFiles++
					continue
				}

				hash, err := helpers.CalculateHash(job.Path, false) // false for full hash
				if err != nil {
					log.Printf("Error full hashing file %s: %v\n", job.Path, err)
					processedFiles++
					continue
				}

				mu.Lock()
				duplicates[hash] = append(duplicates[hash], job.Path)
				processedFiles++

				// Simple progress update every 200 files
				if processedFiles%200 == 0 {
					progress := 40.0 + (float64(processedFiles)/float64(totalFiles))*20.0 // 40-60%
					status.UpdateStatus("phase3", progress, "Computing full hashes", processedFiles, 0)
				}
				mu.Unlock()
			}
		}()
	}

	for key, paths := range Candidates {
		// The key is "size-partialHash". Extract the original size.
		keyParts := strings.SplitN(key, "-", 2)
		if len(keyParts) != 2 {
			continue
		}
		originalSize, err := strconv.ParseInt(keyParts[0], 10, 64)
		if err != nil {
			continue
		}

		for _, path := range paths {
			jobs <- types.FileInfo{Path: path, Size: originalSize}
		}
	}
	close(jobs)

	wg.Wait()

	// Final filter: a hash with only one path is not a duplicate
	for hash, paths := range duplicates {
		if len(paths) < 2 {
			delete(duplicates, hash)
		}
	}

	return duplicates
}
