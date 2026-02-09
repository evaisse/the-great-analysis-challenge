// Zobrist hashing for chess positions
// Provides fast incremental position hashing for transposition tables

use crate::types::*;

/// Zobrist hash key (64-bit unsigned integer)
pub type ZobristKey = u64;

/// Zobrist hashing tables
/// Pre-generated random numbers for each piece on each square,
/// castling rights, en passant files, and side to move
pub struct ZobristTable {
    /// piece_keys[piece_type][color][square]
    piece_keys: [[[u64; 64]; 2]; 6],
    /// castling_keys[rights] where rights is 0-15 (4 bits)
    castling_keys: [u64; 16],
    /// en_passant_keys[file] for files a-h (0-7)
    en_passant_keys: [u64; 8],
    /// Key to XOR when it's black's turn
    black_to_move: u64,
}

impl ZobristTable {
    /// Create a new Zobrist table with pre-generated random numbers
    /// Uses a fixed seed for deterministic behavior across languages
    pub fn new() -> Self {
        let mut table = ZobristTable {
            piece_keys: [[[0; 64]; 2]; 6],
            castling_keys: [0; 16],
            en_passant_keys: [0; 8],
            black_to_move: 0,
        };

        // Use a simple deterministic PRNG with fixed seed
        let mut rng = SimplePRNG::new(0x0123456789ABCDEF);

        // Generate piece keys
        for piece_type in 0..6 {
            for color in 0..2 {
                for square in 0..64 {
                    table.piece_keys[piece_type][color][square] = rng.next();
                }
            }
        }

        // Generate castling keys
        for i in 0..16 {
            table.castling_keys[i] = rng.next();
        }

        // Generate en passant keys
        for file in 0..8 {
            table.en_passant_keys[file] = rng.next();
        }

        // Generate black to move key
        table.black_to_move = rng.next();

        table
    }

    /// Get the piece key for a piece at a square
    pub fn piece_key(&self, piece: Piece, square: Square) -> u64 {
        let piece_idx = match piece.piece_type {
            PieceType::Pawn => 0,
            PieceType::Knight => 1,
            PieceType::Bishop => 2,
            PieceType::Rook => 3,
            PieceType::Queen => 4,
            PieceType::King => 5,
        };
        let color_idx = match piece.color {
            Color::White => 0,
            Color::Black => 1,
        };
        self.piece_keys[piece_idx][color_idx][square]
    }

    /// Get the castling key for castling rights
    pub fn castling_key(&self, rights: CastlingRights) -> u64 {
        let mut index = 0;
        if rights.white_kingside {
            index |= 1;
        }
        if rights.white_queenside {
            index |= 2;
        }
        if rights.black_kingside {
            index |= 4;
        }
        if rights.black_queenside {
            index |= 8;
        }
        self.castling_keys[index]
    }

    /// Get the en passant key for a file (0-7)
    pub fn en_passant_key(&self, file: usize) -> u64 {
        self.en_passant_keys[file]
    }

    /// Get the black to move key
    pub fn black_to_move_key(&self) -> u64 {
        self.black_to_move
    }
}

impl Default for ZobristTable {
    fn default() -> Self {
        Self::new()
    }
}

/// Simple deterministic PRNG for Zobrist key generation
/// Uses a linear congruential generator with fixed parameters
/// This ensures identical keys across all language implementations
struct SimplePRNG {
    state: u64,
}

impl SimplePRNG {
    fn new(seed: u64) -> Self {
        SimplePRNG { state: seed }
    }

    fn next(&mut self) -> u64 {
        // LCG parameters from Numerical Recipes
        // These specific values ensure good randomness properties
        const MULTIPLIER: u64 = 6364136223846793005;
        const INCREMENT: u64 = 1442695040888963407;

        self.state = self
            .state
            .wrapping_mul(MULTIPLIER)
            .wrapping_add(INCREMENT);
        self.state
    }
}

/// Compute the Zobrist hash for a game state
pub fn compute_hash(state: &GameState, zobrist: &ZobristTable) -> ZobristKey {
    let mut hash: u64 = 0;

    // Hash all pieces on the board
    for square in 0..64 {
        if let Some(piece) = state.board[square] {
            hash ^= zobrist.piece_key(piece, square);
        }
    }

    // Hash castling rights
    hash ^= zobrist.castling_key(state.castling_rights);

    // Hash en passant target
    if let Some(ep_square) = state.en_passant_target {
        let file = ep_square % 8;
        hash ^= zobrist.en_passant_key(file);
    }

    // Hash side to move
    if state.turn == Color::Black {
        hash ^= zobrist.black_to_move_key();
    }

    hash
}

/// Incrementally update a hash after a move
/// This is more efficient than recomputing the entire hash
pub fn update_hash_after_move(
    mut hash: ZobristKey,
    from: Square,
    to: Square,
    moved_piece: Piece,
    captured_piece: Option<Piece>,
    old_ep: Option<Square>,
    new_ep: Option<Square>,
    old_castling: CastlingRights,
    new_castling: CastlingRights,
    zobrist: &ZobristTable,
) -> ZobristKey {
    // Remove moved piece from source square
    hash ^= zobrist.piece_key(moved_piece, from);

    // Add moved piece to destination square
    hash ^= zobrist.piece_key(moved_piece, to);

    // Remove captured piece if any
    if let Some(captured) = captured_piece {
        hash ^= zobrist.piece_key(captured, to);
    }

    // Update en passant
    if let Some(old_ep_square) = old_ep {
        let file = old_ep_square % 8;
        hash ^= zobrist.en_passant_key(file);
    }
    if let Some(new_ep_square) = new_ep {
        let file = new_ep_square % 8;
        hash ^= zobrist.en_passant_key(file);
    }

    // Update castling rights
    if old_castling != new_castling {
        hash ^= zobrist.castling_key(old_castling);
        hash ^= zobrist.castling_key(new_castling);
    }

    // Toggle side to move
    hash ^= zobrist.black_to_move_key();

    hash
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_zobrist_table_creation() {
        let zobrist = ZobristTable::new();
        
        // Check that keys are non-zero
        assert_ne!(zobrist.piece_keys[0][0][0], 0);
        assert_ne!(zobrist.castling_keys[0], 0);
        assert_ne!(zobrist.en_passant_keys[0], 0);
        assert_ne!(zobrist.black_to_move, 0);
    }

    #[test]
    fn test_zobrist_deterministic() {
        // Two tables should generate identical keys
        let zobrist1 = ZobristTable::new();
        let zobrist2 = ZobristTable::new();
        
        assert_eq!(zobrist1.piece_keys[0][0][0], zobrist2.piece_keys[0][0][0]);
        assert_eq!(zobrist1.castling_keys[5], zobrist2.castling_keys[5]);
        assert_eq!(zobrist1.black_to_move, zobrist2.black_to_move);
    }

    #[test]
    fn test_initial_position_hash() {
        let zobrist = ZobristTable::new();
        let state = GameState::new();
        let hash = compute_hash(&state, &zobrist);
        
        // Hash should be non-zero for initial position
        assert_ne!(hash, 0);
        
        // Computing hash twice should give same result
        let hash2 = compute_hash(&state, &zobrist);
        assert_eq!(hash, hash2);
    }

    #[test]
    fn test_hash_changes_with_side_to_move() {
        let zobrist = ZobristTable::new();
        let mut state = GameState::new();
        let hash1 = compute_hash(&state, &zobrist);
        
        state.turn = Color::Black;
        let hash2 = compute_hash(&state, &zobrist);
        
        // Hashes should differ
        assert_ne!(hash1, hash2);
        
        // Difference should be exactly the black_to_move key
        assert_eq!(hash1 ^ hash2, zobrist.black_to_move_key());
    }
}
