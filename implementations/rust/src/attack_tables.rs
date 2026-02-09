/// Pre-calculated attack tables for chess pieces
/// This module contains lookup tables for knight attacks, king attacks,
/// ray tables for sliding pieces, and distance tables.

use crate::types::Square;

/// Knight attack offsets: L-shaped moves
const KNIGHT_OFFSETS: [(i32, i32); 8] = [
    (-2, -1), (-2, 1), (-1, -2), (-1, 2),
    (1, -2), (1, 2), (2, -1), (2, 1),
];

/// King attack offsets: all adjacent squares
const KING_OFFSETS: [(i32, i32); 8] = [
    (-1, -1), (-1, 0), (-1, 1),
    (0, -1),           (0, 1),
    (1, -1),  (1, 0),  (1, 1),
];

/// Direction vectors for ray generation
#[derive(Debug, Clone, Copy)]
pub enum Direction {
    North,
    South,
    East,
    West,
    NorthEast,
    NorthWest,
    SouthEast,
    SouthWest,
}

impl Direction {
    fn offset(&self) -> (i32, i32) {
        match self {
            Direction::North => (1, 0),
            Direction::South => (-1, 0),
            Direction::East => (0, 1),
            Direction::West => (0, -1),
            Direction::NorthEast => (1, 1),
            Direction::NorthWest => (1, -1),
            Direction::SouthEast => (-1, 1),
            Direction::SouthWest => (-1, -1),
        }
    }

    pub fn all() -> [Direction; 8] {
        [
            Direction::North,
            Direction::South,
            Direction::East,
            Direction::West,
            Direction::NorthEast,
            Direction::NorthWest,
            Direction::SouthEast,
            Direction::SouthWest,
        ]
    }
}

/// Convert (row, col) to square index
fn square_to_index(row: i32, col: i32) -> Option<Square> {
    if row >= 0 && row < 8 && col >= 0 && col < 8 {
        Some((row * 8 + col) as Square)
    } else {
        None
    }
}

/// Convert square index to (row, col)
fn index_to_square(square: Square) -> (i32, i32) {
    let row = (square / 8) as i32;
    let col = (square % 8) as i32;
    (row, col)
}

/// Generate knight attacks for a given square
fn generate_knight_attacks(square: Square) -> Vec<Square> {
    let (row, col) = index_to_square(square);
    let mut attacks = Vec::new();

    for (dr, dc) in KNIGHT_OFFSETS {
        if let Some(target) = square_to_index(row + dr, col + dc) {
            attacks.push(target);
        }
    }

    attacks
}

/// Generate king attacks for a given square
fn generate_king_attacks(square: Square) -> Vec<Square> {
    let (row, col) = index_to_square(square);
    let mut attacks = Vec::new();

    for (dr, dc) in KING_OFFSETS {
        if let Some(target) = square_to_index(row + dr, col + dc) {
            attacks.push(target);
        }
    }

    attacks
}

/// Generate ray in a specific direction from a square
fn generate_ray(square: Square, direction: Direction) -> Vec<Square> {
    let (row, col) = index_to_square(square);
    let (dr, dc) = direction.offset();
    let mut ray = Vec::new();

    let mut current_row = row + dr;
    let mut current_col = col + dc;

    while let Some(target) = square_to_index(current_row, current_col) {
        ray.push(target);
        current_row += dr;
        current_col += dc;
    }

    ray
}

/// Calculate Chebyshev distance (king distance) between two squares
fn chebyshev_distance(sq1: Square, sq2: Square) -> u8 {
    let (r1, c1) = index_to_square(sq1);
    let (r2, c2) = index_to_square(sq2);
    let dr = (r1 - r2).abs();
    let dc = (c1 - c2).abs();
    dr.max(dc) as u8
}

/// Calculate Manhattan distance between two squares
fn manhattan_distance(sq1: Square, sq2: Square) -> u8 {
    let (r1, c1) = index_to_square(sq1);
    let (r2, c2) = index_to_square(sq2);
    let dr = (r1 - r2).abs();
    let dc = (c1 - c2).abs();
    (dr + dc) as u8
}

/// Pre-calculated knight attack table
pub struct KnightAttacks {
    attacks: [[Square; 8]; 64],
    counts: [usize; 64],
}

impl KnightAttacks {
    pub const fn new() -> Self {
        Self {
            attacks: [[0; 8]; 64],
            counts: [0; 64],
        }
    }

    pub fn get(&self, square: Square) -> &[Square] {
        let count = self.counts[square as usize];
        &self.attacks[square as usize][..count]
    }
}

/// Pre-calculated king attack table
pub struct KingAttacks {
    attacks: [[Square; 8]; 64],
    counts: [usize; 64],
}

impl KingAttacks {
    pub const fn new() -> Self {
        Self {
            attacks: [[0; 8]; 64],
            counts: [0; 64],
        }
    }

    pub fn get(&self, square: Square) -> &[Square] {
        let count = self.counts[square as usize];
        &self.attacks[square as usize][..count]
    }
}

/// Pre-calculated ray table
pub struct RayTable {
    rays: [[[Square; 7]; 8]; 64],
    counts: [[usize; 8]; 64],
}

impl RayTable {
    pub const fn new() -> Self {
        Self {
            rays: [[[0; 7]; 8]; 64],
            counts: [[0; 8]; 64],
        }
    }

    pub fn get(&self, square: Square, direction: Direction) -> &[Square] {
        let dir_idx = direction as usize;
        let count = self.counts[square as usize][dir_idx];
        &self.rays[square as usize][dir_idx][..count]
    }
}

/// Distance tables
pub struct DistanceTables {
    chebyshev: [[u8; 64]; 64],
    manhattan: [[u8; 64]; 64],
}

impl DistanceTables {
    pub const fn new() -> Self {
        Self {
            chebyshev: [[0; 64]; 64],
            manhattan: [[0; 64]; 64],
        }
    }

    pub fn chebyshev(&self, sq1: Square, sq2: Square) -> u8 {
        self.chebyshev[sq1 as usize][sq2 as usize]
    }

    pub fn manhattan(&self, sq1: Square, sq2: Square) -> u8 {
        self.manhattan[sq1 as usize][sq2 as usize]
    }
}

/// Global attack tables
pub struct AttackTables {
    pub knight: KnightAttacks,
    pub king: KingAttacks,
    pub rays: RayTable,
    pub distance: DistanceTables,
}

impl AttackTables {
    /// Initialize all attack tables
    pub fn new() -> Self {
        let mut tables = Self {
            knight: KnightAttacks::new(),
            king: KingAttacks::new(),
            rays: RayTable::new(),
            distance: DistanceTables::new(),
        };

        // Initialize knight attacks
        for square in 0..64 {
            let attacks = generate_knight_attacks(square);
            tables.knight.counts[square as usize] = attacks.len();
            for (i, &target) in attacks.iter().enumerate() {
                tables.knight.attacks[square as usize][i] = target;
            }
        }

        // Initialize king attacks
        for square in 0..64 {
            let attacks = generate_king_attacks(square);
            tables.king.counts[square as usize] = attacks.len();
            for (i, &target) in attacks.iter().enumerate() {
                tables.king.attacks[square as usize][i] = target;
            }
        }

        // Initialize ray tables
        for square in 0..64 {
            for (dir_idx, direction) in Direction::all().iter().enumerate() {
                let ray = generate_ray(square, *direction);
                tables.rays.counts[square as usize][dir_idx] = ray.len();
                for (i, &target) in ray.iter().enumerate() {
                    tables.rays.rays[square as usize][dir_idx][i] = target;
                }
            }
        }

        // Initialize distance tables
        for sq1 in 0..64 {
            for sq2 in 0..64 {
                tables.distance.chebyshev[sq1 as usize][sq2 as usize] =
                    chebyshev_distance(sq1, sq2);
                tables.distance.manhattan[sq1 as usize][sq2 as usize] =
                    manhattan_distance(sq1, sq2);
            }
        }

        tables
    }
}

// Lazy static initialization
use std::sync::OnceLock;

static ATTACK_TABLES: OnceLock<AttackTables> = OnceLock::new();

/// Get the global attack tables instance
pub fn get_attack_tables() -> &'static AttackTables {
    ATTACK_TABLES.get_or_init(|| AttackTables::new())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_knight_attacks_corner() {
        let tables = get_attack_tables();
        let attacks = tables.knight.get(0); // a1
        assert_eq!(attacks.len(), 2); // b3 and c2
        assert!(attacks.contains(&10)); // b3 (row 1, col 2)
        assert!(attacks.contains(&17)); // c2 (row 2, col 1)
    }

    #[test]
    fn test_knight_attacks_center() {
        let tables = get_attack_tables();
        let attacks = tables.knight.get(27); // d4
        assert_eq!(attacks.len(), 8); // All 8 knight moves from center
    }

    #[test]
    fn test_king_attacks_corner() {
        let tables = get_attack_tables();
        let attacks = tables.king.get(0); // a1
        assert_eq!(attacks.len(), 3); // b1, a2, b2
    }

    #[test]
    fn test_king_attacks_center() {
        let tables = get_attack_tables();
        let attacks = tables.king.get(27); // d4
        assert_eq!(attacks.len(), 8); // All 8 adjacent squares
    }

    #[test]
    fn test_ray_north() {
        let tables = get_attack_tables();
        let ray = tables.rays.get(0, Direction::North); // From a1 north
        assert_eq!(ray.len(), 7); // a2-a8
        assert_eq!(ray[0], 8); // a2
        assert_eq!(ray[6], 56); // a8
    }

    #[test]
    fn test_chebyshev_distance() {
        let tables = get_attack_tables();
        assert_eq!(tables.distance.chebyshev(0, 0), 0); // Same square
        assert_eq!(tables.distance.chebyshev(0, 63), 7); // a1 to h8
        assert_eq!(tables.distance.chebyshev(0, 7), 7); // a1 to h1
    }

    #[test]
    fn test_manhattan_distance() {
        let tables = get_attack_tables();
        assert_eq!(tables.distance.manhattan(0, 0), 0); // Same square
        assert_eq!(tables.distance.manhattan(0, 63), 14); // a1 to h8 (7+7)
        assert_eq!(tables.distance.manhattan(0, 7), 7); // a1 to h1
    }
}
