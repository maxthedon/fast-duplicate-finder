package library

import (
	"encoding/json"
	"fmt"

	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder"
	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/helpers"
	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/logger"
	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/status"
)

// DuplicateFinderResult represents the complete result of a duplicate finding operation
type DuplicateFinderResult struct {
	Success bool   `json:"success"`
	Error   string `json:"error,omitempty"`
	Report  string `json:"report,omitempty"` // JSON string of the report
}

// StatusCallback is the type for status update callbacks
// This will be used by the Flutter binding to receive status updates
type StatusCallback func(statusJSON string)

var globalStatusCallback StatusCallback
var lastReport string // Cache the last report JSON

// SetStatusCallback sets the global status callback function
// This function will be called by the C binding layer
func SetStatusCallback(callback StatusCallback) {
	globalStatusCallback = callback

	// Add the callback to the status manager
	status.AddStatusCallback(func(s status.Status) {
		if globalStatusCallback != nil {
			statusJSON, err := json.Marshal(s)
			if err != nil {
				logger.Error("Failed to marshal status to JSON: "+err.Error(), "Library")
				return
			}
			globalStatusCallback(string(statusJSON))
		}
	})

	logger.Info("Status callback registered", "Library")
}

// RunDuplicateFinder is the main library function that will be exposed to Flutter
// It runs the duplicate finder and returns the result as JSON
func RunDuplicateFinder(rootDir string) string {
	logger.Info("Library RunDuplicateFinder called with directory: "+rootDir, "Library")

	// Reset status for new run
	status.ResetStatus()

	// Clear the cached report from previous scan
	lastReport = ""

	result := DuplicateFinderResult{}

	// Run the duplicate finder
	filteredFileDuplicates, filteredFolderDuplicates, allFileDuplicates, allFolderDuplicates, err := fastdupefinder.RunFinder(rootDir)
	if err != nil {
		result.Success = false
		result.Error = err.Error()
		logger.Error("Duplicate finder failed: "+err.Error(), "Library")
	} else {
		// Generate the report
		report := helpers.GenerateReport(filteredFileDuplicates, filteredFolderDuplicates, allFileDuplicates, allFolderDuplicates)
		reportJSON, err := json.Marshal(report)
		if err != nil {
			result.Success = false
			result.Error = "Failed to generate JSON report: " + err.Error()
			logger.Error("Failed to marshal report to JSON: "+err.Error(), "Library")
		} else {
			result.Success = true
			result.Report = string(reportJSON)
			lastReport = string(reportJSON) // Cache the report
			logger.Info("Duplicate finder completed successfully", "Library")
		}
	}

	// Convert result to JSON
	resultJSON, err := json.Marshal(result)
	if err != nil {
		logger.Error("Failed to marshal result to JSON: "+err.Error(), "Library")
		// Return a simple error JSON
		return `{"success": false, "error": "Failed to serialize result"}`
	}

	return string(resultJSON)
}

// GetCurrentStatus returns the current status as JSON string
// This can be called by Flutter to get the current status
func GetCurrentStatus() string {
	statusJSON, err := status.GetCurrentStatusJSON()
	if err != nil {
		logger.Error("Failed to get current status JSON: "+err.Error(), "Library")
		return `{"error": "Failed to get status"}`
	}
	return statusJSON
}

// GetLogs returns recent log entries as JSON string
// This can be called by Flutter to get recent logs
func GetLogs(count int) string {
	if count <= 0 {
		count = 50 // Default to last 50 entries
	}

	entries := logger.GetLogger().GetRecentEntries(count)
	logsJSON, err := json.Marshal(entries)
	if err != nil {
		logger.Error("Failed to marshal logs to JSON: "+err.Error(), "Library")
		return `{"error": "Failed to get logs"}`
	}
	return string(logsJSON)
}

// ClearLogs clears all log entries
func ClearLogs() {
	logger.GetLogger().ClearEntries()
	logger.Info("Logs cleared", "Library")
}

// CancelCurrentScan cancels the currently running scan
func CancelCurrentScan() {
	fastdupefinder.SetCancelled(true)
	logger.Info("Scan cancellation requested", "Library")
}

// GetLastReport returns the cached report from the last successful scan
func GetLastReport() string {
	if lastReport == "" {
		return `{"error": "No report available"}`
	}
	return lastReport
}

// GetVersion returns the version information
func GetVersion() string {
	version := map[string]string{
		"version": "1.0.0",
		"name":    "Fast Duplicate Finder",
	}
	versionJSON, _ := json.Marshal(version)
	return string(versionJSON)
}

// InitializeLibrary initializes the library
// This should be called once when the library is loaded
func InitializeLibrary() {
	// Initialize logger
	log := logger.GetLogger()

	logger.Info("Fast Duplicate Finder library initialized", "Library")

	// The logger will be stopped when the process ends
	// If you need explicit cleanup, you can call log.Stop()
	_ = log
}

// Example of how this might be called from C bindings:
// These functions would be wrapped with C-compatible signatures

/*
//export RunDuplicateFinderC
func RunDuplicateFinderC(rootDir *C.char) *C.char {
	// This is just an example of how the C binding might look
	// The actual implementation would depend on the specific binding tool used
	return nil
}
*/

// For testing purposes, let's add a simple test function
func TestLibrary() {
	fmt.Println("Testing library...")

	// Initialize
	InitializeLibrary()

	// Set a test callback
	SetStatusCallback(func(statusJSON string) {
		fmt.Printf("Status update: %s\n", statusJSON)
	})

	fmt.Println("Library test completed")
}
