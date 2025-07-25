class Settings {
  final int? cpuCores;
  final bool useAutoCpuDetection;

  const Settings({
    this.cpuCores,
    this.useAutoCpuDetection = true,
  });

  Settings copyWith({
    int? cpuCores,
    bool? useAutoCpuDetection,
  }) {
    return Settings(
      cpuCores: cpuCores ?? this.cpuCores,
      useAutoCpuDetection: useAutoCpuDetection ?? this.useAutoCpuDetection,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cpuCores': cpuCores,
      'useAutoCpuDetection': useAutoCpuDetection,
    };
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      cpuCores: json['cpuCores'] as int?,
      useAutoCpuDetection: json['useAutoCpuDetection'] as bool? ?? true,
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
