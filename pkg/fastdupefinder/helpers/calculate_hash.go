package helpers

import (
	"fmt"
	"io"
	"os"

	"github.com/cespare/xxhash"
)

// PartialHashSize defines how many bytes to read from the beginning of a file
// for the initial quick hash. 4KB is a common and effective size.
const PartialHashSize = 4096

// CalculateHash computes the SHA256 hash of a file.
// If 'partial' is true, it only reads the first PARTIAL_HASH_SIZE bytes.
func CalculateHash(FilePath string, Partial bool) (string, error) {
	file, err := os.Open(FilePath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	//hash := sha256.New()
	hash := xxhash.New()

	if Partial {
		// Read only the first chunk of the file
		buffer := make([]byte, PartialHashSize)
		_, err := file.Read(buffer)
		if err != nil && err != io.EOF {
			return "", err
		}
		hash.Write(buffer)
	} else {
		// Read the entire file
		if _, err := io.Copy(hash, file); err != nil {
			return "", err
		}
	}

	return fmt.Sprintf("%x", hash.Sum(nil)), nil
}
