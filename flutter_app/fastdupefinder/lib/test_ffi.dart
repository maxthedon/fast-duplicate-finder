import 'dart:io';
import 'services/fast_dupe_finder_service.dart';
import 'models/scan_progress.dart';
import 'utils/logger.dart';

void main() async {
  Logger.log('=== Testing FFI Integration ===');
  
  try {
    final service = FastDupeFinderService();
    
    // Test basic functionality
    Logger.log('1. Service initialized successfully');
    
    // Test a small directory scan
    final testDir = '/home/maxthedon/Desktop/TestData';
    
    if (await Directory(testDir).exists()) {
      Logger.log('2. Starting scan of: $testDir');
      
      await service.startScan(testDir, (ScanProgress progress) {
        Logger.log('Progress: ${progress.phaseDescription} - ${(progress.progressPercentage * 100).toInt()}%');
      });
      
      // Get results
      final results = await service.getResults();
      Logger.log('3. Scan completed!');
      Logger.log('   - Duplicate groups found: ${results.duplicateGroups.length}');
      Logger.log('   - Total wasted space: ${results.totalWastedSpace} bytes');
      Logger.log('   - Scanned path: ${results.scannedPath}');
      
      for (var group in results.duplicateGroups.take(3)) {
        Logger.log('   - ${group.fileName} (${group.duplicateCount} duplicates, ${group.fileSize} bytes)');
      }
    } else {
      Logger.log('2. Test directory does not exist: $testDir');
      Logger.log('   Creating a temporary test instead...');
      
      // Create a temporary directory with some test files
      final tempDir = Directory.systemTemp.createTempSync('ffi_test_');
      
      // Create some duplicate files
      final file1 = File('${tempDir.path}/file1.txt');
      final file2 = File('${tempDir.path}/file2.txt');
      await file1.writeAsString('Hello World');
      await file2.writeAsString('Hello World');
      
      Logger.log('   Created test files in: ${tempDir.path}');
      
      await service.startScan(tempDir.path, (ScanProgress progress) {
        Logger.log('Progress: ${progress.phaseDescription} - ${(progress.progressPercentage * 100).toInt()}%');
      });
      
      final results = await service.getResults();
      Logger.log('3. Scan completed!');
      Logger.log('   - Duplicate groups found: ${results.duplicateGroups.length}');
      Logger.log('   - Total wasted space: ${results.totalWastedSpace} bytes');
      
      // Cleanup
      await tempDir.delete(recursive: true);
    }
    
    Logger.log('✅ FFI integration test completed successfully!');
    
  } catch (e, stackTrace) {
    Logger.log('❌ FFI integration test failed: $e');
    Logger.log('Stack trace: $stackTrace');
  }
}
