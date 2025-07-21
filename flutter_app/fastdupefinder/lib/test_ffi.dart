import 'dart:io';
import 'services/fast_dupe_finder_service.dart';
import 'models/scan_progress.dart';

void main() async {
  print('=== Testing FFI Integration ===');
  
  try {
    final service = FastDupeFinderService();
    
    // Test basic functionality
    print('1. Service initialized successfully');
    
    // Test a small directory scan
    final testDir = '/home/maxthedon/Desktop/TestData';
    
    if (await Directory(testDir).exists()) {
      print('2. Starting scan of: $testDir');
      
      await service.startScan(testDir, (ScanProgress progress) {
        print('Progress: ${progress.phaseDescription} - ${(progress.progressPercentage * 100).toInt()}%');
      });
      
      // Get results
      final results = await service.getResults();
      print('3. Scan completed!');
      print('   - Duplicate groups found: ${results.duplicateGroups.length}');
      print('   - Total wasted space: ${results.totalWastedSpace} bytes');
      print('   - Scanned path: ${results.scannedPath}');
      
      for (var group in results.duplicateGroups.take(3)) {
        print('   - ${group.fileName} (${group.duplicateCount} duplicates, ${group.fileSize} bytes)');
      }
    } else {
      print('2. Test directory does not exist: $testDir');
      print('   Creating a temporary test instead...');
      
      // Create a temporary directory with some test files
      final tempDir = Directory.systemTemp.createTempSync('ffi_test_');
      
      // Create some duplicate files
      final file1 = File('${tempDir.path}/file1.txt');
      final file2 = File('${tempDir.path}/file2.txt');
      await file1.writeAsString('Hello World');
      await file2.writeAsString('Hello World');
      
      print('   Created test files in: ${tempDir.path}');
      
      await service.startScan(tempDir.path, (ScanProgress progress) {
        print('Progress: ${progress.phaseDescription} - ${(progress.progressPercentage * 100).toInt()}%');
      });
      
      final results = await service.getResults();
      print('3. Scan completed!');
      print('   - Duplicate groups found: ${results.duplicateGroups.length}');
      print('   - Total wasted space: ${results.totalWastedSpace} bytes');
      
      // Cleanup
      await tempDir.delete(recursive: true);
    }
    
    print('✅ FFI integration test completed successfully!');
    
  } catch (e, stackTrace) {
    print('❌ FFI integration test failed: $e');
    print('Stack trace: $stackTrace');
  }
}
