package main

import (
	"fmt"
	"os"

	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder"
	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/helpers/output"
	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/logger"
	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/status"
)

// MODIFY THIS FUNCTION
func main() {
	// Initialize logger
	log := logger.GetLogger()
	defer log.Stop()

	logger.Info("Fast Dupe Finder started", "Main")

	if len(os.Args) < 2 {
		fmt.Printf("Usage: %s <directory>\n", os.Args[0])
		logger.Error("No directory argument provided", "Main")
		os.Exit(1)
	}
	rootDir := os.Args[1]

	// Initialize status
	status.ResetStatus()

	// Add a status callback for demonstration (this will be used later for Flutter integration)
	status.AddStatusCallback(func(s status.Status) {
		logger.InfoWithData("Status update received", s, "Main")
	})

	logger.Info("Starting duplicate search for directory: "+rootDir, "Main")
	status.UpdateStatus("starting", 0.0, "Initializing duplicate finder", 0, 0)

	filteredFileDuplicates, filteredFolderDuplicates, allFileDuplicates, allFolderDuplicates, err := fastdupefinder.RunFinder(rootDir)
	if err != nil {
		logger.Fatal("Fatal error occurred: "+err.Error(), "Main")
		os.Exit(1)
	}

	status.UpdateStatus("completed", 100.0, "Duplicate search completed", len(allFileDuplicates), len(allFolderDuplicates))
	logger.Info("Duplicate search completed successfully", "Main")

	print(output.StringifyFileResults(filteredFileDuplicates))
	print(output.StringifyFolderResults(filteredFolderDuplicates))

	//print(output.JSONifyReport(helpers.GenerateReport(filteredFileDuplicates, filteredFolderDuplicates, allFileDuplicates, allFolderDuplicates)))

	logger.Info("Application finished", "Main")

}
