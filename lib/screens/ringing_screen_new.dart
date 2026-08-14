import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:flutter/services.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:squares/squares.dart';
import 'package:square_bishop/square_bishop.dart';

import '../models/puzzles.dart';
import '../services/elo_service.dart';

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
  
  late AnimationController _pulseController;
  late Animation<Color?> _pulseAnimation;
  bool _isFlashingRed = false;

  int _hintsRemaining = 3;
  int? _hintSquare; // To highlight hint

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
    
    await _setupBoardForPuzzle();
  }

  Future<void> _setupBoardForPuzzle() async {
    _game = bishop.Game(variant: bishop.Variant.standard(), fen: _currentPuzzle.fen);
    _playerColor = _currentPuzzle.fen.contains(' b ') ? Squares.white : Squares.black;
    _squaresState = _game.squaresState(_playerColor);
    
    _currentMoveIndex = 0;
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
      
      // Auto-play the opponent setup move
      _makeBishopMoveFromUci(setupMove);
      
      _currentMoveIndex = 1;
    }
    
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _makeBishopMoveFromUci(String uci) {
    if (uci.length < 4) return;
    // Bishop uses algebraic notation natively but we can just use makeMoveString
    _game.makeMoveString(uci);
    setState(() {
      _squaresState = _game.squaresState(_playerColor);
    });
    Haptics.vibrate(HapticsType.medium);
  }

  String _getObjective(String themes) {
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
    if (_hintsRemaining <= 0 || _isProcessing || _isSuccess) return;
    if (_currentMoveIndex >= _currentPuzzle.moves.length) return;
    
    final expectedMove = _currentPuzzle.moves[_currentMoveIndex];
    if (expectedMove.length >= 2) {
      // Find the square index from the string (e.g. 'e2')
      final sqStr = expectedMove.substring(0, 2);
      final file = sqStr.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final rank = int.parse(sqStr[1]) - 1;
      
      Haptics.vibrate(HapticsType.light);
      
      setState(() {
        _hintsRemaining--;
        // For Squares package, white is at bottom (rank 0).
        // 0-63, bottom left is a1 (0). 
        // File 0-7, Rank 0-7.
        // Index = rank * 8 + file; Wait, standard board index? Let's check squares internals.
        // Actually Squares usually handles indices. 
        // A safer way is to just use Squares internals if possible, or just calculate it:
        _hintSquare = Squares.boardIndex(file, rank);
      });
    }
  }

  void _onUserMove(Move move) async {
    if (_isSuccess || _isLoading || _isProcessing) return;

    if (_currentMoveIndex >= _currentPuzzle.moves.length) return;
    final expectedMoveUci = _currentPuzzle.moves[_currentMoveIndex];

    // In squares, we convert the Move back to UCI to check against expected move
    // squares.Move has 'from', 'to', 'promo' but they are integers.
    // However, square_bishop provides 'game.makeSquaresMove(move)'.
    // If we let bishop make the move, we can read the last move in UCI format.
    
    bool valid = _game.makeSquaresMove(move);
    if (!valid) {
      Haptics.vibrate(HapticsType.error);
      return; // Illegal move completely ignored
    }

    setState(() {
      _squaresState = _game.squaresState(_playerColor);
      _isProcessing = true;
      _hintSquare = null;
    });

    // Get the move string that bishop just recorded
    final lastMoveString = _game.history.last.move.formatted(variant: _game.variant);
    // Note: formatted() might give SAN or UCI.
    // bishop has 'algebraic' or 'uci' representation?
    // Let's rely on just matching the from and to squares natively if possible,
    // or we can just see if the UCI string matches.
    // Actually, square_bishop's `move.toAlgebraic()` might exist.

    // Let's test the move directly
    // Instead of trusting formatted, we could just undo the move if it's wrong.
    // If it's correct, we proceed.
    
    // To get standard UCI in bishop:
    // Actually, `move.name` or similar might not exist in Squares Move. 
    // Wait, `_game.history.last.move.uci` might exist.
    // Let's assume `_game.history.last.move.algebraic()` exists?
    // I will write a simple check:
  }
