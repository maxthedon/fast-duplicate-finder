import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/settings.dart';

class SettingsProvider extends ChangeNotifier {
  Settings _settings = const Settings();
  bool _isLoading = true;
  String? _settingsFilePath;

  Settings get settings => _settings;
  bool get isLoading => _isLoading;

  /// Initialize the settings provider and load saved settings
  Future<void> initialize() async {
    try {
      await _loadSettings();
    } catch (e) {
      debugPrint('Error loading settings: $e');
      // Use default settings if loading fails
      _settings = const Settings();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update CPU cores setting
  Future<void> updateCpuCores(int? cores, {bool useAuto = false}) async {
    _settings = _settings.copyWith(
      cpuCores: cores,
      useAutoCpuDetection: useAuto,
    );
    await _saveSettings();
    notifyListeners();
  }

  /// Reset to auto CPU detection
  Future<void> setAutoCpuDetection() async {
    _settings = _settings.copyWith(useAutoCpuDetection: true);
    await _saveSettings();
    notifyListeners();
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _settings = const Settings();
    await _saveSettings();
    notifyListeners();
  }

  /// Get the settings file path
  Future<String> _getSettingsFilePath() async {
    if (_settingsFilePath != null) {
      return _settingsFilePath!;
    }

    final directory = await getApplicationDocumentsDirectory();
    final appDir = Directory('${directory.path}/FastDupeFinder');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    
    _settingsFilePath = '${appDir.path}/settings.json';
    return _settingsFilePath!;
  }

  /// Load settings from file
  Future<void> _loadSettings() async {
    try {
      final filePath = await _getSettingsFilePath();
      final file = File(filePath);
      
      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;
        _settings = Settings.fromJson(json);
      } else {
        _settings = const Settings();
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      _settings = const Settings();
    }
  }

  /// Save settings to file
  Future<void> _saveSettings() async {
    try {
      final filePath = await _getSettingsFilePath();
      final file = File(filePath);
      final json = jsonEncode(_settings.toJson());
      await file.writeAsString(json);
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }
}
