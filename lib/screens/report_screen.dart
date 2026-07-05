import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/platform_theme.dart';
import '../services/elo_service.dart';
import '../widgets/audio_clip_tile.dart';
import '../services/sleep_service.dart';
import '../services/performance_insight_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final stats = await EloService.getStats();
    final insight = await PerformanceInsightService.getInsights();
    final sleepHistory = await SleepService.getHistory();
    if (mounted) {
      setState(() {
        _stats = stats;
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
              const Text('Report', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chevron_left, color: Colors.white54),
                  SizedBox(width: 8),
                  Text('This week', style: TextStyle(color: Colors.white, fontSize: 16)),
                  SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: Colors.white54),
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
                    const SizedBox(width: 8),
                    _buildTab(2, 'Brain Report'),
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
          color: isSelected ? Colors.white : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    if (_selectedTab == 0) return _buildWakeReport();
    if (_selectedTab == 1) return _buildSleepReport();
    return _buildBrainReport();
  }

  Widget _buildWakeReport() {
    int totalPuzzles = _stats['totalPuzzlesSolved'] ?? 0;
    int elo = _stats['userElo'] ?? 400;

    return Column(
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
                    Text('$totalPuzzles', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('Puzzles Solved', style: TextStyle(color: Colors.white.withOpacity(0.7))),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$elo', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                Text('Current Elo', style: TextStyle(color: Colors.white.withOpacity(0.7))),
              ],
            ),
          ],
        ),
        const SizedBox(height: 40),
        Expanded(child: _buildMockChart()),
      ],
    );
  }

  Widget _buildSleepReport() {

    if (_sleepHistory.isEmpty) {
      return const Center(child: Text('No sleep history yet.', style: TextStyle(color: Colors.white54)));
    }
    
    final lastSession = _sleepHistory.last;
    final durationHours = lastSession.duration.inMinutes / 60.0;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.indigo, Colors.deepPurple]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Night 💤', style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${durationHours.floor()}h ${(durationHours * 60 % 60).toInt()}m', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                        const Text('Sleep', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${lastSession.score}', style: const TextStyle(color: Colors.greenAccent, fontSize: 32, fontWeight: FontWeight.bold)),
                        const Text('Recovery', style: TextStyle(color: Colors.white70)),
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
                color: Colors.greenAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
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
                  Text('Your average sleep: ${_performanceInsight['avgSleep']}', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('${_performanceInsight['bestPerformanceSleep']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          const Text('Sounds Captured', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${lastSession.audioEvents.length} saved', style: const TextStyle(color: Colors.white70)),
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
               child: Text('+${lastSession.additionalMoments} other sounds detected', style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
            ),
          if (lastSession.audioEvents.isEmpty)
             const Text('No sounds captured last night.', style: TextStyle(color: Colors.white54)),
          ...lastSession.audioEvents.map((e) => AudioClipTile(event: e, sessionStart: lastSession.startTime)).toList(),
        ],
      ),
    );
  }
  Widget _buildBrainReport() {
    int currentElo = _stats['userElo'] ?? 400;
    int eloGained = currentElo - 400;
    int puzzlesSolved = _stats['totalPuzzlesSolved'] ?? 0;
    int fastestSolve = 0; // Not tracked yet

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Brain Growth', style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Chess Rating', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('400 → $currentElo', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Text('+${max(0, eloGained)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
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
                color: Colors.greenAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
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
                  Text('Your average sleep: ${_performanceInsight['avgSleep']}', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('${_performanceInsight['bestPerformanceSleep']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          _buildStatRow('Puzzles Solved', '$puzzlesSolved', Icons.extension),
          const SizedBox(height: 12),
          _buildStatRow('Fastest Solve', fastestSolve > 0 && fastestSolve < 999 ? '${fastestSolve}s' : '--', Icons.timer),
          const SizedBox(height: 12),
          _buildStatRow('Accuracy', '88%', Icons.analytics), // Mock accuracy for V1
          const SizedBox(height: 24),

          if (_performanceInsight['hasInsight'] == true)
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
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
                  Text('Your average sleep: ${_performanceInsight['avgSleep']}', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('${_performanceInsight['bestPerformanceSleep']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          _buildInsightCard(),
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
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_clock, color: Colors.white54),
                SizedBox(width: 8),
                Text('Keep solving puzzles.', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            Text('Your chess profile is being built.', style: TextStyle(color: Colors.white, fontSize: 16, height: 1.4)),
          ],
        ),
      );
    }
    
    // Parse themesStats
    Map<String, dynamic> themesStats = _stats['themesStats'] ?? {};
    String topTheme = "Tactics";
    int topCount = 0;
    
    themesStats.forEach((key, value) {
      int count = value['count'] ?? 0;
      if (count > topCount) {
        topCount = count;
        topTheme = key;
      }
    });

    String displayTheme = topTheme.replaceAll(RegExp(r'(?<!^)(?=[A-Z])'), ' '); // camelCase to spaces
    displayTheme = displayTheme.isNotEmpty ? '${displayTheme[0].toUpperCase()}${displayTheme.substring(1)}' : 'Tactics';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('♞', style: TextStyle(fontSize: 24)),
              SizedBox(width: 8),
              Text('Tactical Strength', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(displayTheme, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('92% accuracy', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)), // Mock accuracy for now
          const SizedBox(height: 12),
          const Text('Your strongest pattern.', style: TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white54, size: 20),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMockChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 9) return const Text('9:00', style: TextStyle(color: Colors.white54, fontSize: 10));
                if (value == 10) return const Text('10:00', style: TextStyle(color: Colors.white54, fontSize: 10));
                if (value == 11) return const Text('11:00', style: TextStyle(color: Colors.white54, fontSize: 10));
                return const SizedBox.shrink();
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                if (value >= 0 && value < 7) {
                  return Text(days[value.toInt()], style: const TextStyle(color: Colors.white54, fontSize: 12));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 10.3),
              FlSpot(1, 10.1),
              FlSpot(2, 10.5),
              FlSpot(3, 9.8),
              FlSpot(4, 10.3),
              FlSpot(5, 11.0),
              FlSpot(6, 10.8),
            ],
            isCurved: true,
            color: Colors.deepOrangeAccent,
            barWidth: 3,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.deepOrangeAccent.withOpacity(0.2),
            ),
          ),
        ],
        minY: 8.5,
        maxY: 11.5,
      ),
    );
  }
}
