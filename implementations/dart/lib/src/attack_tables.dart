/// Pre-calculated attack tables for efficient move generation.
///
/// This module provides compile-time constant attack tables for knights, kings,
/// ray directions for sliding pieces, and distance calculations between squares.
///
/// Coordinate system: row 0 = rank 8, row 7 = rank 1, col 0 = a-file, col 7 = h-file
/// Square indices: 0 = a8 (0,0), 7 = h8 (0,7), 56 = a1 (7,0), 63 = h1 (7,7)

class AttackTables {
  /// Knight attack patterns for each square (64 entries).
  /// Each entry contains a list of (row, col) pairs the knight can attack from that square.
  static const List<List<({int row, int col})>> knightAttacks = [
    // Row 0 (rank 8)
    [(row: 2, col: 1), (row: 1, col: 2)], // a8 (0,0)
    [(row: 2, col: 0), (row: 2, col: 2), (row: 1, col: 3)], // b8 (0,1)
    [(row: 2, col: 1), (row: 2, col: 3), (row: 1, col: 0), (row: 1, col: 4)], // c8 (0,2)
    [(row: 2, col: 2), (row: 2, col: 4), (row: 1, col: 1), (row: 1, col: 5)], // d8 (0,3)
    [(row: 2, col: 3), (row: 2, col: 5), (row: 1, col: 2), (row: 1, col: 6)], // e8 (0,4)
    [(row: 2, col: 4), (row: 2, col: 6), (row: 1, col: 3), (row: 1, col: 7)], // f8 (0,5)
    [(row: 2, col: 5), (row: 2, col: 7), (row: 1, col: 4)], // g8 (0,6)
    [(row: 2, col: 6), (row: 1, col: 5)], // h8 (0,7)
    // Row 1 (rank 7)
    [(row: 3, col: 1), (row: 2, col: 2)], // a7 (1,0)
    [(row: 3, col: 0), (row: 3, col: 2), (row: 2, col: 3)], // b7 (1,1)
    [(row: 3, col: 1), (row: 3, col: 3), (row: 2, col: 0), (row: 2, col: 4), (row: 0, col: 0), (row: 0, col: 4)], // c7 (1,2)
    [(row: 3, col: 2), (row: 3, col: 4), (row: 2, col: 1), (row: 2, col: 5), (row: 0, col: 1), (row: 0, col: 5)], // d7 (1,3)
    [(row: 3, col: 3), (row: 3, col: 5), (row: 2, col: 2), (row: 2, col: 6), (row: 0, col: 2), (row: 0, col: 6)], // e7 (1,4)
    [(row: 3, col: 4), (row: 3, col: 6), (row: 2, col: 3), (row: 2, col: 7), (row: 0, col: 3), (row: 0, col: 7)], // f7 (1,5)
    [(row: 3, col: 5), (row: 3, col: 7), (row: 2, col: 4), (row: 0, col: 4)], // g7 (1,6)
    [(row: 3, col: 6), (row: 2, col: 5), (row: 0, col: 5)], // h7 (1,7)
    // Row 2 (rank 6)
    [(row: 4, col: 1), (row: 3, col: 2), (row: 0, col: 1), (row: 1, col: 2)], // a6 (2,0)
    [(row: 4, col: 0), (row: 4, col: 2), (row: 3, col: 3), (row: 0, col: 0), (row: 0, col: 2), (row: 1, col: 3)], // b6 (2,1)
    [(row: 4, col: 1), (row: 4, col: 3), (row: 3, col: 0), (row: 3, col: 4), (row: 0, col: 1), (row: 0, col: 3), (row: 1, col: 0), (row: 1, col: 4)], // c6 (2,2)
    [(row: 4, col: 2), (row: 4, col: 4), (row: 3, col: 1), (row: 3, col: 5), (row: 0, col: 2), (row: 0, col: 4), (row: 1, col: 1), (row: 1, col: 5)], // d6 (2,3)
    [(row: 4, col: 3), (row: 4, col: 5), (row: 3, col: 2), (row: 3, col: 6), (row: 0, col: 3), (row: 0, col: 5), (row: 1, col: 2), (row: 1, col: 6)], // e6 (2,4)
    [(row: 4, col: 4), (row: 4, col: 6), (row: 3, col: 3), (row: 3, col: 7), (row: 0, col: 4), (row: 0, col: 6), (row: 1, col: 3), (row: 1, col: 7)], // f6 (2,5)
    [(row: 4, col: 5), (row: 4, col: 7), (row: 3, col: 4), (row: 0, col: 5), (row: 0, col: 7), (row: 1, col: 4)], // g6 (2,6)
    [(row: 4, col: 6), (row: 3, col: 5), (row: 0, col: 6), (row: 1, col: 5)], // h6 (2,7)
    // Row 3 (rank 5)
    [(row: 5, col: 1), (row: 4, col: 2), (row: 1, col: 1), (row: 2, col: 2)], // a5 (3,0)
    [(row: 5, col: 0), (row: 5, col: 2), (row: 4, col: 3), (row: 1, col: 0), (row: 1, col: 2), (row: 2, col: 3)], // b5 (3,1)
    [(row: 5, col: 1), (row: 5, col: 3), (row: 4, col: 0), (row: 4, col: 4), (row: 1, col: 1), (row: 1, col: 3), (row: 2, col: 0), (row: 2, col: 4)], // c5 (3,2)
    [(row: 5, col: 2), (row: 5, col: 4), (row: 4, col: 1), (row: 4, col: 5), (row: 1, col: 2), (row: 1, col: 4), (row: 2, col: 1), (row: 2, col: 5)], // d5 (3,3)
    [(row: 5, col: 3), (row: 5, col: 5), (row: 4, col: 2), (row: 4, col: 6), (row: 1, col: 3), (row: 1, col: 5), (row: 2, col: 2), (row: 2, col: 6)], // e5 (3,4)
    [(row: 5, col: 4), (row: 5, col: 6), (row: 4, col: 3), (row: 4, col: 7), (row: 1, col: 4), (row: 1, col: 6), (row: 2, col: 3), (row: 2, col: 7)], // f5 (3,5)
    [(row: 5, col: 5), (row: 5, col: 7), (row: 4, col: 4), (row: 1, col: 5), (row: 1, col: 7), (row: 2, col: 4)], // g5 (3,6)
    [(row: 5, col: 6), (row: 4, col: 5), (row: 1, col: 6), (row: 2, col: 5)], // h5 (3,7)
    // Row 4 (rank 4)
    [(row: 6, col: 1), (row: 5, col: 2), (row: 2, col: 1), (row: 3, col: 2)], // a4 (4,0)
    [(row: 6, col: 0), (row: 6, col: 2), (row: 5, col: 3), (row: 2, col: 0), (row: 2, col: 2), (row: 3, col: 3)], // b4 (4,1)
    [(row: 6, col: 1), (row: 6, col: 3), (row: 5, col: 0), (row: 5, col: 4), (row: 2, col: 1), (row: 2, col: 3), (row: 3, col: 0), (row: 3, col: 4)], // c4 (4,2)
    [(row: 6, col: 2), (row: 6, col: 4), (row: 5, col: 1), (row: 5, col: 5), (row: 2, col: 2), (row: 2, col: 4), (row: 3, col: 1), (row: 3, col: 5)], // d4 (4,3)
    [(row: 6, col: 3), (row: 6, col: 5), (row: 5, col: 2), (row: 5, col: 6), (row: 2, col: 3), (row: 2, col: 5), (row: 3, col: 2), (row: 3, col: 6)], // e4 (4,4)
    [(row: 6, col: 4), (row: 6, col: 6), (row: 5, col: 3), (row: 5, col: 7), (row: 2, col: 4), (row: 2, col: 6), (row: 3, col: 3), (row: 3, col: 7)], // f4 (4,5)
    [(row: 6, col: 5), (row: 6, col: 7), (row: 5, col: 4), (row: 2, col: 5), (row: 2, col: 7), (row: 3, col: 4)], // g4 (4,6)
    [(row: 6, col: 6), (row: 5, col: 5), (row: 2, col: 6), (row: 3, col: 5)], // h4 (4,7)
    // Row 5 (rank 3)
    [(row: 7, col: 1), (row: 6, col: 2), (row: 3, col: 1), (row: 4, col: 2)], // a3 (5,0)
    [(row: 7, col: 0), (row: 7, col: 2), (row: 6, col: 3), (row: 3, col: 0), (row: 3, col: 2), (row: 4, col: 3)], // b3 (5,1)
    [(row: 7, col: 1), (row: 7, col: 3), (row: 6, col: 0), (row: 6, col: 4), (row: 3, col: 1), (row: 3, col: 3), (row: 4, col: 0), (row: 4, col: 4)], // c3 (5,2)
    [(row: 7, col: 2), (row: 7, col: 4), (row: 6, col: 1), (row: 6, col: 5), (row: 3, col: 2), (row: 3, col: 4), (row: 4, col: 1), (row: 4, col: 5)], // d3 (5,3)
    [(row: 7, col: 3), (row: 7, col: 5), (row: 6, col: 2), (row: 6, col: 6), (row: 3, col: 3), (row: 3, col: 5), (row: 4, col: 2), (row: 4, col: 6)], // e3 (5,4)
    [(row: 7, col: 4), (row: 7, col: 6), (row: 6, col: 3), (row: 6, col: 7), (row: 3, col: 4), (row: 3, col: 6), (row: 4, col: 3), (row: 4, col: 7)], // f3 (5,5)
    [(row: 7, col: 5), (row: 7, col: 7), (row: 6, col: 4), (row: 3, col: 5), (row: 3, col: 7), (row: 4, col: 4)], // g3 (5,6)
    [(row: 7, col: 6), (row: 6, col: 5), (row: 3, col: 6), (row: 4, col: 5)], // h3 (5,7)
    // Row 6 (rank 2)
    [(row: 7, col: 2), (row: 4, col: 1), (row: 5, col: 2)], // a2 (6,0)
    [(row: 7, col: 3), (row: 4, col: 0), (row: 4, col: 2), (row: 5, col: 3)], // b2 (6,1)
    [(row: 7, col: 0), (row: 7, col: 4), (row: 4, col: 1), (row: 4, col: 3), (row: 5, col: 0), (row: 5, col: 4)], // c2 (6,2)
    [(row: 7, col: 1), (row: 7, col: 5), (row: 4, col: 2), (row: 4, col: 4), (row: 5, col: 1), (row: 5, col: 5)], // d2 (6,3)
    [(row: 7, col: 2), (row: 7, col: 6), (row: 4, col: 3), (row: 4, col: 5), (row: 5, col: 2), (row: 5, col: 6)], // e2 (6,4)
    [(row: 7, col: 3), (row: 7, col: 7), (row: 4, col: 4), (row: 4, col: 6), (row: 5, col: 3), (row: 5, col: 7)], // f2 (6,5)
    [(row: 7, col: 4), (row: 4, col: 5), (row: 4, col: 7), (row: 5, col: 4)], // g2 (6,6)
    [(row: 7, col: 5), (row: 4, col: 6), (row: 5, col: 5)], // h2 (6,7)
    // Row 7 (rank 1)
    [(row: 6, col: 2), (row: 5, col: 1)], // a1 (7,0)
    [(row: 6, col: 3), (row: 5, col: 0), (row: 5, col: 2)], // b1 (7,1)
    [(row: 6, col: 0), (row: 6, col: 4), (row: 5, col: 1), (row: 5, col: 3)], // c1 (7,2)
    [(row: 6, col: 1), (row: 6, col: 5), (row: 5, col: 2), (row: 5, col: 4)], // d1 (7,3)
    [(row: 6, col: 2), (row: 6, col: 6), (row: 5, col: 3), (row: 5, col: 5)], // e1 (7,4)
    [(row: 6, col: 3), (row: 6, col: 7), (row: 5, col: 4), (row: 5, col: 6)], // f1 (7,5)
    [(row: 6, col: 4), (row: 5, col: 5), (row: 5, col: 7)], // g1 (7,6)
    [(row: 6, col: 5), (row: 5, col: 6)], // h1 (7,7)
  ];

  /// King attack patterns for each square (64 entries).
  /// Each entry contains a list of (row, col) pairs the king can attack from that square.
  static const List<List<({int row, int col})>> kingAttacks = [
    // Row 0 (rank 8)
    [(row: 0, col: 1), (row: 1, col: 0), (row: 1, col: 1)], // a8 (0,0)
    [(row: 0, col: 0), (row: 0, col: 2), (row: 1, col: 0), (row: 1, col: 1), (row: 1, col: 2)], // b8 (0,1)
    [(row: 0, col: 1), (row: 0, col: 3), (row: 1, col: 1), (row: 1, col: 2), (row: 1, col: 3)], // c8 (0,2)
    [(row: 0, col: 2), (row: 0, col: 4), (row: 1, col: 2), (row: 1, col: 3), (row: 1, col: 4)], // d8 (0,3)
    [(row: 0, col: 3), (row: 0, col: 5), (row: 1, col: 3), (row: 1, col: 4), (row: 1, col: 5)], // e8 (0,4)
    [(row: 0, col: 4), (row: 0, col: 6), (row: 1, col: 4), (row: 1, col: 5), (row: 1, col: 6)], // f8 (0,5)
    [(row: 0, col: 5), (row: 0, col: 7), (row: 1, col: 5), (row: 1, col: 6), (row: 1, col: 7)], // g8 (0,6)
    [(row: 0, col: 6), (row: 1, col: 6), (row: 1, col: 7)], // h8 (0,7)
    // Row 1 (rank 7)
    [(row: 0, col: 0), (row: 0, col: 1), (row: 1, col: 1), (row: 2, col: 0), (row: 2, col: 1)], // a7 (1,0)
    [(row: 0, col: 0), (row: 0, col: 1), (row: 0, col: 2), (row: 1, col: 0), (row: 1, col: 2), (row: 2, col: 0), (row: 2, col: 1), (row: 2, col: 2)], // b7 (1,1)
    [(row: 0, col: 1), (row: 0, col: 2), (row: 0, col: 3), (row: 1, col: 1), (row: 1, col: 3), (row: 2, col: 1), (row: 2, col: 2), (row: 2, col: 3)], // c7 (1,2)
    [(row: 0, col: 2), (row: 0, col: 3), (row: 0, col: 4), (row: 1, col: 2), (row: 1, col: 4), (row: 2, col: 2), (row: 2, col: 3), (row: 2, col: 4)], // d7 (1,3)
    [(row: 0, col: 3), (row: 0, col: 4), (row: 0, col: 5), (row: 1, col: 3), (row: 1, col: 5), (row: 2, col: 3), (row: 2, col: 4), (row: 2, col: 5)], // e7 (1,4)
    [(row: 0, col: 4), (row: 0, col: 5), (row: 0, col: 6), (row: 1, col: 4), (row: 1, col: 6), (row: 2, col: 4), (row: 2, col: 5), (row: 2, col: 6)], // f7 (1,5)
    [(row: 0, col: 5), (row: 0, col: 6), (row: 0, col: 7), (row: 1, col: 5), (row: 1, col: 7), (row: 2, col: 5), (row: 2, col: 6), (row: 2, col: 7)], // g7 (1,6)
    [(row: 0, col: 6), (row: 0, col: 7), (row: 1, col: 6), (row: 2, col: 6), (row: 2, col: 7)], // h7 (1,7)
    // Row 2 (rank 6)
    [(row: 1, col: 0), (row: 1, col: 1), (row: 2, col: 1), (row: 3, col: 0), (row: 3, col: 1)], // a6 (2,0)
    [(row: 1, col: 0), (row: 1, col: 1), (row: 1, col: 2), (row: 2, col: 0), (row: 2, col: 2), (row: 3, col: 0), (row: 3, col: 1), (row: 3, col: 2)], // b6 (2,1)
    [(row: 1, col: 1), (row: 1, col: 2), (row: 1, col: 3), (row: 2, col: 1), (row: 2, col: 3), (row: 3, col: 1), (row: 3, col: 2), (row: 3, col: 3)], // c6 (2,2)
    [(row: 1, col: 2), (row: 1, col: 3), (row: 1, col: 4), (row: 2, col: 2), (row: 2, col: 4), (row: 3, col: 2), (row: 3, col: 3), (row: 3, col: 4)], // d6 (2,3)
    [(row: 1, col: 3), (row: 1, col: 4), (row: 1, col: 5), (row: 2, col: 3), (row: 2, col: 5), (row: 3, col: 3), (row: 3, col: 4), (row: 3, col: 5)], // e6 (2,4)
    [(row: 1, col: 4), (row: 1, col: 5), (row: 1, col: 6), (row: 2, col: 4), (row: 2, col: 6), (row: 3, col: 4), (row: 3, col: 5), (row: 3, col: 6)], // f6 (2,5)
    [(row: 1, col: 5), (row: 1, col: 6), (row: 1, col: 7), (row: 2, col: 5), (row: 2, col: 7), (row: 3, col: 5), (row: 3, col: 6), (row: 3, col: 7)], // g6 (2,6)
    [(row: 1, col: 6), (row: 1, col: 7), (row: 2, col: 6), (row: 3, col: 6), (row: 3, col: 7)], // h6 (2,7)
    // Row 3 (rank 5)
    [(row: 2, col: 0), (row: 2, col: 1), (row: 3, col: 1), (row: 4, col: 0), (row: 4, col: 1)], // a5 (3,0)
    [(row: 2, col: 0), (row: 2, col: 1), (row: 2, col: 2), (row: 3, col: 0), (row: 3, col: 2), (row: 4, col: 0), (row: 4, col: 1), (row: 4, col: 2)], // b5 (3,1)
    [(row: 2, col: 1), (row: 2, col: 2), (row: 2, col: 3), (row: 3, col: 1), (row: 3, col: 3), (row: 4, col: 1), (row: 4, col: 2), (row: 4, col: 3)], // c5 (3,2)
    [(row: 2, col: 2), (row: 2, col: 3), (row: 2, col: 4), (row: 3, col: 2), (row: 3, col: 4), (row: 4, col: 2), (row: 4, col: 3), (row: 4, col: 4)], // d5 (3,3)
    [(row: 2, col: 3), (row: 2, col: 4), (row: 2, col: 5), (row: 3, col: 3), (row: 3, col: 5), (row: 4, col: 3), (row: 4, col: 4), (row: 4, col: 5)], // e5 (3,4)
    [(row: 2, col: 4), (row: 2, col: 5), (row: 2, col: 6), (row: 3, col: 4), (row: 3, col: 6), (row: 4, col: 4), (row: 4, col: 5), (row: 4, col: 6)], // f5 (3,5)
    [(row: 2, col: 5), (row: 2, col: 6), (row: 2, col: 7), (row: 3, col: 5), (row: 3, col: 7), (row: 4, col: 5), (row: 4, col: 6), (row: 4, col: 7)], // g5 (3,6)
    [(row: 2, col: 6), (row: 2, col: 7), (row: 3, col: 6), (row: 4, col: 6), (row: 4, col: 7)], // h5 (3,7)
    // Row 4 (rank 4)
    [(row: 3, col: 0), (row: 3, col: 1), (row: 4, col: 1), (row: 5, col: 0), (row: 5, col: 1)], // a4 (4,0)
    [(row: 3, col: 0), (row: 3, col: 1), (row: 3, col: 2), (row: 4, col: 0), (row: 4, col: 2), (row: 5, col: 0), (row: 5, col: 1), (row: 5, col: 2)], // b4 (4,1)
    [(row: 3, col: 1), (row: 3, col: 2), (row: 3, col: 3), (row: 4, col: 1), (row: 4, col: 3), (row: 5, col: 1), (row: 5, col: 2), (row: 5, col: 3)], // c4 (4,2)
    [(row: 3, col: 2), (row: 3, col: 3), (row: 3, col: 4), (row: 4, col: 2), (row: 4, col: 4), (row: 5, col: 2), (row: 5, col: 3), (row: 5, col: 4)], // d4 (4,3)
    [(row: 3, col: 3), (row: 3, col: 4), (row: 3, col: 5), (row: 4, col: 3), (row: 4, col: 5), (row: 5, col: 3), (row: 5, col: 4), (row: 5, col: 5)], // e4 (4,4)
    [(row: 3, col: 4), (row: 3, col: 5), (row: 3, col: 6), (row: 4, col: 4), (row: 4, col: 6), (row: 5, col: 4), (row: 5, col: 5), (row: 5, col: 6)], // f4 (4,5)
    [(row: 3, col: 5), (row: 3, col: 6), (row: 3, col: 7), (row: 4, col: 5), (row: 4, col: 7), (row: 5, col: 5), (row: 5, col: 6), (row: 5, col: 7)], // g4 (4,6)
    [(row: 3, col: 6), (row: 3, col: 7), (row: 4, col: 6), (row: 5, col: 6), (row: 5, col: 7)], // h4 (4,7)
    // Row 5 (rank 3)
    [(row: 4, col: 0), (row: 4, col: 1), (row: 5, col: 1), (row: 6, col: 0), (row: 6, col: 1)], // a3 (5,0)
    [(row: 4, col: 0), (row: 4, col: 1), (row: 4, col: 2), (row: 5, col: 0), (row: 5, col: 2), (row: 6, col: 0), (row: 6, col: 1), (row: 6, col: 2)], // b3 (5,1)
    [(row: 4, col: 1), (row: 4, col: 2), (row: 4, col: 3), (row: 5, col: 1), (row: 5, col: 3), (row: 6, col: 1), (row: 6, col: 2), (row: 6, col: 3)], // c3 (5,2)
    [(row: 4, col: 2), (row: 4, col: 3), (row: 4, col: 4), (row: 5, col: 2), (row: 5, col: 4), (row: 6, col: 2), (row: 6, col: 3), (row: 6, col: 4)], // d3 (5,3)
    [(row: 4, col: 3), (row: 4, col: 4), (row: 4, col: 5), (row: 5, col: 3), (row: 5, col: 5), (row: 6, col: 3), (row: 6, col: 4), (row: 6, col: 5)], // e3 (5,4)
    [(row: 4, col: 4), (row: 4, col: 5), (row: 4, col: 6), (row: 5, col: 4), (row: 5, col: 6), (row: 6, col: 4), (row: 6, col: 5), (row: 6, col: 6)], // f3 (5,5)
    [(row: 4, col: 5), (row: 4, col: 6), (row: 4, col: 7), (row: 5, col: 5), (row: 5, col: 7), (row: 6, col: 5), (row: 6, col: 6), (row: 6, col: 7)], // g3 (5,6)
    [(row: 4, col: 6), (row: 4, col: 7), (row: 5, col: 6), (row: 6, col: 6), (row: 6, col: 7)], // h3 (5,7)
    // Row 6 (rank 2)
    [(row: 5, col: 0), (row: 5, col: 1), (row: 6, col: 1), (row: 7, col: 0), (row: 7, col: 1)], // a2 (6,0)
    [(row: 5, col: 0), (row: 5, col: 1), (row: 5, col: 2), (row: 6, col: 0), (row: 6, col: 2), (row: 7, col: 0), (row: 7, col: 1), (row: 7, col: 2)], // b2 (6,1)
    [(row: 5, col: 1), (row: 5, col: 2), (row: 5, col: 3), (row: 6, col: 1), (row: 6, col: 3), (row: 7, col: 1), (row: 7, col: 2), (row: 7, col: 3)], // c2 (6,2)
    [(row: 5, col: 2), (row: 5, col: 3), (row: 5, col: 4), (row: 6, col: 2), (row: 6, col: 4), (row: 7, col: 2), (row: 7, col: 3), (row: 7, col: 4)], // d2 (6,3)
    [(row: 5, col: 3), (row: 5, col: 4), (row: 5, col: 5), (row: 6, col: 3), (row: 6, col: 5), (row: 7, col: 3), (row: 7, col: 4), (row: 7, col: 5)], // e2 (6,4)
    [(row: 5, col: 4), (row: 5, col: 5), (row: 5, col: 6), (row: 6, col: 4), (row: 6, col: 6), (row: 7, col: 4), (row: 7, col: 5), (row: 7, col: 6)], // f2 (6,5)
    [(row: 5, col: 5), (row: 5, col: 6), (row: 5, col: 7), (row: 6, col: 5), (row: 6, col: 7), (row: 7, col: 5), (row: 7, col: 6), (row: 7, col: 7)], // g2 (6,6)
    [(row: 5, col: 6), (row: 5, col: 7), (row: 6, col: 6), (row: 7, col: 6), (row: 7, col: 7)], // h2 (6,7)
    // Row 7 (rank 1)
    [(row: 6, col: 0), (row: 6, col: 1), (row: 7, col: 1)], // a1 (7,0)
    [(row: 6, col: 0), (row: 6, col: 1), (row: 6, col: 2), (row: 7, col: 0), (row: 7, col: 2)], // b1 (7,1)
    [(row: 6, col: 1), (row: 6, col: 2), (row: 6, col: 3), (row: 7, col: 1), (row: 7, col: 3)], // c1 (7,2)
    [(row: 6, col: 2), (row: 6, col: 3), (row: 6, col: 4), (row: 7, col: 2), (row: 7, col: 4)], // d1 (7,3)
    [(row: 6, col: 3), (row: 6, col: 4), (row: 6, col: 5), (row: 7, col: 3), (row: 7, col: 5)], // e1 (7,4)
    [(row: 6, col: 4), (row: 6, col: 5), (row: 6, col: 6), (row: 7, col: 4), (row: 7, col: 6)], // f1 (7,5)
    [(row: 6, col: 5), (row: 6, col: 6), (row: 6, col: 7), (row: 7, col: 5), (row: 7, col: 7)], // g1 (7,6)
    [(row: 6, col: 6), (row: 6, col: 7), (row: 7, col: 6)], // h1 (7,7)
  ];

  /// Ray directions: N, NE, E, SE, S, SW, W, NW
  static const List<({int dRow, int dCol})> rayDirections = [
    (dRow: -1, dCol: 0), // N
    (dRow: -1, dCol: 1), // NE
    (dRow: 0, dCol: 1), // E
    (dRow: 1, dCol: 1), // SE
    (dRow: 1, dCol: 0), // S
    (dRow: 1, dCol: -1), // SW
    (dRow: 0, dCol: -1), // W
    (dRow: -1, dCol: -1), // NW
  ];

  /// Precomputed rays for sliding pieces.
  /// rays[square][direction] returns a list of squares in that direction.
  /// Direction indices: 0=N, 1=NE, 2=E, 3=SE, 4=S, 5=SW, 6=W, 7=NW
  static List<List<List<({int row, int col})>>> generateRays() {
    final rays = List.generate(
      64,
      (squareIndex) => List.generate(8, (direction) => <({int row, int col})[]),
    );

    for (int squareIndex = 0; squareIndex < 64; squareIndex++) {
      final row = squareIndex ~/ 8;
      final col = squareIndex % 8;

      for (int dirIndex = 0; dirIndex < 8; dirIndex++) {
        final dir = rayDirections[dirIndex];
        final raySquares = <({int row, int col})>[];

        int r = row + dir.dRow;
        int c = col + dir.dCol;

        while (r >= 0 && r < 8 && c >= 0 && c < 8) {
          raySquares.add((row: r, col: c));
          r += dir.dRow;
          c += dir.dCol;
        }

        rays[squareIndex][dirIndex] = raySquares;
      }
    }

    return rays;
  }

  /// Chebyshev distance (king distance) between two squares.
  /// Returns max(|row1 - row2|, |col1 - col2|).
  static int chebyshevDistance(int row1, int col1, int row2, int col2) {
    final rowDist = (row1 - row2).abs();
    final colDist = (col1 - col2).abs();
    return rowDist > colDist ? rowDist : colDist;
  }

  /// Manhattan distance (taxicab distance) between two squares.
  /// Returns |row1 - row2| + |col1 - col2|.
  static int manhattanDistance(int row1, int col1, int row2, int col2) {
    return (row1 - row2).abs() + (col1 - col2).abs();
  }

  /// Precomputed Chebyshev distance table for all square pairs.
  /// chebyshevDistanceTable[sq1][sq2] returns the Chebyshev distance.
  static List<List<int>> generateChebyshevDistanceTable() {
    final table = List.generate(64, (_) => List.filled(64, 0));

    for (int sq1 = 0; sq1 < 64; sq1++) {
      for (int sq2 = 0; sq2 < 64; sq2++) {
        final row1 = sq1 ~/ 8;
        final col1 = sq1 % 8;
        final row2 = sq2 ~/ 8;
        final col2 = sq2 % 8;
        table[sq1][sq2] = chebyshevDistance(row1, col1, row2, col2);
      }
    }

    return table;
  }

  /// Precomputed Manhattan distance table for all square pairs.
  /// manhattanDistanceTable[sq1][sq2] returns the Manhattan distance.
  static List<List<int>> generateManhattanDistanceTable() {
    final table = List.generate(64, (_) => List.filled(64, 0));

    for (int sq1 = 0; sq1 < 64; sq1++) {
      for (int sq2 = 0; sq2 < 64; sq2++) {
        final row1 = sq1 ~/ 8;
        final col1 = sq1 % 8;
        final row2 = sq2 ~/ 8;
        final col2 = sq2 % 8;
        table[sq1][sq2] = manhattanDistance(row1, col1, row2, col2);
      }
    }

    return table;
  }

  /// Convert (row, col) to square index (0-63).
  static int toSquareIndex(int row, int col) => row * 8 + col;

  /// Convert square index to (row, col).
  static ({int row, int col}) fromSquareIndex(int index) =>
      (row: index ~/ 8, col: index % 8);
}
