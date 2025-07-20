package fastdupefinder

import (
	"log"
	"os"
	"path/filepath"
	"sync"

	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/types"
)

// Phase1GroupBySize walks the filesystem and groups files by their size.
// It uses a pool of workers to perform `os.Stat` calls concurrently.
func Phase1GroupBySize(RootDir string, NumWorkers int) map[int64][]string {
	pathsChan := make(chan string, NumWorkers)
	infoChan := make(chan types.FileInfo, NumWorkers)

	// Start a single goroutine to walk the filesystem.
	// This is the "producer" of file paths.

	go func() {

		defer close(pathsChan)
		err := filepath.Walk(RootDir, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				log.Printf("Error accessing path %s: %v\n", path, err)
				return nil // Continue walking
			}
			if info.Mode().IsRegular() && info.Size() > 0 {
				pathsChan <- path
			}
			return nil
		})
		if err != nil {
			log.Printf("FATAL: Error walking directory: %v", err)
		}
	}()

	// Start a pool of worker goroutines to process paths.
	// These are the "consumers" that get file stats.
	var statWg sync.WaitGroup
	for i := 0; i < NumWorkers; i++ {
		statWg.Add(1)
		go func() {
			defer statWg.Done()
			for path := range pathsChan {
				info, err := os.Stat(path)
				if err != nil {
					log.Printf("Error stating file %s: %v\n", path, err)
					continue
				}
				infoChan <- types.FileInfo{Path: path, Size: info.Size()}
			}
		}()
	}

	// Start a goroutine to close the infoChan once all stat workers are done.
	go func() {
		statWg.Wait()
		close(infoChan)
	}()

	// Collect results from infoChan and group by size.
	filesBySize := make(map[int64][]string)

	for info := range infoChan {
		filesBySize[info.Size] = append(filesBySize[info.Size], info.Path)
	}

	// Filter out sizes that only have one file.
	for size, paths := range filesBySize {
		if len(paths) < 2 {
			delete(filesBySize, size)
		}
	}

	return filesBySize
}
