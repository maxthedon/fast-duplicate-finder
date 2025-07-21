// This is a basic Flutter widget test for Fast Duplicate Finder app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fastdupefinder/main.dart';
import 'package:fastdupefinder/providers/scan_provider.dart';

void main() {
  testWidgets('App launches and shows splash screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FastDupeFinderApp());

    // Verify that we can see the app name on splash screen
    expect(find.text('Fast Duplicate Finder'), findsOneWidget);
    
    // Verify that we can see the loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    // Wait for the splash screen timer to complete (3 seconds)
    await tester.pumpAndSettle(const Duration(seconds: 4));
    
    // After splash, we should be on the home screen
    expect(find.text('Select Root Folder:'), findsOneWidget);
  });

  testWidgets('ScanProvider initializes correctly', (WidgetTester tester) async {
    // Test that the provider initializes with correct default values
    final scanProvider = ScanProvider();
    
    expect(scanProvider.selectedPath, isNull);
    expect(scanProvider.isScanning, isFalse);
    expect(scanProvider.canStartScan, isFalse);
    expect(scanProvider.hasResults, isFalse);
    
    scanProvider.dispose();
  });

  testWidgets('ScanProvider path selection works', (WidgetTester tester) async {
    final scanProvider = ScanProvider();
    
    // Test setting a path
    scanProvider.setSelectedPath('/test/path');
    expect(scanProvider.selectedPath, equals('/test/path'));
    expect(scanProvider.canStartScan, isTrue);
    
    // Test clearing the path
    scanProvider.setSelectedPath(null);
    expect(scanProvider.selectedPath, isNull);
    expect(scanProvider.canStartScan, isFalse);
    
    scanProvider.dispose();
  });
}
