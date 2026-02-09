<?php

/**
 * Global constants for chess engine
 * These are defined in the global namespace so they can be used everywhere
 */

/**
 * Piece types
 */
define('CHESS_EMPTY', 0);
define('CHESS_PAWN', 1);
define('CHESS_KNIGHT', 2);
define('CHESS_BISHOP', 3);
define('CHESS_ROOK', 4);
define('CHESS_QUEEN', 5);
define('CHESS_KING', 6);

/**
 * Colors
 */
define('CHESS_WHITE', 0);
define('CHESS_BLACK', 1);

/**
 * Piece values for evaluation
 */
define('CHESS_PIECE_VALUES', [
    CHESS_EMPTY => 0,
    CHESS_PAWN => 100,
    CHESS_KNIGHT => 320,
    CHESS_BISHOP => 330,
    CHESS_ROOK => 500,
    CHESS_QUEEN => 900,
    CHESS_KING => 20000,
]);
