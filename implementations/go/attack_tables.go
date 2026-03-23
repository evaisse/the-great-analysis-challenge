package main

type Direction int

const (
	DirectionSouthWest Direction = -9
	DirectionSouth     Direction = -8
	DirectionSouthEast Direction = -7
	DirectionWest      Direction = -1
	DirectionEast      Direction = 1
	DirectionNorthWest Direction = 7
	DirectionNorth     Direction = 8
	DirectionNorthEast Direction = 9
)

var knightAttackTable [64][]Square
var kingAttackTable [64][]Square
var rayTables map[Direction][64][]Square
var chebyshevDistanceTable [64][64]int
var manhattanDistanceTable [64][64]int

func init() {
	knightAttackTable = buildAttackTable([]Square{
		{-1, -2}, {1, -2}, {-2, -1}, {2, -1},
		{-2, 1}, {2, 1}, {-1, 2}, {1, 2},
	})
	kingAttackTable = buildAttackTable([]Square{
		{-1, -1}, {0, -1}, {1, -1},
		{-1, 0}, {1, 0},
		{-1, 1}, {0, 1}, {1, 1},
	})

	rayTables = map[Direction][64][]Square{
		DirectionSouthWest: buildRayTable(-1, -1),
		DirectionSouth:     buildRayTable(0, -1),
		DirectionSouthEast: buildRayTable(1, -1),
		DirectionWest:      buildRayTable(-1, 0),
		DirectionEast:      buildRayTable(1, 0),
		DirectionNorthWest: buildRayTable(-1, 1),
		DirectionNorth:     buildRayTable(0, 1),
		DirectionNorthEast: buildRayTable(1, 1),
	}

	chebyshevDistanceTable = buildDistanceTable(func(fileDistance, rankDistance int) int {
		if fileDistance > rankDistance {
			return fileDistance
		}
		return rankDistance
	})
	manhattanDistanceTable = buildDistanceTable(func(fileDistance, rankDistance int) int {
		return fileDistance + rankDistance
	})
}

func buildAttackTable(deltas []Square) [64][]Square {
	var table [64][]Square
	for rank := 0; rank < 8; rank++ {
		for file := 0; file < 8; file++ {
			index := squareIndex(Square{File: file, Rank: rank})
			attacks := make([]Square, 0, len(deltas))
			for _, delta := range deltas {
				target := Square{File: file + delta.File, Rank: rank + delta.Rank}
				if target.IsValid() {
					attacks = append(attacks, target)
				}
			}
			table[index] = attacks
		}
	}
	return table
}

func buildRayTable(fileDelta, rankDelta int) [64][]Square {
	var table [64][]Square
	for rank := 0; rank < 8; rank++ {
		for file := 0; file < 8; file++ {
			index := squareIndex(Square{File: file, Rank: rank})
			ray := make([]Square, 0, 7)
			target := Square{File: file + fileDelta, Rank: rank + rankDelta}
			for target.IsValid() {
				ray = append(ray, target)
				target = Square{File: target.File + fileDelta, Rank: target.Rank + rankDelta}
			}
			table[index] = ray
		}
	}
	return table
}

func buildDistanceTable(metric func(int, int) int) [64][64]int {
	var table [64][64]int
	for from := 0; from < 64; from++ {
		fromSquare := indexToSquare(from)
		for to := 0; to < 64; to++ {
			toSquare := indexToSquare(to)
			fileDistance := fromSquare.File - toSquare.File
			if fileDistance < 0 {
				fileDistance = -fileDistance
			}
			rankDistance := fromSquare.Rank - toSquare.Rank
			if rankDistance < 0 {
				rankDistance = -rankDistance
			}
			table[from][to] = metric(fileDistance, rankDistance)
		}
	}
	return table
}

func squareIndex(square Square) int {
	return square.Rank*8 + square.File
}

func indexToSquare(index int) Square {
	return Square{File: index % 8, Rank: index / 8}
}

func knightAttacks(square Square) []Square {
	return knightAttackTable[squareIndex(square)]
}

func kingAttacks(square Square) []Square {
	return kingAttackTable[squareIndex(square)]
}

func rayAttacks(direction Direction, square Square) []Square {
	return rayTables[direction][squareIndex(square)]
}

func chebyshevDistance(from, to Square) int {
	return chebyshevDistanceTable[squareIndex(from)][squareIndex(to)]
}

func attackTableManhattanDistance(from, to Square) int {
	return manhattanDistanceTable[squareIndex(from)][squareIndex(to)]
}
