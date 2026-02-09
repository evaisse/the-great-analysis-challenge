"""
Pre-calculated attack tables for chess pieces.

This module generates and stores attack patterns for knights, kings,
sliding pieces (rays), and distance tables at module initialization.

Coordinate system: (row, col) where:
- row 0 = rank 1 (white's first rank)
- col 0 = a-file
"""

from typing import Final, Tuple, List


def _square_to_index(row: int, col: int) -> int:
    """Convert (row, col) to square index (0-63)."""
    return row * 8 + col


def _index_to_square(index: int) -> Tuple[int, int]:
    """Convert square index to (row, col)."""
    return (index // 8, index % 8)


def _is_valid_square(row: int, col: int) -> bool:
    """Check if a square is on the board."""
    return 0 <= row < 8 and 0 <= col < 8


def _generate_knight_attacks() -> Tuple[Tuple[Tuple[int, int], ...], ...]:
    """Generate knight attack tables for all 64 squares."""
    knight_offsets = [
        (-2, -1), (-2, 1), (-1, -2), (-1, 2),
        (1, -2), (1, 2), (2, -1), (2, 1)
    ]
    
    attacks = []
    for square in range(64):
        row, col = _index_to_square(square)
        attacked_squares = []
        
        for dr, dc in knight_offsets:
            new_row, new_col = row + dr, col + dc
            if _is_valid_square(new_row, new_col):
                attacked_squares.append((new_row, new_col))
        
        attacks.append(tuple(attacked_squares))
    
    return tuple(attacks)


def _generate_king_attacks() -> Tuple[Tuple[Tuple[int, int], ...], ...]:
    """Generate king attack tables for all 64 squares."""
    king_offsets = [
        (-1, -1), (-1, 0), (-1, 1),
        (0, -1),           (0, 1),
        (1, -1),  (1, 0),  (1, 1)
    ]
    
    attacks = []
    for square in range(64):
        row, col = _index_to_square(square)
        attacked_squares = []
        
        for dr, dc in king_offsets:
            new_row, new_col = row + dr, col + dc
            if _is_valid_square(new_row, new_col):
                attacked_squares.append((new_row, new_col))
        
        attacks.append(tuple(attacked_squares))
    
    return tuple(attacks)


def _generate_ray_tables() -> Tuple[Tuple[Tuple[Tuple[int, int], ...], ...], ...]:
    """
    Generate ray tables for sliding pieces.
    
    Returns a tuple of 8 direction tables, each containing 64 entries.
    Directions: N, NE, E, SE, S, SW, W, NW
    """
    directions = [
        (-1, 0),   # North
        (-1, 1),   # North-East
        (0, 1),    # East
        (1, 1),    # South-East
        (1, 0),    # South
        (1, -1),   # South-West
        (0, -1),   # West
        (-1, -1)   # North-West
    ]
    
    ray_tables = []
    for dr, dc in directions:
        direction_rays = []
        
        for square in range(64):
            row, col = _index_to_square(square)
            ray = []
            
            current_row, current_col = row + dr, col + dc
            while _is_valid_square(current_row, current_col):
                ray.append((current_row, current_col))
                current_row += dr
                current_col += dc
            
            direction_rays.append(tuple(ray))
        
        ray_tables.append(tuple(direction_rays))
    
    return tuple(ray_tables)


def _generate_distance_tables() -> Tuple[Tuple[Tuple[int, ...], ...], Tuple[Tuple[int, ...], ...]]:
    """
    Generate Chebyshev and Manhattan distance tables.
    
    Returns: (chebyshev_table, manhattan_table)
    Each table is 64x64 entries.
    """
    chebyshev = []
    manhattan = []
    
    for from_square in range(64):
        from_row, from_col = _index_to_square(from_square)
        cheb_row = []
        manh_row = []
        
        for to_square in range(64):
            to_row, to_col = _index_to_square(to_square)
            
            # Chebyshev distance (max of row/col difference)
            cheb_dist = max(abs(to_row - from_row), abs(to_col - from_col))
            cheb_row.append(cheb_dist)
            
            # Manhattan distance (sum of row/col difference)
            manh_dist = abs(to_row - from_row) + abs(to_col - from_col)
            manh_row.append(manh_dist)
        
        chebyshev.append(tuple(cheb_row))
        manhattan.append(tuple(manh_row))
    
    return tuple(chebyshev), tuple(manhattan)


# Pre-calculated attack tables (generated at module initialization)
KNIGHT_ATTACKS: Final[Tuple[Tuple[Tuple[int, int], ...], ...]] = _generate_knight_attacks()
KING_ATTACKS: Final[Tuple[Tuple[Tuple[int, int], ...], ...]] = _generate_king_attacks()
RAY_TABLES: Final[Tuple[Tuple[Tuple[Tuple[int, int], ...], ...], ...]] = _generate_ray_tables()

# Distance tables
_distances = _generate_distance_tables()
CHEBYSHEV_DISTANCE: Final[Tuple[Tuple[int, ...], ...]] = _distances[0]
MANHATTAN_DISTANCE: Final[Tuple[Tuple[int, ...], ...]] = _distances[1]


# Direction indices for RAY_TABLES
NORTH: Final[int] = 0
NORTH_EAST: Final[int] = 1
EAST: Final[int] = 2
SOUTH_EAST: Final[int] = 3
SOUTH: Final[int] = 4
SOUTH_WEST: Final[int] = 5
WEST: Final[int] = 6
NORTH_WEST: Final[int] = 7


def get_knight_attacks(row: int, col: int) -> Tuple[Tuple[int, int], ...]:
    """Get all squares attacked by a knight at (row, col)."""
    square = _square_to_index(row, col)
    return KNIGHT_ATTACKS[square]


def get_king_attacks(row: int, col: int) -> Tuple[Tuple[int, int], ...]:
    """Get all squares attacked by a king at (row, col)."""
    square = _square_to_index(row, col)
    return KING_ATTACKS[square]


def get_ray(row: int, col: int, direction: int) -> Tuple[Tuple[int, int], ...]:
    """Get ray from (row, col) in given direction."""
    square = _square_to_index(row, col)
    return RAY_TABLES[direction][square]


def get_chebyshev_distance(from_row: int, from_col: int, to_row: int, to_col: int) -> int:
    """Get Chebyshev distance between two squares."""
    from_square = _square_to_index(from_row, from_col)
    to_square = _square_to_index(to_row, to_col)
    return CHEBYSHEV_DISTANCE[from_square][to_square]


def get_manhattan_distance(from_row: int, from_col: int, to_row: int, to_col: int) -> int:
    """Get Manhattan distance between two squares."""
    from_square = _square_to_index(from_row, from_col)
    to_square = _square_to_index(to_row, to_col)
    return MANHATTAN_DISTANCE[from_square][to_square]
