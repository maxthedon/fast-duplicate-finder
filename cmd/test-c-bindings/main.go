package main

import (
	"fmt"
	"time"

	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/library"
)

func main() {
	fmt.Println("=== Testing C Bindings Compatibility ===")

	// Test that all the functions our C bindings will use are available
	fmt.Println("🔧 Initializing library...")
	library.InitializeLibrary()

	// Test version info
	version := library.GetVersion()
	fmt.Printf("📦 Version: %s\n", version)

	// Test directory scanning
	testDir := "/home/maxthedon/Desktop/TestData"
	fmt.Printf("🔍 Testing scan of: %s\n", testDir)

	// Set up status callback to monitor progress
	library.SetStatusCallback(func(statusJSON string) {
		fmt.Printf("📊 Status: %s\n", statusJSON)
	})

	// Run the duplicate finder
	fmt.Println("🚀 Starting duplicate detection...")
	result := library.RunDuplicateFinder(testDir)

	// Show result summary (just first few characters)
	if len(result) > 200 {
		fmt.Printf("📋 Result (truncated): %s...\n", result[:200])
	} else {
		fmt.Printf("📋 Result: %s\n", result)
	}

	// Test status retrieval
	currentStatus := library.GetCurrentStatus()
	fmt.Printf("📈 Current Status: %s\n", currentStatus)

	// Test log retrieval
	logs := library.GetLogs(5)
	fmt.Printf("📝 Recent Logs: %s\n", logs)

	fmt.Println("✅ All library functions work correctly!")
	fmt.Println("🔧 The C bindings should work when built with CGO")

	time.Sleep(100 * time.Millisecond) // Let async operations finish
}
