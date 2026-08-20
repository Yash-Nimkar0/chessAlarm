import 'report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../widgets/weather_widget.dart';
import '../widgets/platform_theme.dart';
import '../widgets/animated_pressable.dart';
import '../services/elo_service.dart';
import '../services/analytics_service.dart';
import '../theme/design_tokens.dart';

import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sleep_service.dart';

class MorningScreen extends StatefulWidget {
  const MorningScreen({Key? key}) : super(key: key);

  @override
  State<MorningScreen> createState() => _MorningScreenState();
}

class _MorningScreenState extends State<MorningScreen> {
  int _currentStreak = 0;
  int _morningsWon = 0;
  int _morningsWonThisWeek = 0;
  int _fastestSolve = 0;
  int _sleepMomentsCaptured = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // A failure partway through (a bad read, a corrupt stored value) used
    // to leave _isLoading stuck true forever — the screen just sat on its
    // spinner with no way out. Degrade to whatever stats did load instead.
    Map<String, int> stats = const {};
    List<SleepSession> sleepHistory = const [];
    try {
      stats = await EloService.getStats();
    } catch (e) {
      if (kDebugMode) print('MorningScreen: failed to load stats: $e');
    }
    try {
      sleepHistory = await SleepService.getHistory();
    } catch (e) {
      if (kDebugMode) print('MorningScreen: failed to load sleep history: $e');
    }

    if (mounted) {
      setState(() {
        _currentStreak = stats['currentStreak'] ?? 0;
        _morningsWon = stats['morningsWon'] ?? 0;
        _morningsWonThisWeek = stats['morningsWonThisWeek'] ?? 0;
        _fastestSolve = stats['fastestSolve'] ?? 0;
        if (sleepHistory.isNotEmpty) {
          _sleepMomentsCaptured = sleepHistory.last.audioEvents.length;
        }
        _isLoading = false;
      });
      _checkWeeklyRecap();
      _checkPmfSurvey();
    }
  }
  
  void _checkPmfSurvey() async {
    if (_morningsWon >= 3) {
      final prefs = await SharedPreferences.getInstance();
      final hasAnswered = prefs.getBool('pmf_survey_answered') ?? false;
      if (!hasAnswered) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showPmfSurveyModal();
          });
        }
      }
    }
  }
  
  void _checkWeeklyRecap() async {
    if (DateTime.now().weekday == DateTime.sunday) {
      final prefs = await SharedPreferences.getInstance();
      final lastShown = prefs.getString('last_weekly_recap_date');
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      if (lastShown != todayStr) {
        await prefs.setString('last_weekly_recap_date', todayStr);
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showWeeklyRecapModal();
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const PlatformScaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PlatformScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const WeatherWidget(),
                const SizedBox(height: 24),
                _buildMorningGiftCard(),
                const SizedBox(height: 16),

                if (_sleepMomentsCaptured > 0) ...[
                  _buildMorningSleepDiscoveryCard(),
                  const SizedBox(height: 16),
                ],
                if (_morningsWon < 7) ...[
                  _buildFirstWeekJourneyCard(),
                  const SizedBox(height: 16),
                ] else ...[
                  _buildDailyDiscoveryCard(),
                  const SizedBox(height: 16),
                ],

              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _giftRevealed = false;

  static const List<String> _dailyMessages = [
    "You showed up today. That's the whole game.",
    "Every morning you win is a vote for who you're becoming.",
    "Discipline is just self-respect in action.",
    "The hardest part of the day is already behind you.",
    "Small wins, repeated daily, become an identity.",
    "You didn't hit snooze on your life today.",
    "Consistency beats intensity. You're proving that right now.",
  ];

  String get _todaysMessage => _dailyMessages[DateTime.now().weekday % _dailyMessages.length];

  // This used to be a fake "gift from Alex" with a stock photo of a random
  // stranger pretending to be a real message from a real person — the same
  // kind of fabricated-social-content issue as the mock "Wake Together"
  // card removed from the home screen. Replaced with an honest daily
  // message that's clearly from the app itself, keeping the same
  // tap-to-reveal delight without pretending to be from someone it isn't.
  Widget _buildMorningGiftCard() {
    return AnimatedPressable(
      onTap: () {
        if (!_giftRevealed) {
          setState(() {
            _giftRevealed = true;
          });
          Haptics.vibrate(HapticsType.heavy);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _giftRevealed
                ? [AppTokens.signal.withValues(alpha: 0.85), AppTokens.signalDeep]
                : [Colors.orange.shade700, Colors.deepOrange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: _giftRevealed ? [] : [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_giftRevealed) ...[
              const Icon(Icons.card_giftcard, color: Colors.white, size: 64),
              const SizedBox(height: 24),
              const Text("🎁 Today's Message", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white)),
              const SizedBox(height: 8),
              const Text('Tap to reveal', style: TextStyle(color: Colors.white70, fontSize: 16)),
            ] else ...[
              const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 40),
              const SizedBox(height: 16),
              Text(
                _todaysMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white, height: 1.3),
              ),
              const SizedBox(height: 8),
              const Text('- Wakle', style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Colors.white70)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMorningSleepDiscoveryCard() {
    return AnimatedPressable(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) {
           return const ReportScreen();
        }));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTokens.signal.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(color: AppTokens.signal.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('While You Were Sleeping...', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('$_sleepMomentsCaptured moments captured', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16)),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Listen →', style: TextStyle(color: AppTokens.signal, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _discoveryRevealed = false;

  Widget _buildDailyDiscoveryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTokens.signal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: AppTokens.signal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.explore, color: AppTokens.signal),
              SizedBox(width: 8),
              Text("Today's Discovery", style: TextStyle(color: AppTokens.signal, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _discoveryRevealed 
              ? 'Visualization' 
              : 'A mental technique used by elite performers.', 
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 16),
          if (_discoveryRevealed)
            Text(
              'Elite performers use morning visualization to prime their brain for success.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 15, height: 1.4)
            )
          else
            AnimatedPressable(
              onTap: () {
                Haptics.vibrate(HapticsType.medium);
                setState(() => _discoveryRevealed = true);
              },
              child: const Row(
                children: [
                  Text('Reveal today\'s discovery', style: TextStyle(color: AppTokens.signal, fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, color: AppTokens.signal, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFirstWeekJourneyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Your First 7 Mornings", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          _buildJourneyStep(1, 'Awaken', _morningsWon >= 1),
          _buildJourneyStep(3, 'Consistent Waker', _currentStreak >= 3),
          _buildJourneyStep(5, 'Advanced Stats', _morningsWon >= 5),
          _buildJourneyStep(7, 'First Insight Report', _currentStreak >= 7),
        ],
      ),
    );
  }

  Widget _buildJourneyStep(int day, String title, bool unlocked) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(unlocked ? Icons.check_circle : Icons.lock, color: unlocked ? AppTokens.signal : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), size: 20),
          const SizedBox(width: 12),
          Text('Day $day', style: TextStyle(color: unlocked ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          Text(title, style: TextStyle(color: unlocked ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38))),
        ],
      ),
    );
  }
  
  void _showWeeklyRecapModal() {
    Haptics.vibrate(HapticsType.heavy);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Your Brain Week', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 32),
            _buildRecapStat('Missions completed', '$_morningsWonThisWeek', AppTokens.signal),
            _buildRecapStat('Streak extended', '$_currentStreak days', Colors.amberAccent),
            _buildRecapStat('Total missions', '$_morningsWon', AppTokens.signal),
            if (_fastestSolve > 0 && _fastestSolve < 999)
                _buildRecapStat('Fastest solve', '$_fastestSolve seconds', AppTokens.signal),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.onSurface,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
                ),
                child: const Text('Start Next Week', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecapStat(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
  
  void _showPmfSurveyModal() {
    Haptics.vibrate(HapticsType.heavy);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Quick question:', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16)),
            const SizedBox(height: 12),
            Text(
              'Would you be disappointed if this app disappeared?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, height: 1.3),
            ),
            const SizedBox(height: 32),
            _buildPmfOption(context, Icons.sentiment_dissatisfied, 'Yes, very disappointed', 'yes'),
            const SizedBox(height: 12),
            _buildPmfOption(context, Icons.sentiment_neutral, 'Somewhat disappointed', 'somewhat'),
            const SizedBox(height: 12),
            _buildPmfOption(context, Icons.sentiment_satisfied, 'Not really', 'no'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPmfOption(BuildContext context, IconData icon, String text, String value) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          Haptics.vibrate(HapticsType.medium);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('pmf_survey_answered', true);
          AnalyticsService.logEvent('pmf_survey_answered', {'answer': value});
          if (!context.mounted) return;
          Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: AppTokens.signal),
            const SizedBox(width: 16),
            Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
