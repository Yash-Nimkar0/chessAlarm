class Puzzle {
  final int rating;
  final String fen;
  final List<String> moves;

  const Puzzle({
    required this.rating,
    required this.fen,
    required this.moves,
  });
}

class PuzzleService {
  // A scalable database of puzzles. In a production environment, this list
  // would be populated by reading a bundled CSV file containing 10,000+ Lichess puzzles.
  static const List<Puzzle> puzzles = [
    // --- 400 ELO (Beginner: Mate in 1) ---
    Puzzle(
      rating: 400,
      fen: 'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5Q2/PPPP1PPP/RNB1K1NR w KQkq - 0 1',
      moves: ['f3f7'], // Scholar's Mate
    ),
    Puzzle(
      rating: 450,
      fen: '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1',
      moves: ['a1a8'], // Back rank mate
    ),
    
    // --- 600 ELO (Novice: Mate in 1 & Simple Mate in 2) ---
    Puzzle(
      rating: 600,
      fen: 'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR b KQkq - 1 3',
      moves: ['h4e1'], // Fool's Mate
    ),
    Puzzle(
      rating: 650,
      fen: '7k/7p/7K/8/8/8/8/R7 w - - 0 1',
      moves: ['a1a8'], // Corner rook mate
    ),

    // --- 800 ELO (Intermediate: Mate in 2) ---
    Puzzle(
      rating: 800,
      fen: '1k1r4/pp3p1p/5p2/8/8/2R2N2/P4PPP/1R4K1 w - - 0 1',
      moves: ['b1b7', 'b8b7', 'c3c7'], // Typical tactical sequence
    ),
    Puzzle(
      rating: 850,
      fen: 'r1b2rk1/pppp1ppp/8/4P3/2B4q/2N3P1/PP1P1b1P/R1BQR1K1 w - - 0 12',
      moves: ['g1f2', 'h4h2', 'f2f1', 'h2h1'], // Queen infiltration
    ),

    // --- 1000 ELO (Advanced: Mate in 2 & 3) ---
    Puzzle(
      rating: 1000,
      fen: 'r2q1rk1/pp1b1ppp/2n1pn2/2bp4/8/2P1PN2/PP1NBPPP/R1BQ1RK1 w - - 3 9',
      moves: ['e2a6', 'b7a6', 'd1a4'],
    ),
    Puzzle(
      rating: 1200,
      fen: '5rk1/5ppp/8/8/8/8/5PPP/5RK1 w - - 0 1',
      moves: ['f1a1', 'f8a8', 'a1a8'], 
    ),
  ];

  /// Dynamically fetches a puzzle that matches the user's current Elo rating.
  static Puzzle getRandomPuzzle(int userElo) {
    final list = List<Puzzle>.from(puzzles);
    
    // Sort the puzzles by how close their rating is to the user's Elo
    list.sort((a, b) => (a.rating - userElo).abs().compareTo((b.rating - userElo).abs()));
    
    // Pick from the top 3 closest puzzles to add variety so they don't get the same puzzle twice
    final closest = list.take(3).toList();
    closest.shuffle();
    return closest.first;
  }
}
