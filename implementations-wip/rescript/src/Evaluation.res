open Types
open Utils

let isEndgame = (state: gameState): bool => {
  let pieceCount = ref(0)
  let queenCount = ref(0)

  for square in 0 to 63 {
    switch Belt.Array.getExn(state.board, square) {
    | Some(piece) =>
      if piece.pieceType != King && piece.pieceType != Pawn {
        pieceCount := pieceCount.contents + 1
        if piece.pieceType == Queen {
          queenCount := queenCount.contents + 1
        }
      }
    | None => ()
    }
  }

  pieceCount.contents <= 4 || (pieceCount.contents <= 6 && queenCount.contents == 0)
}

let positionBonus = (state: gameState, square: square, piece: piece): int => {
  let file = modInt(square, 8)
  let rank = square / 8
  let bonus = ref(0)

  let centerSquares = [27, 28, 35, 36]
  if Belt.Array.some(centerSquares, value => value == square) {
    bonus := bonus.contents + 10
  }

  switch piece.pieceType {
  | Pawn =>
    let advancement = if piece.color == White { rank } else { 7 - rank }
    bonus := bonus.contents + advancement * 5
  | King =>
    if !isEndgame(state) {
      let kingSafetyRow = if piece.color == White { 0 } else { 7 }
      if rank == kingSafetyRow && (file <= 2 || file >= 5) {
        bonus := bonus.contents + 20
      } else {
        bonus := bonus.contents - 20
      }
    }
  | _ => ()
  }

  bonus.contents
}

let evaluateGameState = (state: gameState): int => {
  let score = ref(0)

  for square in 0 to 63 {
    switch Belt.Array.getExn(state.board, square) {
    | Some(piece) =>
      let value = pieceValue(piece.pieceType)
      let bonus = positionBonus(state, square, piece)
      let total = value + bonus
      if piece.color == White {
        score := score.contents + total
      } else {
        score := score.contents - total
      }
    | None => ()
    }
  }

  score.contents
}
