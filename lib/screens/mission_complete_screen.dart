import 'dart:async';
import 'package:flutter/material.dart';
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
      
      // Auto-transition after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const MainScreen(initialIndex: 2), // 2 is the Morning Screen
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Colors.black);
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '♟ Morning Won',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.greenAccent,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              if (!widget.isSkip) ...[
                Text(
                  'Solved in ${widget.elapsedSeconds}s',
                  style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  '+${widget.eloChange} Rating',
                  style: const TextStyle(fontSize: 24, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
              ] else ...[
                const Text(
                  'Backup Unlock Used',
                  style: TextStyle(fontSize: 24, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                '🔥 $_currentStreak Day Streak',
                style: const TextStyle(fontSize: 24, color: Colors.orange, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 64),
              const Text(
                'Your mind is awake.',
                style: TextStyle(fontSize: 18, color: Colors.white54, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
