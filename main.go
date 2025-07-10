package main

import (
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/cespare/xxhash/v2"
)

// PartialHashSize defines how many bytes to read from the beginning of a file
// for the initial quick hash. 4KB is a common and effective size.
const PartialHashSize = 4096

// fileInfo holds the path and size of a file.
type fileInfo struct {
	path string
	size int64
}

// hashResult holds the path and calculated hash of a file.
type hashResult struct {
	path string
	hash string
}

func main() {
	if len(os.Args) < 2 {
		fmt.Printf("Usage: %s <directory>\n", os.Args[0])
		os.Exit(1)
	}
	rootDir := os.Args[1]

	duplicates, err := runFinder(rootDir)
	if err != nil {
		log.Fatalf("Encountered a fatal error: %v", err)
	}

	//printResults(duplicates)
	print(len(duplicates))
}

func runFinder(rootDir string) (map[string][]string, error) {
	numWorkers := runtime.NumCPU()
	log.Printf("Starting duplicate file finder in: %s (using %d workers)\n", rootDir, numWorkers)

	// --- Phase 1: Group files by size ---
	start := time.Now()
	log.Println("Phase 1: Scanning files and grouping by size...")
	potentialDupesBySize := phase1GroupBySize(rootDir, numWorkers)
	log.Printf("Phase 1 completed in %v. Found %d sizes with potential duplicates.\n", time.Since(start), len(potentialDupesBySize))

	// --- Phase 2: Filter by partial hash ---
	start = time.Now()
	log.Println("Phase 2: Filtering candidates by partial hash...")
	potentialDupesByPartialHash := phase2FilterByPartialHash(potentialDupesBySize, numWorkers)
	log.Printf("Phase 2 completed in %v. Found %d partial hashes with potential duplicates.\n", time.Since(start), len(potentialDupesByPartialHash))

	// --- Phase 3: Confirm duplicates with full hash ---
	start = time.Now()
	log.Println("Phase 3: Confirming duplicates with full file hash...")
	finalDuplicates := phase3FindDuplicatesByFullHash(potentialDupesByPartialHash, numWorkers)
	log.Printf("Phase 3 completed in %v.\n", time.Since(start))

	return finalDuplicates, nil
}

// phase1_groupBySize walks the filesystem and groups files by their size.
// It uses a pool of workers to perform `os.Stat` calls concurrently.
func phase1GroupBySize(rootDir string, numWorkers int) map[int64][]string {
	pathsChan := make(chan string, numWorkers)
	infoChan := make(chan fileInfo, numWorkers)

	// Start a single goroutine to walk the filesystem.
	// This is the "producer" of file paths.

	go func() {

		defer close(pathsChan)
		err := filepath.Walk(rootDir, func(path string, info os.FileInfo, err error) error {
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
	for i := 0; i < numWorkers; i++ {
		statWg.Add(1)
		go func() {
			defer statWg.Done()
			for path := range pathsChan {
				info, err := os.Stat(path)
				if err != nil {
					log.Printf("Error stating file %s: %v\n", path, err)
					continue
				}
				infoChan <- fileInfo{path: path, size: info.Size()}
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
		filesBySize[info.size] = append(filesBySize[info.size], info.path)
	}

	// Filter out sizes that only have one file.
	for size, paths := range filesBySize {
		if len(paths) < 2 {
			delete(filesBySize, size)
		}
	}

	return filesBySize
}

// phase2_filterByPartialHash takes the size-grouped map and filters it further
// by hashing the first few kilobytes of each file.
func phase2FilterByPartialHash(filesBySize map[int64][]string, numWorkers int) map[string][]string {
	// A map where the key is a composite "size-partialHash" to avoid collisions.
	candidates := make(map[string][]string)
	var mu sync.Mutex // Mutex to protect the candidates map

	var wg sync.WaitGroup
	jobs := make(chan string, numWorkers)

	// Worker goroutines
	for i := 0; i < numWorkers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for path := range jobs {
				hash, err := calculateHash(path, true) // true for partial hash
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
	for _, paths := range filesBySize {
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

// phase3_findDuplicatesByFullHash is the final confirmation step. It calculates the full
// SHA256 hash for the remaining candidates.
func phase3FindDuplicatesByFullHash(candidates map[string][]string, numWorkers int) map[string][]string {
	duplicates := make(map[string][]string)
	var mu sync.Mutex

	var wg sync.WaitGroup
	jobs := make(chan fileInfo, numWorkers)

	for i := 0; i < numWorkers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for job := range jobs {

				currentInfo, err := os.Stat(job.path)
				if err != nil {
					log.Printf("Error stating file %s before full hash: %v", job.path, err)
					continue // Skip if file is gone or unreadable.
				}
				if currentInfo.Size() != job.size {
					log.Printf("File changed size during scan, skipping: %s", job.path)
					continue // Skip if size has changed.
				}

				hash, err := calculateHash(job.path, false) // false for full hash
				if err != nil {
					log.Printf("Error full hashing file %s: %v\n", job.path, err)
					continue
				}
				mu.Lock()
				duplicates[hash] = append(duplicates[hash], job.path)
				mu.Unlock()
			}
		}()
	}

	for key, paths := range candidates {
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
			jobs <- fileInfo{path: path, size: originalSize}
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

// calculateHash computes the SHA256 hash of a file.
// If 'partial' is true, it only reads the first PARTIAL_HASH_SIZE bytes.
func calculateHash(filePath string, partial bool) (string, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	//hash := sha256.New()
	hash := xxhash.New()

	if partial {
		// Read only the first chunk of the file
		buffer := make([]byte, PartialHashSize)
		_, err := file.Read(buffer)
		if err != nil && err != io.EOF {
			return "", err
		}
		hash.Write(buffer)
	} else {
		// Read the entire file
		if _, err := io.Copy(hash, file); err != nil {
			return "", err
		}
	}

	return fmt.Sprintf("%x", hash.Sum(nil)), nil
}

// printResults displays the final list of duplicate files.
func printResults(duplicates map[string][]string) {
	if len(duplicates) == 0 {
		fmt.Println("\n--- No duplicate files found. ---")
		return
	}

	fmt.Println("\n--- Found Duplicate Files ---")
	i := 0
	var totalWastedSpace int64 = 0
	for hash, paths := range duplicates {
		i++
		fmt.Printf("\nSet %d (SHA256: %s...):\n", i, hash[:12])

		info, err := os.Stat(paths[0])
		if err == nil {
			// Calculate wasted space: (number of duplicates - 1) * size
			wasted := info.Size() * int64(len(paths)-1)
			totalWastedSpace += wasted
			fmt.Printf("  Size: %d bytes | Wasted: %d bytes\n", info.Size(), wasted)
		}

		for _, path := range paths {
			fmt.Printf("  - %s\n", path)
		}
	}

	fmt.Printf("\nSummary: Found %d sets of duplicate files. Total wasted space: %d bytes.\n", len(duplicates), totalWastedSpace)
}
