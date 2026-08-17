import 'report_screen.dart';
import 'package:flutter/material.dart';
import '../services/preferences_service.dart';
import '../utils/greeting_utils.dart';
import '../widgets/weather_widget.dart';
import '../widgets/platform_theme.dart';
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
  String _userName = '';

  int _userElo = 1000;
  int _currentStreak = 0;
  int _puzzlesSolved = 0;
  int _morningsWon = 0;
  String _companionLevel = "Novice";
  int _puzzlesSolvedThisWeek = 0;
  int _fastestSolve = 0;
  int _sleepMomentsCaptured = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadName();
    _loadData();
  }

  Future<void> _loadName() async {
    final name = await PreferencesService.getUserName();
    if (mounted) setState(() => _userName = name);
  }

  Future<void> _loadData() async {
    final elo = await EloService.getElo();
    final stats = await EloService.getStats();
    final sleepHistory = await SleepService.getHistory();
    
    if (mounted) {
      setState(() {
        _userElo = elo;
        _currentStreak = stats['currentStreak'] ?? 0;
        _puzzlesSolved = stats['puzzlesSolved'] ?? 0;
        _morningsWon = stats['morningsWon'] ?? 0;
        _puzzlesSolvedThisWeek = stats['puzzlesSolvedThisWeek'] ?? 0;
        _fastestSolve = stats['fastestSolve'] ?? 0;
        if (sleepHistory.isNotEmpty) {
          _sleepMomentsCaptured = sleepHistory.last.audioEvents.length;
        }
        _companionLevel = EloService.getLevel(_morningsWon);
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

  void _calculateDailyDiscovery() {
    _discoveryRevealed = (_morningsWon) % 2 == 1;
  }

  void _showBrainCheckModal() {
    Haptics.vibrate(HapticsType.light);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('How sharp are you today?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 24),
            _buildMoodOption(context, Icons.bedtime, 'Tired', 'Need more coffee'),
            _buildMoodOption(context, Icons.sentiment_satisfied, 'Normal', 'Ready to go'),
            _buildMoodOption(context, Icons.bolt, 'Sharp', 'Feeling focused'),
            _buildMoodOption(context, Icons.local_fire_department, 'Peak', 'God mode enabled'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showScoreModal() {
    Haptics.vibrate(HapticsType.light);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Morning Score Breakdown', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 24),
            _buildScoreRow('Accuracy', '+35'),
            _buildScoreRow('Speed', '+22'),
            _buildScoreRow('Wake streak', '+20'),
            Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12), height: 32),
            Text('Tomorrow\'s goal:', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('Solve 5 sec faster', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('+ $label', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16)),
          Text(value, style: const TextStyle(color: AppTokens.signal, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  void _showCompanionModal() {
    Haptics.vibrate(HapticsType.light);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pets, size: 64, color: AppTokens.signal),
            const SizedBox(height: 16),
            Text(_companionLevel, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text('"Your tactics improved this week.\nLet\'s reach the next rank!"', 
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
            const SizedBox(height: 24),
            Text('XP to Next Level', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: 0.7, backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12), color: AppTokens.signal, minHeight: 8),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(children: [
                  const Icon(Icons.check_circle, color: AppTokens.signal, size: 20),
                  const SizedBox(height: 4),
                  Text('3 mornings left', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                ]),
                Column(children: [
                  const Icon(Icons.extension, color: AppTokens.signal, size: 20),
                  const SizedBox(height: 4),
                  Text('20 missions left', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                ]),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showProgressModal() {
    Haptics.vibrate(HapticsType.light);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Wake Consistency', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$_morningsWon', style: AppTokens.display.copyWith(fontSize: 48, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(width: 8),
                const Text('Mornings won', style: TextStyle(color: AppTokens.signal, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 32),
            Text('Since joining:', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 12),
            _buildWowStat('You completed', '$_puzzlesSolved missions'),
            _buildWowStat('Current streak', '$_currentStreak days'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildWowStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMoodOption(BuildContext context, IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, size: 24, color: AppTokens.signal),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
      subtitle: Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
      onTap: () {
        Haptics.vibrate(HapticsType.medium);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logged feeling: $title')));
      },
    );
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
                Text(
                  _userName.isEmpty ? GreetingUtils.getGreeting() : '${GreetingUtils.getGreeting()}, $_userName',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)
                ),
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

  Widget _buildMorningGiftCard() {
    return GestureDetector(
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
                ? [Theme.of(context).colorScheme.primaryContainer, Theme.of(context).colorScheme.surfaceContainerHighest]
                : [Colors.orange.shade700, Colors.deepOrange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: _giftRevealed ? [] : [
            BoxShadow(
              color: Colors.orange.withOpacity(0.5),
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
              const Text('🎁 Something from Alex', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white)),
              const SizedBox(height: 8),
              const Text('Tap to reveal', style: TextStyle(color: Colors.white70, fontSize: 16)),
            ] else ...[
              const CircleAvatar(radius: 32, backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=68')),
              const SizedBox(height: 16),
              const Text('Good morning ❤️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28)),
              const SizedBox(height: 8),
              const Text('- Alex', style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMorningScoreCard() {
    return GestureDetector(
      onTap: _showScoreModal,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Morning Score', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  ),
                  child: const Text('Early Riser', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('85', style: AppTokens.display.copyWith(color: Colors.white, fontSize: 56, fontWeight: FontWeight.bold, height: 1.0)),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.arrow_upward, color: AppTokens.signal, size: 16),
                const Text(' +5 from yesterday', style: TextStyle(color: AppTokens.signal, fontWeight: FontWeight.w500)),
                const Spacer(),
                Icon(Icons.local_fire_department, color: AppTokens.signal, size: 20),
                const SizedBox(width: 4),
                Text('$_currentStreak day streak', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoreButton(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Haptics.vibrate(HapticsType.light);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildMorningSleepDiscoveryCard() {
    return GestureDetector(
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

  Widget _buildPerformanceCard() {
    return _buildCardBase(
      title: 'Today\'s Performance',
      icon: Icons.timer,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mission Speed', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('32 sec', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Average', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('41 sec', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTokens.signal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            child: const Center(
              child: Text('↑ 22% faster today', style: TextStyle(color: AppTokens.signal, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
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
            GestureDetector(
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

  Widget _buildDailyConceptCard() {
    final dayIndex = DateTime.now().difference(DateTime(2024, 1, 1)).inDays;
    final concepts = [
      {"title": "The Pareto Principle", "desc": "80% of outcomes often come from 20% of actions."},
      {"title": "First Principles Thinking", "desc": "Break problems down to their basic truths."},
      {"title": "Inversion", "desc": "Avoiding mistakes can be as valuable as finding wins."},
      {"title": "Compound Interest", "desc": "Small consistent habits grow exponentially over time."},
      {"title": "Occam's Razor", "desc": "The simplest explanation is usually the best one."}
    ];
    final concept = concepts[dayIndex % concepts.length];

    return _buildCardBase(
      title: 'Daily Concept',
      icon: Icons.menu_book,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(concept["title"]!, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('"${concept["desc"]!}"', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 15, fontStyle: FontStyle.italic, height: 1.4)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Haptics.vibrate(HapticsType.light);
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  title: Text('Apply: ${concept["title"]}'),
                  content: TextField(
                    autofocus: true,
                    decoration: InputDecoration(hintText: 'How could you use this today?', hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Save', style: TextStyle(color: AppTokens.signal))),
                  ],
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
            ),
            child: const Text('Apply Today'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteCard() {
    final dayIndex = DateTime.now().difference(DateTime(2024, 1, 1)).inDays;
    final quotes = [
      "Every morning is a new opportunity.",
      "Stay hungry, stay foolish.",
      "The harder you work for something, the greater you'll feel when you achieve it.",
      "Success is not final; failure is not fatal: It is the courage to continue that counts.",
      "Focus on the step in front of you, not the whole staircase.",
      "We are what we repeatedly do. Excellence, then, is not an act, but a habit."
    ];
    final quote = quotes[dayIndex % quotes.length];
    
    return _buildCardBase(
      title: "Today's Thought",
      icon: Icons.lightbulb,
      child: Text('"$quote"', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontStyle: FontStyle.italic, height: 1.4)),
    );
  }

  Widget _buildBrainFactCard() {
    final dayIndex = DateTime.now().difference(DateTime(2024, 1, 1)).inDays;
    final facts = [
      "Masters recognize patterns rather than relying purely on willpower.",
      "Short repeated practice sessions usually outperform single long sessions.",
      "Removing distractions improves deep work quality by up to 50%.",
      "Recall practice strengthens learning significantly more than just re-reading.",
      "Your brain strengthens memories during deep sleep."
    ];
    final fact = facts[dayIndex % facts.length];

    return _buildCardBase(
      title: 'Brain Fact',
      icon: Icons.science,
      child: Text(fact, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, height: 1.4)),
    );
  }

  Widget _buildCardBase({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          child,
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
            _buildRecapStat('Missions completed', '$_puzzlesSolvedThisWeek', AppTokens.signal),
            _buildRecapStat('Streak extended', '$_currentStreak days', Colors.amberAccent),
            _buildRecapStat('Total missions', '$_puzzlesSolved', AppTokens.signal),
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
