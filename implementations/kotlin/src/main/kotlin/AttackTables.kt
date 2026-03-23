private val KNIGHT_DELTAS = listOf(
    -1 to -2, 1 to -2,
    -2 to -1, 2 to -1,
    -2 to 1, 2 to 1,
    -1 to 2, 1 to 2,
)

private val KING_DELTAS = listOf(
    -1 to -1, 0 to -1, 1 to -1,
    -1 to 0,            1 to 0,
    -1 to 1,  0 to 1,  1 to 1,
)

private val RAY_DIRECTIONS = mapOf(
    -9 to (-1 to -1),
    -8 to (0 to -1),
    -7 to (1 to -1),
    -1 to (-1 to 0),
    1 to (1 to 0),
    7 to (-1 to 1),
    8 to (0 to 1),
    9 to (1 to 1),
)

private fun buildAttackTable(deltas: List<Pair<Int, Int>>): Array<List<Square>> {
    return Array(64) { square ->
        val file = square % 8
        val rank = square / 8
        val attacks = mutableListOf<Square>()
        for ((df, dr) in deltas) {
            val targetFile = file + df
            val targetRank = rank + dr
            if (targetFile in 0..7 && targetRank in 0..7) {
                attacks.add(targetRank * 8 + targetFile)
            }
        }
        attacks
    }
}

private fun buildRayTable(delta: Pair<Int, Int>): Array<List<Square>> {
    val (df, dr) = delta
    return Array(64) { square ->
        val file = square % 8
        val rank = square / 8
        val ray = mutableListOf<Square>()
        var targetFile = file + df
        var targetRank = rank + dr
        while (targetFile in 0..7 && targetRank in 0..7) {
            ray.add(targetRank * 8 + targetFile)
            targetFile += df
            targetRank += dr
        }
        ray
    }
}

private fun buildDistanceTable(metric: (Int, Int) -> Int): Array<IntArray> {
    return Array(64) { from ->
        val fromFile = from % 8
        val fromRank = from / 8
        IntArray(64) { to ->
            val toFile = to % 8
            val toRank = to / 8
            metric(kotlin.math.abs(fromFile - toFile), kotlin.math.abs(fromRank - toRank))
        }
    }
}

object AttackTables {
    private val knightAttackTable = buildAttackTable(KNIGHT_DELTAS)
    private val kingAttackTable = buildAttackTable(KING_DELTAS)
    private val rayTables = RAY_DIRECTIONS.mapValues { (_, delta) -> buildRayTable(delta) }
    private val chebyshevDistanceTable = buildDistanceTable(::maxOf)
    private val manhattanDistanceTable = buildDistanceTable { fileDistance, rankDistance -> fileDistance + rankDistance }

    fun knightAttacks(square: Square): List<Square> = knightAttackTable[square]

    fun kingAttacks(square: Square): List<Square> = kingAttackTable[square]

    fun rayAttacks(square: Square, direction: Int): List<Square> = rayTables.getValue(direction)[square]

    fun chebyshevDistance(from: Square, to: Square): Int = chebyshevDistanceTable[from][to]

    fun manhattanDistance(from: Square, to: Square): Int = manhattanDistanceTable[from][to]
}
