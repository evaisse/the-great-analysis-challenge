/// Type-safe castling rights
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CastlingRights {
    pub white_kingside: bool,
    pub white_queenside: bool,
    pub black_kingside: bool,
    pub black_queenside: bool,
}

impl CastlingRights {
    /// Create new castling rights with all rights available
    pub const fn new() -> Self {
        Self {
            white_kingside: true,
            white_queenside: true,
            black_kingside: true,
            black_queenside: true,
        }
    }

    /// Create castling rights with no rights available
    pub const fn none() -> Self {
        Self {
            white_kingside: false,
            white_queenside: false,
            black_kingside: false,
            black_queenside: false,
        }
    }

    /// Create custom castling rights
    pub const fn custom(
        white_kingside: bool,
        white_queenside: bool,
        black_kingside: bool,
        black_queenside: bool,
    ) -> Self {
        Self {
            white_kingside,
            white_queenside,
            black_kingside,
            black_queenside,
        }
    }

    /// Remove white kingside castling
    pub fn remove_white_kingside(&mut self) {
        self.white_kingside = false;
    }

    /// Remove white queenside castling
    pub fn remove_white_queenside(&mut self) {
        self.white_queenside = false;
    }

    /// Remove black kingside castling
    pub fn remove_black_kingside(&mut self) {
        self.black_kingside = false;
    }

    /// Remove black queenside castling
    pub fn remove_black_queenside(&mut self) {
        self.black_queenside = false;
    }

    /// Remove all white castling rights
    pub fn remove_white(&mut self) {
        self.white_kingside = false;
        self.white_queenside = false;
    }

    /// Remove all black castling rights
    pub fn remove_black(&mut self) {
        self.black_kingside = false;
        self.black_queenside = false;
    }
}

impl Default for CastlingRights {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new_castling_rights() {
        let rights = CastlingRights::new();
        assert!(rights.white_kingside);
        assert!(rights.white_queenside);
        assert!(rights.black_kingside);
        assert!(rights.black_queenside);
    }

    #[test]
    fn test_none_castling_rights() {
        let rights = CastlingRights::none();
        assert!(!rights.white_kingside);
        assert!(!rights.white_queenside);
        assert!(!rights.black_kingside);
        assert!(!rights.black_queenside);
    }

    #[test]
    fn test_remove_rights() {
        let mut rights = CastlingRights::new();
        rights.remove_white_kingside();
        assert!(!rights.white_kingside);
        assert!(rights.white_queenside);
    }
}
