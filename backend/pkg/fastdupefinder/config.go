package fastdupefinder

// Phase1Config represents the configuration options for the duplicate finder
type Phase1Config struct {
	// CpuCores specifies the number of CPU cores to use for processing
	// If 0 or negative, auto-detection will be used
	CpuCores int `json:"cpuCores"`

	// FilterByFilename determines if files should be grouped by both size and filename in Phase 1
	// When true, only files with the same size AND filename will be considered potential duplicates
	// When false (default), files are grouped only by size
	FilterByFilename bool `json:"filterByFilename"`
}

// DefaultConfig returns a Config with default values
func DefaultConfig() Phase1Config {
	return Phase1Config{
		CpuCores:         0,     // Auto-detect
		FilterByFilename: false, // Disabled by default
	}
}

// WithCpuCores returns a new Config with the specified CPU cores
func (c Phase1Config) WithCpuCores(cpuCores int) Phase1Config {
	c.CpuCores = cpuCores
	return c
}

// WithFilenameFilter returns a new Config with filename filtering enabled/disabled
func (c Phase1Config) WithFilenameFilter(enabled bool) Phase1Config {
	c.FilterByFilename = enabled
	return c
}
