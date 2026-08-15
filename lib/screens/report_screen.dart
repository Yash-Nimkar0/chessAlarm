import 'package:flutter/material.dart';
import '../widgets/audio_clip_tile.dart';
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
    final insight = await PerformanceInsightService.getInsights();
    final sleepHistory = await SleepService.getHistory();
    final stats = await EloService.getStats();
    
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chevron_left, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text('This week', style: AppTokens.body.copyWith(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
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
    return GestureDetector(
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
    int totalPuzzles = _stats['totalPuzzlesSolved'] ?? 0;

    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$totalPuzzles', style: AppTokens.display.copyWith(color: Theme.of(context).colorScheme.onSurface, fontSize: 36, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text('Missions Beaten', style: AppTokens.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildStatRow('Current Streak', '$_currentStreak Days', '🔥'),
          const SizedBox(height: 24),
          if (totalPuzzles == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
              child: Column(
                children: [
                  Icon(Icons.query_stats, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('Your first morning starts here', style: AppTokens.display.copyWith(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Complete your first wake mission to start tracking your consistency.', style: AppTokens.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4), textAlign: TextAlign.center),
                ],
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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
        child: Column(
          children: [
            Icon(Icons.bedtime_off, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('Your first night starts here', style: AppTokens.display.copyWith(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Track your sleep to unlock insights and build your consistency score.', style: AppTokens.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4), textAlign: TextAlign.center),
          ],
        ),
      );
    }
    
    final lastSession = _sleepHistory.last;
    
    // Generate dummy fl_chart data based on sleep history if available
    List<FlSpot> spots = [];
    if (_sleepHistory.length >= 2) {
      for (int i = 0; i < _sleepHistory.length; i++) {
        spots.add(FlSpot(i.toDouble(), _sleepHistory[i].score.toDouble()));
      }
    } else {
      spots = const [FlSpot(0, 60), FlSpot(1, 80), FlSpot(2, 75), FlSpot(3, 90), FlSpot(4, 85)];
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
                  child: LineChart(
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
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${lastSession.score}', style: AppTokens.display.copyWith(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                        Text('Last Night Score', style: AppTokens.body.copyWith(color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_performanceInsight['hasInsight'] == true)
            Container(
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
            ),
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
      ),
    );
  }


  Widget _buildInsightCard() {
    int puzzlesSolved = _stats['puzzlesSolved'] ?? 0;
    
    if (puzzlesSolved < 50) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_clock, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('Keep completing missions.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Your Wakely profile is being built.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, height: 1.4)),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
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
              Text('🔥', style: TextStyle(fontSize: 24)),
              SizedBox(width: 8),
              Text('Consistency Focus', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
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

  Widget _buildStatRow(String label, String value, String emoji) {
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
              Text(emoji, style: const TextStyle(fontSize: 20)),
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
