import 'report_screen.dart';
import 'package:flutter/material.dart';
import '../services/preferences_service.dart';
import '../utils/greeting_utils.dart';
import '../widgets/weather_widget.dart';
import '../widgets/platform_theme.dart';
import '../services/elo_service.dart';
import '../services/analytics_service.dart';
import 'practice_screen.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sleep_service.dart';
import 'dart:math';

class MorningScreen extends StatefulWidget {
  const MorningScreen({Key? key}) : super(key: key);

  @override
  State<MorningScreen> createState() => _MorningScreenState();
}

class _MorningScreenState extends State<MorningScreen> {
  String _userName = 'Grandmaster';

  int _userElo = 1000;
  int _currentStreak = 0;
  int _puzzlesSolved = 0;
  int _morningsWon = 0;
  String _companionLevel = "Pawn";
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

  int _calculateMorningScore() {
    final baseScore = 70;
    final streakBonus = min(_currentStreak * 2, 20);
    final eloBonus = min((_userElo - 1000) ~/ 50, 10);
    return min(baseScore + streakBonus + eloBonus, 100);
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
            const Text('How sharp are you today?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 24),
            _buildMoodOption(context, '😴', 'Tired', 'Need more coffee'),
            _buildMoodOption(context, '🙂', 'Normal', 'Ready to go'),
            _buildMoodOption(context, '⚡', 'Sharp', 'Feeling focused'),
            _buildMoodOption(context, '🔥', 'Peak', 'God mode enabled'),
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
            const Text('Morning Score Breakdown', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 24),
            _buildScoreRow('Accuracy', '+35'),
            _buildScoreRow('Speed', '+22'),
            _buildScoreRow('Wake streak', '+20'),
            _buildScoreRow('Difficulty', '+10'),
            const Divider(color: Colors.white12, height: 32),
            const Text('Tomorrow\'s goal:', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 4),
            const Text('Solve 5 sec faster', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
          Text('+ $label', style: const TextStyle(color: Colors.white70, fontSize: 16)),
          Text(value, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
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
            const Icon(Icons.pets, size: 64, color: Colors.orangeAccent),
            const SizedBox(height: 16),
            Text('$_companionLevel', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            const Text('"Your tactics improved this week.\nLet\'s reach the next rank!"', 
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
            const SizedBox(height: 24),
            const Text('XP to Next Level', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: 0.7, backgroundColor: Colors.white12, color: Colors.orangeAccent, minHeight: 8),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(children: [
                  Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                  SizedBox(height: 4),
                  Text('3 mornings left', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
                Column(children: [
                  Icon(Icons.extension, color: Colors.blueAccent, size: 20),
                  SizedBox(height: 4),
                  Text('20 puzzles left', style: TextStyle(color: Colors.white70, fontSize: 12)),
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
            const Text('♟ Puzzle Rating', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$_userElo', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(width: 8),
                const Text('▲ +18 today', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 24),
            Text('Next Rank: Knight at 1500', style: TextStyle(color: Colors.white.withOpacity(0.9))),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (_userElo - 1000) / 500, backgroundColor: Colors.white12, color: Colors.blueAccent, minHeight: 8),
            const SizedBox(height: 32),
            const Text('Since joining:', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 12),
            _buildWowStat('You solved', '$_puzzlesSolved puzzles'),
            _buildWowStat('You trained your brain for', '26 hours'),
            _buildWowStat('Your rating improved', '+${_userElo - 1000} points'),
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
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMoodOption(BuildContext context, String emoji, String title, String subtitle) {
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 24)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5))),
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
                Text('${GreetingUtils.getGreeting()}, $_userName', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 16),
                _buildMorningScoreCard(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: _buildCoreButton(Icons.extension, 'Daily Challenge', 'Solve puzzle', Colors.blueAccent, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PracticeScreen()));
                    })),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCoreButton(Icons.psychology, 'Brain Check', 'Log mood', Colors.purpleAccent, _showBrainCheckModal)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildCoreButton(Icons.pets, 'Companion', _companionLevel, Colors.orangeAccent, _showCompanionModal)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCoreButton(Icons.trending_up, 'Progress', '$_userElo Elo', Colors.greenAccent, _showProgressModal)),
                  ],
                ),
                const SizedBox(height: 32),
                _buildBrainWorkoutCard(),
                const SizedBox(height: 16),
                _buildPerformanceCard(),
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
                _buildDailyConceptCard(),
                const SizedBox(height: 16),
                _buildBrainFactCard(),
                const SizedBox(height: 16),
                _buildQuoteCard(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMorningScoreCard() {
    final score = _calculateMorningScore();
    return GestureDetector(
      onTap: _showScoreModal,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade900, Colors.purple.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
          ],
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
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('♞ The Tactician', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$score', style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.bold, height: 1.0)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.arrow_upward, color: Colors.greenAccent, size: 16),
                const Text(' +5 from yesterday', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w500)),
                const Spacer(),
                Icon(Icons.local_fire_department, color: Colors.orange.shade400, size: 20),
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
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildMorningSleepDiscoveryCard() {
    return GestureDetector(
      onTap: () {
        // We need to navigate to MainScreen and switch to Report tab.
        // Or simply push ReportScreen. But it's part of the Main bottom nav.
        // For now, push ReportScreen directly.
        Navigator.push(context, MaterialPageRoute(builder: (context) {
           // A tiny wrapper since MainScreen is stateful and manages tabs. 
           // We can just push MainScreen and try to set the tab. 
           // But setting it is hard without a provider. 
           // We will just push a new ReportScreen for simplicity in Beta.
           // Actually, let's just push it.
           return const ReportScreen();
        }));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.indigo.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.indigoAccent.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🌙 While You Were Sleeping...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('$_sleepMomentsCaptured moments captured', style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Listen →', style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrainWorkoutCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.fitness_center, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  const Text("Today's Brain Workout", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('3 min', style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildWorkoutItem(Icons.extension, 'Chess Puzzle', 'Difficulty: $_userElo'),
          const SizedBox(height: 12),
          _buildWorkoutItem(Icons.speed, 'Speed Test', 'Reaction time'),
          const SizedBox(height: 12),
          _buildWorkoutItem(Icons.visibility, 'Memory Test', 'Pattern recall'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PracticeScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Start →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          ],
        ),
      ],
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
                  const Text('Puzzle Speed', style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 4),
                  const Text('32 sec', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your Average', style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 4),
                  const Text('41 sec', style: TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('↑ 22% faster today', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
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
        color: Colors.purpleAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.explore, color: Colors.purpleAccent),
              const SizedBox(width: 8),
              const Text("Today's Discovery", style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _discoveryRevealed 
              ? 'Visualization' 
              : 'A mental technique used by elite performers.', 
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 16),
          if (_discoveryRevealed)
            const Text(
              'Chess masters improve by mentally moving pieces without a board.',
              style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4)
            )
          else
            GestureDetector(
              onTap: () {
                Haptics.vibrate(HapticsType.medium);
                setState(() => _discoveryRevealed = true);
              },
              child: const Row(
                children: [
                  Text('Reveal today\'s discovery', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, color: Colors.purpleAccent, size: 16),
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
          Text(concept["title"]!, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('"${concept["desc"]!}"', style: const TextStyle(color: Colors.white70, fontSize: 15, fontStyle: FontStyle.italic, height: 1.4)),
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
                    decoration: const InputDecoration(hintText: 'How could you use this today?', hintStyle: TextStyle(color: Colors.white54)),
                    style: const TextStyle(color: Colors.white),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Save', style: TextStyle(color: Colors.blueAccent))),
                  ],
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white12,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      "Every chess master was once a beginner.",
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
      child: Text('"$quote"', style: const TextStyle(color: Colors.white, fontSize: 16, fontStyle: FontStyle.italic, height: 1.4)),
    );
  }

  Widget _buildBrainFactCard() {
    final dayIndex = DateTime.now().difference(DateTime(2024, 1, 1)).inDays;
    final facts = [
      "Grandmasters recognize positions as patterns rather than calculating every move.",
      "Short repeated practice sessions usually outperform single long sessions.",
      "Removing distractions improves deep work quality by up to 50%.",
      "Recall practice strengthens learning significantly more than just re-reading.",
      "Your brain strengthens memories during deep sleep."
    ];
    final fact = facts[dayIndex % facts.length];

    return _buildCardBase(
      title: 'Brain Fact',
      icon: Icons.science,
      child: Text(fact, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4)),
    );
  }

  Widget _buildCardBase({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white54, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w600, fontSize: 14)),
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Your First 7 Mornings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          _buildJourneyStep(1, 'Awaken', _morningsWon >= 1),
          _buildJourneyStep(3, 'Unlock Knight Rank', _morningsWon >= 3),
          _buildJourneyStep(5, 'Advanced Stats', _morningsWon >= 5),
          _buildJourneyStep(7, 'First Brain Report', _morningsWon >= 7),
        ],
      ),
    );
  }

  Widget _buildJourneyStep(int day, String title, bool unlocked) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(unlocked ? Icons.check_circle : Icons.lock, color: unlocked ? Colors.greenAccent : Colors.white38, size: 20),
          const SizedBox(width: 12),
          Text('Day $day', style: TextStyle(color: unlocked ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          Text(title, style: TextStyle(color: unlocked ? Colors.white : Colors.white38)),
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
            const Text('Your Brain Week 🧠', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 32),
            _buildRecapStat('♟ Puzzles solved', '$_puzzlesSolvedThisWeek', Colors.blueAccent),
            _buildRecapStat('🔥 Mornings won', '${min(_currentStreak, 7)}/7', Colors.orangeAccent),
            _buildRecapStat('📈 Rating gained', '+${max(0, _userElo - 1000)}', Colors.greenAccent),
            if (_fastestSolve > 0 && _fastestSolve < 999)
                _buildRecapStat('⏱ Fastest solve', '$_fastestSolve seconds', Colors.purpleAccent),
            _buildRecapStat('🏆 Longest streak', '$_currentStreak days', Colors.amberAccent),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
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
            const Text('Quick question:', style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 12),
            const Text(
              'Would you be disappointed if this app disappeared?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
            ),
            const SizedBox(height: 32),
            _buildPmfOption(context, '😢', 'Yes, very disappointed', 'yes'),
            const SizedBox(height: 12),
            _buildPmfOption(context, '😐', 'Somewhat disappointed', 'somewhat'),
            const SizedBox(height: 12),
            _buildPmfOption(context, '🙂', 'Not really', 'no'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPmfOption(BuildContext context, String emoji, String text, String value) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          Haptics.vibrate(HapticsType.medium);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('pmf_survey_answered', true);
          AnalyticsService.logEvent('pmf_survey_answered', {'answer': value});
          Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.1),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
