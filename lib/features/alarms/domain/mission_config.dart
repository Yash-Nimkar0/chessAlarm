/// Typed mission configuration, replacing string-based mission identification.
///
/// This replaces the old pattern where mission type was passed as raw strings
/// ('math', 'memory', etc.) throughout the app. Using an enum prevents typos,
/// enables exhaustive switch checks, and makes the valid set of missions explicit.

enum MissionType {
  math,
  memory,
  typing,
  colorTiles,
  missingSymbol,
  shake,
  qr,
  steps,
  none;

  /// Convert from the legacy string representation used in MissionSettings.
  static MissionType fromString(String value) {
    switch (value) {
      case 'math':
        return MissionType.math;
      case 'memory':
        return MissionType.memory;
      case 'typing':
        return MissionType.typing;
      case 'color_tiles':
        return MissionType.colorTiles;
      case 'missing_symbol':
        return MissionType.missingSymbol;
      case 'shake':
        return MissionType.shake;
      case 'qr':
        return MissionType.qr;
      case 'steps':
        return MissionType.steps;
      case 'none':
        return MissionType.none;
      default:
        return MissionType.none; // Safe default — matches old behavior
    }
  }

  /// Convert to the legacy string representation for backward compatibility.
  String toStringValue() {
    switch (this) {
      case MissionType.math:
        return 'math';
      case MissionType.memory:
        return 'memory';
      case MissionType.typing:
        return 'typing';
      case MissionType.colorTiles:
        return 'color_tiles';
      case MissionType.missingSymbol:
        return 'missing_symbol';
      case MissionType.shake:
        return 'shake';
      case MissionType.qr:
        return 'qr';
      case MissionType.steps:
        return 'steps';
      case MissionType.none:
        return 'none';
    }
  }

  /// Human-readable display name for UI.
  String get displayName {
    switch (this) {
      case MissionType.math:
        return 'Math';
      case MissionType.memory:
        return 'Memory';
      case MissionType.typing:
        return 'Typing';
      case MissionType.colorTiles:
        return 'Color Tiles';
      case MissionType.missingSymbol:
        return 'Missing Symbol';
      case MissionType.shake:
        return 'Shake';
      case MissionType.qr:
        return 'QR / Barcode';
      case MissionType.steps:
        return 'Steps';
      case MissionType.none:
        return 'None';
    }
  }
}

/// Typed mission configuration.
///
/// Separates mission-specific data from alarm-level data. The old [MissionSettings]
/// class conflated alarm type (wakeRoutine/quickAlarm) with mission config —
/// this class holds only mission-specific configuration.
class MissionConfig {
  final MissionType type;
  final String difficultyMode;
  final int? difficultyOverride;
  final int rounds;
  final Map<String, dynamic>? data;

  const MissionConfig({
    this.type = MissionType.none,
    this.difficultyMode = 'adaptive',
    this.difficultyOverride,
    this.rounds = 1,
    this.data,
  });

  MissionConfig copyWith({
    MissionType? type,
    String? difficultyMode,
    int? difficultyOverride,
    int? rounds,
    Map<String, dynamic>? data,
  }) {
    return MissionConfig(
      type: type ?? this.type,
      difficultyMode: difficultyMode ?? this.difficultyMode,
      difficultyOverride: difficultyOverride ?? this.difficultyOverride,
      rounds: rounds ?? this.rounds,
      data: data ?? this.data,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toStringValue(),
      'difficultyMode': difficultyMode,
      'difficultyOverride': difficultyOverride,
      'rounds': rounds,
      'data': data,
    };
  }

  factory MissionConfig.fromJson(Map<String, dynamic> json) {
    return MissionConfig(
      type: MissionType.fromString(json['type'] as String? ?? 'memory'),
      difficultyMode: json['difficultyMode'] as String? ?? 'adaptive',
      difficultyOverride: json['difficultyOverride'] as int?,
      rounds: json['rounds'] as int? ?? 1,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MissionConfig &&
        other.type == type &&
        other.difficultyMode == difficultyMode &&
        other.difficultyOverride == difficultyOverride &&
        other.rounds == rounds;
  }

  @override
  int get hashCode => Object.hash(type, difficultyMode, difficultyOverride, rounds);

  @override
  String toString() => 'MissionConfig(type: $type, difficulty: $difficultyMode, rounds: $rounds)';
}
