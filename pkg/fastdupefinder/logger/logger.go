package logger

import (
	"encoding/json"
	"fmt"
	"sync"
	"time"
)

// LogLevel represents the severity of a log entry
type LogLevel int

const (
	DEBUG LogLevel = iota
	INFO
	WARN
	ERROR
	FATAL
)

var logLevelNames = map[LogLevel]string{
	DEBUG: "DEBUG",
	INFO:  "INFO",
	WARN:  "WARN",
	ERROR: "ERROR",
	FATAL: "FATAL",
}

// LogEntry represents a single log entry
type LogEntry struct {
	Timestamp time.Time `json:"timestamp"`
	Level     LogLevel  `json:"level"`
	Message   string    `json:"message"`
	Context   string    `json:"context,omitempty"`
	Data      any       `json:"data,omitempty"`
}

// Logger is the main logger struct
type Logger struct {
	entries    []LogEntry
	maxEntries int
	mutex      sync.RWMutex
	logChan    chan LogEntry
	done       chan bool
	callbacks  []func(LogEntry)
}

var globalLogger *Logger
var once sync.Once

// GetLogger returns the singleton logger instance
func GetLogger() *Logger {
	once.Do(func() {
		globalLogger = NewLogger(1000) // Keep last 1000 log entries
		globalLogger.Start()
	})
	return globalLogger
}

// NewLogger creates a new logger instance
func NewLogger(maxEntries int) *Logger {
	return &Logger{
		entries:    make([]LogEntry, 0),
		maxEntries: maxEntries,
		logChan:    make(chan LogEntry, 100), // Buffer for async logging
		done:       make(chan bool),
		callbacks:  make([]func(LogEntry), 0),
	}
}

// Start begins the async logging goroutine
func (l *Logger) Start() {
	go func() {
		for {
			select {
			case entry := <-l.logChan:
				l.addEntry(entry)
				// Notify all callbacks
				for _, callback := range l.callbacks {
					go callback(entry) // Execute callbacks asynchronously
				}
			case <-l.done:
				return
			}
		}
	}()
}

// Stop stops the logger
func (l *Logger) Stop() {
	close(l.done)
}

// addEntry adds an entry to the log history (thread-safe)
func (l *Logger) addEntry(entry LogEntry) {
	l.mutex.Lock()
	defer l.mutex.Unlock()

	l.entries = append(l.entries, entry)

	// Keep only the last maxEntries entries
	if len(l.entries) > l.maxEntries {
		l.entries = l.entries[len(l.entries)-l.maxEntries:]
	}
}

// log is the internal logging method
func (l *Logger) log(level LogLevel, message string, context string, data any) {
	entry := LogEntry{
		Timestamp: time.Now(),
		Level:     level,
		Message:   message,
		Context:   context,
		Data:      data,
	}

	// Send to channel for async processing
	select {
	case l.logChan <- entry:
	default:
		// Channel is full, log synchronously to avoid blocking
		l.addEntry(entry)
	}
}

// Debug logs a debug message
func (l *Logger) Debug(message string, context ...string) {
	ctx := ""
	if len(context) > 0 {
		ctx = context[0]
	}
	l.log(DEBUG, message, ctx, nil)
}

// Info logs an info message
func (l *Logger) Info(message string, context ...string) {
	ctx := ""
	if len(context) > 0 {
		ctx = context[0]
	}
	l.log(INFO, message, ctx, nil)
}

// Warn logs a warning message
func (l *Logger) Warn(message string, context ...string) {
	ctx := ""
	if len(context) > 0 {
		ctx = context[0]
	}
	l.log(WARN, message, ctx, nil)
}

// Error logs an error message
func (l *Logger) Error(message string, context ...string) {
	ctx := ""
	if len(context) > 0 {
		ctx = context[0]
	}
	l.log(ERROR, message, ctx, nil)
}

// Fatal logs a fatal message
func (l *Logger) Fatal(message string, context ...string) {
	ctx := ""
	if len(context) > 0 {
		ctx = context[0]
	}
	l.log(FATAL, message, ctx, nil)
}

// InfoWithData logs an info message with additional data
func (l *Logger) InfoWithData(message string, data any, context ...string) {
	ctx := ""
	if len(context) > 0 {
		ctx = context[0]
	}
	l.log(INFO, message, ctx, data)
}

// ErrorWithData logs an error message with additional data
func (l *Logger) ErrorWithData(message string, data any, context ...string) {
	ctx := ""
	if len(context) > 0 {
		ctx = context[0]
	}
	l.log(ERROR, message, ctx, data)
}

// GetEntries returns all log entries (thread-safe)
func (l *Logger) GetEntries() []LogEntry {
	l.mutex.RLock()
	defer l.mutex.RUnlock()

	// Return a copy to avoid race conditions
	entries := make([]LogEntry, len(l.entries))
	copy(entries, l.entries)
	return entries
}

// GetEntriesJSON returns all log entries as JSON
func (l *Logger) GetEntriesJSON() (string, error) {
	entries := l.GetEntries()
	jsonData, err := json.Marshal(entries)
	if err != nil {
		return "", err
	}
	return string(jsonData), nil
}

// GetRecentEntries returns the last n log entries
func (l *Logger) GetRecentEntries(n int) []LogEntry {
	l.mutex.RLock()
	defer l.mutex.RUnlock()

	if n >= len(l.entries) {
		entries := make([]LogEntry, len(l.entries))
		copy(entries, l.entries)
		return entries
	}

	start := len(l.entries) - n
	entries := make([]LogEntry, n)
	copy(entries, l.entries[start:])
	return entries
}

// AddCallback adds a callback function that will be called for each new log entry
func (l *Logger) AddCallback(callback func(LogEntry)) {
	l.mutex.Lock()
	defer l.mutex.Unlock()
	l.callbacks = append(l.callbacks, callback)
}

// ClearEntries clears all log entries
func (l *Logger) ClearEntries() {
	l.mutex.Lock()
	defer l.mutex.Unlock()
	l.entries = l.entries[:0]
}

// String method for LogLevel
func (ll LogLevel) String() string {
	if name, ok := logLevelNames[ll]; ok {
		return name
	}
	return fmt.Sprintf("UNKNOWN(%d)", ll)
}

// MarshalJSON for LogLevel
func (ll LogLevel) MarshalJSON() ([]byte, error) {
	return json.Marshal(ll.String())
}

// Global convenience functions
func Debug(message string, context ...string) {
	GetLogger().Debug(message, context...)
}

func Info(message string, context ...string) {
	GetLogger().Info(message, context...)
}

func Warn(message string, context ...string) {
	GetLogger().Warn(message, context...)
}

func Error(message string, context ...string) {
	GetLogger().Error(message, context...)
}

func Fatal(message string, context ...string) {
	GetLogger().Fatal(message, context...)
}

func InfoWithData(message string, data any, context ...string) {
	GetLogger().InfoWithData(message, data, context...)
}

func ErrorWithData(message string, data any, context ...string) {
	GetLogger().ErrorWithData(message, data, context...)
}
