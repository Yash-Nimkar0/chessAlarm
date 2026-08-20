import 'report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../widgets/weather_widget.dart';
import '../widgets/platform_theme.dart';
import '../widgets/animated_pressable.dart';
import '../widgets/animated_counter.dart';
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
                _buildDailyInsightCard(),
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

  // This used to be a giant full-bleed orange "tap to reveal a gift from
  // Alex" card - a fake message from a fake person (fixed once already this
  // session), then a generic motivational-quote card that was still a giant
  // attention-grabbing blob with no real substance. Replaced with a small,
  // calm "Daily Insight" card that says something true and specific about
  // *this user's* actual data instead of a canned quote that could apply to
  // anyone.
  ({IconData icon, String text}) _computeInsight() {
    if (_fastestSolve > 0 && _fastestSolve < 999) {
      return (icon: Icons.bolt_rounded, text: 'Your fastest wake-up so far is ${_fastestSolve}s. See if you can beat it tomorrow.');
    }
    if (_currentStreak >= 2) {
      return (icon: Icons.local_fire_department_rounded, text: "You're on a $_currentStreak day streak. Don't break the chain tonight.");
    }
    if (_morningsWonThisWeek > 0) {
      return (icon: Icons.calendar_today_rounded, text: '$_morningsWonThisWeek morning${_morningsWonThisWeek == 1 ? '' : 's'} won this week so far.');
    }
    if (_morningsWon > 0) {
      return (icon: Icons.emoji_events_rounded, text: '$_morningsWon total morning${_morningsWon == 1 ? '' : 's'} won. Keep building the habit.');
    }
    return (icon: Icons.explore_rounded, text: 'Complete your first wake mission to start unlocking insights here.');
  }

  Widget _buildDailyInsightCard() {
    final insight = _computeInsight();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTokens.signal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: AppTokens.signal.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppTokens.signal.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: Icon(insight.icon, color: AppTokens.signal, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DAILY INSIGHT', style: TextStyle(color: AppTokens.signal, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 4),
                Text(
                  insight.text,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.w600, height: 1.35),
                ),
              ],
            ),
          ),
        ],
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
            AnimatedCounter(value: _sleepMomentsCaptured, formatter: (v) => '$v moments captured', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16)),
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
            _buildRecapStat('Missions completed', _morningsWonThisWeek, AppTokens.signal, delayMs: 0),
            _buildRecapStat('Streak extended', _currentStreak, Colors.amberAccent, formatter: (v) => '$v days', delayMs: 120),
            _buildRecapStat('Total missions', _morningsWon, AppTokens.signal, delayMs: 240),
            if (_fastestSolve > 0 && _fastestSolve < 999)
                _buildRecapStat('Fastest solve', _fastestSolve, AppTokens.signal, formatter: (v) => '$v seconds', delayMs: 360),
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

  Widget _buildRecapStat(String label, int value, Color color, {String Function(int)? formatter, int delayMs = 0}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16)),
          AnimatedCounter(
            value: value,
            formatter: formatter,
            delay: Duration(milliseconds: delayMs),
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
          ),
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
