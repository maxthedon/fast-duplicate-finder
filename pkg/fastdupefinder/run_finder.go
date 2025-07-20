package fastdupefinder

import (
	"runtime"
)

// RunFinder orchestrates the entire duplicate finding process.
func RunFinder(RootDir string) (map[string][]string, map[string][]string, map[string][]string, map[string][]string, error) {
	numWorkers := runtime.NumCPU()

	potentialDupesBySize := Phase1GroupBySize(RootDir, numWorkers)
	potentialDupesByPartialHash := Phase2FilterByPartialHash(potentialDupesBySize, numWorkers)
	allFileDuplicates := Phase3FindDuplicatesByFullHash(potentialDupesByPartialHash, numWorkers)
	allFolderDuplicates := Phase4FindDuplicateFolders(allFileDuplicates)

	filteredFileDuplicates, filteredFolderDuplicates := Phase5FilterResults(allFolderDuplicates, allFileDuplicates)

	return filteredFileDuplicates, filteredFolderDuplicates, allFileDuplicates, allFolderDuplicates, nil

}
