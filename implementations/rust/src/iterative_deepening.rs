// Iterative Deepening Search
// Searches progressively from depth 1 to max_depth, using TT and time management

use crate::ai::AI;
use crate::board::Board;
use crate::time_manager::TimeManager;
use crate::transposition_table::{TranspositionTable, decode_move};
use crate::types::*;

const MATE_SCORE: i32 = 100000;
const MAX_DEPTH: u8 = 100;

/// Result of iterative deepening search
pub struct IterativeDeepeningResult {
    pub best_move: Option<Move>,
    pub best_score: i32,
    pub depth_reached: u8,
}

/// Extract principal variation from transposition table
pub fn extract_pv(
    board: &Board,
    tt: &TranspositionTable,
    depth: u8,
) -> Vec<String> {
    let mut pv = Vec::new();
    let mut seen = std::collections::HashSet::new();
    let mut board_copy = board.get_state().clone();
    let mut temp_board = Board::new();
    temp_board.set_state(board_copy.clone());
    let mut current_depth = depth;

    while current_depth > 0 {
        let hash = temp_board.get_state().hash;
        
        if seen.contains(&hash) {
            break;
        }
        
        let entry = match tt.probe(hash) {
            Some(e) => e,
            None => break,
        };
        
        let best_move_encoded = match entry.best_move {
            Some(m) => m,
            None => break,
        };
        
        seen.insert(hash);
        
        let (from, to) = decode_move(best_move_encoded);
        let move_str = format!("{}{}", square_to_algebraic(from), square_to_algebraic(to));
        pv.push(move_str);
        
        // Try to make the move
        let legal_moves = crate::move_generator::MoveGenerator::new()
            .get_legal_moves(&temp_board, temp_board.get_turn());
        
        let mut found = false;
        for chess_move in &legal_moves {
            if chess_move.from == from && chess_move.to == to {
                temp_board.make_move(chess_move);
                found = true;
                break;
            }
        }
        
        if !found {
            break;
        }
        
        current_depth -= 1;
    }

    pv
}

/// Perform iterative deepening search
pub fn iterative_deepening(
    board: &Board,
    max_depth: u8,
    time_manager: &mut TimeManager,
    ai: &mut AI,
) -> IterativeDeepeningResult {
    let mut best_move: Option<Move> = None;
    let mut best_score: i32 = 0;
    let mut depth_reached: u8 = 0;

    for depth in 1..=max_depth {
        if time_manager.should_stop() {
            break;
        }

        // Check if we should start this iteration
        if !time_manager.should_continue_iteration(depth - 1) {
            break;
        }

        let result = ai.find_best_move(board, depth);

        // Check if search was interrupted
        if time_manager.search_was_interrupted() {
            break;
        }

        // Update best move and score
        if let Some(ref move_found) = result.best_move {
            best_move = Some(move_found.clone());
            best_score = result.evaluation;
            depth_reached = depth;

            // Extract PV
            let pv = extract_pv(board, ai.get_tt(), depth);
            let pv_str = pv.join(" ");

            // Print info line
            println!(
                "info depth {} score cp {} nodes {} time {} pv {}",
                depth,
                best_score,
                result.nodes,
                time_manager.elapsed_ms(),
                pv_str
            );
            std::io::Write::flush(&mut std::io::stdout()).unwrap();

            // Report to time manager
            let best_move_encoded = crate::transposition_table::encode_move(
                move_found.from,
                move_found.to,
            );
            time_manager.report_iteration(depth, best_score, Some(best_move_encoded));

            // Early exit if mate found
            if best_score.abs() >= MATE_SCORE - MAX_DEPTH as i32 {
                break;
            }
        } else {
            // No legal moves
            break;
        }
    }

    IterativeDeepeningResult {
        best_move,
        best_score,
        depth_reached,
    }
}
