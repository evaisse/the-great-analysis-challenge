use crate::types::*;

pub struct ZobristKeys {
    pub pieces: [[u64; 64]; 12],
    pub side_to_move: u64,
    pub castling: [u64; 4],
    pub en_passant: [u64; 8],
}

impl ZobristKeys {
    pub fn new() -> Self {
        let mut keys = Self {
            pieces: [[0; 64]; 12],
            side_to_move: 0,
            castling: [0; 4],
            en_passant: [0; 8],
        };
        
        let mut state = 0x123456789ABCDEF0u64;
        
        for p in 0..12 {
            for s in 0..64 {
                state = xorshift64(state);
                keys.pieces[p][s] = state;
            }
        }
        
        state = xorshift64(state);
        keys.side_to_move = state;
        
        for i in 0..4 {
            state = xorshift64(state);
            keys.castling[i] = state;
        }
        
        for i in 0..8 {
            state = xorshift64(state);
            keys.en_passant[i] = state;
        }
        
        keys
    }

    pub fn compute_hash(&self, state: &GameState) -> u64 {
        let mut hash = 0u64;
        
        for (i, piece_opt) in state.board.iter().enumerate() {
            if let Some(piece) = piece_opt {
                hash ^= self.pieces[piece_to_index(*piece)][i];
            }
        }
        
        if state.turn == Color::Black {
            hash ^= self.side_to_move;
        }
        
        if state.castling_rights.white_kingside { hash ^= self.castling[0]; }
        if state.castling_rights.white_queenside { hash ^= self.castling[1]; }
        if state.castling_rights.black_kingside { hash ^= self.castling[2]; }
        if state.castling_rights.black_queenside { hash ^= self.castling[3]; }
        
        if let Some(sq) = state.en_passant_target {
            let file = sq % 8;
            hash ^= self.en_passant[file];
        }
        
        hash
    }
}

fn xorshift64(mut state: u64) -> u64 {
    state ^= state << 13;
    state ^= state >> 7;
    state ^= state << 17;
    state
}

pub fn piece_to_index(piece: Piece) -> usize {
    let type_idx = match piece.piece_type {
        PieceType::Pawn => 0,
        PieceType::Knight => 1,
        PieceType::Bishop => 2,
        PieceType::Rook => 3,
        PieceType::Queen => 4,
        PieceType::King => 5,
    };
    if piece.color == Color::White {
        type_idx
    } else {
        type_idx + 6
    }
}

use std::sync::OnceLock;

static KEYS: OnceLock<ZobristKeys> = OnceLock::new();

pub fn get_keys() -> &'static ZobristKeys {
    KEYS.get_or_init(ZobristKeys::new)
}
