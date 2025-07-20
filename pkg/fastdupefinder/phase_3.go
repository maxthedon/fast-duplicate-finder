package fastdupefinder

import (
	"log"
	"os"
	"strconv"
	"strings"
	"sync"

	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/helpers"
	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/types"
)

// Phase3FindDuplicatesByFullHash is the final confirmation step. It calculates the full
// SHA256 hash for the remaining candidates.
func Phase3FindDuplicatesByFullHash(Candidates map[string][]string, NumWorkers int) map[string][]string {
	duplicates := make(map[string][]string)
	var mu sync.Mutex

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
					continue // Skip if file is gone or unreadable.
				}
				if currentInfo.Size() != job.Size {
					log.Printf("File changed size during scan, skipping: %s", job.Path)
					continue // Skip if size has changed.
				}

				hash, err := helpers.CalculateHash(job.Path, false) // false for full hash
				if err != nil {
					log.Printf("Error full hashing file %s: %v\n", job.Path, err)
					continue
				}
				mu.Lock()
				duplicates[hash] = append(duplicates[hash], job.Path)
				mu.Unlock()
			}
		}()
	}

	for key, paths := range Candidates {
		// The key is "size-partialHash". We need to extract the original size.
		keyParts := strings.SplitN(key, "-", 2)
		if len(keyParts) != 2 {
			continue // Should not happen with our key format.
		}
		originalSize, err := strconv.ParseInt(keyParts[0], 10, 64)
		if err != nil {
			continue // Should not happen.
		}

		for _, path := range paths {
			jobs <- types.FileInfo{Path: path, Size: originalSize}
		}
	}
	close(jobs)

	wg.Wait()

	// Final filter: a hash with only one path is not a duplicate.
	for hash, paths := range duplicates {
		if len(paths) < 2 {
			delete(duplicates, hash)
		}
	}

	return duplicates
}
