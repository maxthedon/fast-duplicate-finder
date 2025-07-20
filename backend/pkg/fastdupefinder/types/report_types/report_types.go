package reporttypes

// --- JSON Output Structures ---

// ReportOutput is the top-level structure for the final JSON report.
type ReportOutput struct {
	Summary          SummaryInfo           `json:"summary"`
	FileDuplicates   FileDuplicateReport   `json:"fileDuplicates"`
	FolderDuplicates FolderDuplicateReport `json:"folderDuplicates"`
	RawData          *RawDataReport        `json:"rawData,omitempty"` // Pointer to omit if empty
}

// SummaryInfo provides high-level counts of the findings.
type SummaryInfo struct {
	TotalAllFileSets   int   `json:"totalAllFileSets"`
	TotalAllFolderSets int   `json:"totalAllFolderSets"`
	TopLevelFolderSets int   `json:"topLevelFolderSets"`
	StandaloneFileSets int   `json:"standaloneFileSets"`
	WastedSpaceBytes   int64 `json:"wastedSpaceBytes"`
}

// FileDuplicateReport contains a list of duplicate file sets.
type FileDuplicateReport struct {
	Description string    `json:"description"`
	Sets        []FileSet `json:"sets"`
}

// FolderDuplicateReport contains a list of duplicate folder sets.
type FolderDuplicateReport struct {
	Description string      `json:"description"`
	Sets        []FolderSet `json:"sets"`
}

// FileSet represents a single group of identical files.
type FileSet struct {
	Hash      string   `json:"hash"`
	Paths     []string `json:"paths"`
	SizeBytes int64    `json:"sizeBytes"`
}

// FolderSet represents a single group of identical folders.
type FolderSet struct {
	Signature string   `json:"signature"`
	Paths     []string `json:"paths"`
}

// RawDataReport contains the unfiltered, complete results for detailed analysis.
type RawDataReport struct {
	AllFileDuplicates   FileDuplicateReport   `json:"allFileDuplicates"`
	AllFolderDuplicates FolderDuplicateReport `json:"allFolderDuplicates"`
}
