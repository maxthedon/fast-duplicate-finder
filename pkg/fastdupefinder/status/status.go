package status

import (
	"encoding/json"
	"sync"
	"time"

	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/logger"
)

// Status represents the current status of the duplicate finder
type Status struct {
	Phase         string    `json:"phase"`
	Progress      float64   `json:"progress"`
	Message       string    `json:"message"`
	FilesFound    int       `json:"files_found"`
	DupesFound    int       `json:"dupes_found"`
	StartTime     time.Time `json:"start_time"`
	ElapsedTime   string    `json:"elapsed_time"`
	CurrentItem   int       `json:"current_item"`
	TotalItems    int       `json:"total_items"`
	DetailMessage string    `json:"detail_message"`
}

// StatusManager manages the current status
type StatusManager struct {
	currentStatus Status
	mutex         sync.RWMutex
	callbacks     []func(Status)
}

var globalStatusManager *StatusManager
var statusOnce sync.Once

// GetStatusManager returns the singleton status manager
func GetStatusManager() *StatusManager {
	statusOnce.Do(func() {
		globalStatusManager = &StatusManager{
			currentStatus: Status{
				Phase:         "idle",
				Progress:      0.0,
				Message:       "Ready",
				StartTime:     time.Now(),
				CurrentItem:   0,
				TotalItems:    0,
				DetailMessage: "",
			},
			callbacks: make([]func(Status), 0),
		}
	})
	return globalStatusManager
}

// UpdateStatus updates the current status and notifies callbacks
func (sm *StatusManager) UpdateStatus(phase string, progress float64, message string, filesFound, dupesFound int) {
	sm.UpdateDetailedStatus(phase, progress, message, filesFound, dupesFound, 0, 0, "")
}

// UpdateDetailedStatus updates the current status with detailed progress information
func (sm *StatusManager) UpdateDetailedStatus(phase string, progress float64, message string, filesFound, dupesFound, currentItem, totalItems int, detailMessage string) {
	sm.mutex.Lock()
	defer sm.mutex.Unlock()

	sm.currentStatus.Phase = phase
	sm.currentStatus.Progress = progress
	sm.currentStatus.Message = message
	sm.currentStatus.FilesFound = filesFound
	sm.currentStatus.DupesFound = dupesFound
	sm.currentStatus.CurrentItem = currentItem
	sm.currentStatus.TotalItems = totalItems
	sm.currentStatus.DetailMessage = detailMessage
	sm.currentStatus.ElapsedTime = time.Since(sm.currentStatus.StartTime).String()

	// Log the status update
	logger.InfoWithData("Status updated", sm.currentStatus, "StatusManager")

	// Notify all callbacks asynchronously
	for _, callback := range sm.callbacks {
		go callback(sm.currentStatus)
	}
}

// GetStatus returns the current status
func (sm *StatusManager) GetStatus() Status {
	sm.mutex.RLock()
	defer sm.mutex.RUnlock()
	return sm.currentStatus
}

// GetStatusJSON returns the current status as JSON
func (sm *StatusManager) GetStatusJSON() (string, error) {
	status := sm.GetStatus()
	jsonData, err := json.Marshal(status)
	if err != nil {
		return "", err
	}
	return string(jsonData), nil
}

// AddCallback adds a callback function for status updates
func (sm *StatusManager) AddCallback(callback func(Status)) {
	sm.mutex.Lock()
	defer sm.mutex.Unlock()
	sm.callbacks = append(sm.callbacks, callback)
}

// Reset resets the status to initial state
func (sm *StatusManager) Reset() {
	sm.mutex.Lock()
	defer sm.mutex.Unlock()

	sm.currentStatus = Status{
		Phase:         "idle",
		Progress:      0.0,
		Message:       "Ready",
		StartTime:     time.Now(),
		CurrentItem:   0,
		TotalItems:    0,
		DetailMessage: "",
	}

	logger.Info("Status reset", "StatusManager")
} // Global convenience functions
func UpdateStatus(phase string, progress float64, message string, filesFound, dupesFound int) {
	GetStatusManager().UpdateStatus(phase, progress, message, filesFound, dupesFound)
}

func UpdateDetailedStatus(phase string, progress float64, message string, filesFound, dupesFound, currentItem, totalItems int, detailMessage string) {
	GetStatusManager().UpdateDetailedStatus(phase, progress, message, filesFound, dupesFound, currentItem, totalItems, detailMessage)
}

func GetCurrentStatus() Status {
	return GetStatusManager().GetStatus()
}

func GetCurrentStatusJSON() (string, error) {
	return GetStatusManager().GetStatusJSON()
}

func AddStatusCallback(callback func(Status)) {
	GetStatusManager().AddCallback(callback)
}

func ResetStatus() {
	GetStatusManager().Reset()
}
