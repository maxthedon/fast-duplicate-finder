package main

import (
	"fmt"
	"time"

	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/library"
)

func main() {
	fmt.Println("=== Fast Duplicate Finder Library Test ===")

	// Initialize the library
	library.InitializeLibrary()

	// Set up status callback
	library.SetStatusCallback(func(statusJSON string) {
		fmt.Printf("📊 Status Update: %s\n", statusJSON)
	})

	// Get version info
	fmt.Printf("🔧 Version: %s\n", library.GetVersion())

	// Test directory
	testDir := "/home/maxthedon/Desktop/TestData"

	fmt.Printf("🔍 Running duplicate finder on: %s\n", testDir) // Run the duplicate finder
	result := library.RunDuplicateFinder(testDir)
	fmt.Printf("📋 Result: %s\n", result)

	// Get current status
	fmt.Printf("📈 Current Status: %s\n", library.GetCurrentStatus())

	// Get recent logs
	fmt.Printf("📝 Recent Logs: %s\n", library.GetLogs(10))

	// Wait a moment to let async operations complete
	time.Sleep(100 * time.Millisecond)

	fmt.Println("✅ Library test completed!")
}
