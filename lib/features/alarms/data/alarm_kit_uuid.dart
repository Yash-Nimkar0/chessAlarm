/// Decodes the numeric Wakely alarm ID embedded in a native AlarmKit UUID.
///
/// Must exactly mirror `WakelyAlarmKitManager.getUUID(for:)` on the Swift
/// side, which encodes the ID as the last 12 digits of the UUID's final
/// segment, left-zero-padded (e.g. id 3 -> "00000000-0000-0000-0000-000000000003").
///
/// Returns null if [uuid] is null or doesn't decode to any digits.
int? parseAlarmKitUUID(String? uuid) {
  if (uuid == null) return null;
  final lastSegment = uuid.split('-').last;
  final digitsOnly = lastSegment.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.isEmpty) return null;
  final stripped = digitsOnly.replaceFirst(RegExp(r'^0+'), '');
  if (stripped.isEmpty) return 0;
  return int.tryParse(stripped);
}
