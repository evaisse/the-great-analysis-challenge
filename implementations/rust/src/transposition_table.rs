// Transposition Table for storing evaluated positions
// Implements probe/store operations with replacement policy

use crate::types::*;
use crate::zobrist::ZobristKey;

/// Bound type for transposition table entries
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BoundType {
    /// Exact score (no alpha-beta cutoff)
    Exact,
    /// Lower bound (beta cutoff / fail-high)
    /// Actual score is >= stored score
    LowerBound,
    /// Upper bound (alpha cutoff / fail-low)
    /// Actual score is <= stored score
    UpperBound,
}

/// Entry in the transposition table
#[derive(Debug, Clone, Copy)]
pub struct TTEntry {
    /// Zobrist hash key
    pub key: ZobristKey,
    /// Depth of search when this entry was stored
    pub depth: u8,
    /// Evaluated score
    pub score: i32,
    /// Type of bound
    pub bound: BoundType,
    /// Best move found at this position (encoded as from | to << 6)
    pub best_move: Option<u16>,
    /// Age/generation for replacement policy
    pub age: u8,
}

impl TTEntry {
    /// Create an empty entry
    fn empty() -> Self {
        TTEntry {
            key: 0,
            depth: 0,
            score: 0,
            bound: BoundType::Exact,
            best_move: None,
            age: 0,
        }
    }

    /// Check if this entry is valid (non-zero key)
    fn is_valid(&self) -> bool {
        self.key != 0
    }
}

/// Transposition Table
pub struct TranspositionTable {
    /// Table entries (size is always a power of 2 for fast modulo)
    entries: Vec<TTEntry>,
    /// Current age/generation
    age: u8,
    /// Number of entries
    size: usize,
}

impl TranspositionTable {
    /// Create a new transposition table with given size in MB
    /// Default size is 16 MB (~500K entries at 32 bytes per entry)
    pub fn new(size_mb: usize) -> Self {
        let bytes = size_mb * 1024 * 1024;
        let entry_size = std::mem::size_of::<TTEntry>();
        let mut num_entries = bytes / entry_size;

        // Round to next power of 2 for fast modulo
        num_entries = num_entries.next_power_of_two();

        TranspositionTable {
            entries: vec![TTEntry::empty(); num_entries],
            age: 0,
            size: num_entries,
        }
    }

    /// Get index for a hash key
    fn index(&self, key: ZobristKey) -> usize {
        (key as usize) & (self.size - 1)
    }

    /// Probe the table for an entry
    /// Returns Some(entry) if found, None otherwise
    pub fn probe(&self, key: ZobristKey) -> Option<&TTEntry> {
        let idx = self.index(key);
        let entry = &self.entries[idx];

        if entry.is_valid() && entry.key == key {
            Some(entry)
        } else {
            None
        }
    }

    /// Store an entry in the table
    /// Uses a replacement policy: prefer recent age and greater depth
    pub fn store(
        &mut self,
        key: ZobristKey,
        depth: u8,
        score: i32,
        bound: BoundType,
        best_move: Option<u16>,
    ) {
        let idx = self.index(key);
        let old_entry = &self.entries[idx];

        // Replacement policy
        let should_replace = !old_entry.is_valid()
            || old_entry.age != self.age
            || depth >= old_entry.depth;

        if should_replace {
            self.entries[idx] = TTEntry {
                key,
                depth,
                score,
                bound,
                best_move,
                age: self.age,
            };
        }
    }

    /// Clear the table
    pub fn clear(&mut self) {
        self.entries.fill(TTEntry::empty());
    }

    /// Increment the age/generation
    pub fn new_search(&mut self) {
        self.age = self.age.wrapping_add(1);
    }

    /// Get the fill percentage (0-100)
    pub fn fill_percentage(&self) -> f32 {
        let filled = self
            .entries
            .iter()
            .filter(|e| e.is_valid() && e.age == self.age)
            .count();
        (filled as f32 / self.size as f32) * 100.0
    }

    /// Get table size in entries
    pub fn size(&self) -> usize {
        self.size
    }
}

impl Default for TranspositionTable {
    fn default() -> Self {
        Self::new(16) // 16 MB default
    }
}

/// Encode a move as a u16 (from | to << 6)
pub fn encode_move(from: Square, to: Square) -> u16 {
    (from as u16) | ((to as u16) << 6)
}

/// Decode a move from u16
pub fn decode_move(encoded: u16) -> (Square, Square) {
    let from = (encoded & 0x3F) as Square;
    let to = ((encoded >> 6) & 0x3F) as Square;
    (from, to)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tt_creation() {
        let tt = TranspositionTable::new(16);
        assert!(tt.size() > 0);
        assert_eq!(tt.fill_percentage(), 0.0);
    }

    #[test]
    fn test_tt_store_and_probe() {
        let mut tt = TranspositionTable::new(16);
        let key = 0x123456789ABCDEF0;

        // Store an entry
        tt.store(key, 5, 100, BoundType::Exact, Some(encode_move(12, 28)));

        // Probe should find it
        let entry = tt.probe(key);
        assert!(entry.is_some());

        let entry = entry.unwrap();
        assert_eq!(entry.key, key);
        assert_eq!(entry.depth, 5);
        assert_eq!(entry.score, 100);
        assert_eq!(entry.bound, BoundType::Exact);
    }

    #[test]
    fn test_tt_replacement_policy() {
        let mut tt = TranspositionTable::new(1); // Very small table
        let key1 = 0x1000;
        let key2 = 0x2000 | (tt.size() as u64); // Collides with key1

        // Store first entry
        tt.store(key1, 5, 100, BoundType::Exact, None);
        assert!(tt.probe(key1).is_some());

        // Store second entry with higher depth (should replace)
        tt.store(key2, 10, 200, BoundType::Exact, None);
        assert!(tt.probe(key2).is_some());
        assert!(tt.probe(key1).is_none()); // First entry replaced
    }

    #[test]
    fn test_move_encoding() {
        let from = 12;
        let to = 28;
        let encoded = encode_move(from, to);
        let (decoded_from, decoded_to) = decode_move(encoded);
        assert_eq!(from, decoded_from);
        assert_eq!(to, decoded_to);
    }

    #[test]
    fn test_tt_clear() {
        let mut tt = TranspositionTable::new(16);
        tt.store(0x1234, 5, 100, BoundType::Exact, None);
        assert!(tt.probe(0x1234).is_some());

        tt.clear();
        assert!(tt.probe(0x1234).is_none());
    }

    #[test]
    fn test_tt_age_increment() {
        let mut tt = TranspositionTable::new(16);
        let initial_age = tt.age;
        tt.new_search();
        assert_eq!(tt.age, initial_age.wrapping_add(1));
    }
}
