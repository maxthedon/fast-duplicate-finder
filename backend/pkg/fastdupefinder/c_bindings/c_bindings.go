package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"encoding/json"
	"unsafe"

	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/library"
	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/logger"
	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/status"
)

// Global callback function pointer for status updates
var globalStatusCallback unsafe.Pointer

//export InitializeLibraryC
func InitializeLibraryC() {
	library.InitializeLibrary()
}

//export RunDuplicateFinderC
func RunDuplicateFinderC(rootDir *C.char) *C.char {
	return RunDuplicateFinderWithConfigC(rootDir, 0) // 0 means auto-detect
}

//export RunDuplicateFinderWithConfigC
func RunDuplicateFinderWithConfigC(rootDir *C.char, cpuCores C.int) *C.char {
	goRootDir := C.GoString(rootDir)
	result := library.RunDuplicateFinderWithConfig(goRootDir, int(cpuCores))
	return C.CString(result)
}

//export GetCurrentStatusC
func GetCurrentStatusC() *C.char {
	result := library.GetCurrentStatus()
	return C.CString(result)
}

//export GetVersionC
func GetVersionC() *C.char {
	result := library.GetVersion()
	return C.CString(result)
}

//export GetLogsC
func GetLogsC(count C.int) *C.char {
	result := library.GetLogs(int(count))
	return C.CString(result)
}

//export ClearLogsC
func ClearLogsC() {
	logger.GetLogger().ClearEntries()
}

//export FreeStringC
func FreeStringC(ptr *C.char) {
	C.free(unsafe.Pointer(ptr))
}

// Status callback management

//export SetStatusCallbackC
func SetStatusCallbackC(callback unsafe.Pointer) {
	globalStatusCallback = callback

	if callback != nil {
		// Set up the Go callback that will call the C callback
		library.SetStatusCallback(func(statusJSON string) {
			if globalStatusCallback != nil {
				statusCStr := C.CString(statusJSON)
				// Call the C callback function
				callCStatusCallback(globalStatusCallback, statusCStr)
				C.free(unsafe.Pointer(statusCStr))
			}
		})
	} else {
		// Clear the callback
		library.SetStatusCallback(nil)
	}
}

//export RemoveStatusCallbackC
func RemoveStatusCallbackC() {
	globalStatusCallback = nil
	library.SetStatusCallback(nil)
}

// Mobile-specific functions

//export RunDuplicateFinderMobileC
func RunDuplicateFinderMobileC(rootDir *C.char, maxWorkers C.int, reducedLogging C.int, lowMemoryMode C.int) *C.char {
	goRootDir := C.GoString(rootDir)

	// Configure for mobile if requested
	if reducedLogging != 0 {
		logger.GetLogger().ClearEntries()
	}

	// For now, use the standard function - can be enhanced later with mobile-specific optimizations
	result := library.RunDuplicateFinder(goRootDir)
	return C.CString(result)
}

//export GetMobileConfigC
func GetMobileConfigC() *C.char {
	config := map[string]interface{}{
		"max_workers":     4, // Conservative for mobile
		"reduced_logging": true,
		"low_memory_mode": true,
		"recommended_settings": map[string]interface{}{
			"use_worker_limit":            true,
			"clear_logs_frequently":       true,
			"progress_update_interval_ms": 500,
		},
	}

	jsonData, err := json.Marshal(config)
	if err != nil {
		return C.CString(`{"error": "failed to generate mobile config"}`)
	}

	return C.CString(string(jsonData))
}

// Utility functions for error handling

//export GetLastErrorC
func GetLastErrorC() *C.char {
	// This could be enhanced to track the last error
	// For now, return empty string
	return C.CString("")
}

//export IsRunningC
func IsRunningC() C.int {
	currentStatus := status.GetCurrentStatus()
	if currentStatus.Phase == "completed" || currentStatus.Phase == "idle" {
		return 0 // Not running
	}
	return 1 // Running
}

//export CancelScanC
func CancelScanC() {
	// Set the cancellation flag in phase 5
	// This is a new function that needs to be exposed
	if IsRunningC() != 0 {
		// Import the phase 5 package function to set cancelled
		library.CancelCurrentScan()
	}
}

//export GetLastReportC
func GetLastReportC() *C.char {
	result := library.GetLastReport()
	return C.CString(result)
}

// C callback helper function - this will be implemented on the C side
// but we need to declare it here for Go to call it
func callCStatusCallback(callback unsafe.Pointer, status *C.char) {
	// This function will be implemented in C and linked
	// For now, it's just a placeholder
}

// Required main function for building as C shared library
func main() {}
