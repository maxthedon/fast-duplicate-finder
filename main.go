package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"sort"
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

// MODIFY THIS FUNCTION
func main() {
	if len(os.Args) < 2 {
		fmt.Printf("Usage: %s <directory>\n", os.Args[0])
		os.Exit(1)
	}
	rootDir := os.Args[1]

	// The function now returns two maps
	fileDuplicates, folderDuplicates, err := runFinder(rootDir)
	if err != nil {
		log.Fatalf("Encountered a fatal error: %v", err)
	}

	filteredFolderDuplicates := filterNestedFolders(folderDuplicates)
	filteredFilesInDuplicateFolders := filterFilesWithinDuplicateFolders(fileDuplicates, filteredFolderDuplicates)

	output := resultAsJSON(
		fileDuplicates,                  // All file duplicates before filtering
		filteredFilesInDuplicateFolders, // Final file duplicates after filtering
		folderDuplicates,                // All folder duplicates before filtering
		filteredFolderDuplicates,        // Final folder duplicates after filtering
	)

	// Marshal the data into a nicely formatted JSON string.
	jsonData, err := json.MarshalIndent(output, "", "  ")
	if err != nil {
		log.Fatalf("FATAL: Failed to generate JSON report: %v", err)
	}

	// Print the final JSON to standard output.
	fmt.Println(string(jsonData))

	printFileResults(filteredFilesInDuplicateFolders)
	printFolderResults(filteredFolderDuplicates)

	log.Printf(
		"Summary: Found %d sets of duplicate files and %d sets of duplicate folders.",
		len(filteredFilesInDuplicateFolders),
		len(filteredFolderDuplicates),
	)

}

// MODIFY THIS FUNCTION
func runFinder(rootDir string) (map[string][]string, map[string][]string, error) { // Note the new return signature
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
	finalFileDuplicates := phase3FindDuplicatesByFullHash(potentialDupesByPartialHash, numWorkers)
	log.Printf("Phase 3 completed in %v. Found %d sets of duplicate files.\n", time.Since(start), len(finalFileDuplicates))

	// --- Phase 4: Find duplicate folders ---
	start = time.Now()
	log.Println("Phase 4: Analyzing folder structures for duplicates...")
	finalFolderDuplicates := phase4FindDuplicateFolders(finalFileDuplicates)
	log.Printf("Phase 4 completed in %v. Found %d sets of duplicate folders.\n", time.Since(start), len(finalFolderDuplicates))

	return finalFileDuplicates, finalFolderDuplicates, nil // Return both maps
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

// ADD THIS ENTIRE NEW FUNCTION
// phase4FindDuplicateFolders identifies duplicate folders based on the file duplicates found.
// It uses a recursive, bottom-up approach with memoization to generate a signature
// for each folder based on its contents (files and sub-folders).
func phase4FindDuplicateFolders(fileDuplicates map[string][]string) map[string][]string {
	// Step 1: Create a reverse map for quick hash lookups (path -> hash)
	pathToHashMap := make(map[string]string)
	for hash, paths := range fileDuplicates {
		for _, path := range paths {
			pathToHashMap[path] = hash
		}
	}

	// Step 2: Identify all candidate folders and sort them by depth (deepest first)
	candidateFoldersSet := make(map[string]struct{})
	for path := range pathToHashMap {
		dir := filepath.Dir(path)
		candidateFoldersSet[dir] = struct{}{}
	}

	candidateFolders := make([]string, 0, len(candidateFoldersSet))
	for dir := range candidateFoldersSet {
		candidateFolders = append(candidateFolders, dir)
	}

	// Sort by path depth, descending. This ensures we process children before parents.
	sort.Slice(candidateFolders, func(i, j int) bool {
		return strings.Count(candidateFolders[i], string(os.PathSeparator)) > strings.Count(candidateFolders[j], string(os.PathSeparator))
	})

	// Step 3 & 4: Recursively get signatures and group folders
	folderSignatureCache := make(map[string]string) // Memoization cache
	signatureToFoldersMap := make(map[string][]string)

	for _, folderPath := range candidateFolders {
		signature, isDuplicable := getFolderSignature(folderPath, pathToHashMap, folderSignatureCache)
		if isDuplicable {
			signatureToFoldersMap[signature] = append(signatureToFoldersMap[signature], folderPath)
		}
	}

	// Step 5: Final filter to remove unique folders
	for signature, paths := range signatureToFoldersMap {
		if len(paths) < 2 {
			delete(signatureToFoldersMap, signature)
		}
	}

	return signatureToFoldersMap
}

// ADD THIS ENTIRE NEW HELPER FUNCTION
// getFolderSignature is a recursive helper that calculates a canonical signature for a folder.
// It returns the signature and a boolean indicating if the folder is a candidate for duplication.
// A folder is NOT a candidate if it contains any unique files or unique sub-folders.
func getFolderSignature(
	folderPath string,
	pathToHashMap map[string]string,
	folderSignatureCache map[string]string,
) (string, bool) {
	// Base Case: If we have already calculated this signature, return it from the cache.
	if sig, found := folderSignatureCache[folderPath]; found {
		return sig, true
	}

	entries, err := os.ReadDir(folderPath)
	if err != nil {
		log.Printf("Could not read directory %s: %v", folderPath, err)
		return "", false // Cannot be a duplicate if we can't read it.
	}

	var contentItems []string

	for _, entry := range entries {
		fullPath := filepath.Join(folderPath, entry.Name())
		if entry.IsDir() {
			// Recursive step for subdirectory
			childSignature, childIsDuplicable := getFolderSignature(fullPath, pathToHashMap, folderSignatureCache)
			if !childIsDuplicable {
				return "", false // Parent folder contains a unique child, so it's also unique.
			}
			// Prefix 'D:' for directory
			contentItems = append(contentItems, fmt.Sprintf("D:%s:%s", entry.Name(), childSignature))
		} else {
			// File step
			hash, found := pathToHashMap[fullPath]
			if !found {
				return "", false // Folder contains a unique file, so it's not a duplicate.
			}
			// Prefix 'F:' for file
			contentItems = append(contentItems, fmt.Sprintf("F:%s:%s", entry.Name(), hash))
		}
	}

	// Sort the content items to create a canonical signature, independent of filesystem order.
	sort.Strings(contentItems)
	finalSignature := strings.Join(contentItems, ";")

	// Save the result to the cache before returning.
	folderSignatureCache[folderPath] = finalSignature

	return finalSignature, true
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

// printFileResults displays the final list of duplicate files.
func printFileResults(duplicates map[string][]string) {
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

func printFolderResults(duplicates map[string][]string) {
	if len(duplicates) == 0 {
		fmt.Println("\n--- No duplicate folders found. ---")
		return
	}

	fmt.Println("\n--- Found Duplicate Folders ---")
	i := 0
	for signature, paths := range duplicates {
		i++
		fmt.Printf("\nSet %d (Folder Signature Hash: %s...):\n", i, signature[:12])
		for _, path := range paths {
			fmt.Printf("  - %s\n", path)
		}
	}
}

// filterNestedFolders takes a map of duplicate folders and removes any sets
// that are subdirectories of another duplicate folder set.
// For example, if ["/a/src", "/b/src"] is a duplicate set, and
// ["/a/src/utils", "/b/src/utils"] is another, this function will
// remove the latter set, keeping only the top-level one.
func filterNestedFolders(folderDuplicates map[string][]string) map[string][]string {
	// Step 1: Create a master set of all individual duplicate folder paths for quick lookups.
	// Using a map[string]struct{} is the idiomatic way to create a set in Go.
	allDuplicatePaths := make(map[string]struct{})
	for _, paths := range folderDuplicates {
		for _, path := range paths {
			// Clean the path to handle cases like "dir/." vs "dir"
			cleanedPath := filepath.Clean(path)
			allDuplicatePaths[cleanedPath] = struct{}{}
		}
	}

	// Step 2: Iterate through the original duplicate sets and decide which ones to keep.
	filteredResults := make(map[string][]string)

	for signature, paths := range folderDuplicates {
		// We only need to check one path from the set, as all paths in a set
		// share the same parent-child relationship with other sets.
		if len(paths) == 0 {
			continue // Should not happen, but defensive check.
		}
		pathToCheck := filepath.Clean(paths[0])

		// Walk upwards from the current path to see if any of its parents
		// are also in the master set of duplicate folders.
		isNested := false
		parent := filepath.Dir(pathToCheck)

		// Loop until we reach the root of the filesystem (e.g., filepath.Dir("/") is "/").
		for parent != pathToCheck {
			if _, exists := allDuplicatePaths[parent]; exists {
				// This folder's parent is also a duplicate. Therefore, this set is nested.
				isNested = true
				break // No need to check further up.
			}
			pathToCheck = parent
			parent = filepath.Dir(pathToCheck)
		}

		// Step 3: If the set was not found to be nested, add it to our final results.
		if !isNested {
			filteredResults[signature] = paths
		}
	}

	return filteredResults
}

// filterFilesWithinDuplicateFolders removes file duplicates that exist inside
// the folders that have already been identified as top-level duplicates.
// This helps to de-clutter the final report, as users are typically more
// interested in the duplicate folders themselves rather than every file inside them.
func filterFilesWithinDuplicateFolders(
	fileDuplicates map[string][]string,
	filteredFolderDuplicates map[string][]string,
) map[string][]string {

	// Step 1: Create a fast lookup set of all top-level duplicate folder paths.
	// We add a path separator to the end to ensure we only match directories,
	// preventing false positives where a file path might share a prefix with a
	// folder name (e.g., /data/project vs /data/project-archive).
	duplicateFolderSet := make(map[string]struct{})
	for _, paths := range filteredFolderDuplicates {
		for _, path := range paths {
			// Ensure path is clean and has a trailing separator for prefix matching.
			folderPrefix := filepath.Clean(path) + string(os.PathSeparator)
			duplicateFolderSet[folderPrefix] = struct{}{}
		}
	}

	// If there are no duplicate folders, there's nothing to filter.
	if len(duplicateFolderSet) == 0 {
		return fileDuplicates
	}

	// Step 2: Build the new map of file duplicates, excluding the nested files.
	finalFileDuplicates := make(map[string][]string)

	for hash, paths := range fileDuplicates {
		// For each group of duplicate files, create a new list containing only
		// the files that are NOT located inside one of the duplicate folders.
		var keptPaths []string

		for _, filePath := range paths {
			isNested := false
			// Check if the file's path starts with any of the duplicate folder paths.
			for folderPrefix := range duplicateFolderSet {
				if strings.HasPrefix(filePath, folderPrefix) {
					isNested = true
					break // The file is inside a duplicate folder; no need to check others.
				}
			}

			// If the file is not nested within any duplicate folder, add it to our list.
			if !isNested {
				keptPaths = append(keptPaths, filePath)
			}
		}

		// Step 3: After filtering, if the group still has more than one file,
		// it's still a valid set of duplicates. Add it to the final results.
		if len(keptPaths) > 1 {
			finalFileDuplicates[hash] = keptPaths
		}
	}

	return finalFileDuplicates
}

// resultAsJSON formats all findings into a single JSON object and prints it to standard output.
// It includes both the final, filtered results and the complete raw data for comprehensive reporting.
func resultAsJSON(
	allFileDuplicates,
	finalFileDuplicates,
	allFolderDuplicates,
	topLevelFolderDuplicates map[string][]string) JSONOutput {

	// Helper function to convert a map of file duplicates to a slice of FileSet.
	// This avoids code repetition and handles sorting for consistent output.
	convertFileMapToSets := func(dupes map[string][]string) ([]FileSet, int64) {
		var totalWasted int64 = 0
		sets := make([]FileSet, 0, len(dupes))
		for hash, paths := range dupes {
			var sizeBytes int64
			if len(paths) > 0 {
				info, err := os.Stat(paths[0])
				if err == nil {
					sizeBytes = info.Size()
					// Wasted space is (count - 1) * size for this set
					if len(paths) > 1 {
						totalWasted += sizeBytes * int64(len(paths)-1)
					}
				} else {
					log.Printf("Warning: Could not stat file %s to get size: %v", paths[0], err)
					sizeBytes = -1 // Indicate error
				}
			}
			sets = append(sets, FileSet{Hash: hash, Paths: paths, SizeBytes: sizeBytes})
		}
		// Sort by hash for deterministic output
		sort.Slice(sets, func(i, j int) bool { return sets[i].Hash < sets[j].Hash })
		return sets, totalWasted
	}

	// Helper function to convert a map of folder duplicates to a slice of FolderSet.
	convertFolderMapToSets := func(dupes map[string][]string) []FolderSet {
		sets := make([]FolderSet, 0, len(dupes))
		for signature, paths := range dupes {
			sets = append(sets, FolderSet{Signature: signature, Paths: paths})
		}
		// Sort by signature for deterministic output
		sort.Slice(sets, func(i, j int) bool { return sets[i].Signature < sets[j].Signature })
		return sets
	}

	// --- Populate the Final Report ---
	finalFileSets, wastedSpace := convertFileMapToSets(finalFileDuplicates)
	topLevelFolderSets := convertFolderMapToSets(topLevelFolderDuplicates)

	// --- Populate the Raw Data Report ---
	allFileSets, _ := convertFileMapToSets(allFileDuplicates)
	allFolderSets := convertFolderMapToSets(allFolderDuplicates)

	// --- Assemble the final JSON object ---
	return JSONOutput{
		Summary: SummaryInfo{
			TotalAllFileSets:   len(allFileDuplicates),
			TotalAllFolderSets: len(allFolderDuplicates),
			TopLevelFolderSets: len(topLevelFolderDuplicates),
			StandaloneFileSets: len(finalFileDuplicates),
			WastedSpaceBytes:   wastedSpace,
		},
		FileDuplicates: FileDuplicateReport{
			Description: "Duplicate files that are NOT inside a top-level duplicate folder.",
			Sets:        finalFileSets,
		},
		FolderDuplicates: FolderDuplicateReport{
			Description: "Top-level duplicate folders. Files inside these are not listed in 'fileDuplicates'.",
			Sets:        topLevelFolderSets,
		},
		RawData: &RawDataReport{
			AllFileDuplicates: FileDuplicateReport{
				Description: "The complete list of all duplicate files found, before any filtering.",
				Sets:        allFileSets,
			},
			AllFolderDuplicates: FolderDuplicateReport{
				Description: "The complete list of all duplicate folders found, including nested ones.",
				Sets:        allFolderSets,
			},
		},
	}
}

// --- JSON Output Structures ---

// JSONOutput is the top-level structure for the final JSON report.
type JSONOutput struct {
	Summary          SummaryInfo           `json:"summary"`
	FileDuplicates   FileDuplicateReport   `json:"fileDuplicates"`
	FolderDuplicates FolderDuplicateReport `json:"folderDuplicates"`
	RawData          *RawDataReport        `json:"rawData,omitempty"` // Pointer to omit if empty
}

// SummaryInfo provides high-level counts of the findings.
type SummaryInfo struct {
	TotalAllFileSets   int   `json:"totalAllFileSets"`
	TotalAllFolderSets int   `json:"totalAllFolderSets"`
	TopLevelFolderSets int   `json:"topLevelFolderSets"`
	StandaloneFileSets int   `json:"standaloneFileSets"`
	WastedSpaceBytes   int64 `json:"wastedSpaceBytes"`
}

// FileDuplicateReport contains a list of duplicate file sets.
type FileDuplicateReport struct {
	Description string    `json:"description"`
	Sets        []FileSet `json:"sets"`
}

// FolderDuplicateReport contains a list of duplicate folder sets.
type FolderDuplicateReport struct {
	Description string      `json:"description"`
	Sets        []FolderSet `json:"sets"`
}

// FileSet represents a single group of identical files.
type FileSet struct {
	Hash      string   `json:"hash"`
	Paths     []string `json:"paths"`
	SizeBytes int64    `json:"sizeBytes"`
}

// FolderSet represents a single group of identical folders.
type FolderSet struct {
	Signature string   `json:"signature"`
	Paths     []string `json:"paths"`
}

// RawDataReport contains the unfiltered, complete results for detailed analysis.
type RawDataReport struct {
	AllFileDuplicates   FileDuplicateReport   `json:"allFileDuplicates"`
	AllFolderDuplicates FolderDuplicateReport `json:"allFolderDuplicates"`
}
