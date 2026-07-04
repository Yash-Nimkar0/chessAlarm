import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'dart:math';

class Puzzle {
  final String id;
  final String fen;
  final List<String> moves;
  final int rating;
  final String themes;

  const Puzzle({
    required this.id,
    required this.fen,
    required this.moves,
    required this.rating,
    required this.themes,
  });
}

class PuzzleService {
  static List<Puzzle> _puzzles = [];
  static bool _isLoaded = false;

  /// Loads puzzles asynchronously from the bundled CSV file in a background isolate.
  static Future<void> loadPuzzles() async {
    if (_isLoaded) return;
    
    final csvString = await rootBundle.loadString('assets/puzzles.csv');
    
    // Parse in a background isolate to avoid jank
    _puzzles = await compute(_parseCsv, csvString);
    _isLoaded = true;
  }

  /// The heavy parsing function that runs in the background.
  static List<Puzzle> _parseCsv(String csvString) {
    // Headers: PuzzleId,FEN,Moves,Rating,RatingDeviation,Popularity,NbPlays,Themes,GameUrl,OpeningTags
    final rows = const CsvToListConverter(eol: '\n').convert(csvString);
    final puzzles = <Puzzle>[];
    
    // Skip header row
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 8) continue;
      
      try {
        final id = row[0].toString();
        final fen = row[1].toString();
        final movesStr = row[2].toString();
        final rating = int.tryParse(row[3].toString()) ?? 1500;
        final themes = row[7].toString();

        final moves = movesStr.split(' ');
        
        puzzles.add(Puzzle(
          id: id,
          fen: fen,
          moves: moves,
          rating: rating,
          themes: themes,
        ));
      } catch (e) {
        // Skip malformed rows
        continue;
      }
    }
    
    return puzzles;
  }

  /// Dynamically fetches a puzzle that matches the user's current Elo rating.
  static Future<Puzzle> getRandomPuzzle(int userElo) async {
    if (!_isLoaded) {
      await loadPuzzles();
    }
    
    if (_puzzles.isEmpty) {
      // Fallback
      return Puzzle(
        id: "fallback",
        rating: 800,
        fen: '1k1r4/pp3p1p/5p2/8/8/2R2N2/P4PPP/1R4K1 w - - 0 1',
        moves: ['b1b7', 'b8b7', 'c3c7'],
        themes: "mate mateIn2",
      );
    }
    
    final list = List<Puzzle>.from(_puzzles);
    
    // Sort the puzzles by how close their rating is to the user's Elo
    list.sort((a, b) => (a.rating - userElo).abs().compareTo((b.rating - userElo).abs()));
    
    // Pick from the top 100 closest puzzles to add variety
    final closest = list.take(100).toList();
    closest.shuffle();
    return closest.first;
  }
}
