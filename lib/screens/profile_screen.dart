import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/elo_service.dart';
import '../widgets/platform_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _userElo = 400;
  List<int> _eloHistory = [];
  Map<String, int> _stats = {
    'currentStreak': 0,
    'longestStreak': 0,
    'morningsWon': 0,
    'puzzlesSolved': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final elo = await EloService.getElo();
    final history = await EloService.getEloHistory();
    final stats = await EloService.getStats();
    
    if (mounted) {
      setState(() {
        _userElo = elo;
        _eloHistory = history;
        _stats = stats;
      });
    }
  }

  Widget _buildBrainGraph(ColorScheme colorScheme) {
    if (_eloHistory.isEmpty) return const SizedBox.shrink();
    List<int> graphData = List.from(_eloHistory);
    if (graphData.length == 1) graphData.add(graphData.first);

    List<FlSpot> spots = [];
    for (int i = 0; i < graphData.length; i++) {
      spots.add(FlSpot(i.toDouble(), graphData[i].toDouble()));
    }

    double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 50;
    double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 50;
    if (minY < 100) minY = 100;

    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: colorScheme.primary,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true, 
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: colorScheme.primary,
                    strokeWidth: 2,
                    strokeColor: colorScheme.surface,
                  );
                }
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withOpacity(0.3),
                    colorScheme.primary.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return PlatformCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final level = EloService.getLevel(_stats['morningsWon'] ?? 0);

    return Scaffold(
      backgroundColor: Colors.transparent, // Let parent handle bg if needed
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Avatar and Level Section
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primaryContainer,
                        border: Border.all(color: colorScheme.primary, width: 3),
                      ),
                      child: Icon(Icons.person, size: 60, color: colorScheme.onPrimaryContainer),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Level: $level',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'Morning Rating: $_userElo',
                      style: TextStyle(
                        fontSize: 18,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Brain Graph
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'BRAIN GRAPH (7 DAYS)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              _buildBrainGraph(colorScheme),
              
              const SizedBox(height: 20),
              
              // Metrics Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    _buildStatCard(
                      'Current Streak',
                      '${_stats['currentStreak']} 🔥',
                      Icons.local_fire_department,
                      Colors.orange,
                    ),
                    _buildStatCard(
                      'Longest Streak',
                      '${_stats['longestStreak']} 👑',
                      Icons.emoji_events,
                      Colors.amber,
                    ),
                    _buildStatCard(
                      'Mornings Won',
                      '${_stats['morningsWon']} 🌅',
                      Icons.wb_sunny,
                      Colors.blue,
                    ),
                    _buildStatCard(
                      'Puzzles Solved',
                      '${_stats['puzzlesSolved']} 🧩',
                      Icons.extension,
                      Colors.purple,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
