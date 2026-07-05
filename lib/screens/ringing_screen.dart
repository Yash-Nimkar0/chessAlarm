import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import 'package:alarm/alarm.dart';
import 'package:flutter/services.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

import 'package:bishop/bishop.dart' as bishop;
import 'package:squares/squares.dart';
import 'package:square_bishop/square_bishop.dart';

import '../models/puzzles.dart';
import '../services/elo_service.dart';
import 'dart:io';
import '../models/mission_settings.dart';
import 'missions/math_mission.dart';
import 'missions/memory_mission.dart';
import 'mission_complete_screen.dart';
import '../widgets/platform_theme.dart';
import '../services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/sleep_service.dart';

class RingingScreen extends StatefulWidget {
  final AlarmSettings alarmSettings;
  const RingingScreen({Key? key, required this.alarmSettings}) : super(key: key);

  @override
  State<RingingScreen> createState() => _RingingScreenState();
}

class _RingingScreenState extends State<RingingScreen> with SingleTickerProviderStateMixin {
  late bishop.Game _game;
  late SquaresState _squaresState;
  int _playerColor = Squares.white;

  late Puzzle _currentPuzzle;
  bool _isLoading = true;
  bool _isProcessing = false;
  int _currentMoveIndex = 0;
  int _userElo = 400;
  bool _isSuccess = false;

  // History Scrubbing Anti-Cheat
  int _scrubIndex = -1; // -1 means live state
  
  late AnimationController _pulseController;
  late Animation<Color?> _pulseAnimation;
  bool _isFlashingRed = false;

  int _hintsRemaining = 3;
  int? _hintSquare;

  late MissionSettings _missionSettings;
  late DateTime _startTime;

  int _skipsUsed = 0;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logEvent('alarm_triggered', {'alarm_id': widget.alarmSettings.id});
    _startTime = DateTime.now();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _pulseAnimation = ColorTween(
      begin: const Color(0xFF1A0000),
      end: const Color(0xFF4A0000),
    ).animate(_pulseController);

    _loadSkips();

    if (widget.alarmSettings.payload != null) {
      _missionSettings = MissionSettings.fromJsonString(widget.alarmSettings.payload!);
    } else {
      _missionSettings = MissionSettings(type: 'wakeRoutine');
    }

    if (_missionSettings.type == 'wakeRoutine') {
      _initPuzzle();
    } else {
      _isLoading = false;
    }
  }

  void _loadSkips() async {
    final prefs = await SharedPreferences.getInstance();
    final monthKey = 'skips_${DateTime.now().year}_${DateTime.now().month}';
    if (mounted) {
      setState(() {
        _skipsUsed = prefs.getInt(monthKey) ?? 0;
      });
    }
  }

  void _initPuzzle() async {
    _userElo = await EloService.getElo();
    int puzzleElo = _missionSettings.difficultyOverride ?? _userElo;
    
    if (_missionSettings.difficultyOverride == null) {
      int reduction = (_userElo * 0.20).round();
      if (reduction > 300) reduction = 300;
      puzzleElo = _userElo - reduction;
    }
    
    if (puzzleElo < 400) puzzleElo = 400; // Floor
    
    _currentPuzzle = await PuzzleService.getRandomPuzzle(puzzleElo);
    AnalyticsService.logEvent('puzzle_started', {'puzzle_elo': puzzleElo});
    
    await _setupBoardForPuzzle();
  }

  Future<void> _setupBoardForPuzzle() async {
    _game = bishop.Game(variant: bishop.Variant.standard(), fen: _currentPuzzle.fen);
    _playerColor = _currentPuzzle.fen.contains(' b ') ? Squares.white : Squares.black;
    _squaresState = _game.squaresState(_playerColor);
    
    _currentMoveIndex = 0;
    _scrubIndex = -1;
    _hintSquare = null;

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isProcessing = true;
      });
    }

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    
    if (_currentPuzzle.moves.isNotEmpty) {
      final setupMove = _currentPuzzle.moves[0];
      
      _game.makeMoveString(setupMove);
      Haptics.vibrate(HapticsType.medium);
      
      _currentMoveIndex = 1;
      _squaresState = _game.squaresState(_playerColor);
    }
    
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  SquaresState get _renderState {
    var sState = _squaresState;
    
    if (_scrubIndex != -1) {
      if (_scrubIndex < _game.history.length) {
        // Temporarily undo moves to capture the old state
        int movesToUndo = _game.history.length - _scrubIndex - 1;
        List<bishop.Move> undone = [];
        for (int i = 0; i < movesToUndo; i++) {
          final m = _game.undo();
          if (m != null) undone.add(m);
        }
        sState = _game.squaresState(_playerColor);
        
        // Put them back
        for (var m in undone.reversed) {
          _game.makeMove(m);
        }
      }
    }
    
    // Inject hint highlighting if active
    if (_hintSquare != null && _scrubIndex == -1) {
      sState = sState.copyWith(
        board: sState.board.copyWith(lastTo: _hintSquare),
      );
    }
    
    return sState;
  }

  void _scrubBackward() {
    if (_isProcessing || _game.history.isEmpty) return;
    int currentIndex = _scrubIndex == -1 ? _game.history.length - 2 : _scrubIndex - 1;
    if (currentIndex >= 0) {
      Haptics.vibrate(HapticsType.light);
      setState(() {
        _scrubIndex = currentIndex;
      });
    }
  }

  void _scrubForward() {
    if (_isProcessing || _scrubIndex == -1) return;
    int nextIndex = _scrubIndex + 1;
    Haptics.vibrate(HapticsType.light);
    setState(() {
      if (nextIndex >= _game.history.length - 1) {
        _scrubIndex = -1;
      } else {
        _scrubIndex = nextIndex;
      }
    });
  }

  void _skipPuzzle() async {
    if (_isProcessing) return;
    
    final prefs = await SharedPreferences.getInstance();
    final monthKey = 'skips_${DateTime.now().year}_${DateTime.now().month}';
    final currentSkips = prefs.getInt(monthKey) ?? 0;
    
    if (currentSkips >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No Backup Unlocks remaining this month.')));
      return;
    }
    
    Haptics.vibrate(HapticsType.heavy);
    await prefs.setInt(monthKey, currentSkips + 1);
    AnalyticsService.logEvent('backup_unlock_used');
    
    if (mounted) {
      setState(() => _isProcessing = true);
    }
    
    await Alarm.stop(widget.alarmSettings.id);
    await _rescheduleIfRecurring();
    
    if (mounted) {
      int elapsed = DateTime.now().difference(_startTime).inSeconds;
      await SleepService.recordWakePerformance(elapsed, 0, true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MissionCompleteScreen(
            elapsedSeconds: elapsed,
            eloChange: 0,
            isSkip: true,
          ),
        ),
      );
    }
  }

  String _getObjective(String themes) {
    if (_isSuccess) return themes.contains("mate") ? "CHECKMATE!" : "PUZZLE SOLVED!";
    String prefix = _playerColor == Squares.white ? "WHITE TO PLAY\n" : "BLACK TO PLAY\n";
    if (themes.contains("mateIn1")) return "${prefix}FIND THE MATE IN 1";
    if (themes.contains("mateIn2")) return "${prefix}FIND THE MATE IN 2";
    if (themes.contains("mateIn3")) return "${prefix}FIND THE MATE IN 3";
    if (themes.contains("mate")) return "${prefix}FIND THE CHECKMATE";
    if (themes.contains("fork")) return "${prefix}FIND THE FORK";
    if (themes.contains("pin")) return "${prefix}EXPLOIT THE PIN";
    if (themes.contains("advantage")) return "${prefix}WIN MATERIAL";
    return "${prefix}FIND THE BEST MOVE";
  }

  void _useHint() {
    if (_hintsRemaining <= 0 || _isProcessing || _isSuccess || _scrubIndex != -1) return;
    if (_currentMoveIndex >= _currentPuzzle.moves.length) return;
    
    final expectedMove = _currentPuzzle.moves[_currentMoveIndex];
    if (expectedMove.length >= 2) {
      Haptics.vibrate(HapticsType.light);
      
      final sqStr = expectedMove.substring(0, 2);
      final squareIndex = BoardSize.standard.squareNumber(sqStr);
      
      setState(() {
        _hintsRemaining--;
        _hintSquare = squareIndex;
      });
    }
  }

  void _onUserMove(Move move) async {
    if (_isSuccess || _isLoading || _isProcessing || _scrubIndex != -1) return;
    if (_currentMoveIndex >= _currentPuzzle.moves.length) return;

    final expectedUci = _currentPuzzle.moves[_currentMoveIndex];
    final expectedFrom = BoardSize.standard.squareNumber(expectedUci.substring(0, 2));
    final expectedTo = BoardSize.standard.squareNumber(expectedUci.substring(2, 4));

    if (move.from == expectedFrom && move.to == expectedTo) {
      // User made the correct move!
      _game.makeMoveString(expectedUci); // Make it fully via bishop (handles promos)
      Haptics.vibrate(HapticsType.medium);
      
      setState(() {
        _squaresState = _game.squaresState(_playerColor);
        _hintSquare = null;
        _isProcessing = true;
      });

      _currentMoveIndex++;
      
      if (_currentMoveIndex >= _currentPuzzle.moves.length) {
        _handleSuccess();
      } else {
        _makeOpponentMove();
      }
    } else {
      // It might be a valid bishop move, but it's not the puzzle solution.
      // So we reject it.
      _handleIncorrectMove();
    }
  }

  void _makeOpponentMove() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final opponentMove = _currentPuzzle.moves[_currentMoveIndex];
    
    _game.makeMoveString(opponentMove);
    Haptics.vibrate(HapticsType.medium);
    
    _currentMoveIndex++;
    
    if (mounted) {
      setState(() {
        _squaresState = _game.squaresState(_playerColor);
        _isProcessing = false;
      });
    }
  }

  void _handleIncorrectMove() async {
    if (mounted) {
      setState(() {
        _isFlashingRed = true;
      });
    }

    Haptics.vibrate(HapticsType.error);
    await EloService.updateElo(-10);
    final newElo = await EloService.getElo();

    await Future.delayed(const Duration(milliseconds: 150));
    
    await _setupBoardForPuzzle();
    
    if (mounted) {
      setState(() {
        _userElo = newElo;
        _hintsRemaining = 3;
      });
    }

    await Future.delayed(const Duration(milliseconds: 300));
    
    if (mounted) {
      setState(() {
        _isFlashingRed = false;
      });
    }
  }

  Future<void> _rescheduleIfRecurring() async {
    final prefs = await SharedPreferences.getInstance();
    final String? daysJson = prefs.getString('alarm_days_${widget.alarmSettings.id}');
    if (daysJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(daysJson);
        final List<bool> days = decoded.map((e) => e as bool).toList();
        
        if (days.contains(true)) {
          // Find next occurrence
          DateTime candidate = widget.alarmSettings.dateTime.add(const Duration(days: 1));
          for (int i = 0; i < 7; i++) {
            int dayIndex = candidate.weekday - 1;
            if (days[dayIndex]) {
              final newSettings = widget.alarmSettings.copyWith(
                id: widget.alarmSettings.id,
                dateTime: candidate,
              );
              await Alarm.set(alarmSettings: newSettings);
              return;
            }
            candidate = candidate.add(const Duration(days: 1));
          }
        }
      } catch (e) {}
    }
  }

  void _handleSuccess() async {
    if (mounted) {
      setState(() {
        _isSuccess = true;
        _isProcessing = true;
      });
    }
    Haptics.vibrate(HapticsType.heavy);
    
    int eloReward = 10;
    if (_hintsRemaining == 2) eloReward = 5;
    else if (_hintsRemaining == 1) eloReward = 2;
    else if (_hintsRemaining == 0) eloReward = 0;
    
    await EloService.updateElo(eloReward);
    await EloService.recordMorningSuccess();
    
    int elapsedTime = DateTime.now().difference(_startTime).inSeconds;
    await EloService.recordPuzzleSolved(solveTimeSeconds: elapsedTime, themes: _currentPuzzle?.themes);
    
    final newElo = await EloService.getElo();
    
    if (mounted) {
      setState(() {
        _userElo = newElo;
      });
    }

    await Future.delayed(const Duration(seconds: 2));
    
    await Alarm.stop(widget.alarmSettings.id);
    await _rescheduleIfRecurring();
    
    if (mounted) {
      int elapsed = DateTime.now().difference(_startTime).inSeconds;
      AnalyticsService.logEvent('puzzle_completed', {
        'solve_time': elapsed,
        'elo_gained': eloReward,
      });
      await SleepService.recordWakePerformance(elapsed, _hintsRemaining, false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MissionCompleteScreen(
            elapsedSeconds: elapsed,
            eloChange: eloReward,
            isSkip: false,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.redAccent),
              SizedBox(height: 16),
              Text('Fetching real puzzles...', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }
    
    Widget content;
    int difficulty = _missionSettings.difficultyOverride ?? _userElo;
    
    if (_missionSettings.type == 'math') {
      content = MathMission(onSuccess: _handleSuccess, onSkip: _skipPuzzle, difficulty: difficulty);
    } else if (_missionSettings.type == 'memory') {
      content = MemoryMission(onSuccess: _handleSuccess, onSkip: _skipPuzzle, difficulty: difficulty);
    } else {
      content = _buildChessMission();
    }

    return PopScope(
      canPop: _isSuccess,
      child: PlatformScaffold(
        body: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _isSuccess 
                        ? Colors.green.withOpacity(0.4) 
                        : _isFlashingRed 
                            ? Colors.red.withOpacity(0.8) 
                            : (_pulseAnimation.value ?? Colors.black).withOpacity(Platform.isIOS ? 0.3 : 1.0),
                    Colors.black.withOpacity(Platform.isIOS ? 0.2 : 1.0),
                  ],
                )
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: content,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChessMission() {
    final objectiveText = _getObjective(_currentPuzzle.themes);
    final renderState = _renderState;
    
    BoardTheme boardTheme = BoardTheme.brown;
    switch(ThemeService().boardTheme) {
      case 'blueGrey': boardTheme = BoardTheme.blueGrey; break;
      
      case 'pink': boardTheme = BoardTheme.pink; break;
      
    }

    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
        PlatformCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.military_tech, color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Elo: $_userElo',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        Text(
          objectiveText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: _isSuccess ? 40 : 24, 
            fontWeight: FontWeight.w900, 
            color: _isSuccess ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 8),
        
        if (_isSuccess)
          PlatformCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '+${_hintsRemaining == 3 ? 10 : _hintsRemaining == 2 ? 5 : _hintsRemaining == 1 ? 2 : 0} ELO GAINED',
                style: TextStyle(
                  fontSize: 18, 
                  color: Theme.of(context).colorScheme.onPrimaryContainer, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          ),
        const Spacer(),
        
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxWidth,
                    child: Container(
                      decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: AbsorbPointer(
                    absorbing: _isProcessing || _scrubIndex != -1,
                    child: BoardController(
                      labelConfig: const LabelConfig(showLabels: false),
                      state: renderState.board,
                      playState: _scrubIndex != -1 ? PlayState.observing : renderState.state,
                      pieceSet: PieceSet.merida(),
                      theme: boardTheme,
                      moves: renderState.moves,
                      onMove: _onUserMove,
                      onPremove: _onUserMove,
                      promotionBehaviour: PromotionBehaviour.autoPremove,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  ),
  
  const Spacer(),
  
  // History and Skip Controls
        if (!_isSuccess)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.fast_rewind),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                iconSize: 32,
                onPressed: (_game.history.isNotEmpty && !_isProcessing) ? _scrubBackward : null,
              ),
              const SizedBox(width: 20),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlatformButton(
                    onPressed: (!_isProcessing && _skipsUsed < 3) ? _skipPuzzle : null,
                    isIcon: true,
                    icon: const Icon(Icons.shield),
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                    child: const Text('Backup Unlock'),
                  ),
                  const SizedBox(height: 4),
                  Text('${3 - _skipsUsed} remaining this month', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: const Icon(Icons.fast_forward),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                iconSize: 32,
                onPressed: (_scrubIndex != -1 && !_isProcessing) ? _scrubForward : null,
              ),
            ],
          ),
          
        const SizedBox(height: 16),
        
        if (!_isSuccess)
          PlatformButton(
            onPressed: (_hintsRemaining > 0 && !_isProcessing && _scrubIndex == -1) ? _useHint : null,
            isIcon: true,
            icon: const Icon(Icons.lightbulb_outline),
            child: Text('Hint ($_hintsRemaining Left)'),
          ),
      ],
      ),
    );
  }
}
