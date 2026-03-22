typedef SquareRef = ({int row, int col});

const _knightDeltas = [
  (-2, -1),
  (-2, 1),
  (-1, -2),
  (-1, 2),
  (1, -2),
  (1, 2),
  (2, -1),
  (2, 1),
];

const _kingDeltas = [
  (-1, -1),
  (-1, 0),
  (-1, 1),
  (0, -1),
  (0, 1),
  (1, -1),
  (1, 0),
  (1, 1),
];

const _rayDirections = {
  (-1, -1),
  (-1, 0),
  (-1, 1),
  (0, -1),
  (0, 1),
  (1, -1),
  (1, 0),
  (1, 1),
};

List<List<List<SquareRef>>> _buildAttackTable(List<(int, int)> deltas) {
  return List.generate(
    8,
    (row) => List.generate(
      8,
      (col) => [
        for (final (dRow, dCol) in deltas)
          if (_isValidSquare(row + dRow, col + dCol))
            (row: row + dRow, col: col + dCol),
      ],
    ),
  );
}

List<List<List<SquareRef>>> _buildRayTable(int dRow, int dCol) {
  return List.generate(
    8,
    (row) => List.generate(8, (col) {
      final ray = <SquareRef>[];
      var nextRow = row + dRow;
      var nextCol = col + dCol;
      while (_isValidSquare(nextRow, nextCol)) {
        ray.add((row: nextRow, col: nextCol));
        nextRow += dRow;
        nextCol += dCol;
      }
      return ray;
    }),
  );
}

List<List<int>> _buildDistanceTable(
  int Function(int rowDistance, int colDistance) metric,
) {
  return List.generate(64, (from) {
    final fromRow = from ~/ 8;
    final fromCol = from % 8;
    return List.generate(64, (to) {
      final toRow = to ~/ 8;
      final toCol = to % 8;
      final rowDistance = (fromRow - toRow).abs();
      final colDistance = (fromCol - toCol).abs();
      return metric(rowDistance, colDistance);
    });
  });
}

bool _isValidSquare(int row, int col) =>
    row >= 0 && row < 8 && col >= 0 && col < 8;

int _squareIndex(int row, int col) => row * 8 + col;

final knightAttackTable = _buildAttackTable(_knightDeltas);
final kingAttackTable = _buildAttackTable(_kingDeltas);
final rayTables = {
  for (final (dRow, dCol) in _rayDirections)
    (dRow, dCol): _buildRayTable(dRow, dCol),
};
final chebyshevDistanceTable = _buildDistanceTable(
  (rowDistance, colDistance) =>
      rowDistance > colDistance ? rowDistance : colDistance,
);
final manhattanDistanceTable = _buildDistanceTable(
  (rowDistance, colDistance) => rowDistance + colDistance,
);

List<SquareRef> knightAttacks(int row, int col) => knightAttackTable[row][col];

List<SquareRef> kingAttacks(int row, int col) => kingAttackTable[row][col];

List<SquareRef> rayAttacks(int row, int col, int dRow, int dCol) =>
    rayTables[(dRow, dCol)]![row][col];

int chebyshevDistance(SquareRef from, SquareRef to) =>
    chebyshevDistanceTable[_squareIndex(from.row, from.col)][_squareIndex(
      to.row,
      to.col,
    )];

int manhattanDistance(SquareRef from, SquareRef to) =>
    manhattanDistanceTable[_squareIndex(from.row, from.col)][_squareIndex(
      to.row,
      to.col,
    )];
