import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// The "you're awake" confirmation shown after a quickAlarm/alarm-type
/// wake (success or emergency escape). Mirrors the fade+elastic-pop
/// treatment mission_complete_screen.dart already has for the equivalent
/// moment on wake-routine/mission-type alarms, so both paths feel the same
/// weight of "you won" instead of one being animated and one being static.
class WakeSuccessScreen extends StatefulWidget {
  final String message;

  const WakeSuccessScreen({super.key, this.message = 'Wake up!'});

  @override
  State<WakeSuccessScreen> createState() => _WakeSuccessScreenState();
}

class _WakeSuccessScreenState extends State<WakeSuccessScreen> with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final AnimationController _badgeController;
  late final Animation<double> _badgeScale;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _badgeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _badgeScale = CurvedAnimation(parent: _badgeController, curve: Curves.elasticOut);

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _badgeController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _badgeScale,
                child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
              ),
              const SizedBox(height: 20),
              Text(widget.message, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTokens.signal,
                  foregroundColor: AppTokens.nightBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
                ),
                child: const Text("Done", style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
