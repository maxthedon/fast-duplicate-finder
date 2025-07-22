package fastdupefinder

import (
	"fmt"
	"log"
	"os"
	"sync"

	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/helpers"
	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/status"
)

// Phase2FilterByPartialHash takes the size-grouped map and filters it further
// by hashing selected portions of each file based on size:
// - Files < 1MB: hash first 4KB
// - Files < 10MB: hash first and last 4KB
// - Files >= 10MB: hash first, middle, and last 4KB
func Phase2FilterByPartialHash(FilesBySize map[int64][]string, NumWorkers int) map[string][]string {
	// Count total files to process
	var totalFiles int
	for _, paths := range FilesBySize {
		totalFiles += len(paths)
	}

	candidates := make(map[string][]string)
	var mu sync.Mutex
	var processedFiles int

	var wg sync.WaitGroup
	jobs := make(chan string, NumWorkers)

	// Worker goroutines
	for i := 0; i < NumWorkers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for path := range jobs {
				hash, err := helpers.CalculateHash(path, true) // true for partial hash
				if err != nil {
					log.Printf("Error partial hashing file %s: %v\n", path, err)
					processedFiles++
					continue
				}

				info, _ := os.Stat(path) // We know the file exists
				compositeKey := fmt.Sprintf("%d-%s", info.Size(), hash)

				mu.Lock()
				candidates[compositeKey] = append(candidates[compositeKey], path)
				processedFiles++

				// Simple progress update every 500 files
				if processedFiles%500 == 0 {
					progress := 20.0 + (float64(processedFiles)/float64(totalFiles))*20.0 // 20-40%
					status.UpdateDetailedStatus("phase2", progress, "Computing size-based partial hashes", processedFiles, 0, processedFiles, totalFiles, "Suspects")
				}
				mu.Unlock()
			}
		}()
	}

	// Feed the jobs channel
	for _, paths := range FilesBySize {
		for _, path := range paths {
			jobs <- path
		}
	}
	close(jobs)

	wg.Wait()

	// Filter out groups with only one file
	for key, paths := range candidates {
		if len(paths) < 2 {
			delete(candidates, key)
		}
	}

	return candidates
}
