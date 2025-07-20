package main

import (
	"fmt"
	"os"
	"strings"

	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder"
	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/helpers"
	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/helpers/output"
	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/logger"
	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/status"
)

// MODIFY THIS FUNCTION
func main() {
	// Parse command line arguments
	var rootDir string
	var quietMode bool
	var jsonMode bool
	var showProgress bool

	// Simple argument parsing
	for i, arg := range os.Args[1:] {
		switch arg {
		case "--quiet", "-q":
			quietMode = true
		case "--json", "-j":
			jsonMode = true
		case "--progress", "-p":
			showProgress = true
		case "--help", "-h":
			printUsage()
			os.Exit(0)
		default:
			if i == len(os.Args)-2 || (rootDir == "" && !strings.HasPrefix(arg, "-")) {
				rootDir = arg
			}
		}
	}

	if rootDir == "" {
		printUsage()
		os.Exit(1)
	}

	// Initialize logger (disable in quiet mode)
	log := logger.GetLogger()
	defer log.Stop()

	if !quietMode {
		logger.Info("Fast Dupe Finder started", "Main")
	}

	// Initialize status
	status.ResetStatus()

	// Set up progress display based on mode
	if showProgress && !quietMode {
		// CLI progress mode - show progress on stderr
		status.AddStatusCallback(func(s status.Status) {
			fmt.Fprintf(os.Stderr, "\r%s [%.1f%%] - %s", s.Phase, s.Progress, s.Message)
			if s.Phase == "completed" {
				fmt.Fprintf(os.Stderr, "\n")
			}
		})
	}

	if !quietMode {
		logger.Info("Starting duplicate search for directory: "+rootDir, "Main")
	}

	filteredFileDuplicates, filteredFolderDuplicates, allFileDuplicates, allFolderDuplicates, err := fastdupefinder.RunFinder(rootDir)
	if err != nil {
		if !quietMode {
			logger.Fatal("Fatal error occurred: "+err.Error(), "Main")
		}
		fmt.Fprintf(os.Stderr, "Error: %s\n", err.Error())
		os.Exit(1)
	}

	if !quietMode {
		logger.Info("Duplicate search completed successfully", "Main")
		logger.Info("Application finished", "Main")
	}

	// Output results based on mode
	if jsonMode {
		// JSON output mode
		fmt.Print(output.JSONifyReport(helpers.GenerateReport(filteredFileDuplicates, filteredFolderDuplicates, allFileDuplicates, allFolderDuplicates)))
	} else {
		// Standard text output mode
		fmt.Print(output.StringifyFileResults(filteredFileDuplicates))
		fmt.Print(output.StringifyFolderResults(filteredFolderDuplicates))
	}
}

func printUsage() {
	fmt.Printf(`Usage: %s [OPTIONS] <directory>

OPTIONS:
  -q, --quiet     Suppress progress messages and logging
  -j, --json      Output results in JSON format
  -p, --progress  Show progress updates on stderr (ignored in quiet mode)
  -h, --help      Show this help message

EXAMPLES:
  %s /path/to/scan                    # Basic scan with text output
  %s -q /path/to/scan                 # Quiet mode for piping
  %s -p /path/to/scan                 # Show progress updates
  %s -j /path/to/scan                 # JSON output
  %s -q -j /path/to/scan              # Quiet JSON mode for scripting

PIPING EXAMPLES:
  %s -q /path | grep "Set"            # Find only duplicate sets
  %s -q -j /path | jq .summary        # Extract summary with jq
`, os.Args[0], os.Args[0], os.Args[0], os.Args[0], os.Args[0], os.Args[0], os.Args[0], os.Args[0])
}
