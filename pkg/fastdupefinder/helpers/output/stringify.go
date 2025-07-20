package output

import (
	"encoding/json"
	"fmt"
	"log"
	"os"

	reporttypes "github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/types/report_types"
)

// StringifyFileResults returns a formatted string representation of the duplicate file results.
func StringifyFileResults(duplicates map[string][]string) string {

	temp := ""

	if len(duplicates) == 0 {

		temp = "\n--- No duplicate files found. ---"
		return temp
	}

	temp = "\n--- Found Duplicate Files ---"

	i := 0
	var totalWastedSpace int64 = 0
	for hash, paths := range duplicates {
		i++
		temp += fmt.Sprintf("\nSet %d (SHA256: %s...):\n", i, hash[:12])

		info, err := os.Stat(paths[0])
		if err == nil {
			// Calculate wasted space: (number of duplicates - 1) * size
			wasted := info.Size() * int64(len(paths)-1)
			totalWastedSpace += wasted
			temp += fmt.Sprintf("  Size: %d bytes | Wasted: %d bytes\n", info.Size(), wasted)
		}

		for _, path := range paths {

			temp += fmt.Sprintf("  - %s\n", path)
		}
	}

	temp += fmt.Sprintf("\nSummary: Found %d sets of duplicate files. Total wasted space: %d bytes.\n", len(duplicates), totalWastedSpace)

	return temp
}

// StringifyFolderResults returns a formatted string representation of the duplicate folder results.
func StringifyFolderResults(duplicates map[string][]string) string {

	temp := ""

	if len(duplicates) == 0 {
		temp = "\n--- No duplicate folders found. ---"
		return temp
	}

	temp = "\n--- Found Duplicate Folders ---"

	i := 0
	for signature, paths := range duplicates {
		i++

		temp += fmt.Sprintf("\nSet %d (Folder Signature Hash: %s...):\n", i, signature[:12])
		for _, path := range paths {

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
