use crate::types::*;
use crate::board::Board;
use crate::move_generator::MoveGenerator;
use std::collections::HashMap;

pub struct Perft {
    move_generator: MoveGenerator,
}

impl Perft {
    pub fn new() -> Self {
        Self {
            move_generator: MoveGenerator::new(),
        }
    }

    pub fn perft(&self, board: &Board, depth: u8) -> u64 {
        if depth == 0 {
            return 1;
        }

        let color = board.get_turn();
        let moves = self.move_generator.get_legal_moves(board, color);
        let mut nodes = 0;

        for chess_move in &moves {
            let mut board_copy = board.get_state().clone();
            let mut test_board = Board::new();
            test_board.set_state(board_copy);
            test_board.make_move(chess_move);
            
            nodes += self.perft(&test_board, depth - 1);
        }

        nodes
    }

    pub fn perft_divide(&self, board: &Board, depth: u8) -> HashMap<String, u64> {
        let mut results = HashMap::new();
        let color = board.get_turn();
        let moves = self.move_generator.get_legal_moves(board, color);

        for chess_move in &moves {
            let from = square_to_algebraic(chess_move.from);
            let to = square_to_algebraic(chess_move.to);
            let move_str = match chess_move.promotion {
                Some(promotion) => format!("{}{}{}", from, to, promotion),
                None => format!("{}{}", from, to),
            };
            
            let mut board_copy = board.get_state().clone();
            let mut test_board = Board::new();
            test_board.set_state(board_copy);
            test_board.make_move(chess_move);
            
            let count = self.perft(&test_board, depth - 1);
            results.insert(move_str, count);
        }

        results
    }
}