import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import '../models/puzzles.dart';
import '../services/elo_service.dart';

class RingingScreen extends StatefulWidget {
  final AlarmSettings alarmSettings;
  const RingingScreen({Key? key, required this.alarmSettings}) : super(key: key);

  @override
  State<RingingScreen> createState() => _RingingScreenState();
}

class _RingingScreenState extends State<RingingScreen> with SingleTickerProviderStateMixin {
  final ChessBoardController _chessController = ChessBoardController();
  late Puzzle _currentPuzzle;
  bool _isLoading = true;
  bool _isProcessing = false; // CRITICAL: The new board lock state
  int _currentMoveIndex = 0;
  int _userElo = 400;
  bool _isSuccess = false;
  PlayerColor _playerColor = PlayerColor.white;
  
  late AnimationController _pulseController;
  late Animation<Color?> _pulseAnimation;
  bool _isFlashingRed = false;

  int _hintsRemaining = 3;
  List<BoardArrow> _arrows = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _pulseAnimation = ColorTween(
      begin: const Color(0xFF1A0000),
      end: const Color(0xFF4A0000),
    ).animate(_pulseController);

    _initPuzzle();
  }

  void _initPuzzle() async {
    _userElo = await EloService.getElo();
    _currentPuzzle = await PuzzleService.getRandomPuzzle(_userElo);
    _chessController.loadFen(_currentPuzzle.fen);
    
    _playerColor = _currentPuzzle.fen.contains(' b ') ? PlayerColor.black : PlayerColor.white;

    _chessController.addListener(_onBoardChange);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getObjective(String themes) {
    if (themes.contains("mateIn1")) return "FIND THE MATE IN 1";
    if (themes.contains("mateIn2")) return "FIND THE MATE IN 2";
    if (themes.contains("mateIn3")) return "FIND THE MATE IN 3";
    if (themes.contains("mate")) return "FIND THE CHECKMATE";
    if (themes.contains("fork")) return "FIND THE FORK";
    if (themes.contains("pin")) return "EXPLOIT THE PIN";
    if (themes.contains("advantage")) return "WIN MATERIAL";
    return "FIND THE BEST MOVE";
  }

  void _useHint() {
    if (_hintsRemaining <= 0 || _isProcessing || _isSuccess) return;
    
    if (_currentMoveIndex >= _currentPuzzle.moves.length) return;
    
    final expectedMove = _currentPuzzle.moves[_currentMoveIndex];
    if (expectedMove.length >= 2) {
      final startSquare = expectedMove.substring(0, 2);
      
      setState(() {
        _hintsRemaining--;
        _arrows = [
          BoardArrow(
            from: startSquare,
            to: startSquare, // Point to itself to just highlight the piece
            color: Colors.blueAccent.withOpacity(0.7),
          )
        ];
      });
    }
  }

  void _onBoardChange() async {
    // If the board is processing a move, ignore all other inputs
    if (_isSuccess || _isLoading || _isProcessing) return;

    final history = _chessController.game.history;
    if (history.isEmpty) return;

    final lastMoveState = history.last;
    final lastMove = lastMoveState.move;
    final uciMove = '${lastMove.fromAlgebraic}${lastMove.toAlgebraic}${lastMove.promotion?.name ?? ""}';

    if (_currentMoveIndex >= _currentPuzzle.moves.length) return;

    final expectedMove = _currentPuzzle.moves[_currentMoveIndex];

    // INSTANTLY LOCK THE BOARD
    setState(() {
      _isProcessing = true;
      _arrows = []; // Clear arrows on move
    });

    if (uciMove == expectedMove) {
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
    
    // Temporarily remove listener so the engine making a move doesn't trigger our validation
    _chessController.removeListener(_onBoardChange);
    
    final from = opponentMove.substring(0, 2);
    final to = opponentMove.substring(2, 4);
    if (opponentMove.length > 4) {
      _chessController.makeMoveWithPromotion(
        from: from, 
        to: to, 
        pieceToPromoteTo: opponentMove.substring(4, 5).toUpperCase(),
      );
    } else {
      _chessController.makeMove(from: from, to: to);
    }
    
    _currentMoveIndex++;
    
    // Add listener back and UNLOCK THE BOARD
    _chessController.addListener(_onBoardChange);
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _handleIncorrectMove() async {
    _chessController.removeListener(_onBoardChange);
    
    if (mounted) {
      setState(() {
        _isFlashingRed = true;
      });
    }

    HapticFeedback.heavyImpact();
    // Standard penalty regardless of hints
    await EloService.updateElo(-10);
    final newElo = await EloService.getElo();

    await Future.delayed(const Duration(milliseconds: 150));
    _chessController.undoMove();
    
    if (mounted) {
      setState(() {
        _userElo = newElo;
      });
    }

    await Future.delayed(const Duration(milliseconds: 300));
    
    _chessController.addListener(_onBoardChange);
    if (mounted) {
      setState(() {
        _isFlashingRed = false;
        _isProcessing = false; // UNLOCK THE BOARD
      });
    }
  }

  void _handleSuccess() async {
    if (mounted) {
      setState(() {
        _isSuccess = true;
        _isProcessing = true; // Keep board locked on success
      });
    }
    HapticFeedback.vibrate();
    
    // Diminishing Returns Elo logic based on hints used
    int eloReward = 10;
    if (_hintsRemaining == 2) eloReward = 5;
    else if (_hintsRemaining == 1) eloReward = 2;
    else if (_hintsRemaining == 0) eloReward = 0;
    
    await EloService.updateElo(eloReward);
    final newElo = await EloService.getElo();
    
    if (mounted) {
      setState(() {
        _userElo = newElo;
      });
    }

    await Future.delayed(const Duration(seconds: 2));
    
    await Alarm.stop(widget.alarmSettings.id);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _chessController.removeListener(_onBoardChange);
    _chessController.dispose();
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

    final objectiveText = _getObjective(_currentPuzzle.themes);

    return PopScope(
      canPop: _isSuccess,
      child: Scaffold(
        backgroundColor: Colors.black,
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
                            : _pulseAnimation.value!,
                    Colors.black,
                  ],
                )
              ),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.military_tech, color: Colors.amberAccent, size: 28),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Elo: $_userElo',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Puzzle Objective Header
                          Text(
                            _isSuccess ? 'CHECKMATE!' : objectiveText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: _isSuccess ? 48 : 28, 
                              fontWeight: FontWeight.w900, 
                              color: _isSuccess ? Colors.greenAccent : Colors.white,
                              letterSpacing: 2.0,
                              shadows: [
                                BoxShadow(
                                  color: _isSuccess ? Colors.green : Colors.redAccent,
                                  blurRadius: 20,
                                )
                              ]
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Elo gain feedback
                          if (_isSuccess)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '+${_hintsRemaining == 3 ? 10 : _hintsRemaining == 2 ? 5 : _hintsRemaining == 1 ? 2 : 0} ELO GAINED',
                                style: const TextStyle(
                                  fontSize: 18, 
                                  color: Colors.greenAccent, 
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3.0,
                                ),
                              ),
                            ),
                          const SizedBox(height: 40),
                          
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white24, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: _isSuccess ? Colors.greenAccent.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                )
                              ]
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              // CRITICAL FIX: AbsorbPointer physically disables touch inputs when processing
                              child: AbsorbPointer(
                                absorbing: _isProcessing,
                                child: ChessBoard(
                                  controller: _chessController,
                                  boardColor: BoardColor.brown,
                                  boardOrientation: _playerColor,
                                  arrows: _arrows,
                                  size: MediaQuery.of(context).size.shortestSide > 500
                                      ? 450
                                      : MediaQuery.of(context).size.shortestSide - 36,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          
                          // Hint Button
                          if (!_isSuccess)
                            ElevatedButton.icon(
                              onPressed: _hintsRemaining > 0 ? _useHint : null,
                              icon: const Icon(Icons.lightbulb_outline),
                              label: Text('HINT ($_hintsRemaining LEFT)'),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                disabledForegroundColor: Colors.white24,
                                disabledBackgroundColor: Colors.white.withOpacity(0.05),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}
