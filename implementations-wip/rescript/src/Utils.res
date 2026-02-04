open Types

let oppositeColor = (color: color): color =>
  switch color {
  | White => Black
  | Black => White
  }

let modInt = (value: int, modulus: int): int => value - (value / modulus) * modulus
let absInt = (value: int): int => if value < 0 { -value } else { value }

let parseSquare = (squareStr: string): option<square> => {
  if Js.String.length(squareStr) != 2 {
    None
  } else {
    let fileChar = Js.String.charAt(0, squareStr)
    let rankChar = Js.String.charAt(1, squareStr)

    switch (Belt.Array.getIndexBy(files, f => f == fileChar), Belt.Array.getIndexBy(ranks, r => r == rankChar)) {
    | (Some(fileIndex), Some(rankIndex)) => Some(rankIndex * 8 + fileIndex)
    | _ => None
    }
  }
}

let squareToString = (square: square): string => {
  let fileIndex = modInt(square, 8)
  let rankIndex = square / 8

  switch (Belt.Array.get(files, fileIndex), Belt.Array.get(ranks, rankIndex)) {
  | (Some(fileChar), Some(rankChar)) => fileChar ++ rankChar
  | _ => "??"
  }
}

let pieceTypeToChar = (pieceType: pieceType): string =>
  switch pieceType {
  | Pawn => "P"
  | Knight => "N"
  | Bishop => "B"
  | Rook => "R"
  | Queen => "Q"
  | King => "K"
  }

let pieceToChar = (piece: piece): string => {
  let base = pieceTypeToChar(piece.pieceType)
  switch piece.color {
  | White => base
  | Black => Js.String.toLowerCase(base)
  }
}

let charToPiece = (char: string): option<piece> => {
  if char == "" {
    None
  } else {
    let upper = Js.String.toUpperCase(char)
    let isWhite = char == upper
    let color = if isWhite { White } else { Black }

    switch upper {
    | "P" => Some({pieceType: Pawn, color})
    | "N" => Some({pieceType: Knight, color})
    | "B" => Some({pieceType: Bishop, color})
    | "R" => Some({pieceType: Rook, color})
    | "Q" => Some({pieceType: Queen, color})
    | "K" => Some({pieceType: King, color})
    | _ => None
    }
  }
}
