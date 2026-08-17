import 'package:equatable/equatable.dart';

enum AlarmNativeState {
  scheduled,
  firing,
  snoozed,
  completed,
  stopped,
  unknown
}

enum AlarmInteractionType {
  none,
  openWakely,
  stop,
  secondaryAction
}

/// Canonical event representing state changes or interactions from the native platform.
class AlarmEvent extends Equatable {
  final int alarmId;
  final AlarmNativeState state;
  final AlarmInteractionType interaction;
  final DateTime timestamp;

  const AlarmEvent({
    required this.alarmId,
    required this.state,
    this.interaction = AlarmInteractionType.none,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [alarmId, state, interaction, timestamp];
}
