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
  int _currentMoveIndex = 0;
  int _userElo = 400;
  bool _isSuccess = false;
  PlayerColor _playerColor = PlayerColor.white;
  
  late AnimationController _pulseController;
  late Animation<Color?> _pulseAnimation;
  bool _isFlashingRed = false;

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
    _currentPuzzle = PuzzleService.getRandomPuzzle(_userElo);
    _chessController.loadFen(_currentPuzzle.fen);
    
    if (_currentPuzzle.fen.contains(' b ')) {
      _playerColor = PlayerColor.black;
    } else {
      _playerColor = PlayerColor.white;
    }

    _chessController.addListener(_onBoardChange);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onBoardChange() async {
    if (_isSuccess || _isLoading) return;

    final history = _chessController.game.history;
    if (_currentMoveIndex % 2 != 0) return; // Opponent moving
    if (history.isEmpty) return;

    final lastMoveState = history.last;
    final lastMove = lastMoveState.move;
    final uciMove = '${lastMove.fromAlgebraic}${lastMove.toAlgebraic}${lastMove.promotion?.name ?? ""}';

    // Prevent index out of bounds if they somehow make a move after solving
    if (_currentMoveIndex >= _currentPuzzle.moves.length) return;

    final expectedMove = _currentPuzzle.moves[_currentMoveIndex];

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
    _chessController.addListener(_onBoardChange);
  }

  void _handleIncorrectMove() async {
    _chessController.removeListener(_onBoardChange);
    
    if (mounted) {
      setState(() {
        _isFlashingRed = true;
      });
    }

    HapticFeedback.heavyImpact();
    await EloService.updateElo(-5);
    final newElo = await EloService.getElo();

    // Critical Bug Fix: Micro-delay before undoing to let the flutter_chess_board
    // complete its drop animation and internal state updates without crashing.
    await Future.delayed(const Duration(milliseconds: 150));
    _chessController.undoMove();
    
    if (mounted) {
      setState(() {
        _userElo = newElo;
      });
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _isFlashingRed = false;
      });
    }
    
    _chessController.addListener(_onBoardChange);
  }

  void _handleSuccess() async {
    if (mounted) {
      setState(() {
        _isSuccess = true;
      });
    }
    HapticFeedback.vibrate();
    await EloService.updateElo(15);
    final newElo = await EloService.getElo();
    
    if (mounted) {
      setState(() {
        _userElo = newElo;
      });
    }

    await Future.delayed(const Duration(seconds: 2));
    
    await Alarm.stop(widget.alarmSettings.id);
    if (mounted) {
      // Alarm dismissed, return to home
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
        body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
      );
    }

    final turnText = _playerColor == PlayerColor.white ? 'WHITE TO PLAY' : 'BLACK TO PLAY';

    return PopScope(
      // CRITICAL FIX: Allow pop only if the puzzle is successfully solved.
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
                          // Premium Glassmorphic Elo Badge
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
                          const SizedBox(height: 40),
                          
                          // Turn Indicator / Success Message
                          Text(
                            _isSuccess ? 'CHECKMATE!' : 'WAKE UP',
                            style: TextStyle(
                              fontSize: 48, 
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
                          
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isSuccess ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _isSuccess ? '+15 ELO GAINED' : turnText,
                              style: TextStyle(
                                fontSize: 18, 
                                color: _isSuccess ? Colors.greenAccent : Colors.white70, 
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          
                          // Chessboard with Premium Shadow
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
                              child: ChessBoard(
                                controller: _chessController,
                                boardColor: BoardColor.brown,
                                boardOrientation: _playerColor,
                                size: MediaQuery.of(context).size.shortestSide > 500
                                    ? 450
                                    : MediaQuery.of(context).size.shortestSide - 36,
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
