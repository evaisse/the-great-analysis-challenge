open Types
open Utils

type delta = (int, int)

let knightDeltas: array<delta> = [
  (-1, -2),
  (1, -2),
  (-2, -1),
  (2, -1),
  (-2, 1),
  (2, 1),
  (-1, 2),
  (1, 2),
]

let kingDeltas: array<delta> = [
  (-1, -1),
  (0, -1),
  (1, -1),
  (-1, 0),
  (1, 0),
  (-1, 1),
  (0, 1),
  (1, 1),
]

let bishopDeltas: array<delta> = [(-1, -1), (1, -1), (-1, 1), (1, 1)]
let rookDeltas: array<delta> = [(0, -1), (-1, 0), (1, 0), (0, 1)]
let queenDeltas: array<delta> = Belt.Array.concat(bishopDeltas, rookDeltas)

let buildAttackTable = (deltas: array<delta>): array<array<square>> => {
  let table: array<array<square>> = Array.make(64, [])

  for square in 0 to 63 {
    let file = modInt(square, 8)
    let rank = square / 8
    let attacks = []

    Belt.Array.forEach(deltas, ((df, dr)) => {
      let targetFile = file + df
      let targetRank = rank + dr
      if targetFile >= 0 && targetFile < 8 && targetRank >= 0 && targetRank < 8 {
        Belt.Array.push(attacks, targetRank * 8 + targetFile)
      }
    })

    Belt.Array.setExn(table, square, attacks)
  }

  table
}

let buildRayTable = (deltas: array<delta>): array<array<array<square>>> => {
  let table: array<array<array<square>>> = Array.make(64, [])

  for square in 0 to 63 {
    let file = modInt(square, 8)
    let rank = square / 8
    let rays = []

    Belt.Array.forEach(deltas, ((df, dr)) => {
      let ray = []
      let targetFile = ref(file + df)
      let targetRank = ref(rank + dr)

      while targetFile.contents >= 0 && targetFile.contents < 8 && targetRank.contents >= 0 && targetRank.contents < 8 {
        Belt.Array.push(ray, targetRank.contents * 8 + targetFile.contents)
        targetFile := targetFile.contents + df
        targetRank := targetRank.contents + dr
      }

      Belt.Array.push(rays, ray)
    })

    Belt.Array.setExn(table, square, rays)
  }

  table
}

let buildDistanceTable = (metric: (int, int) => int): array<array<int>> => {
  let table: array<array<int>> = Array.make(64, [])

  for fromSquare in 0 to 63 {
    let fromFile = modInt(fromSquare, 8)
    let fromRank = fromSquare / 8
    let row = []

    for toSquare in 0 to 63 {
      let fileDistance = absInt(fromFile - modInt(toSquare, 8))
      let rankDistance = absInt(fromRank - (toSquare / 8))
      Belt.Array.push(row, metric(fileDistance, rankDistance))
    }

    Belt.Array.setExn(table, fromSquare, row)
  }

  table
}

let knightAttacks = buildAttackTable(knightDeltas)
let kingAttacks = buildAttackTable(kingDeltas)
let bishopRays = buildRayTable(bishopDeltas)
let rookRays = buildRayTable(rookDeltas)
let queenRays = buildRayTable(queenDeltas)
let chebyshevDistance = buildDistanceTable((fileDistance, rankDistance) => if fileDistance > rankDistance { fileDistance } else { rankDistance })
let manhattanDistance = buildDistanceTable((fileDistance, rankDistance) => fileDistance + rankDistance)
