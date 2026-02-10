// Board representation and game state management

import gleam/list
import gleam/string
import gleam/int
import gleam/io
import types.{
  type Color, type Piece, type Square, type Move, type PieceType, type GameState,
  type CastlingRights, White, Black, King, Queen, Rook, Bishop, Knight, Pawn,
  Piece, Move, GameState, CastlingRights, new_castling_rights, opposite_color,
  piece_to_char, square_to_algebraic
}

pub fn new_game() -> GameState {
  let board = new_board()
  GameState(
    board: board,
    turn: White,
    castling_rights: new_castling_rights(),
    en_passant_target: None,
    halfmove_clock: 0,
    fullmove_number: 1,
    move_history: [],
  )
}

fn new_board() -> List(Option(Piece)) {
  let empty_row = list.repeat(None, 8)
  let white_pawn_row = list.repeat(Some(Piece(Pawn, White)), 8)
  let black_pawn_row = list.repeat(Some(Piece(Pawn, Black)), 8)
  
  let white_back_row = [
    Some(Piece(Rook, White)),
    Some(Piece(Knight, White)),
    Some(Piece(Bishop, White)),
    Some(Piece(Queen, White)),
    Some(Piece(King, White)),
    Some(Piece(Bishop, White)),
    Some(Piece(Knight, White)),
    Some(Piece(Rook, White)),
  ]
  
  let black_back_row = [
    Some(Piece(Rook, Black)),
    Some(Piece(Knight, Black)),
    Some(Piece(Bishop, Black)),
    Some(Piece(Queen, Black)),
    Some(Piece(King, Black)),
    Some(Piece(Bishop, Black)),
    Some(Piece(Knight, Black)),
    Some(Piece(Rook, Black)),
  ]
  
  list.concat([
    white_back_row,
    white_pawn_row,
    empty_row,
    empty_row,
    empty_row,
    empty_row,
    black_pawn_row,
    black_back_row,
  ])
}

pub fn get_piece(game_state: GameState, square: Square) -> Option(Piece) {
  case list.at(game_state.board, square) {
    Ok(piece) -> piece
    Error(_) -> None
  }
}

pub fn set_piece(game_state: GameState, square: Square, piece: Option(Piece)) -> GameState {
  let new_board = list.index_map(game_state.board, fn(current_piece, index) {
    case index == square {
      True -> piece
      False -> current_piece
    }
  })
  GameState(..game_state, board: new_board)
}

pub fn make_move(game_state: GameState, chess_move: Move) -> GameState {
  let piece = get_piece(game_state, chess_move.from)
  case piece {
    None -> game_state
    Some(moving_piece) -> {
      // Move the piece
      let state_after_move = game_state
        |> set_piece(chess_move.to, Some(moving_piece))
        |> set_piece(chess_move.from, None)
      
      // Handle special moves
      let state_after_special = state_after_move
        |> handle_castling(chess_move, moving_piece)
        |> handle_en_passant(chess_move, moving_piece)
        |> handle_promotion(chess_move, moving_piece)
      
      // Update game state
      let new_castling_rights = update_castling_rights(
        state_after_special.castling_rights,
        chess_move,
        moving_piece,
      )
      
      let new_en_passant = case moving_piece.piece_type == Pawn && 
                                int.absolute_value(chess_move.to - chess_move.from) == 16 {
        True -> Some({ chess_move.from + chess_move.to } / 2)
        False -> None
      }
      
      let new_halfmove = case moving_piece.piece_type == Pawn || chess_move.captured != None {
        True -> 0
        False -> state_after_special.halfmove_clock + 1
      }
      
      let new_fullmove = case moving_piece.color == Black {
        True -> state_after_special.fullmove_number + 1
        False -> state_after_special.fullmove_number
      }
      
      GameState(
        ..state_after_special,
        turn: opposite_color(moving_piece.color),
        castling_rights: new_castling_rights,
        en_passant_target: new_en_passant,
        halfmove_clock: new_halfmove,
        fullmove_number: new_fullmove,
        move_history: [chess_move, ..state_after_special.move_history],
      )
    }
  }
}

fn handle_castling(game_state: GameState, chess_move: Move, piece: Piece) -> GameState {
  case chess_move.is_castling {
    False -> game_state
    True -> {
      let rank = case piece.color {
        White -> 0
        Black -> 7
      }
      let #(rook_from, rook_to) = case chess_move.to == rank * 8 + 6 {
        True -> #(rank * 8 + 7, rank * 8 + 5)  // Kingside
        False -> #(rank * 8, rank * 8 + 3)     // Queenside
      }
      
      case get_piece(game_state, rook_from) {
        Some(rook) -> game_state
          |> set_piece(rook_to, Some(rook))
          |> set_piece(rook_from, None)
        None -> game_state
      }
    }
  }
}

fn handle_en_passant(game_state: GameState, chess_move: Move, piece: Piece) -> GameState {
  case chess_move.is_en_passant {
    False -> game_state
    True -> {
      let captured_pawn_square = case piece.color {
        White -> chess_move.to - 8
        Black -> chess_move.to + 8
      }
      set_piece(game_state, captured_pawn_square, None)
    }
  }
}

fn handle_promotion(game_state: GameState, chess_move: Move, piece: Piece) -> GameState {
  case chess_move.promotion {
    None -> game_state
    Some(promotion_type) -> 
      set_piece(game_state, chess_move.to, Some(Piece(promotion_type, piece.color)))
  }
}

fn update_castling_rights(
  rights: CastlingRights,
  chess_move: Move,
  piece: Piece,
) -> CastlingRights {
  case piece.piece_type {
    King -> case piece.color {
      White -> CastlingRights(..rights, white_kingside: False, white_queenside: False)
      Black -> CastlingRights(..rights, black_kingside: False, black_queenside: False)
    }
    Rook -> case piece.color, chess_move.from {
      White, 0 -> CastlingRights(..rights, white_queenside: False)
      White, 7 -> CastlingRights(..rights, white_kingside: False)
      Black, 56 -> CastlingRights(..rights, black_queenside: False)
      Black, 63 -> CastlingRights(..rights, black_kingside: False)
      _, _ -> rights
    }
    _ -> rights
  }
}

pub fn undo_move(game_state: GameState) -> GameState {
  case game_state.move_history {
    [] -> game_state
    [last_move, ..rest_history] -> {
      // This is a simplified undo - in a full implementation,
      // we'd need to store more state information
      let piece = get_piece(game_state, last_move.to)
      case piece {
        None -> game_state
        Some(moved_piece) -> {
          let original_piece = case last_move.promotion {
            Some(_) -> Piece(Pawn, moved_piece.color)
            None -> moved_piece
          }
          
          let state_after_undo = game_state
            |> set_piece(last_move.from, Some(original_piece))
            |> set_piece(last_move.to, case last_move.captured {
              Some(captured_type) -> Some(Piece(captured_type, opposite_color(moved_piece.color)))
              None -> None
            })
          
          GameState(
            ..state_after_undo,
            turn: moved_piece.color,
            move_history: rest_history,
          )
        }
      }
    }
  }
}

pub fn display_board(game_state: GameState) -> String {
  let header = "  a b c d e f g h\n"
  let footer = "  a b c d e f g h\n\n"
  let turn_info = case game_state.turn {
    White -> "White to move"
    Black -> "Black to move"
  }
  
  let board_rows = list.range(7, 0)
    |> list.map(fn(rank) {
      let rank_str = int.to_string(rank + 1)
      let row_pieces = list.range(0, 7)
        |> list.map(fn(file) {
          let square = rank * 8 + file
          case get_piece(game_state, square) {
            Some(piece) -> piece_to_char(piece)
            None -> "."
          }
        })
        |> string.join(" ")
      rank_str <> " " <> row_pieces <> " " <> rank_str <> "\n"
    })
    |> string.join("")
  
  header <> board_rows <> footer <> turn_info
}