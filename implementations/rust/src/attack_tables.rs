#![allow(dead_code)]

use crate::types::Square;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct AttackTableEntry {
    squares: [Square; 8],
    len: usize,
}

impl AttackTableEntry {
    pub const EMPTY: Self = Self {
        squares: [0; 8],
        len: 0,
    };

    pub fn as_slice(&self) -> &[Square] {
        &self.squares[..self.len]
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct RayTableEntry {
    squares: [Square; 7],
    len: usize,
}

impl RayTableEntry {
    pub const EMPTY: Self = Self {
        squares: [0; 7],
        len: 0,
    };

    pub fn as_slice(&self) -> &[Square] {
        &self.squares[..self.len]
    }
}

const KNIGHT_DELTAS: [(i8, i8); 8] = [
    (-1, -2),
    (1, -2),
    (-2, -1),
    (2, -1),
    (-2, 1),
    (2, 1),
    (-1, 2),
    (1, 2),
];

const KING_DELTAS: [(i8, i8); 8] = [
    (-1, -1),
    (0, -1),
    (1, -1),
    (-1, 0),
    (1, 0),
    (-1, 1),
    (0, 1),
    (1, 1),
];

const SOUTHWEST_DELTA: (i8, i8) = (-1, -1);
const SOUTH_DELTA: (i8, i8) = (0, -1);
const SOUTHEAST_DELTA: (i8, i8) = (1, -1);
const WEST_DELTA: (i8, i8) = (-1, 0);
const EAST_DELTA: (i8, i8) = (1, 0);
const NORTHWEST_DELTA: (i8, i8) = (-1, 1);
const NORTH_DELTA: (i8, i8) = (0, 1);
const NORTHEAST_DELTA: (i8, i8) = (1, 1);

pub const KNIGHT_ATTACKS: [AttackTableEntry; 64] = build_attack_table(&KNIGHT_DELTAS);
pub const KING_ATTACKS: [AttackTableEntry; 64] = build_attack_table(&KING_DELTAS);

pub const SOUTHWEST_RAYS: [RayTableEntry; 64] = build_ray_table(SOUTHWEST_DELTA);
pub const SOUTH_RAYS: [RayTableEntry; 64] = build_ray_table(SOUTH_DELTA);
pub const SOUTHEAST_RAYS: [RayTableEntry; 64] = build_ray_table(SOUTHEAST_DELTA);
pub const WEST_RAYS: [RayTableEntry; 64] = build_ray_table(WEST_DELTA);
pub const EAST_RAYS: [RayTableEntry; 64] = build_ray_table(EAST_DELTA);
pub const NORTHWEST_RAYS: [RayTableEntry; 64] = build_ray_table(NORTHWEST_DELTA);
pub const NORTH_RAYS: [RayTableEntry; 64] = build_ray_table(NORTH_DELTA);
pub const NORTHEAST_RAYS: [RayTableEntry; 64] = build_ray_table(NORTHEAST_DELTA);

pub const CHEBYSHEV_DISTANCE: [[u8; 64]; 64] = build_distance_table(DistanceMetric::Chebyshev);
pub const MANHATTAN_DISTANCE: [[u8; 64]; 64] = build_distance_table(DistanceMetric::Manhattan);

#[derive(Clone, Copy)]
enum DistanceMetric {
    Chebyshev,
    Manhattan,
}

pub fn ray_table(direction: i32) -> &'static [RayTableEntry; 64] {
    match direction {
        -9 => &SOUTHWEST_RAYS,
        -8 => &SOUTH_RAYS,
        -7 => &SOUTHEAST_RAYS,
        -1 => &WEST_RAYS,
        1 => &EAST_RAYS,
        7 => &NORTHWEST_RAYS,
        8 => &NORTH_RAYS,
        9 => &NORTHEAST_RAYS,
        _ => panic!("unsupported ray direction: {direction}"),
    }
}

pub fn chebyshev_distance(from: Square, to: Square) -> u8 {
    CHEBYSHEV_DISTANCE[from][to]
}

pub fn manhattan_distance(from: Square, to: Square) -> u8 {
    MANHATTAN_DISTANCE[from][to]
}

const fn build_attack_table(deltas: &[(i8, i8); 8]) -> [AttackTableEntry; 64] {
    let mut table = [AttackTableEntry::EMPTY; 64];
    let mut square = 0;
    while square < 64 {
        table[square] = build_attack_entry(square, deltas);
        square += 1;
    }
    table
}

const fn build_attack_entry(square: Square, deltas: &[(i8, i8); 8]) -> AttackTableEntry {
    let file = (square % 8) as i32;
    let rank = (square / 8) as i32;
    let mut entry = AttackTableEntry::EMPTY;
    let mut index = 0;

    while index < deltas.len() {
        let target_file = file + deltas[index].0 as i32;
        let target_rank = rank + deltas[index].1 as i32;
        if target_file >= 0 && target_file < 8 && target_rank >= 0 && target_rank < 8 {
            entry.squares[entry.len] = (target_rank * 8 + target_file) as Square;
            entry.len += 1;
        }
        index += 1;
    }

    entry
}

const fn build_ray_table(delta: (i8, i8)) -> [RayTableEntry; 64] {
    let mut table = [RayTableEntry::EMPTY; 64];
    let mut square = 0;
    while square < 64 {
        table[square] = build_ray_entry(square, delta);
        square += 1;
    }
    table
}

const fn build_ray_entry(square: Square, delta: (i8, i8)) -> RayTableEntry {
    let mut entry = RayTableEntry::EMPTY;
    let mut file = (square % 8) as i32 + delta.0 as i32;
    let mut rank = (square / 8) as i32 + delta.1 as i32;

    while file >= 0 && file < 8 && rank >= 0 && rank < 8 {
        entry.squares[entry.len] = (rank * 8 + file) as Square;
        entry.len += 1;
        file += delta.0 as i32;
        rank += delta.1 as i32;
    }

    entry
}

const fn build_distance_table(metric: DistanceMetric) -> [[u8; 64]; 64] {
    let mut table = [[0; 64]; 64];
    let mut from = 0;

    while from < 64 {
        let from_file = (from % 8) as i32;
        let from_rank = (from / 8) as i32;
        let mut to = 0;

        while to < 64 {
            let file_distance = abs_i32(from_file - (to % 8) as i32) as u8;
            let rank_distance = abs_i32(from_rank - (to / 8) as i32) as u8;
            table[from][to] = match metric {
                DistanceMetric::Chebyshev => max_u8(file_distance, rank_distance),
                DistanceMetric::Manhattan => file_distance + rank_distance,
            };
            to += 1;
        }

        from += 1;
    }

    table
}

const fn abs_i32(value: i32) -> i32 {
    if value < 0 {
        -value
    } else {
        value
    }
}

const fn max_u8(left: u8, right: u8) -> u8 {
    if left > right {
        left
    } else {
        right
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn collect(entry: &AttackTableEntry) -> Vec<Square> {
        entry.as_slice().to_vec()
    }

    fn collect_ray(entry: &RayTableEntry) -> Vec<Square> {
        entry.as_slice().to_vec()
    }

    #[test]
    fn knight_attacks_match_corner_and_center_expectations() {
        assert_eq!(collect(&KNIGHT_ATTACKS[0]), vec![10, 17]);
        assert_eq!(
            collect(&KNIGHT_ATTACKS[27]),
            vec![10, 12, 17, 21, 33, 37, 42, 44]
        );
    }

    #[test]
    fn king_attacks_match_corner_and_center_expectations() {
        assert_eq!(collect(&KING_ATTACKS[0]), vec![1, 8, 9]);
        assert_eq!(
            collect(&KING_ATTACKS[27]),
            vec![18, 19, 20, 26, 28, 34, 35, 36]
        );
    }

    #[test]
    fn ray_tables_match_expected_paths() {
        assert_eq!(collect_ray(&NORTH_RAYS[0]), vec![8, 16, 24, 32, 40, 48, 56]);
        assert_eq!(collect_ray(&NORTHEAST_RAYS[27]), vec![36, 45, 54, 63]);
        assert_eq!(collect_ray(&SOUTHWEST_RAYS[27]), vec![18, 9, 0]);
    }

    #[test]
    fn distance_tables_match_expected_values() {
        assert_eq!(chebyshev_distance(0, 63), 7);
        assert_eq!(manhattan_distance(0, 63), 14);
        assert_eq!(chebyshev_distance(27, 36), 1);
        assert_eq!(manhattan_distance(27, 36), 2);
    }
}
