import 'dart:convert';

enum MissionType {
  math,
  memory,
  none,
}

class MissionSettings {
  final String type; // "wakeRoutine" or "quickAlarm"
  final int version;
  final double sleepGoal;
  final String mission; // "memory"
  final bool sleepTracking;
  final bool sleepSounds;
  final String createdAt;
  final String difficultyMode;
  
  final bool smartLock;
  final int? difficultyOverride;
  final int missionRounds;
  final Map<String, dynamic>? missionData;

  MissionSettings({
    this.type = "quickAlarm",
    this.version = 1,
    this.sleepGoal = 8.0,
    this.mission = "memory",
    this.sleepTracking = true,
    this.sleepSounds = true,
    String? createdAt,
    this.difficultyMode = "adaptive",
    this.smartLock = true,
    this.difficultyOverride,
    this.missionRounds = 1,
    this.missionData,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

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
      'missionRounds': missionRounds,
      'missionData': missionData,
    };
  }

  MissionSettings copyWith({
    String? type,
    int? version,
    double? sleepGoal,
    String? mission,
    bool? sleepTracking,
    bool? sleepSounds,
    String? createdAt,
    String? difficultyMode,
    bool? smartLock,
    int? difficultyOverride,
    int? missionRounds,
    Map<String, dynamic>? missionData,
  }) {
    return MissionSettings(
      type: type ?? this.type,
      version: version ?? this.version,
      sleepGoal: sleepGoal ?? this.sleepGoal,
      mission: mission ?? this.mission,
      sleepTracking: sleepTracking ?? this.sleepTracking,
      sleepSounds: sleepSounds ?? this.sleepSounds,
      createdAt: createdAt ?? this.createdAt,
      difficultyMode: difficultyMode ?? this.difficultyMode,
      smartLock: smartLock ?? this.smartLock,
      difficultyOverride: difficultyOverride ?? this.difficultyOverride,
      missionRounds: missionRounds ?? this.missionRounds,
      missionData: missionData ?? this.missionData,
    );
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
      mission: (json['mission'] == 'chess' || json['mission'] == null) ? 'memory' : json['mission'],
      sleepTracking: json['sleepTracking'] ?? true,
      sleepSounds: json['sleepSounds'] ?? true,
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
      difficultyMode: json['difficultyMode'] ?? 'adaptive',
      smartLock: json['smartLock'] ?? true,
      difficultyOverride: json['difficultyOverride'],
      missionRounds: json['missionRounds'] ?? 1,
      missionData: json['missionData'] != null ? Map<String, dynamic>.from(json['missionData']) : null,
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
