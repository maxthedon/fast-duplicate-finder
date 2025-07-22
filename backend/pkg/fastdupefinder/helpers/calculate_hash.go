package helpers

import (
	"fmt"
	"io"
	"os"

	"github.com/cespare/xxhash"
)

// PartialHashSize defines how many bytes to read from each section of a file
// for the initial quick hash. 4KB is a common and effective size.
const PartialHashSize = 4096

// File size thresholds for different hashing strategies
const (
	SmallFileThreshold  = 1 * 1024 * 1024  // 1MB
	MediumFileThreshold = 10 * 1024 * 1024 // 10MB
)

// CalculateHash computes the hash of a file.
// If 'partial' is true, it uses size-based partial hashing:
// - Files < 1MB: hash first 4KB
// - Files < 10MB: hash first and last 4KB
// - Files >= 10MB: hash first, middle, and last 4KB
func CalculateHash(FilePath string, Partial bool) (string, error) {
	file, err := os.Open(FilePath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	hash := xxhash.New()

	if Partial {
		// Get file size to determine hashing strategy
		fileInfo, err := file.Stat()
		if err != nil {
			return "", err
		}
		fileSize := fileInfo.Size()

		if fileSize < SmallFileThreshold {
			// Small files (< 1MB): hash first 4KB only
			buffer := make([]byte, PartialHashSize)
			n, err := file.Read(buffer)
			if err != nil && err != io.EOF {
				return "", err
			}
			hash.Write(buffer[:n])
		} else if fileSize < MediumFileThreshold {
			// Medium files (< 10MB): hash first and last 4KB
			buffer := make([]byte, PartialHashSize)

			// Read first 4KB
			n, err := file.Read(buffer)
			if err != nil && err != io.EOF {
				return "", err
			}
			hash.Write(buffer[:n])

			// Read last 4KB (if file is large enough)
			if fileSize > PartialHashSize {
				lastOffset := fileSize - PartialHashSize
				_, err = file.Seek(lastOffset, io.SeekStart)
				if err != nil {
					return "", err
				}
				n, err = file.Read(buffer)
				if err != nil && err != io.EOF {
					return "", err
				}
				hash.Write(buffer[:n])
			}
		} else {
			// Large files (>= 10MB): hash first, middle, and last 4KB
			buffer := make([]byte, PartialHashSize)

			// Read first 4KB
			n, err := file.Read(buffer)
			if err != nil && err != io.EOF {
				return "", err
			}
			hash.Write(buffer[:n])

			// Read middle 4KB
			middleOffset := (fileSize / 2) - (PartialHashSize / 2)
			_, err = file.Seek(middleOffset, io.SeekStart)
			if err != nil {
				return "", err
			}
			n, err = file.Read(buffer)
			if err != nil && err != io.EOF {
				return "", err
			}
			hash.Write(buffer[:n])

			// Read last 4KB
			lastOffset := fileSize - PartialHashSize
			_, err = file.Seek(lastOffset, io.SeekStart)
			if err != nil {
				return "", err
			}
			n, err = file.Read(buffer)
			if err != nil && err != io.EOF {
				return "", err
			}
			hash.Write(buffer[:n])
		}
	} else {
		// Read the entire file for full hash
		if _, err := io.Copy(hash, file); err != nil {
			return "", err
		}
	}

	return fmt.Sprintf("%x", hash.Sum(nil)), nil
}
