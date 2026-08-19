import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../widgets/audio_clip_tile.dart';
import '../widgets/animated_counter.dart';
import '../widgets/animated_pressable.dart';
import '../widgets/score_ring.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/breathing_icon.dart';
import '../services/sleep_service.dart';
import '../services/performance_insight_service.dart';
import '../services/elo_service.dart';
import '../widgets/platform_theme.dart';
import '../theme/design_tokens.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({Key? key}) : super(key: key);

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int _selectedTab = 0;
  bool _isLoading = true;
  
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _performanceInsight = {};
  List<SleepSession> _sleepHistory = [];
  int _currentStreak = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // A failure loading any one of these used to leave _isLoading stuck
    // true forever with no way for the screen to recover — degrade to
    // whatever did load successfully instead of hanging on the spinner.
    Map<String, dynamic> insight = const {};
    List<SleepSession> sleepHistory = const [];
    Map<String, dynamic> stats = const {};
    try {
      insight = await PerformanceInsightService.getInsights();
    } catch (e) {
      if (kDebugMode) print('ReportScreen: failed to load insights: $e');
    }
    try {
      sleepHistory = await SleepService.getHistory();
    } catch (e) {
      if (kDebugMode) print('ReportScreen: failed to load sleep history: $e');
    }
    try {
      stats = await EloService.getStats();
    } catch (e) {
      if (kDebugMode) print('ReportScreen: failed to load stats: $e');
    }

    if (mounted) {
      setState(() {
        _stats = stats;
        _currentStreak = _stats['currentStreak'] ?? 0;
        _performanceInsight = insight;
        _sleepHistory = sleepHistory;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('Report', style: AppTokens.display.copyWith(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 16),
              Center(
                child: Text('This week', style: AppTokens.body.copyWith(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
              ),
              const SizedBox(height: 24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTab(0, 'Wake Report'),
                    const SizedBox(width: 8),
                    _buildTab(1, 'Sleep Report'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator()) 
                  : _buildSelectedTabContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(int index, String text) {
    bool isSelected = _selectedTab == index;
    return AnimatedPressable(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
        child: Text(
          text,
          style: AppTokens.body.copyWith(
            color: isSelected ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    if (_selectedTab == 0) return _buildWakeReport();
    return _buildSleepReport();
  }

  Widget _buildWakeReport() {
    // 'morningsWon' (not 'puzzlesSolved') is the correct counter here: it's
    // incremented by EloService.recordMorningSuccess, which is what
    // RingingScreen calls on a real wake-mission success. puzzlesSolved
    // tracks a separate, unrelated practice-mode feature (see
    // recordPracticeSuccess / practice_screen.dart) and would always read 0
    // for anyone who has only ever completed real alarms.
    int totalPuzzles = _stats['morningsWon'] ?? 0;

    return SingleChildScrollView(
      child: Column(
        children: [
          FadeSlideIn(child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      AnimatedCounter(value: totalPuzzles, style: AppTokens.display.copyWith(color: Theme.of(context).colorScheme.onSurface, fontSize: 36, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text('Missions Beaten', style: AppTokens.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ],
          )),
          const SizedBox(height: 24),
          FadeSlideIn(delay: const Duration(milliseconds: 70), child: _buildStatRow('Current Streak', '$_currentStreak Days', Icons.local_fire_department)),
          const SizedBox(height: 24),
          if (totalPuzzles == 0)
            FadeSlideIn(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
                child: Column(
                  children: [
                    BreathingIcon(
                      icon: Icons.query_stats,
                      size: 72,
                      iconSize: 36,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      backgroundColor: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                    ),
                    const SizedBox(height: 16),
                    Text('Your first morning starts here', style: AppTokens.display.copyWith(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('Complete your first wake mission to start tracking your consistency.', style: AppTokens.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4), textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          else ...[
            _buildInsightCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildSleepReport() {
    if (_sleepHistory.isEmpty) {
      return FadeSlideIn(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
          child: Column(
            children: [
              BreathingIcon(
                icon: Icons.bedtime_off,
                size: 72,
                iconSize: 36,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                backgroundColor: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
              ),
              const SizedBox(height: 16),
              Text('Your first night starts here', style: AppTokens.display.copyWith(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Track your sleep to unlock insights and build your consistency score.', style: AppTokens.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    
    final lastSession = _sleepHistory.last;

    String scoreLabel(int score) {
      if (score >= 85) return 'Excellent sleep';
      if (score >= 70) return 'Great sleep';
      if (score >= 50) return 'Decent night';
      if (score >= 30) return 'Rough night';
      return 'Poor sleep';
    }

    // A trend line needs at least 2 real nights — with fewer than that,
    // this used to fabricate 5 fake data points instead, which meant a
    // brand new user's very first "Sleep Consistency" chart would show an
    // entirely made-up trend with no relationship to their actual night,
    // sitting right next to their real score number below it.
    final hasTrend = _sleepHistory.length >= 2;
    final spots = <FlSpot>[
      for (int i = 0; i < _sleepHistory.length; i++) FlSpot(i.toDouble(), _sleepHistory[i].score.toDouble()),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeSlideIn(child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTokens.signal, AppTokens.signalDeep]),
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              boxShadow: [
                BoxShadow(color: AppTokens.signal.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sleep Consistency', style: AppTokens.body.copyWith(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 120,
                  child: hasTrend
                      ? LineChart(
                          LineChartData(
                            gridData: FlGridData(show: false),
                            titlesData: FlTitlesData(show: false),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                color: Colors.white,
                                barWidth: 4,
                                isStrokeCapRound: true,
                                dotData: FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Center(
                          child: Text(
                            'Track one more night to see your trend',
                            style: AppTokens.body.copyWith(color: Colors.white70, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Last Night Score', style: AppTokens.body.copyWith(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(
                            scoreLabel(lastSession.score),
                            style: AppTokens.display.copyWith(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ScoreRing(
                      score: lastSession.score,
                      size: 84,
                      ringColor: Colors.white,
                      trackColor: Colors.white.withValues(alpha: 0.2),
                      textColor: Colors.white,
                      suffix: '/ 100',
                    ),
                  ],
                ),
              ],
            ),
          )),
          const SizedBox(height: 24),

          if (_performanceInsight['hasInsight'] == true)
            FadeSlideIn(delay: const Duration(milliseconds: 90), child: Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.greenAccent),
                      SizedBox(width: 8),
                      Text('Performance Insight', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Your average sleep: ${_performanceInsight['avgSleep']}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('${_performanceInsight['bestPerformanceSleep']}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            )),
          FadeSlideIn(delay: const Duration(milliseconds: 150), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text('Sounds Captured', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${lastSession.audioEvents.length} saved', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              if (lastSession.audioEvents.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    await SleepService.deleteAllAudioEvents();
                    if (mounted) setState(() {});
                  },
                  child: const Text('Delete all', style: TextStyle(color: Colors.redAccent)),
                ),
            ],
          ),
          if (lastSession.additionalMoments > 0)
            Padding(
               padding: const EdgeInsets.only(bottom: 16.0),
               child: Text('+${lastSession.additionalMoments} other sounds detected', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
            ),
          if (lastSession.audioEvents.isEmpty)
             Text('No sounds captured last night.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ...lastSession.audioEvents.map((e) => AudioClipTile(event: e, sessionStart: lastSession.startTime)).toList(),
            ],
          )),
        ],
      ),
    );
  }


  Widget _buildInsightCard() {
    // This is only ever called once _buildWakeReport has already confirmed
    // totalPuzzles > 0 (real mission data exists) — it used to re-check a
    // completely unrelated, always-zero counter (puzzlesSolved, a separate
    // practice-mode stat — see the comment on totalPuzzles above) and show
    // a "still building your profile" placeholder regardless, directly
    // contradicting the real "Missions Beaten" count shown just above it.
    // The card below already handles a low streak gracefully via its own
    // "Getting Started" vs "Unstoppable" copy, so there's no need for an
    // outer gate at all once real data is confirmed to exist.
    return Container(
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
              Icon(Icons.local_fire_department, color: AppTokens.signal, size: 28),
              SizedBox(width: 8),
              Text('Consistency Focus', style: TextStyle(color: AppTokens.signal, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(_currentStreak >= 3 ? 'Unstoppable' : 'Getting Started', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('$_currentStreak day streak', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Building strong habits.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTokens.signal, size: 20),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
            ],
          ),
          Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

}
