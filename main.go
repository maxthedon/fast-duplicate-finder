package main

import (
	"fmt"
	"log"
	"os"

	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder"
	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/helpers"
	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/helpers/output"
)

// MODIFY THIS FUNCTION
func main() {
	if len(os.Args) < 2 {
		fmt.Printf("Usage: %s <directory>\n", os.Args[0])
		os.Exit(1)
	}
	rootDir := os.Args[1]

	filteredFileDuplicates, filteredFolderDuplicates, allFileDuplicates, allFolderDuplicates, err := fastdupefinder.RunFinder(rootDir)
	if err != nil {
		log.Fatalf("Encountered a fatal error: %v", err)
	}

	print(output.StringifyFileResults(filteredFileDuplicates))
	print(output.StringifyFolderResults(filteredFolderDuplicates))

	print(output.JSONifyReport(helpers.GenerateReport(filteredFileDuplicates, filteredFolderDuplicates, allFileDuplicates, allFolderDuplicates)))

}
