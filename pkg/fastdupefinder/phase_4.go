package fastdupefinder

import (
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/helpers"
	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/status"
)

// Phase4FindDuplicateFolders identifies duplicate folders based on the file duplicates found.
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

	// Sort by path depth, descending
	sort.Slice(candidateFolders, func(i, j int) bool {
		return strings.Count(candidateFolders[i], string(os.PathSeparator)) > strings.Count(candidateFolders[j], string(os.PathSeparator))
	})

	// Step 3 & 4: Get signatures and group folders
	folderSignatureCache := make(map[string]string)
	signatureToFoldersMap := make(map[string][]string)

	totalFolders := len(candidateFolders)
	for i, folderPath := range candidateFolders {
		// Update progress every 100 folders
		if i%100 == 0 {
			progress := 60.0 + (float64(i+1)/float64(totalFolders))*20.0 // 60-80%
			status.UpdateStatus("phase4", progress, "Analyzing folders", len(pathToHashMap), 0)
		}

		signature, isDuplicable := helpers.GetFolderSignature(folderPath, pathToHashMap, folderSignatureCache)
		if isDuplicable {
			signatureToFoldersMap[signature] = append(signatureToFoldersMap[signature], folderPath)
		}
	}

	// Step 5: Filter unique folders
	for signature, paths := range signatureToFoldersMap {
		if len(paths) < 2 {
			delete(signatureToFoldersMap, signature)
		}
	}

	return signatureToFoldersMap
}
