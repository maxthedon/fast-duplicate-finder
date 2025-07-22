package helpers

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
)

// GetFolderSignature is a recursive helper that calculates a canonical signature for a folder.
// It is designed to be thread-safe and uses sync.Map for concurrent cache access.
// It returns the signature and a boolean indicating if the folder is a candidate for duplication.
// A folder is NOT a candidate if it contains any unique files or unique sub-folders.
func GetFolderSignature(
	FolderPath string,
	PathToHashMap *sync.Map,
	FolderSignatureCache *sync.Map,
) (string, bool) {
	// Base Case: If we have already calculated this signature, return it from the cache.
	if sig, found := FolderSignatureCache.Load(FolderPath); found {
		return sig.(string), true
	}

	entries, err := os.ReadDir(FolderPath)
	if err != nil {
		log.Printf("Could not read directory %s: %v", FolderPath, err)
		return "", false // Cannot be a duplicate if we can't read it.
	}

	var contentItems []string

	for _, entry := range entries {
		fullPath := filepath.Join(FolderPath, entry.Name())
		if entry.IsDir() {
			// Recursive step for subdirectory
			childSignature, childIsDuplicable := GetFolderSignature(fullPath, PathToHashMap, FolderSignatureCache)
			if !childIsDuplicable {
				// This optimization prevents further processing if a unique child is found.
				// We cache this "unique" status to avoid re-calculating for other potential parents.
				FolderSignatureCache.Store(FolderPath, "") // Storing an empty string for non-duplicable folders.
				return "", false
			}
			// Prefix 'D:' for directory to distinguish from files with the same name.
			contentItems = append(contentItems, fmt.Sprintf("D:%s:%s", entry.Name(), childSignature))
		} else {
			// File step: look up the file's hash.
			hash, found := PathToHashMap.Load(fullPath)
			if !found {
				// Folder contains a unique file, so it's not a duplicate candidate.
				FolderSignatureCache.Store(FolderPath, "")
				return "", false
			}
			// Prefix 'F:' for file.
			contentItems = append(contentItems, fmt.Sprintf("F:%s:%s", entry.Name(), hash.(string)))
		}
	}

	// Sort the content items to create a canonical signature, independent of filesystem order.
	// This ensures that two folders with the same content have the same signature.
	sort.Strings(contentItems)
	finalSignature := strings.Join(contentItems, ";")

	// Save the result to the cache before returning.
	FolderSignatureCache.Store(FolderPath, finalSignature)

	return finalSignature, true
}
