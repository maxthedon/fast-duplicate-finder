package helpers

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// GetFolderSignature is a recursive helper that calculates a canonical signature for a folder.
// It returns the signature and a boolean indicating if the folder is a candidate for duplication.
// A folder is NOT a candidate if it contains any unique files or unique sub-folders.
func GetFolderSignature(
	FolderPath string,
	PathToHashMap map[string]string,
	FolderSignatureCache map[string]string,
) (string, bool) {
	// Base Case: If we have already calculated this signature, return it from the cache.
	if sig, found := FolderSignatureCache[FolderPath]; found {
		return sig, true
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
				return "", false // Parent folder contains a unique child, so it's also unique.
			}
			// Prefix 'D:' for directory
			contentItems = append(contentItems, fmt.Sprintf("D:%s:%s", entry.Name(), childSignature))
		} else {
			// File step
			hash, found := PathToHashMap[fullPath]
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
	FolderSignatureCache[FolderPath] = finalSignature

	return finalSignature, true
}
