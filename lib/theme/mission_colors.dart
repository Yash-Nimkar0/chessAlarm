import 'package:flutter/material.dart';
import '../features/alarms/domain/mission_config.dart';

/// The color each mission type is identified by across the app —
/// the mission picker and its config screens already color-coded
/// missions this way; this makes that same palette available anywhere
/// a [MissionType] needs a color (e.g. the alarm list's mission badge)
/// without duplicating the mapping.
Color missionColor(MissionType type) {
  switch (type) {
    case MissionType.math:
      return Colors.blue;
    case MissionType.memory:
      return Colors.purple;
    case MissionType.typing:
      return Colors.indigo;
    case MissionType.colorTiles:
      return Colors.teal;
    case MissionType.missingSymbol:
      return Colors.orange;
    case MissionType.shake:
      return Colors.redAccent;
    case MissionType.qr:
      return Colors.pink;
    case MissionType.steps:
      return Colors.blueAccent;
    case MissionType.none:
      return Colors.green;
  }
}
