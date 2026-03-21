"""Precomputed attack and distance lookup tables."""

from typing import Callable

BOARD_SIZE = 8

KNIGHT_DELTAS = (
    (-2, -1), (-2, 1), (-1, -2), (-1, 2),
    (1, -2), (1, 2), (2, -1), (2, 1),
)

KING_DELTAS = (
    (-1, -1), (-1, 0), (-1, 1),
    (0, -1),           (0, 1),
    (1, -1),  (1, 0),  (1, 1),
)

RAY_DELTAS = {
    (-1, -1): "southwest",
    (0, -1): "south",
    (1, -1): "southeast",
    (-1, 0): "west",
    (1, 0): "east",
    (-1, 1): "northwest",
    (0, 1): "north",
    (1, 1): "northeast",
}


def _build_attack_table(deltas: tuple[tuple[int, int], ...]) -> list[list[list[tuple[int, int]]]]:
    table = [[[] for _ in range(BOARD_SIZE)] for _ in range(BOARD_SIZE)]
    for row in range(BOARD_SIZE):
        for col in range(BOARD_SIZE):
            attacks = []
            for drow, dcol in deltas:
                new_row = row + drow
                new_col = col + dcol
                if 0 <= new_row < BOARD_SIZE and 0 <= new_col < BOARD_SIZE:
                    attacks.append((new_row, new_col))
            table[row][col] = attacks
    return table


def _build_ray_table(drow: int, dcol: int) -> list[list[list[tuple[int, int]]]]:
    table = [[[] for _ in range(BOARD_SIZE)] for _ in range(BOARD_SIZE)]
    for row in range(BOARD_SIZE):
        for col in range(BOARD_SIZE):
            ray = []
            new_row = row + drow
            new_col = col + dcol
            while 0 <= new_row < BOARD_SIZE and 0 <= new_col < BOARD_SIZE:
                ray.append((new_row, new_col))
                new_row += drow
                new_col += dcol
            table[row][col] = ray
    return table


def _build_distance_table(metric: Callable[[int, int], int]) -> list[list[int]]:
    table = [[0 for _ in range(64)] for _ in range(64)]
    for from_index in range(64):
        from_row, from_col = divmod(from_index, BOARD_SIZE)
        for to_index in range(64):
            to_row, to_col = divmod(to_index, BOARD_SIZE)
            row_distance = abs(from_row - to_row)
            col_distance = abs(from_col - to_col)
            table[from_index][to_index] = metric(row_distance, col_distance)
    return table


KNIGHT_ATTACKS = _build_attack_table(KNIGHT_DELTAS)
KING_ATTACKS = _build_attack_table(KING_DELTAS)
RAY_TABLES = {delta: _build_ray_table(*delta) for delta in RAY_DELTAS}
CHEBYSHEV_DISTANCE = _build_distance_table(max)
MANHATTAN_DISTANCE = _build_distance_table(lambda row_distance, col_distance: row_distance + col_distance)


def square_index(row: int, col: int) -> int:
    return row * BOARD_SIZE + col


def knight_attacks(row: int, col: int) -> list[tuple[int, int]]:
    return KNIGHT_ATTACKS[row][col]


def king_attacks(row: int, col: int) -> list[tuple[int, int]]:
    return KING_ATTACKS[row][col]


def ray_attacks(row: int, col: int, drow: int, dcol: int) -> list[tuple[int, int]]:
    return RAY_TABLES[(drow, dcol)][row][col]


def chebyshev_distance(from_square: tuple[int, int], to_square: tuple[int, int]) -> int:
    return CHEBYSHEV_DISTANCE[square_index(*from_square)][square_index(*to_square)]


def manhattan_distance(from_square: tuple[int, int], to_square: tuple[int, int]) -> int:
    return MANHATTAN_DISTANCE[square_index(*from_square)][square_index(*to_square)]
