/**
 * @typedef {'w' | 'b'} Color
 */

/**
 * @typedef {'p' | 'n' | 'b' | 'r' | 'q' | 'k'} PieceType
 */

/**
 * @typedef {Object} Piece
 * @property {Color} color
 * @property {PieceType} type
 */

/**
 * @typedef {Object} Move
 * @property {number} from
 * @property {number} to
 * @property {PieceType} [promotion]
 */

/**
 * @typedef {Object} GameState
 * @property {(Piece|null)[]} board
 * @property {Color} turn
 * @property {Object} castling
 * @property {boolean} castling.wK
 * @property {boolean} castling.wQ
 * @property {boolean} castling.bK
 * @property {boolean} castling.bQ
 * @property {number|null} enPassant
 * @property {number} halfmoveClock
 * @property {number} fullmoveNumber
 */

export {};
