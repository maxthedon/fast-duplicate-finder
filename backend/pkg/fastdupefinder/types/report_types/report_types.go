package reporttypes

// --- JSON Output Structures ---

// ReportOutput is the top-level structure for the final JSON report.
// Optimized for minimal memory usage while maintaining essential functionality.
type ReportOutput struct {
	Summary          SummaryInfo `json:"summary"`
	FileDuplicates   []FileSet   `json:"fileDuplicates"`
	FolderDuplicates []FolderSet `json:"folderDuplicates"`
}

// SummaryInfo provides essential counts of the findings.
// Reduced to only the most important metrics.
type SummaryInfo struct {
	FileSets         int   `json:"fileSets"`         // Number of duplicate file sets found
	FolderSets       int   `json:"folderSets"`       // Number of duplicate folder sets found
	WastedSpaceBytes int64 `json:"wastedSpaceBytes"` // Total wasted space in bytes
}

// FileSet represents a single group of identical files.
// Hash truncated to 12 characters to save memory (sufficient for display).
type FileSet struct {
	Hash      string   `json:"hash"`      // Truncated to 12 characters
	Paths     []string `json:"paths"`     // Full paths to duplicate files
	SizeBytes int64    `json:"sizeBytes"` // Size of each file in bytes
}

// FolderSet represents a single group of identical folders.
// Signature truncated to 12 characters to save memory.
type FolderSet struct {
	Signature string   `json:"signature"` // Truncated to 12 characters
	Paths     []string `json:"paths"`     // Full paths to duplicate folders
	SizeBytes int64    `json:"sizeBytes"` // Size of each folder in bytes
}
