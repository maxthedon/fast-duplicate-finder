package helpers

import (
	"log"
	"os"
	"sort"

	reporttypes "github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/types/report_types"
)

// GenerateReport formats all findings into a single JSON object and prints it to standard output.
// It includes both the final, filtered results and the complete raw data for comprehensive reporting.
func GenerateReport(
	filteredFileDuplicates,
	filteredFolderDuplicates,
	allFileDuplicates,
	allFolderDuplicates map[string][]string) reporttypes.ReportOutput {

	// Helper function to convert a map of file duplicates to a slice of FileSet.
	// This avoids code repetition and handles sorting for consistent output.
	convertFileMapToSets := func(dupes map[string][]string) ([]reporttypes.FileSet, int64) {
		var totalWasted int64 = 0
		sets := make([]reporttypes.FileSet, 0, len(dupes))
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
			sets = append(sets, reporttypes.FileSet{Hash: hash, Paths: paths, SizeBytes: sizeBytes})
		}
		// Sort by hash for deterministic output
		sort.Slice(sets, func(i, j int) bool { return sets[i].Hash < sets[j].Hash })
		return sets, totalWasted
	}

	// Helper function to convert a map of folder duplicates to a slice of FolderSet.
	convertFolderMapToSets := func(dupes map[string][]string) []reporttypes.FolderSet {
		sets := make([]reporttypes.FolderSet, 0, len(dupes))
		for signature, paths := range dupes {
			sets = append(sets, reporttypes.FolderSet{Signature: signature, Paths: paths})
		}
		// Sort by signature for deterministic output
		sort.Slice(sets, func(i, j int) bool { return sets[i].Signature < sets[j].Signature })
		return sets
	}

	// --- Populate the Final Report ---
	finalFileSets, wastedSpace := convertFileMapToSets(filteredFileDuplicates)
	topLevelFolderSets := convertFolderMapToSets(filteredFolderDuplicates)

	// --- Populate the Raw Data Report ---
	allFileSets, _ := convertFileMapToSets(allFileDuplicates)
	allFolderSets := convertFolderMapToSets(allFolderDuplicates)

	// --- Assemble the final JSON object ---
	return reporttypes.ReportOutput{
		Summary: reporttypes.SummaryInfo{
			TotalAllFileSets:   len(allFileDuplicates),
			TotalAllFolderSets: len(allFolderDuplicates),
			TopLevelFolderSets: len(filteredFolderDuplicates),
			StandaloneFileSets: len(filteredFileDuplicates),
			WastedSpaceBytes:   wastedSpace,
		},
		FileDuplicates: reporttypes.FileDuplicateReport{
			Description: "Duplicate files that are NOT inside a top-level duplicate folder.",
			Sets:        finalFileSets,
		},
		FolderDuplicates: reporttypes.FolderDuplicateReport{
			Description: "Top-level duplicate folders. Files inside these are not listed in 'fileDuplicates'.",
			Sets:        topLevelFolderSets,
		},
		RawData: &reporttypes.RawDataReport{
			AllFileDuplicates: reporttypes.FileDuplicateReport{
				Description: "The complete list of all duplicate files found, before any filtering.",
				Sets:        allFileSets,
			},
			AllFolderDuplicates: reporttypes.FolderDuplicateReport{
				Description: "The complete list of all duplicate folders found, including nested ones.",
				Sets:        allFolderSets,
			},
		},
	}
}
