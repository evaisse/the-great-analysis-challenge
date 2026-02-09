// Time Management for chess search
// Controls search duration based on different time control modes

use std::time::{Duration, Instant};

/// Time control mode
#[derive(Debug, Clone)]
pub enum TimeControl {
    /// Fixed depth search (no time limit)
    Depth(u8),
    /// Fixed time per move in milliseconds
    MoveTime(u64),
    /// Time remaining + increment (wtime, btime, winc, binc)
    TimeIncrement {
        white_time: u64,
        black_time: u64,
        white_inc: u64,
        black_inc: u64,
    },
    /// Infinite search (no limit)
    Infinite,
}

/// Time manager for controlling search duration
pub struct TimeManager {
    /// Time control mode
    time_control: TimeControl,
    /// Start time of the search
    start_time: Instant,
    /// Allocated time for this move in milliseconds
    allocated_time: Option<u64>,
    /// Maximum time for this move (hard limit)
    max_time: Option<u64>,
    /// Number of moves played
    move_number: usize,
    /// Whether we're playing as white
    is_white: bool,
    /// Last best score
    last_score: Option<i32>,
    /// Last best move (encoded)
    last_best_move: Option<u16>,
    /// Number of times the best move changed
    best_move_changes: usize,
}

impl TimeManager {
    /// Create a new time manager
    pub fn new(time_control: TimeControl, move_number: usize, is_white: bool) -> Self {
        let (allocated_time, max_time) = match &time_control {
            TimeControl::Depth(_) => (None, None),
            TimeControl::MoveTime(ms) => (Some(*ms), Some(*ms)),
            TimeControl::TimeIncrement {
                white_time,
                black_time,
                white_inc,
                black_inc,
            } => {
                let (remaining, increment) = if is_white {
                    (*white_time, *white_inc)
                } else {
                    (*black_time, *black_inc)
                };
                let (alloc, max) = Self::allocate_time(remaining, increment, move_number);
                (Some(alloc), Some(max))
            }
            TimeControl::Infinite => (None, None),
        };

        TimeManager {
            time_control,
            start_time: Instant::now(),
            allocated_time,
            max_time,
            move_number,
            is_white,
            last_score: None,
            last_best_move: None,
            best_move_changes: 0,
        }
    }

    /// Allocate time for this move
    /// Returns (base_time, max_time) in milliseconds
    fn allocate_time(remaining_ms: u64, increment_ms: u64, move_number: usize) -> (u64, u64) {
        // Estimate number of moves remaining
        let estimated_moves = if move_number < 20 {
            30
        } else {
            std::cmp::max(20, 50 - move_number)
        };

        // Base time allocation
        let mut base_time = (remaining_ms / estimated_moves as u64) + increment_ms;

        // Don't use more than 50% of remaining time
        let max_time = remaining_ms / 2;

        base_time = std::cmp::min(base_time, max_time);

        // Absolute maximum is 80% of remaining time (emergency situations)
        let absolute_max = (remaining_ms * 80) / 100;

        (base_time, absolute_max)
    }

    /// Check if we should stop searching
    pub fn should_stop(&self) -> bool {
        match self.max_time {
            Some(max_ms) => {
                let elapsed = self.start_time.elapsed().as_millis() as u64;
                elapsed >= max_ms
            }
            None => false,
        }
    }

    /// Check if we should continue to next depth
    pub fn should_continue_iteration(&self, current_depth: u8) -> bool {
        // Check depth limit
        if let TimeControl::Depth(max_depth) = self.time_control {
            if current_depth >= max_depth {
                return false;
            }
        }

        // Check time limit
        if let Some(alloc_ms) = self.allocated_time {
            let elapsed = self.start_time.elapsed().as_millis() as u64;

            // Don't start next iteration if we've used most of our time
            // Heuristic: assume next iteration takes ~3x the time of all previous iterations
            if elapsed * 4 >= alloc_ms {
                return false;
            }

            // Adjust for instability
            let mut threshold = alloc_ms;

            // If score is unstable, use more time
            if self.best_move_changes > 2 {
                threshold = (threshold * 13) / 10; // +30%
            }

            if elapsed >= threshold {
                return false;
            }
        }

        true
    }

    /// Report iteration results for adaptive time management
    pub fn report_iteration(&mut self, _depth: u8, score: i32, best_move: Option<u16>) {
        // Track score instability
        if let Some(last_score) = self.last_score {
            let score_diff = (score - last_score).abs();
            // Significant score change (>50 centipawns)
            if score_diff > 50 {
                self.best_move_changes += 1;
            }
        }
        self.last_score = Some(score);

        // Track best move changes
        if let Some(last_move) = self.last_best_move {
            if let Some(current_move) = best_move {
                if last_move != current_move {
                    self.best_move_changes += 1;
                }
            }
        }
        self.last_best_move = best_move;
    }

    /// Get elapsed time in milliseconds
    pub fn elapsed_ms(&self) -> u64 {
        self.start_time.elapsed().as_millis() as u64
    }

    /// Get allocated time in milliseconds (if any)
    pub fn allocated_time_ms(&self) -> Option<u64> {
        self.allocated_time
    }

    /// Check if search was interrupted by time
    pub fn search_was_interrupted(&self) -> bool {
        self.should_stop()
    }
}

impl Default for TimeManager {
    fn default() -> Self {
        Self::new(TimeControl::Infinite, 1, true)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::thread;

    #[test]
    fn test_time_allocation() {
        let (base, max) = TimeManager::allocate_time(60000, 1000, 10);
        // With 60s remaining and 1s increment at move 10
        // Estimated moves: 30
        // Base: 60000/30 + 1000 = 3000ms
        // Max: 60000/2 = 30000ms
        assert!(base >= 2000 && base <= 4000);
        assert_eq!(max, 30000);
    }

    #[test]
    fn test_move_time_control() {
        let tm = TimeManager::new(TimeControl::MoveTime(1000), 10, true);
        assert_eq!(tm.allocated_time_ms(), Some(1000));
        assert!(!tm.should_stop()); // Just started
    }

    #[test]
    fn test_depth_control() {
        let tm = TimeManager::new(TimeControl::Depth(5), 10, true);
        assert_eq!(tm.allocated_time_ms(), None);
        assert!(!tm.should_stop()); // No time limit
        assert!(tm.should_continue_iteration(3));
        assert!(!tm.should_continue_iteration(5));
    }

    #[test]
    fn test_infinite_control() {
        let tm = TimeManager::new(TimeControl::Infinite, 10, true);
        assert_eq!(tm.allocated_time_ms(), None);
        assert!(!tm.should_stop());
        assert!(tm.should_continue_iteration(10));
    }

    #[test]
    fn test_should_stop_after_time() {
        let tm = TimeManager::new(TimeControl::MoveTime(10), 10, true);
        assert!(!tm.should_stop());
        thread::sleep(Duration::from_millis(15));
        assert!(tm.should_stop());
    }

    #[test]
    fn test_best_move_tracking() {
        let mut tm = TimeManager::new(TimeControl::MoveTime(5000), 10, true);

        tm.report_iteration(1, 100, Some(0x1234));
        assert_eq!(tm.best_move_changes, 0);

        // Same move, different score - should not increment
        tm.report_iteration(2, 150, Some(0x1234));
        assert_eq!(tm.best_move_changes, 0);

        // Different move - should increment
        tm.report_iteration(3, 120, Some(0x5678));
        assert_eq!(tm.best_move_changes, 1);
    }

    #[test]
    fn test_score_instability() {
        let mut tm = TimeManager::new(TimeControl::MoveTime(5000), 10, true);

        tm.report_iteration(1, 100, Some(0x1234));
        assert_eq!(tm.best_move_changes, 0);

        // Large score change (>50 cp) - should increment
        tm.report_iteration(2, 200, Some(0x1234));
        assert_eq!(tm.best_move_changes, 1);
    }
}
