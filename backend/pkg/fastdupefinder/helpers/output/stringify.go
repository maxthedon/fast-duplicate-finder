package output

import (
	"encoding/json"
	"fmt"
	"log"

	reporttypes "github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/types/report_types"
)

// StringifyFileResults returns a formatted string representation of the duplicate file results.
// Now works directly with FileSet slice for better performance.
func StringifyFileResults(fileSets []reporttypes.FileSet) string {
	if len(fileSets) == 0 {
		return "\n--- No duplicate files found. ---"
	}

	temp := "\n--- Found Duplicate Files ---"
	var totalWastedSpace int64 = 0

	for i, set := range fileSets {
		temp += fmt.Sprintf("\nSet %d (SHA256: %s...):\n", i+1, set.Hash)

		if set.SizeBytes > 0 {
			// Calculate wasted space: (number of duplicates - 1) * size
			wasted := set.SizeBytes * int64(len(set.Paths)-1)
			totalWastedSpace += wasted
			temp += fmt.Sprintf("  Size: %d bytes | Wasted: %d bytes\n", set.SizeBytes, wasted)
		}

		for _, path := range set.Paths {
			temp += fmt.Sprintf("  - %s\n", path)
		}
	}

	temp += fmt.Sprintf("\nSummary: Found %d sets of duplicate files. Total wasted space: %d bytes.\n", len(fileSets), totalWastedSpace)
	return temp
}

// StringifyFolderResults returns a formatted string representation of the duplicate folder results.
// Now works directly with FolderSet slice for better performance.
func StringifyFolderResults(folderSets []reporttypes.FolderSet) string {
	if len(folderSets) == 0 {
		return "\n--- No duplicate folders found. ---"
	}

	temp := "\n--- Found Duplicate Folders ---"

	for i, set := range folderSets {
		temp += fmt.Sprintf("\nSet %d (Folder Signature Hash: %s...):\n", i+1, set.Signature)
		for _, path := range set.Paths {
			temp += fmt.Sprintf("  - %s\n", path)
		}
	}

	return temp
}

// JSONifyReport converts the report object into a formatted JSON string.
func JSONifyReport(reportObject reporttypes.ReportOutput) string {

	// Marshal the data into a nicely formatted JSON string.
	jsonData, err := json.MarshalIndent(reportObject, "", "  ")
	if err != nil {
		log.Fatalf("FATAL: Failed to generate JSON report: %v", err)
	}

	return string(jsonData)

}
