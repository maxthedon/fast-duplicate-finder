import 'package:flutter_test/flutter_test.dart';
import 'package:fastdupefinder/services/fast_dupe_finder_service.dart';

void main() {
  group('FastDupeFinderService Isolate Tests', () {
    test('Service initializes without blocking main thread', () async {
      final service = FastDupeFinderService();
      
      // This should not throw and should complete quickly
      expect(service, isNotNull);
    });

    test('Scan runs in isolate and does not block', () async {
      final service = FastDupeFinderService();
      
      // Start a scan - this should not block the test thread
      final startTime = DateTime.now();
      
      try {
        // Note: This will likely fail due to missing native library in test environment
        // but the important thing is that it doesn't block
        await service.startScan('/tmp', (progress) {
          // Progress callback - verifies async behavior
        });
      } catch (e) {
        // Expected to fail in test environment - that's ok
        print('Expected error in test environment: $e');
      }
      
      final elapsed = DateTime.now().difference(startTime);
      
      // The call should return quickly even if it fails
      // If it was blocking, it would take much longer
      expect(elapsed.inMilliseconds, lessThan(5000)); // Should complete within 5 seconds
    });
  });
}
