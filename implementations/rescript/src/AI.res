open Types
open MoveGenerator
open Evaluation

let rec minimax = (state: gameState, depth: int, alpha: int, beta: int): int => {
  if depth == 0 {
    evaluateGameState(state)
  } else {
    let moves = generateLegalMoves(state)
    let moveCount = Js.Array.length(moves)

    if moveCount == 0 {
      if isKingInCheck(state, state.turn) {
        if state.turn == White { -100000 } else { 100000 }
      } else {
        0
      }
    } else if state.turn == White {
      let maxEval = ref(-1000000)
      let alphaRef = ref(alpha)
      let index = ref(0)

      while index.contents < moveCount && beta > alphaRef.contents {
        let move = Belt.Array.getExn(moves, index.contents)
        let nextState = makeMove(state, move)
        let evaluation = minimax(nextState, depth - 1, alphaRef.contents, beta)

        if evaluation > maxEval.contents {
          maxEval := evaluation
        }
        if evaluation > alphaRef.contents {
          alphaRef := evaluation
        }

        index := index.contents + 1
      }

      maxEval.contents
    } else {
      let minEval = ref(1000000)
      let betaRef = ref(beta)
      let index = ref(0)

      while index.contents < moveCount && betaRef.contents > alpha {
        let move = Belt.Array.getExn(moves, index.contents)
        let nextState = makeMove(state, move)
        let evaluation = minimax(nextState, depth - 1, alpha, betaRef.contents)

        if evaluation < minEval.contents {
          minEval := evaluation
        }
        if evaluation < betaRef.contents {
          betaRef := evaluation
        }

        index := index.contents + 1
      }

      minEval.contents
    }
  }
}

let findBestMove = (state: gameState, depth: int): option<(move, int)> => {
  let moves = generateLegalMoves(state)
  let moveCount = Js.Array.length(moves)

  if moveCount == 0 {
    None
  } else {
    let bestMove = ref(Belt.Array.getExn(moves, 0))
    let bestEval =
      if state.turn == White {
        ref(-1000000)
      } else {
        ref(1000000)
      }

    for index in 0 to moveCount - 1 {
      let move = Belt.Array.getExn(moves, index)
      let nextState = makeMove(state, move)
      let evaluation = minimax(nextState, depth - 1, -1000000, 1000000)

      if state.turn == White {
        if evaluation > bestEval.contents {
          bestEval := evaluation
          bestMove := move
        }
      } else {
        if evaluation < bestEval.contents {
          bestEval := evaluation
          bestMove := move
        }
      }
    }

    Some((bestMove.contents, bestEval.contents))
  }
}
