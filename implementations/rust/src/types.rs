use std::fmt;

pub type Square = usize;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PieceType {
    King,
    Queen,
    Rook,
    Bishop,
    Knight,
    Pawn,
}

impl fmt::Display for PieceType {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        let ch = match self {
            PieceType::King => 'K',
            PieceType::Queen => 'Q',
            PieceType::Rook => 'R',
            PieceType::Bishop => 'B',
            PieceType::Knight => 'N',
            PieceType::Pawn => 'P',
        };
        write!(f, "{}", ch)
    }
}

impl PieceType {
    pub fn from_char(ch: char) -> Option<PieceType> {
        match ch.to_ascii_uppercase() {
            'K' => Some(PieceType::King),
            'Q' => Some(PieceType::Queen),
            'R' => Some(PieceType::Rook),
            'B' => Some(PieceType::Bishop),
            'N' => Some(PieceType::Knight),
            'P' => Some(PieceType::Pawn),
            _ => None,
        }
    }

    pub fn value(&self) -> i32 {
        match self {
            PieceType::Pawn => 100,
            PieceType::Knight => 320,
            PieceType::Bishop => 330,
            PieceType::Rook => 500,
            PieceType::Queen => 900,
            PieceType::King => 20000,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Color {
    White,
    Black,
}

impl Color {
    pub fn opposite(&self) -> Color {
        match self {
            Color::White => Color::Black,
            Color::Black => Color::White,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Piece {
    pub piece_type: PieceType,
    pub color: Color,
}

impl Piece {
    pub fn new(piece_type: PieceType, color: Color) -> Self {
        Self { piece_type, color }
    }

    pub fn to_char(&self) -> char {
        let ch = match self.piece_type {
            PieceType::King => 'K',
            PieceType::Queen => 'Q',
            PieceType::Rook => 'R',
            PieceType::Bishop => 'B',
            PieceType::Knight => 'N',
            PieceType::Pawn => 'P',
        };
        if self.color == Color::White {
            ch
        } else {
            ch.to_ascii_lowercase()
        }
    }

    pub fn from_char(ch: char) -> Option<Piece> {
        let piece_type = PieceType::from_char(ch)?;
        let color = if ch.is_ascii_uppercase() {
            Color::White
        } else {
            Color::Black
        };
        Some(Piece::new(piece_type, color))
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Move {
    pub from: Square,
    pub to: Square,
    pub piece: PieceType,
    pub captured: Option<PieceType>,
    pub promotion: Option<PieceType>,
    pub is_castling: bool,
    pub is_en_passant: bool,
}

impl Move {
    pub fn new(from: Square, to: Square, piece: PieceType) -> Self {
        Self {
            from,
            to,
            piece,
            captured: None,
            promotion: None,
            is_castling: false,
            is_en_passant: false,
        }
    }

    pub fn with_capture(mut self, captured: PieceType) -> Self {
        self.captured = Some(captured);
        self
    }

    pub fn with_promotion(mut self, promotion: PieceType) -> Self {
        self.promotion = Some(promotion);
        self
    }

    pub fn with_castling(mut self) -> Self {
        self.is_castling = true;
        self
    }

    pub fn with_en_passant(mut self) -> Self {
        self.is_en_passant = true;
        self
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CastlingRights {
    pub white_kingside: bool,
    pub white_queenside: bool,
    pub black_kingside: bool,
    pub black_queenside: bool,
}

impl CastlingRights {
    pub fn new() -> Self {
        Self {
            white_kingside: true,
            white_queenside: true,
            black_kingside: true,
            black_queenside: true,
        }
    }

    pub fn none() -> Self {
        Self {
            white_kingside: false,
            white_queenside: false,
            black_kingside: false,
            black_queenside: false,
        }
    }
}

#[derive(Debug, Clone)]
pub struct GameState {
    pub board: [Option<Piece>; 64],
    pub turn: Color,
    pub castling_rights: CastlingRights,
    pub en_passant_target: Option<Square>,
    pub halfmove_clock: u32,
    pub fullmove_number: u32,
    pub move_history: Vec<Move>,
    pub hash: u64,
}

impl GameState {
    pub fn new() -> Self {
        let mut board = [None; 64];
        
        // White pieces
        board[0] = Some(Piece::new(PieceType::Rook, Color::White));
        board[1] = Some(Piece::new(PieceType::Knight, Color::White));
        board[2] = Some(Piece::new(PieceType::Bishop, Color::White));
        board[3] = Some(Piece::new(PieceType::Queen, Color::White));
        board[4] = Some(Piece::new(PieceType::King, Color::White));
        board[5] = Some(Piece::new(PieceType::Bishop, Color::White));
        board[6] = Some(Piece::new(PieceType::Knight, Color::White));
        board[7] = Some(Piece::new(PieceType::Rook, Color::White));
        
        for i in 8..16 {
            board[i] = Some(Piece::new(PieceType::Pawn, Color::White));
        }
        
        // Black pieces
        for i in 48..56 {
            board[i] = Some(Piece::new(PieceType::Pawn, Color::Black));
        }
        
        board[56] = Some(Piece::new(PieceType::Rook, Color::Black));
        board[57] = Some(Piece::new(PieceType::Knight, Color::Black));
        board[58] = Some(Piece::new(PieceType::Bishop, Color::Black));
        board[59] = Some(Piece::new(PieceType::Queen, Color::Black));
        board[60] = Some(Piece::new(PieceType::King, Color::Black));
        board[61] = Some(Piece::new(PieceType::Bishop, Color::Black));
        board[62] = Some(Piece::new(PieceType::Knight, Color::Black));
        board[63] = Some(Piece::new(PieceType::Rook, Color::Black));

        let mut state = Self {
            board,
            turn: Color::White,
            castling_rights: CastlingRights::new(),
            en_passant_target: None,
            halfmove_clock: 0,
            fullmove_number: 1,
            move_history: Vec::new(),
            hash: 0,
        };
        
        // Compute initial hash using zobrist module
        // This will be set by the Board when it initializes
        state
    }
}

pub const FILES: [char; 8] = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
pub const RANKS: [char; 8] = ['1', '2', '3', '4', '5', '6', '7', '8'];

pub fn square_to_algebraic(square: Square) -> String {
    let file = square % 8;
    let rank = square / 8;
    format!("{}{}", FILES[file], RANKS[rank])
}

pub fn algebraic_to_square(algebraic: &str) -> Result<Square, String> {
    if algebraic.len() != 2 {
        return Err("Invalid algebraic notation".to_string());
    }
    
    let chars: Vec<char> = algebraic.chars().collect();
    let file = FILES.iter().position(|&f| f == chars[0])
        .ok_or("Invalid file")?;
    let rank = RANKS.iter().position(|&r| r == chars[1])
        .ok_or("Invalid rank")?;
    
    Ok(rank * 8 + file)
}