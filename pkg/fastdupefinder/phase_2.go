package fastdupefinder

import (
	"fmt"
	"log"
	"os"
	"sync"

	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/helpers"
)

// Phase2FilterByPartialHash takes the size-grouped map and filters it further
// by hashing the first few kilobytes of each file.
func Phase2FilterByPartialHash(FilesBySize map[int64][]string, NumWorkers int) map[string][]string {
	// A map where the key is a composite "size-partialHash" to avoid collisions.
	candidates := make(map[string][]string)
	var mu sync.Mutex // Mutex to protect the candidates map

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
					continue
				}
				// The composite key includes file size to prevent hash collisions between
				// files of different sizes.
				info, _ := os.Stat(path) // We know the file exists, so ignore error
				compositeKey := fmt.Sprintf("%d-%s", info.Size(), hash)

				mu.Lock()
				candidates[compositeKey] = append(candidates[compositeKey], path)
				mu.Unlock()
			}
		}()
	}

	// Feed the jobs channel with all file paths from the potential duplicate groups.
	for _, paths := range FilesBySize {
		for _, path := range paths {
			jobs <- path
		}
	}
	close(jobs)

	wg.Wait()

	// Filter out groups with only one file.
	for key, paths := range candidates {
		if len(paths) < 2 {
			delete(candidates, key)
		}
	}

	return candidates
}
