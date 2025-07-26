class Settings {
  final int? cpuCores;
  final bool useAutoCpuDetection;
  final bool filterByFilename;

  const Settings({
    this.cpuCores,
    this.useAutoCpuDetection = true,
    this.filterByFilename = false,
  });

  Settings copyWith({
    int? cpuCores,
    bool? useAutoCpuDetection,
    bool? filterByFilename,
  }) {
    return Settings(
      cpuCores: cpuCores ?? this.cpuCores,
      useAutoCpuDetection: useAutoCpuDetection ?? this.useAutoCpuDetection,
      filterByFilename: filterByFilename ?? this.filterByFilename,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cpuCores': cpuCores,
      'useAutoCpuDetection': useAutoCpuDetection,
      'filterByFilename': filterByFilename,
    };
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      cpuCores: json['cpuCores'] as int?,
      useAutoCpuDetection: json['useAutoCpuDetection'] as bool? ?? true,
      filterByFilename: json['filterByFilename'] as bool? ?? false,
    );
  }

  /// Get the effective number of CPU cores to use
  /// Returns null if auto-detection should be used
  int? getEffectiveCpuCores() {
    if (useAutoCpuDetection) {
      return null; // Let the backend decide
    }
    return cpuCores;
  }

  /// Get display text for current CPU setting
  String getCpuDisplayText() {
    if (useAutoCpuDetection) {
      return 'Auto';
    }
    return cpuCores?.toString() ?? 'Auto';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Settings &&
        other.cpuCores == cpuCores &&
        other.useAutoCpuDetection == useAutoCpuDetection;
  }

  @override
  int get hashCode {
    return cpuCores.hashCode ^ useAutoCpuDetection.hashCode;
  }

  @override
  String toString() {
    return 'Settings(cpuCores: $cpuCores, useAutoCpuDetection: $useAutoCpuDetection)';
  }
}
