/// Represents the capability and authorization status of AlarmKit on the current OS.
class AlarmKitCapability {
  /// Whether the installed OS supports the exact AlarmKit API surface Wakely uses.
  final bool supported;
  
  /// The current authorization status of AlarmKit.
  final AlarmKitAuthorization authorization;

  const AlarmKitCapability({
    required this.supported,
    required this.authorization,
  });

  /// The default unsupported capability.
  static const AlarmKitCapability unsupported = AlarmKitCapability(
    supported: false,
    authorization: AlarmKitAuthorization.unsupported,
  );
  
  /// True if AlarmKit is both supported by the OS and authorized by the user.
  bool get isReady => supported && authorization == AlarmKitAuthorization.authorized;
}

/// The authorization status of AlarmKit on iOS.
enum AlarmKitAuthorization {
  /// AlarmKit is not supported on this OS (e.g., Android, or iOS < supported version).
  unsupported,
  
  /// Supported, but the user has not yet been prompted for permission.
  notDetermined,
  
  /// Supported, but the user denied or revoked permission.
  denied,
  
  /// Supported and the user granted permission.
  authorized,
}
