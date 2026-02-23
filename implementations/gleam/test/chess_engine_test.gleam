import gleeunit
import gleeunit/should
import gleam/list
import gleam/option.{None, Some}
import types.{White, Black}
import board.{new_game, get_piece}
import move_generator.{get_legal_moves}
import fen.{parse_fen, export_fen}
import chess_engine.{new}

pub fn main() {
  gleeunit.main()
}

// Test basic game initialization
pub fn new_game_test() {
  let game = new_game()
  game.turn
  |> should.equal(White)
}

// Test that a new chess engine can be created
pub fn new_engine_test() {
  let engine = new()
  engine.game_state.turn
  |> should.equal(White)
}

// Test legal moves from starting position
pub fn starting_position_moves_test() {
  let game = new_game()
  let legal_moves = get_legal_moves(game, White)

  // Starting position should have 20 legal moves
  legal_moves
  |> list.length
  |> should.equal(20)
}

// Test FEN export/import
pub fn fen_export_import_test() {
  let game = new_game()
  let fen = export_fen(game)

  // Starting position FEN
  fen
  |> should.equal("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

  // Test importing the same FEN
  case parse_fen(fen) {
    Ok(imported_game) -> {
      export_fen(imported_game)
      |> should.equal(fen)
    }
    Error(_) -> should.fail()
  }
}

// Test piece placement
pub fn piece_placement_test() {
  let game = new_game()

  // Test white king is at e1
  case get_piece(game, 4) {
    Some(piece) -> {
      piece.piece_type
      |> should.equal(types.King)
      piece.color
      |> should.equal(White)
    }
    None -> should.fail()
  }

  // Test black king is at e8
  case get_piece(game, 60) {
    Some(piece) -> {
      piece.piece_type
      |> should.equal(types.King)
      piece.color
      |> should.equal(Black)
    }
    None -> should.fail()
  }
}
