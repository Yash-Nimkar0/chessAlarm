import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../../models/mission_settings.dart';
import '../../theme/design_tokens.dart';

class QRConfigScreen extends StatefulWidget {
  final MissionSettings initialSettings;

  const QRConfigScreen({Key? key, required this.initialSettings}) : super(key: key);

  @override
  State<QRConfigScreen> createState() => _QRConfigScreenState();
}

class _QRConfigScreenState extends State<QRConfigScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanning = true;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (!_isScanning) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String code = barcodes.first.rawValue!;
      
      setState(() {
        _isScanning = false;
      });
      _scannerController.stop();
      Haptics.vibrate(HapticsType.success);

      // Prompt for name
      final String? name = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          String inputName = '';
          return AlertDialog(
            title: const Text('Name this item'),
            content: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g. Bathroom Toothpaste',
              ),
              onChanged: (val) => inputName = val,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (inputName.trim().isEmpty) inputName = 'Barcode Item';
                  Navigator.pop(context, inputName.trim());
                },
                child: const Text('Save'),
              ),
            ],
          );
        }
      );

      if (name != null) {
        final newSettings = widget.initialSettings.copyWith(
          mission: 'qr',
          missionData: {
            'qrTargetValue': code,
            'qrTargetName': name,
          },
        );
        if (mounted) Navigator.pop(context, newSettings);
      } else {
        // User cancelled naming, resume scanning
        setState(() {
          _isScanning = true;
        });
        _scannerController.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR / Barcode'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 32.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  ),
                  child: const Text(
                    'Scan a barcode to set it as your target',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.primary, width: 4),
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
