open Types
open Utils

let isValidSquare = (square: square): bool => square >= 0 && square < 64

let getPiece = (state: gameState, square: square): option<piece> => {
  if !isValidSquare(square) {
    None
  } else {
    Belt.Array.getExn(state.board, square)
  }
}

let generatePawnMoves = (state: gameState, from: square, piece: piece): array<move> => {
  let moves: array<move> = []
  let direction = if piece.color == White { 8 } else { -8 }
  let startRank = if piece.color == White { 1 } else { 6 }
  let promotionRank = if piece.color == White { 7 } else { 0 }
  let rank = from / 8
  let file = modInt(from, 8)

  let oneSquareForward = from + direction
  if isValidSquare(oneSquareForward) && getPiece(state, oneSquareForward) == None {
    if oneSquareForward / 8 == promotionRank {
      Belt.Array.forEach(promotionPieces, promo =>
        Belt.Array.push(moves, {
          from,
          to: oneSquareForward,
          piece: Pawn,
          captured: None,
          promotion: Some(promo),
          castling: None,
          enPassant: false,
        })

      )
    } else {
      Belt.Array.push(moves, {
        from,
        to: oneSquareForward,
        piece: Pawn,
        captured: None,
        promotion: None,
        castling: None,
        enPassant: false,
      })

    }

    if rank == startRank {
      let twoSquaresForward = from + 2 * direction
      if getPiece(state, twoSquaresForward) == None {
        Belt.Array.push(moves, {
          from,
          to: twoSquaresForward,
          piece: Pawn,
          captured: None,
          promotion: None,
          castling: None,
          enPassant: false,
        })

      }
    }
  }

  let captureOffsets: array<int> = [direction - 1, direction + 1]
  Belt.Array.forEach(captureOffsets, offset => {
    let to = from + offset
    let toFile = modInt(to, 8)

    if isValidSquare(to) && absInt(toFile - file) == 1 {
      switch getPiece(state, to) {
      | Some(target) if target.color != piece.color =>
        if to / 8 == promotionRank {
          Belt.Array.forEach(promotionPieces, promo =>
            Belt.Array.push(moves, {
              from,
              to,
              piece: Pawn,
              captured: Some(target.pieceType),
              promotion: Some(promo),
              castling: None,
              enPassant: false,
            })

          )
        } else {
          Belt.Array.push(moves, {
            from,
            to,
            piece: Pawn,
            captured: Some(target.pieceType),
            promotion: None,
            castling: None,
            enPassant: false,
          })

        }
      | _ => ()
      }
    }
  })

  switch state.enPassantTarget {
  | None => ()
  | Some(enPassantTarget) =>
    let expectedPawnRank = if piece.color == White { 4 } else { 3 }
    if rank == expectedPawnRank {
      let offsets: array<int> = [-1, 1]
      Belt.Array.forEach(offsets, offset => {
        let adjacentSquare = from + offset
        let adjFile = modInt(adjacentSquare, 8)

        if absInt(adjFile - file) == 1 {
          switch getPiece(state, adjacentSquare) {
          | Some(targetPawn) if targetPawn.pieceType == Pawn && targetPawn.color != piece.color =>
            let captureSquare = enPassantTarget
            if captureSquare == adjacentSquare + direction {
              Belt.Array.push(moves, {
                from,
                to: captureSquare,
                piece: Pawn,
                captured: Some(Pawn),
                promotion: None,
                castling: None,
                enPassant: true,
              })

            }
          | _ => ()
          }
        }
      })
    }
  }

  moves
}

let generateKnightMoves = (state: gameState, from: square, piece: piece): array<move> => {
  let moves: array<move> = []
  let offsets: array<int> = [-17, -15, -10, -6, 6, 10, 15, 17]
  let file = modInt(from, 8)

  Belt.Array.forEach(offsets, offset => {
    let to = from + offset
    let toFile = modInt(to, 8)

    if isValidSquare(to) && absInt(toFile - file) <= 2 {
      switch getPiece(state, to) {
      | None =>
        Belt.Array.push(moves, {
          from,
          to,
          piece: Knight,
          captured: None,
          promotion: None,
          castling: None,
          enPassant: false,
        })

      | Some(target) if target.color != piece.color =>
        Belt.Array.push(moves, {
          from,
          to,
          piece: Knight,
          captured: Some(target.pieceType),
          promotion: None,
          castling: None,
          enPassant: false,
        })

      | _ => ()
      }
    }
  })

  moves
}

let generateSlidingMoves = (
  state: gameState,
  from: square,
  piece: piece,
  directions: array<int>,
  isDiagonal: option<bool>,
): array<move> => {
  let moves: array<move> = []
  let file = modInt(from, 8)

  Belt.Array.forEach(directions, direction => {
    let to = ref(from + direction)
    let prevFile = ref(file)
    let running = ref(true)

    while running.contents && isValidSquare(to.contents) {
      let toFile = modInt(to.contents, 8)

      switch isDiagonal {
      | Some(true) =>
        if absInt(toFile - prevFile.contents) != 1 {
          running := false
        }
      | _ =>
        if (direction == -1 || direction == 1) && absInt(toFile - prevFile.contents) != 1 {
          running := false
        }
      }

      if running.contents {
        switch getPiece(state, to.contents) {
        | None =>
          Belt.Array.push(moves, {
            from,
            to: to.contents,
            piece: piece.pieceType,
            captured: None,
            promotion: None,
            castling: None,
            enPassant: false,
          })

        | Some(target) if target.color != piece.color =>
          Belt.Array.push(moves, {
            from,
            to: to.contents,
            piece: piece.pieceType,
            captured: Some(target.pieceType),
            promotion: None,
            castling: None,
            enPassant: false,
          })

          running := false
        | Some(_) => running := false
        }

        if running.contents {
          prevFile := toFile
          to := to.contents + direction
        }
      }
    }
  })

  moves
}

let rec generateKingMoves = (
  state: gameState,
  from: square,
  piece: piece,
  includeCastling: bool,
): array<move> => {
  let moves: array<move> = []
  let offsets: array<int> = [-9, -8, -7, -1, 1, 7, 8, 9]
  let file = modInt(from, 8)

  Belt.Array.forEach(offsets, offset => {
    let to = from + offset
    let toFile = modInt(to, 8)

    if isValidSquare(to) && absInt(toFile - file) <= 1 {
      switch getPiece(state, to) {
      | None =>
        Belt.Array.push(moves, {
          from,
          to,
          piece: King,
          captured: None,
          promotion: None,
          castling: None,
          enPassant: false,
        })

      | Some(target) if target.color != piece.color =>
        Belt.Array.push(moves, {
          from,
          to,
          piece: King,
          captured: Some(target.pieceType),
          promotion: None,
          castling: None,
          enPassant: false,
        })

      | _ => ()
      }
    }
  })

  if includeCastling {
    let rights = state.castlingRights
    if piece.color == White && from == 4 {
      if rights.whiteKingside && getPiece(state, 5) == None && getPiece(state, 6) == None {
        switch getPiece(state, 7) {
        | Some(rook) if rook.pieceType == Rook =>
          if !isSquareAttacked(state, 4, Black) && !isSquareAttacked(state, 5, Black) && !isSquareAttacked(state, 6, Black) {
            Belt.Array.push(moves, {
              from: 4,
              to: 6,
              piece: King,
              captured: None,
              promotion: None,
              castling: Some("K"),
              enPassant: false,
            })

          }
        | _ => ()
        }
      }

      if rights.whiteQueenside && getPiece(state, 3) == None && getPiece(state, 2) == None && getPiece(state, 1) == None {
        switch getPiece(state, 0) {
        | Some(rook) if rook.pieceType == Rook =>
          if !isSquareAttacked(state, 4, Black) && !isSquareAttacked(state, 3, Black) && !isSquareAttacked(state, 2, Black) {
            Belt.Array.push(moves, {
              from: 4,
              to: 2,
              piece: King,
              captured: None,
              promotion: None,
              castling: Some("Q"),
              enPassant: false,
            })

          }
        | _ => ()
        }
      }
    } else if piece.color == Black && from == 60 {
      if rights.blackKingside && getPiece(state, 61) == None && getPiece(state, 62) == None {
        switch getPiece(state, 63) {
        | Some(rook) if rook.pieceType == Rook =>
          if !isSquareAttacked(state, 60, White) && !isSquareAttacked(state, 61, White) && !isSquareAttacked(state, 62, White) {
            Belt.Array.push(moves, {
              from: 60,
              to: 62,
              piece: King,
              captured: None,
              promotion: None,
              castling: Some("k"),
              enPassant: false,
            })

          }
        | _ => ()
        }
      }

      if rights.blackQueenside && getPiece(state, 59) == None && getPiece(state, 58) == None && getPiece(state, 57) == None {
        switch getPiece(state, 56) {
        | Some(rook) if rook.pieceType == Rook =>
          if !isSquareAttacked(state, 60, White) && !isSquareAttacked(state, 59, White) && !isSquareAttacked(state, 58, White) {
            Belt.Array.push(moves, {
              from: 60,
              to: 58,
              piece: King,
              captured: None,
              promotion: None,
              castling: Some("q"),
              enPassant: false,
            })

          }
        | _ => ()
        }
      }
    }
  }

  moves
}

and isSquareAttacked = (state: gameState, targetSquare: square, byColor: color): bool => {
  let attacked = ref(false)

  for square in 0 to 63 {
    if !attacked.contents {
      switch getPiece(state, square) {
      | Some(piece) if piece.color == byColor =>
        let moves =
          switch piece.pieceType {
          | King => generateKingMoves(state, square, piece, false)
          | Pawn => generatePawnMoves(state, square, piece)
          | Knight => generateKnightMoves(state, square, piece)
          | Bishop => generateSlidingMoves(state, square, piece, [-9, -7, 7, 9], Some(true))
          | Rook => generateSlidingMoves(state, square, piece, [-8, -1, 1, 8], Some(false))
          | Queen => generateSlidingMoves(state, square, piece, [-9, -8, -7, -1, 1, 7, 8, 9], None)
          }
        if Belt.Array.some(moves, move => move.to == targetSquare) {
          attacked := true
        }
      | _ => ()
      }
    }
  }

  attacked.contents
}

let generatePieceMoves = (state: gameState, from: square, piece: piece): array<move> =>
  switch piece.pieceType {
  | Pawn => generatePawnMoves(state, from, piece)
  | Knight => generateKnightMoves(state, from, piece)
  | Bishop => generateSlidingMoves(state, from, piece, [-9, -7, 7, 9], Some(true))
  | Rook => generateSlidingMoves(state, from, piece, [-8, -1, 1, 8], Some(false))
  | Queen => generateSlidingMoves(state, from, piece, [-9, -8, -7, -1, 1, 7, 8, 9], None)
  | King => generateKingMoves(state, from, piece, true)
  }

let generateAllMoves = (state: gameState, color: color): array<move> => {
  let moves: array<move> = []

  for square in 0 to 63 {
    switch getPiece(state, square) {
    | Some(piece) if piece.color == color =>
      let pieceMoves = generatePieceMoves(state, square, piece)
      Belt.Array.forEach(pieceMoves, move => Belt.Array.push(moves, move))
    | _ => ()
    }
  }

  moves
}

let isKingInCheck = (state: gameState, color: color): bool => {
  let kingSquare = ref(None)

  for square in 0 to 63 {
    if kingSquare.contents == None {
      switch getPiece(state, square) {
      | Some(piece) if piece.color == color && piece.pieceType == King => kingSquare := Some(square)
      | _ => ()
      }
    }
  }

  switch kingSquare.contents {
  | None => false
  | Some(square) => isSquareAttacked(state, square, oppositeColor(color))
  }
}

let makeMove = (state: gameState, move: move): gameState => {
  switch getPiece(state, move.from) {
  | None => state
  | Some(piece) =>
    let board = Belt.Array.copy(state.board)
    let setOnBoard = (square: int, pieceOpt: option<piece>) =>
      Belt.Array.setExn(board, square, pieceOpt)

    setOnBoard(move.to, Some(piece))
    setOnBoard(move.from, None)

    switch move.castling {
    | Some("K") =>
      setOnBoard(5, getPiece(state, 7))
      setOnBoard(7, None)
    | Some("Q") =>
      setOnBoard(3, getPiece(state, 0))
      setOnBoard(0, None)
    | Some("k") =>
      setOnBoard(61, getPiece(state, 63))
      setOnBoard(63, None)
    | Some("q") =>
      setOnBoard(59, getPiece(state, 56))
      setOnBoard(56, None)
    | _ => ()
    }

    if move.enPassant {
      let capturedPawnSquare = move.to + (if piece.color == White { -8 } else { 8 })
      setOnBoard(capturedPawnSquare, None)
    }

    switch move.promotion {
    | Some(promo) => setOnBoard(move.to, Some({pieceType: promo, color: piece.color}))
    | None => ()
    }

    let rights = state.castlingRights
    let newRights =
      switch piece.pieceType {
      | King =>
        if piece.color == White {
          {...rights, whiteKingside: false, whiteQueenside: false}
        } else {
          {...rights, blackKingside: false, blackQueenside: false}
        }
      | Rook =>
        if piece.color == White {
          if move.from == 0 {
            {...rights, whiteQueenside: false}
          } else if move.from == 7 {
            {...rights, whiteKingside: false}
          } else {
            rights
          }
        } else {
          if move.from == 56 {
            {...rights, blackQueenside: false}
          } else if move.from == 63 {
            {...rights, blackKingside: false}
          } else {
            rights
          }
        }
      | _ => rights
      }

    let enPassantTarget =
      if piece.pieceType == Pawn && absInt(move.to - move.from) == 16 {
        Some((move.from + move.to) / 2)
      } else {
        None
      }

    let halfmoveClock =
      if piece.pieceType == Pawn || move.captured != None {
        0
      } else {
        state.halfmoveClock + 1
      }

    let fullmoveNumber = if piece.color == Black { state.fullmoveNumber + 1 } else { state.fullmoveNumber }

    let newTurn = oppositeColor(state.turn)
    let moveHistory = Belt.Array.concat(state.moveHistory, [move])

    {
      board,
      turn: newTurn,
      castlingRights: newRights,
      enPassantTarget,
      halfmoveClock,
      fullmoveNumber,
      moveHistory,
    }
  }
}

let generateLegalMoves = (state: gameState): array<move> => {
  let moves = generateAllMoves(state, state.turn)
  Belt.Array.keep(moves, move => {
    let nextState = makeMove(state, move)
    !isKingInCheck(nextState, state.turn)
  })
}
