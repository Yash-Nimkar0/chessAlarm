import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../../theme/design_tokens.dart';
import '../../features/alarms/application/wake_session_controller.dart';
import '../../widgets/animated_pressable.dart';

class QRMission extends StatefulWidget {
  final Map<String, dynamic> missionData;
  final VoidCallback onSuccess;
  final VoidCallback onSkip;

  const QRMission({
    Key? key,
    required this.missionData,
    required this.onSuccess,
    required this.onSkip,
  }) : super(key: key);

  @override
  State<QRMission> createState() => _QRMissionState();
}

class _QRMissionState extends State<QRMission> with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isSuccess = false;
  late final AnimationController _scanLineController;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isSuccess) return;

    // A detected barcode in frame — matching or not — is the mission's own
    // "still actively scanning" signal, since the user isn't tapping the
    // screen while holding the camera up to a code. Without this, a scan
    // taking longer than the watchdog's idle timeout would get interrupted
    // by a fresh alert mid-scan.
    WakeSessionController.instance.recordMissionInteraction();

    final targetValue = widget.missionData['qrTargetValue'] as String?;
    if (targetValue == null) {
      // Fallback if configured improperly
      _markSuccess();
      return;
    }

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue == targetValue) {
        _markSuccess();
        break;
      }
    }
  }

  void _markSuccess() {
    setState(() {
      _isSuccess = true;
    });
    _scannerController.stop();
    Haptics.vibrate(HapticsType.success);
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final targetName = widget.missionData['qrTargetName'] as String? ?? 'Barcode';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Scan your $targetName!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onDetect,
                  ),
                  Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTokens.signal, width: 4),
                        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                      ),
                      child: _isSuccess
                          ? null
                          : AnimatedBuilder(
                              animation: _scanLineController,
                              builder: (context, child) {
                                return Align(
                                  alignment: Alignment(0, _scanLineController.value * 2 - 1),
                                  child: Container(
                                    height: 3,
                                    margin: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: AppTokens.signal.withValues(alpha: 0.8),
                                      boxShadow: [
                                        BoxShadow(color: AppTokens.signal.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 1),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        AnimatedPressable(
          onTap: widget.onSkip,
          child: Text('Skip (-10 Points)', style: TextStyle(color: colorScheme.error, fontSize: 16)),
        ),
      ],
    );
  }
}
