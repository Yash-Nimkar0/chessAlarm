import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../services/elo_service.dart';
import 'main_screen.dart';

class MissionCompleteScreen extends StatefulWidget {
  final int elapsedSeconds;
  final int eloChange;
  final bool isSkip;

  const MissionCompleteScreen({
    Key? key,
    required this.elapsedSeconds,
    required this.eloChange,
    required this.isSkip,
  }) : super(key: key);

  @override
  State<MissionCompleteScreen> createState() => _MissionCompleteScreenState();
}

class _MissionCompleteScreenState extends State<MissionCompleteScreen> with SingleTickerProviderStateMixin {
  int _currentStreak = 0;
  bool _isLoading = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _badgeController;
  late Animation<double> _badgeScale;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    // This is the app's core reward moment — a completed wake mission — so
    // it deserves more than a flat fade. The badge overshoots slightly
    // (elasticOut) for a satisfying "pop" instead of just appearing.
    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _badgeScale = CurvedAnimation(parent: _badgeController, curve: Curves.elasticOut);

    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await EloService.getStats();
    if (mounted) {
      setState(() {
        _currentStreak = stats['currentStreak'] ?? 0;
        _isLoading = false;
      });
      _fadeController.forward();
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _badgeController.forward();
      });

      // Auto-transition after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(initialIndex: 3), // Report Screen
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeOutCubic;

                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);

                return SlideTransition(
                  position: offsetAnimation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 800),
            ),
            (route) => false,
          );
        }
      });
    }
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(backgroundColor: Theme.of(context).colorScheme.surface);
    }
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _badgeScale,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTokens.signal,
                  ),
                  child: Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.surface, size: 52),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Morning Won',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppTokens.signal,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              if (!widget.isSkip) ...[
                Text(
                  'Solved in ${widget.elapsedSeconds}s',
                  style: TextStyle(fontSize: 24, color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  '+${widget.eloChange} Points',
                  style: const TextStyle(fontSize: 24, color: AppTokens.signal, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
              ] else ...[
                const Text(
                  'Backup Unlock Used',
                  style: TextStyle(fontSize: 24, color: AppTokens.signal, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_fire_department, color: AppTokens.signal, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    '$_currentStreak Day Streak',
                    style: const TextStyle(fontSize: 24, color: AppTokens.signal, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 64),
              Text(
                'Your mind is awake.',
                style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
