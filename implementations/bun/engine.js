/** @import { GameState, Move, Piece, Color, PieceType } from './types.js' */

export const INITIAL_FEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

export class ChessEngine {
    constructor() {
        this.state = this.parseFen(INITIAL_FEN);
        this.history = [];
    }

    /**
     * @param {string} fen
     * @returns {GameState}
     */
    parseFen(fen) {
        const parts = fen.split(' ');
        const board = new Array(64).fill(null);
        const rows = parts[0].split('/');
        
        for (let r = 0; r < 8; r++) {
            let col = 0;
            for (const char of rows[r]) {
                if (/\d/.test(char)) {
                    col += parseInt(char);
                } else {
                    const color = char === char.toUpperCase() ? 'w' : 'b';
                    const type = char.toLowerCase();
                    board[r * 8 + col] = { color, type: /** @type {PieceType} */ (type) };
                    col++;
                }
            }
        }

        return {
            board,
            turn: /** @type {Color} */ (parts[1]),
            castling: {
                wK: parts[2].includes('K'),
                wQ: parts[2].includes('Q'),
                bK: parts[2].includes('k'),
                bQ: parts[2].includes('q'),
            },
            enPassant: parts[3] === '-' ? null : this.algebraicToIndex(parts[3]),
            halfmoveClock: parseInt(parts[4] || '0'),
            fullmoveNumber: parseInt(parts[5] || '1'),
        };
    }

    /**
     * @returns {string}
     */
    exportFen() {
        let fen = '';
        for (let r = 0; r < 8; r++) {
            let empty = 0;
            for (let c = 0; c < 8; c++) {
                const piece = this.state.board[r * 8 + c];
                if (piece) {
                    if (empty > 0) {
                        fen += empty;
                        empty = 0;
                    }
                    fen += piece.color === 'w' ? piece.type.toUpperCase() : piece.type;
                } else {
                    empty++;
                }
            }
            if (empty > 0) fen += empty;
            if (r < 7) fen += '/';
        }

        const castling = (this.state.castling.wK ? 'K' : '') +
                         (this.state.castling.wQ ? 'Q' : '') +
                         (this.state.castling.bK ? 'k' : '') +
                         (this.state.castling.bQ ? 'q' : '') || '-';

        const ep = this.state.enPassant === null ? '-' : this.indexToAlgebraic(this.state.enPassant);

        return `${fen} ${this.state.turn} ${castling} ${ep} ${this.state.halfmoveClock} ${this.state.fullmoveNumber}`;
    }

    /**
     * @param {string} square
     * @returns {number}
     */
    algebraicToIndex(square) {
        const file = square.charCodeAt(0) - 'a'.charCodeAt(0);
        const rank = 8 - parseInt(square[1]);
        return rank * 8 + file;
    }

    /**
     * @param {number} index
     * @returns {string}
     */
    indexToAlgebraic(index) {
        const file = String.fromCharCode('a'.charCodeAt(0) + (index % 8));
        const rank = 8 - Math.floor(index / 8);
        return file + rank;
    }

    /**
     * @param {string} moveStr
     * @returns {Move | null}
     */
    parseMove(moveStr) {
        if (moveStr.length < 4) return null;
        const from = this.algebraicToIndex(moveStr.substring(0, 2));
        const to = this.algebraicToIndex(moveStr.substring(2, 4));
        let promotion = moveStr.length > 4 ? /** @type {PieceType} */ (moveStr[4].toLowerCase()) : undefined;
        
        // Auto-detect promotion if not specified
        const piece = this.state.board[from];
        if (piece && piece.type === 'p' && !promotion) {
            const toRank = Math.floor(to / 8);
            if (toRank === 0 || toRank === 7) {
                promotion = 'q';
            }
        }
        
        return { from, to, promotion };
    }

    /**
     * @returns {Move[]}
     */
    generateMoves() {
        const moves = [];
        for (let i = 0; i < 64; i++) {
            const piece = this.state.board[i];
            if (piece && piece.color === this.state.turn) {
                this.generatePieceMoves(i, piece, moves);
            }
        }
        return moves.filter(m => !this.leavesKingInCheck(m));
    }

    /**
     * @param {number} index
     * @param {Piece} piece
     * @param {Move[]} moves
     */
    generatePieceMoves(index, piece, moves) {
        const r = Math.floor(index / 8);
        const c = index % 8;

        const addMove = (tr, tc, promotion) => {
            if (tr >= 0 && tr < 8 && tc >= 0 && tc < 8) {
                moves.push({ from: index, to: tr * 8 + tc, promotion });
                return true;
            }
            return false;
        };

        if (piece.type === 'p') {
            const dir = piece.color === 'w' ? -1 : 1;
            const startRank = piece.color === 'w' ? 6 : 1;
            const promRank = piece.color === 'w' ? 0 : 7;

            // Push
            const pushIdx = index + dir * 8;
            if (pushIdx >= 0 && pushIdx < 64 && !this.state.board[pushIdx]) {
                if (r + dir === promRank) {
                    ['q', 'r', 'b', 'n'].forEach(p => addMove(r + dir, c, p));
                } else {
                    addMove(r + dir, c);
                    if (r === startRank && !this.state.board[index + dir * 16]) {
                        addMove(r + dir * 2, c);
                    }
                }
            }
            // Captures
            [-1, 1].forEach(dc => {
                const targetIdx = index + dir * 8 + dc;
                if (c + dc >= 0 && c + dc < 8) {
                    const target = this.state.board[targetIdx];
                    if ((target && target.color !== piece.color) || targetIdx === this.state.enPassant) {
                        if (r + dir === promRank) {
                            ['q', 'r', 'b', 'n'].forEach(p => addMove(r + dir, c + dc, p));
                        } else {
                            addMove(r + dir, c + dc);
                        }
                    }
                }
            });
        } else if (piece.type === 'n') {
            [[-1, -2], [-2, -1], [-2, 1], [-1, 2], [1, 2], [2, 1], [2, -1], [1, -2]].forEach(([dr, dc]) => {
                const tr = r + dr, tc = c + dc;
                if (tr >= 0 && tr < 8 && tc >= 0 && tc < 8) {
                    const target = this.state.board[tr * 8 + tc];
                    if (!target || target.color !== piece.color) addMove(tr, tc);
                }
            });
        } else if (piece.type === 'k') {
            [[-1, -1], [-1, 1], [1, -1], [1, 1], [-1, 0], [1, 0], [0, -1], [0, 1]].forEach(([dr, dc]) => {
                const tr = r + dr, tc = c + dc;
                if (tr >= 0 && tr < 8 && tc >= 0 && tc < 8) {
                    const target = this.state.board[tr * 8 + tc];
                    if (!target || target.color !== piece.color) addMove(tr, tc);
                }
            });
            // Castling
            if (piece.color === 'w') {
                if (this.state.castling.wK && !this.state.board[61] && !this.state.board[62] && !this.isSquareAttacked(60, 'b') && !this.isSquareAttacked(61, 'b')) addMove(7, 6);
                if (this.state.castling.wQ && !this.state.board[59] && !this.state.board[58] && !this.state.board[57] && !this.isSquareAttacked(60, 'b') && !this.isSquareAttacked(59, 'b')) addMove(7, 2);
            } else {
                if (this.state.castling.bK && !this.state.board[5] && !this.state.board[6] && !this.isSquareAttacked(4, 'w') && !this.isSquareAttacked(5, 'w')) addMove(0, 6);
                if (this.state.castling.bQ && !this.state.board[3] && !this.state.board[2] && !this.state.board[1] && !this.isSquareAttacked(4, 'w') && !this.isSquareAttacked(3, 'w')) addMove(0, 2);
            }
        } else {
            const dirs = piece.type === 'b' ? [[-1, -1], [-1, 1], [1, -1], [1, 1]] :
                         piece.type === 'r' ? [[-1, 0], [1, 0], [0, -1], [0, 1]] :
                         [[-1, -1], [-1, 1], [1, -1], [1, 1], [-1, 0], [1, 0], [0, -1], [0, 1]];
            dirs.forEach(([dr, dc]) => {
                for (let dist = 1; dist < 8; dist++) {
                    const tr = r + dr * dist, tc = c + dc * dist;
                    if (tr < 0 || tr >= 8 || tc < 0 || tc >= 8) break;
                    const target = this.state.board[tr * 8 + tc];
                    if (!target) {
                        addMove(tr, tc);
                    } else {
                        if (target.color !== piece.color) addMove(tr, tc);
                        break;
                    }
                }
            });
        }
    }

    /**
     * @param {number} index
     * @param {Color} attackerColor
     * @returns {boolean}
     */
    isSquareAttacked(index, attackerColor) {
        const r = Math.floor(index / 8), c = index % 8;
        
        // Knight
        for (const [dr, dc] of [[-1, -2], [-2, -1], [-2, 1], [-1, 2], [1, 2], [2, 1], [2, -1], [1, -2]]) {
            const tr = r + dr, tc = c + dc;
            if (tr >= 0 && tr < 8 && tc >= 0 && tc < 8) {
                const p = this.state.board[tr * 8 + tc];
                if (p && p.type === 'n' && p.color === attackerColor) return true;
            }
        }

        // King
        for (const [dr, dc] of [[-1, -1], [-1, 1], [1, -1], [1, 1], [-1, 0], [1, 0], [0, -1], [0, 1]]) {
            const tr = r + dr, tc = c + dc;
            if (tr >= 0 && tr < 8 && tc >= 0 && tc < 8) {
                const p = this.state.board[tr * 8 + tc];
                if (p && p.type === 'k' && p.color === attackerColor) return true;
            }
        }

        // Sliding pieces (Rook, Bishop, Queen)
        const sliding = [
            { type: ['r', 'q'], dirs: [[-1, 0], [1, 0], [0, -1], [0, 1]] },
            { type: ['b', 'q'], dirs: [[-1, -1], [-1, 1], [1, -1], [1, 1]] }
        ];
        for (const { type, dirs } of sliding) {
            for (const [dr, dc] of dirs) {
                for (let d = 1; d < 8; d++) {
                    const tr = r + dr * d, tc = c + dc * d;
                    if (tr < 0 || tr >= 8 || tc < 0 || tc >= 8) break;
                    const p = this.state.board[tr * 8 + tc];
                    if (p) {
                        if (p.color === attackerColor && type.includes(p.type)) return true;
                        break;
                    }
                }
            }
        }

        // Pawn
        const pDir = attackerColor === 'w' ? 1 : -1;
        for (const dc of [-1, 1]) {
            const tr = r + pDir, tc = c + dc;
            if (tr >= 0 && tr < 8 && tc >= 0 && tc < 8) {
                const p = this.state.board[tr * 8 + tc];
                if (p && p.type === 'p' && p.color === attackerColor) return true;
            }
        }

        return false;
    }

    /**
     * @param {Move} move
     * @returns {boolean}
     */
    leavesKingInCheck(move) {
        const prevState = JSON.parse(JSON.stringify(this.state));
        this.makeMove(move, false);
        const inCheck = this.isInCheck(prevState.turn);
        this.state = prevState;
        return inCheck;
    }

    /**
     * @param {Color} color
     * @returns {boolean}
     */
    isInCheck(color) {
        const kingIdx = this.state.board.findIndex(p => p && p.type === 'k' && p.color === color);
        if (kingIdx === -1) return false;
        return this.isSquareAttacked(kingIdx, color === 'w' ? 'b' : 'w');
    }

    /**
     * @param {Move} move
     * @param {boolean} updateHistory
     */
    makeMove(move, updateHistory = true) {
        if (updateHistory) this.history.push(JSON.parse(JSON.stringify(this.state)));
        
        const piece = this.state.board[move.from];
        if (!piece) return;

        const target = this.state.board[move.to];
        let nextEp = null;

        if (piece.type === 'p') {
            if (move.to === this.state.enPassant) {
                const dir = piece.color === 'w' ? 1 : -1;
                this.state.board[move.to + dir * 8] = null;
            }
            if (Math.abs(move.from - move.to) === 16) {
                nextEp = (move.from + move.to) / 2;
            }
            if (move.promotion) {
                piece.type = move.promotion;
            } else if ((piece.color === 'w' && Math.floor(move.to / 8) === 0) || (piece.color === 'b' && Math.floor(move.to / 8) === 7)) {
                piece.type = 'q'; // Auto-promote to Queen
            }
        }

        if (piece.type === 'k') {
            if (Math.abs(move.from - move.to) === 2 || (move.from === 60 && (move.to === 62 || move.to === 58)) || (move.from === 4 && (move.to === 6 || move.to === 2))) {
                if (move.to === 62) { this.state.board[61] = this.state.board[63]; this.state.board[63] = null; }
                else if (move.to === 58) { this.state.board[59] = this.state.board[56]; this.state.board[56] = null; }
                else if (move.to === 6) { this.state.board[5] = this.state.board[7]; this.state.board[7] = null; }
                else if (move.to === 2) { this.state.board[3] = this.state.board[0]; this.state.board[0] = null; }
            }
            if (piece.color === 'w') { this.state.castling.wK = false; this.state.castling.wQ = false; }
            else { this.state.castling.bK = false; this.state.castling.bQ = false; }
        }

        if (move.from === 56 || move.to === 56) this.state.castling.wQ = false;
        if (move.from === 63 || move.to === 63) this.state.castling.wK = false;
        if (move.from === 0 || move.to === 0) this.state.castling.bQ = false;
        if (move.from === 7 || move.to === 7) this.state.castling.bK = false;

        this.state.board[move.to] = piece;
        this.state.board[move.from] = null;
        this.state.enPassant = nextEp;
        if (piece.type === 'p' || target) this.state.halfmoveClock = 0;
        else this.state.halfmoveClock++;
        if (this.state.turn === 'b') this.state.fullmoveNumber++;
        this.state.turn = this.state.turn === 'w' ? 'b' : 'w';
    }

    undo() {
        if (this.history.length > 0) {
            this.state = this.history.pop();
        }
    }

    /**
     * @param {number} depth
     * @returns {number}
     */
    perft(depth) {
        if (depth === 0) return 1;
        let nodes = 0;
        const moves = this.generateMoves();
        for (const move of moves) {
            this.makeMove(move);
            nodes += this.perft(depth - 1);
            this.undo();
        }
        return nodes;
    }
}
