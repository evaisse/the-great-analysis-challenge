open Types
open MoveGenerator

let rec perft = (state: gameState, depth: int): int => {
  if depth == 0 {
    1
  } else {
    let moves = generateLegalMoves(state)
    let nodes = ref(0)
    let moveCount = Js.Array.length(moves)

    for index in 0 to moveCount - 1 {
      let move = Belt.Array.getExn(moves, index)
      let nextState = makeMove(state, move)
      nodes := nodes.contents + perft(nextState, depth - 1)
    }

    nodes.contents
  }
}
