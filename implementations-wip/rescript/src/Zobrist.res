open Types

type keys = {
  pieces: array<array<bigint>>,
  sideToMove: bigint,
  castling: array<bigint>,
  enPassant: array<bigint>,
}

let xor = (a: bigint, b: bigint): bigint => {
  // ReScript doesn't have a direct infix for bigint xor, using raw JS
  %raw(`((a, b) => a ^ b)`)(a, b)
}

let shiftL = (a: bigint, b: bigint): bigint => %raw(`((a, b) => a << b)`)(a, b)
let shiftR = (a: bigint, b: bigint): bigint => %raw(`((a, b) => a >> b)`)(a, b)
let bitAnd = (a: bigint, b: bigint): bigint => %raw(`((a, b) => a & b)`)(a, b)

let mask64: bigint = %raw(`0xFFFFFFFFFFFFFFFFn`)

let xorshift64 = (state: bigint): bigint => {
  let s = ref(state)
  s := xor(s.contents, bitAnd(shiftL(s.contents, 13n), mask64))
  s := xor(s.contents, shiftR(s.contents, 7n))
  s := xor(s.contents, bitAnd(shiftL(s.contents, 17n), mask64))
  s.contents
}

let generateKeys = (): keys => {
  let state = ref(%raw(`0x123456789ABCDEF0n`))
  
  let next = () => {
    state := xorshift64(state.contents)
    state.contents
  }

  let pieces = Array.make(12, [])
  for i in 0 to 11 {
    let pieceKeys = Array.make(64, 0n)
    for j in 0 to 63 {
      pieceKeys[j] = next()
    }
    pieces[i] = pieceKeys
  }

  let sideToMove = next()

  let castling = Array.make(4, 0n)
  for i in 0 to 3 {
    castling[i] = next()
  }

  let enPassant = Array.make(8, 0n)
  for i in 0 to 7 {
    enPassant[i] = next()
  }

  {pieces, sideToMove, castling, enPassant}
}

let globalKeys = generateKeys()

let getPieceIndex = (piece: piece): int => {
  let typeIdx = switch piece.pieceType {
  | Pawn => 0
  | Knight => 1
  | Bishop => 2
  | Rook => 3
  | Queen => 4
  | King => 5
  }
  if piece.color == White {
    typeIdx
  } else {
    typeIdx + 6
  }
}

let computeHash = (state: gameState): bigint => {
  let hash = ref(0n)
  
  for i in 0 to 63 {
    switch state.board[i] {
    | Some(piece) =>
      let idx = getPieceIndex(piece)
      hash := xor(hash.contents, globalKeys.pieces[idx][i])
    | None => ()
    }
  }

  if state.turn == Black {
    hash := xor(hash.contents, globalKeys.sideToMove)
  }

  if state.castlingRights.whiteKingside { hash := xor(hash.contents, globalKeys.castling[0]) }
  if state.castlingRights.whiteQueenside { hash := xor(hash.contents, globalKeys.castling[1]) }
  if state.castlingRights.blackKingside { hash := xor(hash.contents, globalKeys.castling[2]) }
  if state.castlingRights.blackQueenside { hash := xor(hash.contents, globalKeys.castling[3]) }

  switch state.enPassantTarget {
  | Some(sq) => hash := xor(hash.contents, globalKeys.enPassant[Utils.modInt(sq, 8)])
  | None => ()
  }

  hash.contents
}