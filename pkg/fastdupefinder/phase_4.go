package fastdupefinder

import (
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/helpers"
)

// Phase4FindDuplicateFolders identifies duplicate folders based on the file duplicates found.
// It uses a recursive, bottom-up approach with memoization to generate a signature
// for each folder based on its contents (files and sub-folders).
func Phase4FindDuplicateFolders(FileDuplicates map[string][]string) map[string][]string {
	// Step 1: Create a reverse map for quick hash lookups (path -> hash)
	pathToHashMap := make(map[string]string)
	for hash, paths := range FileDuplicates {
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
		signature, isDuplicable := helpers.GetFolderSignature(folderPath, pathToHashMap, folderSignatureCache)
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
