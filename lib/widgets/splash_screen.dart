import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Shown for the brief window while the app boots (main.dart's
/// _WakelyAppLoaderState._initApp future is still pending) — this used to
/// be a plain black screen with a stock green spinner, completely
/// unrelated to the rest of the app's identity and the very first thing
/// every user ever sees on cold launch. A gently breathing sun, echoing
/// the app icon, reads as intentional instead of a generic placeholder.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppTokens.nightBg,
        body: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_controller.value);
              return Opacity(
                opacity: 0.55 + (0.45 * t),
                child: Transform.scale(
                  scale: 0.92 + (0.08 * t),
                  child: child,
                ),
              );
            },
            child: const Icon(Icons.wb_sunny_rounded, color: AppTokens.signal, size: 64),
          ),
        ),
      ),
    );
  }
}
