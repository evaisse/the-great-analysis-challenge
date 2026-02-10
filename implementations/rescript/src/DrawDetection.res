open Types

let isDrawByRepetition = (state: gameState): bool => {
  let currentHash = state.zobristHash
  let count = ref(1)

  let historyLen = Belt.Array.length(state.positionHistory)
  let startIdx = if historyLen > state.halfmoveClock {
    historyLen - state.halfmoveClock
  } else {
    0
  }

  let found = ref(false)
  let i = ref(historyLen - 1)
  while i.contents >= startIdx && !found.contents {
    if Belt.Array.getExn(state.positionHistory, i.contents) == currentHash {
      count := count.contents + 1
      if count.contents >= 3 {
        found := true
      }
    }
    i := i.contents - 1
  }
  found.contents
}

let isDrawByFiftyMoves = (state: gameState): bool => {
  state.halfmoveClock >= 100
}

let isDraw = (state: gameState): bool => {
  isDrawByRepetition(state) || isDrawByFiftyMoves(state)
}
