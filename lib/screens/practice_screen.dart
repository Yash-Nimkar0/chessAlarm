import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import 'package:squares/squares.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:square_bishop/square_bishop.dart';
import '../models/puzzles.dart';
import '../services/elo_service.dart';
import '../widgets/platform_theme.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({Key? key}) : super(key: key);

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late bishop.Game _game;
  late SquaresState _squaresState;
  late Puzzle _currentPuzzle;
  int _currentMoveIndex = 0;
  int _userElo = 1000;
  int? _difficultyOverride;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isSuccess = false;
  bool _isFlashingRed = false;
  int _playerColor = Squares.white;
  late DateTime _startTime;

  int _scrubIndex = -1;
  int? _hintSquare;
  int _hintsRemaining = 3;

  @override
  void initState() {
    super.initState();
    _initPuzzle();
  }

  void _initPuzzle() async {
    _userElo = await EloService.getElo();
    final eloToUse = _difficultyOverride ?? _userElo;
    _currentPuzzle = await PuzzleService.getRandomPuzzle(eloToUse);
    _setupBoardForPuzzle();
  }

  void _skipPuzzle() async {
    if (_isProcessing) return;
    Haptics.vibrate(HapticsType.heavy);
    
    setState(() {
      _isLoading = true;
      _hintsRemaining = 3;
    });
    
    final eloToUse = _difficultyOverride ?? _userElo;
    _currentPuzzle = await PuzzleService.getRandomPuzzle(eloToUse);
    await _setupBoardForPuzzle();
  }

  Future<void> _setupBoardForPuzzle() async {
    _game = bishop.Game(variant: bishop.Variant.standard(), fen: _currentPuzzle.fen);
    _playerColor = _currentPuzzle.fen.contains(' b ') ? Squares.white : Squares.black;
    _squaresState = _game.squaresState(_playerColor);
    
    _currentMoveIndex = 0;
    _scrubIndex = -1;
    _hintSquare = null;
    _startTime = DateTime.now();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
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

  void _onMove(Move move) {
    if (_isSuccess || _isLoading || _isProcessing || _scrubIndex != -1) return;
    if (_currentMoveIndex >= _currentPuzzle.moves.length) return;

    final expectedUci = _currentPuzzle.moves[_currentMoveIndex];
    final expectedFrom = BoardSize.standard.squareNumber(expectedUci.substring(0, 2));
    final expectedTo = BoardSize.standard.squareNumber(expectedUci.substring(2, 4));
    
    if (move.from == expectedFrom && move.to == expectedTo) {
      _game.makeMoveString(expectedUci);
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

  void _handleSuccess() async {
    if (mounted) {
      setState(() {
        _isSuccess = true;
        _isProcessing = false;
      });
    }
    Haptics.vibrate(HapticsType.heavy);
    
    await EloService.updateElo(5);
    await EloService.recordPracticeSuccess();
    
    int elapsed = DateTime.now().difference(_startTime).inSeconds;
    await EloService.recordPuzzleSolved(solveTimeSeconds: elapsed, themes: _currentPuzzle.themes);
    
    final newElo = await EloService.getElo();
    if (mounted) {
      setState(() {
        _userElo = newElo;
      });
    }
  }

  void _showDifficultySelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text("Difficulty")),
          ListTile(
            title: Text("Auto (Your Elo: $_userElo)"),
            onTap: () {
              setState(() => _difficultyOverride = null);
              Navigator.pop(context);
              _skipPuzzle();
            },
          ),
          for (int d in [800, 1200, 1600, 2000])
            ListTile(
              title: Text("$d"),
              onTap: () {
                setState(() => _difficultyOverride = d);
                Navigator.pop(context);
                _skipPuzzle();
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(title: const Text('Daily Training')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    
    BoardTheme boardTheme = BoardTheme.blueGrey;
    switch(ThemeService().boardTheme) {
      case 'brown': boardTheme = BoardTheme.brown; break;
      
      case 'pink': boardTheme = BoardTheme.pink; break;
      
    }


    return PlatformScaffold(
      appBar: AppBar(
        title: const Text('Practice'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _showDifficultySelector(context),
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _isSuccess 
                  ? Colors.green.withOpacity(0.4) 
                  : _isFlashingRed 
                      ? Colors.red.withOpacity(0.8) 
                      : colorScheme.surface.withOpacity(0.8),
              Colors.black.withOpacity(0.9),
            ],
          )
        ),
        child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.psychology, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Practice Mode',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Rating: $_userElo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            
            if (_isSuccess)
              PlatformCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    "SOLVED!",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
              )
            else
              Text(
                _playerColor == Squares.white ? "WHITE TO PLAY" : "BLACK TO PLAY",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

            const SizedBox(height: 16),
            
            Expanded(
              flex: 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double size = constraints.maxWidth < constraints.maxHeight ? constraints.maxWidth : constraints.maxHeight;
                    return Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isFlashingRed ? Colors.red : colorScheme.outline.withOpacity(0.3),
                        width: _isFlashingRed ? 4 : 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: _isSuccess ? Colors.green.withOpacity(0.5) : Colors.transparent,
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: AbsorbPointer(
                      absorbing: _isProcessing || _scrubIndex != -1,
                      child: BoardController(
                        labelConfig: const LabelConfig(showLabels: false),
                        state: _renderState.board,
                        playState: _scrubIndex != -1 ? PlayState.observing : _renderState.state,
                        pieceSet: PieceSet.merida(),
                        theme: boardTheme,
                        moves: _renderState.moves,
                        onMove: _onMove,
                        onPremove: _onMove,
                        promotionBehaviour: PromotionBehaviour.autoPremove,
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
                  PlatformButton(
                    onPressed: !_isProcessing ? _skipPuzzle : null,
                    isIcon: true,
                    icon: const Icon(Icons.fast_forward),
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                    child: const Text('Skip (-10 Elo)'),
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
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: PlatformButton(
                  onPressed: (_hintsRemaining > 0 && !_isProcessing && _scrubIndex == -1) ? _useHint : null,
                  isIcon: true,
                  icon: const Icon(Icons.lightbulb_outline),
                  child: Text('Hint ($_hintsRemaining Left)'),
                ),
              ),

            if (_isSuccess)
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: PlatformButton(
                  onPressed: _skipPuzzle,
                  icon: const Icon(Icons.arrow_forward),
                  isIcon: true,
                  backgroundColor: colorScheme.primary,
                  child: const Text("Next Puzzle"),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
