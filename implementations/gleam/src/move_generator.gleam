// Move generation and validation

import board.{get_piece, make_move}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import types.{
  type Color, type GameState, type Move, type Piece, type PieceType, type Square,
  Bishop, Black, King, Knight, Move, Pawn, Piece, Queen, Rook, White,
  opposite_color,
}

pub fn generate_moves(game_state: GameState, color: Color) -> List(Move) {
  list.range(0, 63)
  |> list.flat_map(fn(square) {
    case get_piece(game_state, square) {
      Some(piece) ->
        case piece.color == color {
          True -> generate_piece_moves(game_state, square, piece)
          False -> []
        }
      _ -> []
    }
  })
}

fn generate_piece_moves(
  game_state: GameState,
  from: Square,
  piece: Piece,
) -> List(Move) {
  case piece.piece_type {
    Pawn -> generate_pawn_moves(game_state, from, piece.color)
    Knight -> generate_knight_moves(game_state, from, piece.color)
    Bishop -> generate_bishop_moves(game_state, from, piece.color)
    Rook -> generate_rook_moves(game_state, from, piece.color)
    Queen -> generate_queen_moves(game_state, from, piece.color)
    King -> generate_king_moves(game_state, from, piece.color)
  }
}

fn generate_pawn_moves(
  game_state: GameState,
  from: Square,
  color: Color,
) -> List(Move) {
  let direction = case color {
    White -> 8
    Black -> -8
  }
  let start_rank = case color {
    White -> 1
    Black -> 6
  }
  let promotion_rank = case color {
    White -> 7
    Black -> 0
  }

  let rank = from / 8
  let file = from % 8
  let moves = []

  // One square forward
  let one_forward = from + direction
  let one_forward_empty =
    is_valid_square(one_forward) && get_piece(game_state, one_forward) == None
  let moves = case one_forward_empty {
    True -> {
      let to_rank = one_forward / 8
      case to_rank == promotion_rank {
        True -> [
          Move(from, one_forward, Pawn, None, Some(Queen), False, False),
          Move(from, one_forward, Pawn, None, Some(Rook), False, False),
          Move(from, one_forward, Pawn, None, Some(Bishop), False, False),
          Move(from, one_forward, Pawn, None, Some(Knight), False, False),
          ..moves
        ]
        False -> [
          Move(from, one_forward, Pawn, None, None, False, False),
          ..moves
        ]
      }
    }
    False -> moves
  }

  // Two squares forward from starting position
  let two_forward = from + 2 * direction
  let moves = case
    rank == start_rank
    && one_forward_empty
    && is_valid_square(two_forward)
    && get_piece(game_state, two_forward) == None
  {
    True -> [Move(from, two_forward, Pawn, None, None, False, False), ..moves]
    False -> moves
  }

  // Captures
  let capture_moves =
    [direction - 1, direction + 1]
    |> list.flat_map(fn(offset) {
      let to = from + offset
      let to_file = to % 8
      case is_valid_square(to) && int.absolute_value(to_file - file) == 1 {
        True -> {
          case get_piece(game_state, to) {
            Some(target) ->
              case target.color != color {
                True -> {
                  let to_rank = to / 8
                  case to_rank == promotion_rank {
                    True -> [
                      Move(
                        from,
                        to,
                        Pawn,
                        Some(target.piece_type),
                        Some(Queen),
                        False,
                        False,
                      ),
                      Move(
                        from,
                        to,
                        Pawn,
                        Some(target.piece_type),
                        Some(Rook),
                        False,
                        False,
                      ),
                      Move(
                        from,
                        to,
                        Pawn,
                        Some(target.piece_type),
                        Some(Bishop),
                        False,
                        False,
                      ),
                      Move(
                        from,
                        to,
                        Pawn,
                        Some(target.piece_type),
                        Some(Knight),
                        False,
                        False,
                      ),
                    ]
                    False -> [
                      Move(
                        from,
                        to,
                        Pawn,
                        Some(target.piece_type),
                        None,
                        False,
                        False,
                      ),
                    ]
                  }
                }
                False -> []
              }
            _ -> []
          }
        }
        False -> []
      }
    })

  // En passant
  let en_passant_moves = case game_state.en_passant_target {
    Some(en_passant_square) -> {
      let expected_rank = case color {
        White -> 4
        Black -> 3
      }
      case rank == expected_rank {
        True ->
          [direction - 1, direction + 1]
          |> list.filter_map(fn(offset) {
            let to = from + offset
            let to_file = to % 8
            case
              to == en_passant_square && int.absolute_value(to_file - file) == 1
            {
              True -> Ok(Move(from, to, Pawn, Some(Pawn), None, False, True))
              False -> Error(Nil)
            }
          })
        False -> []
      }
    }
    None -> []
  }

  list.concat([moves, capture_moves, en_passant_moves])
}

fn generate_knight_moves(
  game_state: GameState,
  from: Square,
  color: Color,
) -> List(Move) {
  let offsets = [-17, -15, -10, -6, 6, 10, 15, 17]
  let file = from % 8

  offsets
  |> list.filter_map(fn(offset) {
    let to = from + offset
    let to_file = to % 8
    case is_valid_square(to) && int.absolute_value(to_file - file) <= 2 {
      True -> {
        case get_piece(game_state, to) {
          None -> Ok(Move(from, to, Knight, None, None, False, False))
          Some(target) ->
            case target.color != color {
              True ->
                Ok(Move(
                  from,
                  to,
                  Knight,
                  Some(target.piece_type),
                  None,
                  False,
                  False,
                ))
              False -> Error(Nil)
            }
        }
      }
      False -> Error(Nil)
    }
  })
}

fn generate_sliding_moves(
  game_state: GameState,
  from: Square,
  color: Color,
  directions: List(Int),
  piece_type: PieceType,
) -> List(Move) {
  directions
  |> list.flat_map(fn(direction) {
    generate_direction_moves(
      game_state,
      from,
      from,
      color,
      direction,
      piece_type,
      [],
    )
  })
}

fn generate_direction_moves(
  game_state: GameState,
  origin: Square,
  current: Square,
  color: Color,
  direction: Int,
  piece_type: PieceType,
  acc: List(Move),
) -> List(Move) {
  let to = current + direction
  let from_file = current % 8
  let to_file = to % 8

  case is_valid_square(to) {
    False -> acc
    True -> {
      // Check for wrapping on horizontal/diagonal moves
      let file_diff = int.absolute_value(to_file - from_file)
      case file_diff > 1 {
        True -> acc
        False -> {
          case get_piece(game_state, to) {
            None -> {
              let new_move =
                Move(origin, to, piece_type, None, None, False, False)
              generate_direction_moves(
                game_state,
                origin,
                to,
                color,
                direction,
                piece_type,
                [new_move, ..acc],
              )
            }
            Some(target) ->
              case target.color != color {
                True -> {
                  let capture_move =
                    Move(
                      origin,
                      to,
                      piece_type,
                      Some(target.piece_type),
                      None,
                      False,
                      False,
                    )
                  [capture_move, ..acc]
                }
                False -> acc
              }
          }
        }
      }
    }
  }
}

fn generate_bishop_moves(
  game_state: GameState,
  from: Square,
  color: Color,
) -> List(Move) {
  generate_sliding_moves(game_state, from, color, [-9, -7, 7, 9], Bishop)
}

fn generate_rook_moves(
  game_state: GameState,
  from: Square,
  color: Color,
) -> List(Move) {
  generate_sliding_moves(game_state, from, color, [-8, -1, 1, 8], Rook)
}

fn generate_queen_moves(
  game_state: GameState,
  from: Square,
  color: Color,
) -> List(Move) {
  generate_sliding_moves(
    game_state,
    from,
    color,
    [-9, -8, -7, -1, 1, 7, 8, 9],
    Queen,
  )
}

fn generate_king_moves(
  game_state: GameState,
  from: Square,
  color: Color,
) -> List(Move) {
  let offsets = [-9, -8, -7, -1, 1, 7, 8, 9]
  let file = from % 8

  let normal_moves =
    offsets
    |> list.filter_map(fn(offset) {
      let to = from + offset
      let to_file = to % 8
      case is_valid_square(to) && int.absolute_value(to_file - file) <= 1 {
        True -> {
          case get_piece(game_state, to) {
            None -> Ok(Move(from, to, King, None, None, False, False))
            Some(target) ->
              case target.color != color {
                True ->
                  Ok(Move(
                    from,
                    to,
                    King,
                    Some(target.piece_type),
                    None,
                    False,
                    False,
                  ))
                False -> Error(Nil)
              }
          }
        }
        False -> Error(Nil)
      }
    })

  // Add castling moves
  let castling_moves = generate_castling_moves(game_state, from, color)

  list.concat([normal_moves, castling_moves])
}

fn generate_castling_moves(
  game_state: GameState,
  from: Square,
  color: Color,
) -> List(Move) {
  case color, from {
    White, 4 -> {
      let kingside = case
        game_state.castling_rights.white_kingside
        && get_piece(game_state, 5) == None
        && get_piece(game_state, 6) == None
        && is_rook_at(game_state, 7, White)
        && !is_square_attacked(game_state, 4, Black)
        && !is_square_attacked(game_state, 5, Black)
        && !is_square_attacked(game_state, 6, Black)
      {
        True -> [Move(4, 6, King, None, None, True, False)]
        False -> []
      }

      let queenside = case
        game_state.castling_rights.white_queenside
        && get_piece(game_state, 3) == None
        && get_piece(game_state, 2) == None
        && get_piece(game_state, 1) == None
        && is_rook_at(game_state, 0, White)
        && !is_square_attacked(game_state, 4, Black)
        && !is_square_attacked(game_state, 3, Black)
        && !is_square_attacked(game_state, 2, Black)
      {
        True -> [Move(4, 2, King, None, None, True, False)]
        False -> []
      }

      list.concat([kingside, queenside])
    }
    Black, 60 -> {
      let kingside = case
        game_state.castling_rights.black_kingside
        && get_piece(game_state, 61) == None
        && get_piece(game_state, 62) == None
        && is_rook_at(game_state, 63, Black)
        && !is_square_attacked(game_state, 60, White)
        && !is_square_attacked(game_state, 61, White)
        && !is_square_attacked(game_state, 62, White)
      {
        True -> [Move(60, 62, King, None, None, True, False)]
        False -> []
      }

      let queenside = case
        game_state.castling_rights.black_queenside
        && get_piece(game_state, 59) == None
        && get_piece(game_state, 58) == None
        && get_piece(game_state, 57) == None
        && is_rook_at(game_state, 56, Black)
        && !is_square_attacked(game_state, 60, White)
        && !is_square_attacked(game_state, 59, White)
        && !is_square_attacked(game_state, 58, White)
      {
        True -> [Move(60, 58, King, None, None, True, False)]
        False -> []
      }

      list.concat([kingside, queenside])
    }
    _, _ -> []
  }
}

fn is_rook_at(game_state: GameState, square: Square, color: Color) -> Bool {
  case get_piece(game_state, square) {
    Some(piece) ->
      case piece.piece_type == Rook && piece.color == color {
        True -> True
        False -> False
      }
    _ -> False
  }
}

pub fn is_square_attacked(
  game_state: GameState,
  square: Square,
  by_color: Color,
) -> Bool {
  list.range(0, 63)
  |> list.any(fn(from_square) {
    case get_piece(game_state, from_square) {
      Some(piece) ->
        case piece.color == by_color {
          True -> piece_attacks_square(game_state, from_square, piece, square)
          False -> False
        }
      _ -> False
    }
  })
}

fn piece_attacks_square(
  game_state: GameState,
  from: Square,
  piece: Piece,
  target: Square,
) -> Bool {
  case piece.piece_type {
    Pawn -> pawn_attacks_square(from, piece.color, target)
    Knight ->
      offset_piece_attacks_square(
        from,
        target,
        [-17, -15, -10, -6, 6, 10, 15, 17],
        2,
      )
    Bishop ->
      sliding_piece_attacks_square(game_state, from, target, [-9, -7, 7, 9])
    Rook ->
      sliding_piece_attacks_square(game_state, from, target, [-8, -1, 1, 8])
    Queen ->
      sliding_piece_attacks_square(game_state, from, target, [
        -9, -8, -7, -1, 1, 7, 8, 9,
      ])
    King ->
      offset_piece_attacks_square(from, target, [-9, -8, -7, -1, 1, 7, 8, 9], 1)
  }
}

fn pawn_attacks_square(from: Square, color: Color, target: Square) -> Bool {
  let from_file = from % 8
  let target_file = target % 8
  let file_diff = int.absolute_value(target_file - from_file)

  case is_valid_square(target) && file_diff == 1 {
    False -> False
    True ->
      case color {
        White -> target == from + 7 || target == from + 9
        Black -> target == from - 7 || target == from - 9
      }
  }
}

fn offset_piece_attacks_square(
  from: Square,
  target: Square,
  offsets: List(Int),
  max_file_delta: Int,
) -> Bool {
  let from_file = from % 8

  offsets
  |> list.any(fn(offset) {
    let to = from + offset
    let to_file = to % 8

    is_valid_square(to)
    && int.absolute_value(to_file - from_file) <= max_file_delta
    && to == target
  })
}

fn sliding_piece_attacks_square(
  game_state: GameState,
  from: Square,
  target: Square,
  directions: List(Int),
) -> Bool {
  directions
  |> list.any(fn(direction) {
    attacks_along_direction(game_state, from, target, direction)
  })
}

fn attacks_along_direction(
  game_state: GameState,
  current: Square,
  target: Square,
  direction: Int,
) -> Bool {
  let next = current + direction
  let current_file = current % 8
  let next_file = next % 8

  case is_valid_square(next) {
    False -> False
    True -> {
      let file_diff = int.absolute_value(next_file - current_file)
      case file_diff > 1 {
        True -> False
        False ->
          case next == target {
            True -> True
            False ->
              case get_piece(game_state, next) {
                None ->
                  attacks_along_direction(game_state, next, target, direction)
                Some(_) -> False
              }
          }
      }
    }
  }
}

pub fn is_in_check(game_state: GameState, color: Color) -> Bool {
  let king_square =
    list.range(0, 63)
    |> list.find_map(fn(square) {
      case get_piece(game_state, square) {
        Some(piece) ->
          case piece.piece_type == King && piece.color == color {
            True -> Ok(square)
            False -> Error(Nil)
          }
        _ -> Error(Nil)
      }
    })

  case king_square {
    Ok(ks) -> is_square_attacked(game_state, ks, opposite_color(color))
    Error(_) -> False
  }
}

pub fn get_legal_moves(game_state: GameState, color: Color) -> List(Move) {
  generate_moves(game_state, color)
  |> list.filter(fn(m) {
    let new_state = make_move(game_state, m)
    !is_in_check(new_state, color)
  })
}

pub fn is_checkmate(game_state: GameState, color: Color) -> Bool {
  is_in_check(game_state, color)
  && list.is_empty(get_legal_moves(game_state, color))
}

pub fn is_stalemate(game_state: GameState, color: Color) -> Bool {
  !is_in_check(game_state, color)
  && list.is_empty(get_legal_moves(game_state, color))
}

fn is_valid_square(square: Square) -> Bool {
  square >= 0 && square < 64
}
