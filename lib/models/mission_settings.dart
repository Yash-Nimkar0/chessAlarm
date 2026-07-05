import 'dart:convert';

enum MissionType {
  chess,
  math,
  memory,
  none,
}

class MissionSettings {
  final String type; // "wakeRoutine" or "quickAlarm"
  final int version;
  final double sleepGoal;
  final String mission; // "chess"
  final bool sleepTracking;
  final bool sleepSounds;
  final String createdAt;
  final String difficultyMode;
  
  final bool smartLock;
  final int? difficultyOverride;

  MissionSettings({
    this.type = "quickAlarm",
    this.version = 1,
    this.sleepGoal = 8.0,
    this.mission = "chess",
    this.sleepTracking = true,
    this.sleepSounds = true,
    String? createdAt,
    this.difficultyMode = "adaptive",
    this.smartLock = true,
    this.difficultyOverride,
  }) : this.createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'version': version,
      'sleepGoal': sleepGoal,
      'mission': mission,
      'sleepTracking': sleepTracking,
      'sleepSounds': sleepSounds,
      'createdAt': createdAt,
      'difficultyMode': difficultyMode,
      'smartLock': smartLock,
      'difficultyOverride': difficultyOverride,
    };
  }

  factory MissionSettings.fromJson(Map<String, dynamic> json) {
    // Handle legacy conversion
    String typeStr = json['type'] ?? 'quickAlarm';
    if (typeStr == 'chess') {
        typeStr = 'wakeRoutine'; // Assume old chess missions were wake routines
    }
    
    return MissionSettings(
      type: typeStr,
      version: json['version'] ?? 1,
      sleepGoal: (json['sleepGoal'] as num?)?.toDouble() ?? 8.0,
      mission: json['mission'] ?? 'chess',
      sleepTracking: json['sleepTracking'] ?? true,
      sleepSounds: json['sleepSounds'] ?? true,
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
      difficultyMode: json['difficultyMode'] ?? 'adaptive',
      smartLock: json['smartLock'] ?? true,
      difficultyOverride: json['difficultyOverride'],
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory MissionSettings.fromJsonString(String str) {
    try {
      return MissionSettings.fromJson(jsonDecode(str));
    } catch (e) {
      return MissionSettings();
    }
  }
}
