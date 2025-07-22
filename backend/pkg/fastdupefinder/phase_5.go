// Package fastdupefinder provides the core logic for finding duplicate files and folders.
package fastdupefinder

import (
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"sync"

	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/status"
	"golang.org/x/sync/errgroup"
)

// Global cancellation flag and mutex to ensure thread-safe access.
var (
	scanCancelled bool
	cancelMutex   sync.RWMutex
)

// SetCancelled updates the global cancellation flag.
// It is called to signal that the scan should be stopped.
func SetCancelled(cancelled bool) {
	cancelMutex.Lock()
	defer cancelMutex.Unlock()
	scanCancelled = cancelled
}

// IsCancelled checks if the scan has been cancelled.
// This is checked periodically in long-running operations to allow for early exit.
func IsCancelled() bool {
	cancelMutex.RLock()
	defer cancelMutex.RUnlock()
	return scanCancelled
}

// Phase5FilterResults is the entry point for the fifth and final phase of the duplicate finding process.
// It orchestrates the filtering of nested duplicate folders and files contained within them.
// The process is optimized for speed and concurrency, especially for large datasets.
func Phase5FilterResults(folderDuplicates map[string][]string, fileDuplicates map[string][]string) (map[string][]string, map[string][]string) {
	status.UpdateDetailedStatus("phase5", 85.0, "Filtering nested duplicates", len(fileDuplicates), len(folderDuplicates), 0, len(fileDuplicates)+len(folderDuplicates), "Duplicates")

	if IsCancelled() {
		return make(map[string][]string), make(map[string][]string)
	}

	// Phase 1: Filter nested duplicate folders. This is a prerequisite for filtering files.
	filteredFolderDuplicates := filterNestedFolders(folderDuplicates)

	if IsCancelled() {
		return make(map[string][]string), make(map[string][]string)
	}

	// Phase 2: Filter files that are located within the identified top-level duplicate folders.
	filteredFileDuplicates := filterFilesWithinDuplicateFolders(fileDuplicates, filteredFolderDuplicates)

	return filteredFileDuplicates, filteredFolderDuplicates
}

// filterNestedFolders identifies and removes duplicate folder sets that are subdirectories
// of other duplicate folder sets. It uses a combination of sorting and concurrent processing.
func filterNestedFolders(folderDuplicates map[string][]string) map[string][]string {
	if len(folderDuplicates) < 2 {
		return folderDuplicates
	}

	// Step 1: Concurrently collect all unique folder paths and map them to their signatures.
	// This is faster than a single-threaded iteration for large numbers of duplicates.
	allPaths, pathToSignature := collectAndMapPaths(folderDuplicates)

	// Step 2: Sort paths alphabetically. This is a crucial step that ensures parent
	// directories are processed before their children (e.g., "/a" before "/a/b").
	// Go's sort.Strings uses a highly efficient hybrid sorting algorithm (pdqsort),
	// which is well-suited for both very large (100,000+) and smaller datasets.
	sort.Strings(allPaths)

	// Step 3: Identify top-level (non-nested) paths in a single pass.
	// This loop is sequential as each step depends on the previous one.
	topLevelPaths := identifyTopLevelPaths(allPaths)

	// Step 4: Reconstruct the results map containing only the top-level duplicate sets.
	// This step is performed concurrently for efficiency.
	return buildFilteredFolderMap(topLevelPaths, pathToSignature, folderDuplicates)
}

// collectAndMapPaths concurrently extracts all paths from the folderDuplicates map
// and creates a reverse mapping from each path to its signature.
func collectAndMapPaths(folderDuplicates map[string][]string) ([]string, *sync.Map) {
	var allPaths sync.Map
	var pathToSignature sync.Map
	var g errgroup.Group
	g.SetLimit(runtime.NumCPU())

	for signature, paths := range folderDuplicates {
		sig := signature
		pths := paths
		g.Go(func() error {
			for _, path := range pths {
				if IsCancelled() {
					return nil
				}
				cleanedPath := filepath.Clean(path)
				allPaths.Store(cleanedPath, struct{}{})
				pathToSignature.Store(cleanedPath, sig)
			}
			return nil
		})
	}
	g.Wait()

	// Convert sync.Map keys to a slice for sorting.
	pathSlice := make([]string, 0)
	allPaths.Range(func(key, value interface{}) bool {
		pathSlice = append(pathSlice, key.(string))
		return true
	})

	return pathSlice, &pathToSignature
}

// identifyTopLevelPaths iterates through a sorted list of paths and identifies
// those that are not subdirectories of previously identified top-level paths.
func identifyTopLevelPaths(allPaths []string) map[string]struct{} {
	topLevelPaths := make(map[string]struct{})
	var lastTopLevel string
	for _, path := range allPaths {
		if IsCancelled() {
			break
		}
		// If the current path is a subdirectory of the last identified top-level folder, skip it.
		// The check `path[len(lastTopLevel)] == os.PathSeparator` ensures we match whole directory names.
		if lastTopLevel != "" && strings.HasPrefix(path, lastTopLevel+string(os.PathSeparator)) {
			continue
		}
		// This path is not nested, so it's a new top-level candidate.
		topLevelPaths[path] = struct{}{}
		lastTopLevel = path
	}
	return topLevelPaths
}

// buildFilteredFolderMap concurrently reconstructs the results map containing only
// the top-level duplicate sets.
func buildFilteredFolderMap(topLevelPaths map[string]struct{}, pathToSignature *sync.Map, originalFolderDups map[string][]string) map[string][]string {
	var filteredResults sync.Map
	var g errgroup.Group
	g.SetLimit(runtime.NumCPU())

	for path := range topLevelPaths {
		p := path
		g.Go(func() error {
			if IsCancelled() {
				return nil
			}
			if sig, ok := pathToSignature.Load(p); ok {
				// We add all original paths belonging to this signature to the results.
				// The Store operation ensures that we only add each signature once.
				if _, loaded := filteredResults.LoadOrStore(sig.(string), originalFolderDups[sig.(string)]); !loaded {
					// First time this signature is seen, it's stored.
				}
			}
			return nil
		})
	}
	g.Wait()

	// Convert sync.Map to a standard map for the final result.
	result := make(map[string][]string)
	filteredResults.Range(func(key, value interface{}) bool {
		result[key.(string)] = value.([]string)
		return true
	})
	return result
}

// TrieNode represents a node in the Trie data structure used for efficient prefix matching.
type TrieNode struct {
	children map[rune]*TrieNode
	isEnd    bool
}

// Trie is a data structure that stores strings for fast prefix-based lookups.
type Trie struct {
	root *TrieNode
}

// NewTrie creates and initializes a new Trie.
func NewTrie() *Trie {
	return &Trie{root: &TrieNode{children: make(map[rune]*TrieNode)}}
}

// Insert adds a path string to the Trie.
func (t *Trie) Insert(path string) {
	node := t.root
	for _, r := range path {
		if _, ok := node.children[r]; !ok {
			node.children[r] = &TrieNode{children: make(map[rune]*TrieNode)}
		}
		node = node.children[r]
	}
	node.isEnd = true
}

// HasPrefix checks if any stored path in the Trie is a prefix of the given path.
func (t *Trie) HasPrefix(path string) bool {
	node := t.root
	for i, r := range path {
		// If the current node marks the end of a stored path, we've found a prefix.
		if node.isEnd {
			// Ensure it's a directory prefix (matches separator or end of string)
			if i > 0 && (path[i-1] == os.PathSeparator || i == len(path)) {
				return true
			}
		}
		if _, ok := node.children[r]; !ok {
			return false // No matching prefix found.
		}
		node = node.children[r]
	}
	// Check if the full path itself is a registered prefix.
	return node.isEnd
}

// filterFilesWithinDuplicateFolders removes file duplicates that are located inside
// the top-level duplicate folders. It uses a Trie for high-speed lookups and
// processes files concurrently.
func filterFilesWithinDuplicateFolders(fileDuplicates map[string][]string, filteredFolderDuplicates map[string][]string) map[string][]string {
	if len(filteredFolderDuplicates) == 0 {
		return fileDuplicates
	}

	// Step 1: Build a Trie from the duplicate folder paths for efficient prefix matching.
	folderTrie := NewTrie()
	for _, paths := range filteredFolderDuplicates {
		for _, path := range paths {
			// Add a separator to ensure we only match full directory paths.
			folderTrie.Insert(filepath.Clean(path) + string(os.PathSeparator))
		}
	}

	// Step 2: Concurrently filter the file duplicates.
	finalFileDuplicates := &sync.Map{}
	var g errgroup.Group

	// Dynamically set the number of workers based on CPU and workload.
	numWorkers := runtime.NumCPU()
	if len(fileDuplicates) < numWorkers*20 {
		numWorkers = (len(fileDuplicates) / 20) + 1
	}
	if numWorkers > 16 {
		numWorkers = 16 // Cap workers to prevent excessive overhead.
	}
	g.SetLimit(numWorkers)

	for hash, paths := range fileDuplicates {
		if IsCancelled() {
			break
		}
		h := hash
		pths := paths

		g.Go(func() error {
			var keptPaths []string
			for _, filePath := range pths {
				if IsCancelled() {
					return nil
				}
				// Use the Trie to check if the file path has a duplicate folder as a prefix.
				if !folderTrie.HasPrefix(filePath) {
					keptPaths = append(keptPaths, filePath)
				}
			}

			// If more than one path remains after filtering, it's still a valid duplicate set.
			if len(keptPaths) > 1 {
				finalFileDuplicates.Store(h, keptPaths)
			}
			return nil
		})
	}

	g.Wait()

	if IsCancelled() {
		return make(map[string][]string)
	}

	// Step 3: Convert the concurrent map back to a standard map.
	result := make(map[string][]string)
	finalFileDuplicates.Range(func(key, value interface{}) bool {
		result[key.(string)] = value.([]string)
		return true
	})

	return result
}
