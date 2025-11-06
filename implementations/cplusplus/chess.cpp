/**
 * Chess Engine Implementation in C++
 * Follows the Chess Engine Specification v1.0
 */

#include <iostream>
#include <string>
#include <vector>
#include <sstream>
#include <algorithm>
#include <cctype>
#include <ctime>
#include <climits>

using namespace std;

// Piece constants
const int EMPTY = 0;
const int PAWN = 1;
const int KNIGHT = 2;
const int BISHOP = 3;
const int ROOK = 4;
const int QUEEN = 5;
const int KING = 6;

const int WHITE = 8;
const int BLACK = 16;

// Piece values for evaluation
const int PIECE_VALUES[] = {0, 100, 320, 330, 500, 900, 20000};

// Move structure
struct Move {
    int from_row, from_col;
    int to_row, to_col;
    int promotion;
    bool is_castling;
    bool is_en_passant;
    
    Move() : from_row(0), from_col(0), to_row(0), to_col(0), 
             promotion(0), is_castling(false), is_en_passant(false) {}
};

// Game state structure for move history
struct GameState {
    int board[8][8];
    bool white_to_move;
    bool white_king_moved;
    bool white_rook_a_moved;
    bool white_rook_h_moved;
    bool black_king_moved;
    bool black_rook_a_moved;
    bool black_rook_h_moved;
    int en_passant_col;
    Move last_move;
};

class ChessBoard {
private:
    int board[8][8];
    bool white_to_move;
    bool white_king_moved;
    bool white_rook_a_moved;
    bool white_rook_h_moved;
    bool black_king_moved;
    bool black_rook_a_moved;
    bool black_rook_h_moved;
    int en_passant_col;
    vector<GameState> history;

public:
    ChessBoard() {
        init_board();
    }

    void init_board() {
        // Initialize standard starting position
        white_to_move = true;
        white_king_moved = false;
        white_rook_a_moved = false;
        white_rook_h_moved = false;
        black_king_moved = false;
        black_rook_a_moved = false;
        black_rook_h_moved = false;
        en_passant_col = -1;
        history.clear();

        // Clear board
        for (int i = 0; i < 8; i++) {
            for (int j = 0; j < 8; j++) {
                board[i][j] = EMPTY;
            }
        }

        // Black pieces
        board[0][0] = BLACK | ROOK;
        board[0][1] = BLACK | KNIGHT;
        board[0][2] = BLACK | BISHOP;
        board[0][3] = BLACK | QUEEN;
        board[0][4] = BLACK | KING;
        board[0][5] = BLACK | BISHOP;
        board[0][6] = BLACK | KNIGHT;
        board[0][7] = BLACK | ROOK;
        for (int i = 0; i < 8; i++) {
            board[1][i] = BLACK | PAWN;
        }

        // White pieces
        for (int i = 0; i < 8; i++) {
            board[6][i] = WHITE | PAWN;
        }
        board[7][0] = WHITE | ROOK;
        board[7][1] = WHITE | KNIGHT;
        board[7][2] = WHITE | BISHOP;
        board[7][3] = WHITE | QUEEN;
        board[7][4] = WHITE | KING;
        board[7][5] = WHITE | BISHOP;
        board[7][6] = WHITE | KNIGHT;
        board[7][7] = WHITE | ROOK;
    }

    void display() {
        cout << "  a b c d e f g h\n";
        for (int i = 0; i < 8; i++) {
            cout << (8 - i) << " ";
            for (int j = 0; j < 8; j++) {
                cout << piece_to_char(board[i][j]) << " ";
            }
            cout << (8 - i) << "\n";
        }
        cout << "  a b c d e f g h\n\n";
        cout << (white_to_move ? "White" : "Black") << " to move\n";
    }

    char piece_to_char(int piece) {
        if (piece == EMPTY) return '.';
        
        int type = piece & 7;
        bool is_white = (piece & WHITE) != 0;
        
        char c;
        switch (type) {
            case PAWN: c = 'P'; break;
            case KNIGHT: c = 'N'; break;
            case BISHOP: c = 'B'; break;
            case ROOK: c = 'R'; break;
            case QUEEN: c = 'Q'; break;
            case KING: c = 'K'; break;
            default: c = '.';
        }
        
        return is_white ? c : tolower(c);
    }

    bool parse_move(const string& move_str, Move& move) {
        if (move_str.length() < 4) return false;
        
        move.from_col = move_str[0] - 'a';
        move.from_row = 8 - (move_str[1] - '0');
        move.to_col = move_str[2] - 'a';
        move.to_row = 8 - (move_str[3] - '0');
        
        if (move.from_col < 0 || move.from_col > 7 || 
            move.from_row < 0 || move.from_row > 7 ||
            move.to_col < 0 || move.to_col > 7 || 
            move.to_row < 0 || move.to_row > 7) {
            return false;
        }
        
        move.promotion = QUEEN;
        if (move_str.length() >= 5) {
            char promo = toupper(move_str[4]);
            switch (promo) {
                case 'Q': move.promotion = QUEEN; break;
                case 'R': move.promotion = ROOK; break;
                case 'B': move.promotion = BISHOP; break;
                case 'N': move.promotion = KNIGHT; break;
                default: return false;
            }
        }
        
        return true;
    }

    bool make_move(const string& move_str) {
        Move move;
        if (!parse_move(move_str, move)) {
            cout << "ERROR: Invalid move format\n";
            return false;
        }

        int piece = board[move.from_row][move.from_col];
        if (piece == EMPTY) {
            cout << "ERROR: No piece at source square\n";
            return false;
        }

        bool is_white = (piece & WHITE) != 0;
        if (is_white != white_to_move) {
            cout << "ERROR: Wrong color piece\n";
            return false;
        }

        if (!is_legal_move(move)) {
            cout << "ERROR: Illegal move\n";
            return false;
        }

        // Save current state
        save_state();

        // Execute move
        execute_move(move);

        // Check if own king is in check (invalid move)
        if (is_in_check(!white_to_move)) {
            undo_move();
            cout << "ERROR: King would be in check\n";
            return false;
        }

        // Check for checkmate or stalemate
        if (is_in_check(white_to_move)) {
            if (is_checkmate()) {
                cout << "OK: " << move_str << "\n";
                display();
                cout << "CHECKMATE: " << (white_to_move ? "Black" : "White") << " wins\n";
                return true;
            }
        } else if (is_stalemate()) {
            cout << "OK: " << move_str << "\n";
            display();
            cout << "STALEMATE: Draw\n";
            return true;
        }

        cout << "OK: " << move_str << "\n";
        display();
        return true;
    }

    void save_state() {
        GameState state;
        for (int i = 0; i < 8; i++) {
            for (int j = 0; j < 8; j++) {
                state.board[i][j] = board[i][j];
            }
        }
        state.white_to_move = white_to_move;
        state.white_king_moved = white_king_moved;
        state.white_rook_a_moved = white_rook_a_moved;
        state.white_rook_h_moved = white_rook_h_moved;
        state.black_king_moved = black_king_moved;
        state.black_rook_a_moved = black_rook_a_moved;
        state.black_rook_h_moved = black_rook_h_moved;
        state.en_passant_col = en_passant_col;
        history.push_back(state);
    }

    void execute_move(Move& move) {
        int piece = board[move.from_row][move.from_col];
        int type = piece & 7;
        
        // Reset en passant
        en_passant_col = -1;
        
        // Check for castling
        if (type == KING && abs(move.to_col - move.from_col) == 2) {
            move.is_castling = true;
            // Move king
            board[move.to_row][move.to_col] = piece;
            board[move.from_row][move.from_col] = EMPTY;
            
            // Move rook
            if (move.to_col == 6) { // Kingside
                board[move.to_row][5] = board[move.to_row][7];
                board[move.to_row][7] = EMPTY;
            } else { // Queenside
                board[move.to_row][3] = board[move.to_row][0];
                board[move.to_row][0] = EMPTY;
            }
        }
        // Check for en passant
        else if (type == PAWN && move.to_col != move.from_col && 
                 board[move.to_row][move.to_col] == EMPTY) {
            move.is_en_passant = true;
            board[move.to_row][move.to_col] = piece;
            board[move.from_row][move.from_col] = EMPTY;
            board[move.from_row][move.to_col] = EMPTY; // Capture en passant pawn
        }
        // Regular move
        else {
            board[move.to_row][move.to_col] = piece;
            board[move.from_row][move.from_col] = EMPTY;
        }
        
        // Handle pawn promotion
        if (type == PAWN && (move.to_row == 0 || move.to_row == 7)) {
            int color = piece & (WHITE | BLACK);
            board[move.to_row][move.to_col] = color | move.promotion;
        }
        
        // Set en passant flag for double pawn move
        if (type == PAWN && abs(move.to_row - move.from_row) == 2) {
            en_passant_col = move.from_col;
        }
        
        // Update castling flags
        if (type == KING) {
            if (white_to_move) white_king_moved = true;
            else black_king_moved = true;
        }
        if (type == ROOK) {
            if (white_to_move) {
                if (move.from_col == 0) white_rook_a_moved = true;
                if (move.from_col == 7) white_rook_h_moved = true;
            } else {
                if (move.from_col == 0) black_rook_a_moved = true;
                if (move.from_col == 7) black_rook_h_moved = true;
            }
        }
        
        white_to_move = !white_to_move;
    }

    void undo_move() {
        if (history.empty()) return;
        
        GameState state = history.back();
        history.pop_back();
        
        for (int i = 0; i < 8; i++) {
            for (int j = 0; j < 8; j++) {
                board[i][j] = state.board[i][j];
            }
        }
        white_to_move = state.white_to_move;
        white_king_moved = state.white_king_moved;
        white_rook_a_moved = state.white_rook_a_moved;
        white_rook_h_moved = state.white_rook_h_moved;
        black_king_moved = state.black_king_moved;
        black_rook_a_moved = state.black_rook_a_moved;
        black_rook_h_moved = state.black_rook_h_moved;
        en_passant_col = state.en_passant_col;
    }

    bool is_legal_move(const Move& move) {
        int piece = board[move.from_row][move.from_col];
        int type = piece & 7;
        bool is_white = (piece & WHITE) != 0;
        
        int dr = move.to_row - move.from_row;
        int dc = move.to_col - move.from_col;
        
        int target = board[move.to_row][move.to_col];
        bool target_is_white = (target & WHITE) != 0;
        
        // Can't capture own piece
        if (target != EMPTY && target_is_white == is_white) {
            return false;
        }
        
        switch (type) {
            case PAWN:
                return is_legal_pawn_move(move, is_white, dr, dc, target);
            case KNIGHT:
                return (abs(dr) == 2 && abs(dc) == 1) || (abs(dr) == 1 && abs(dc) == 2);
            case BISHOP:
                return abs(dr) == abs(dc) && is_path_clear(move);
            case ROOK:
                return (dr == 0 || dc == 0) && is_path_clear(move);
            case QUEEN:
                return ((dr == 0 || dc == 0) || (abs(dr) == abs(dc))) && is_path_clear(move);
            case KING:
                return is_legal_king_move(move, is_white, dr, dc);
        }
        
        return false;
    }

    bool is_legal_pawn_move(const Move& move, bool is_white, int dr, int dc, int target) {
        int direction = is_white ? -1 : 1;
        
        // Forward move
        if (dc == 0) {
            if (target != EMPTY) return false;
            if (dr == direction) return true;
            // Double move from starting position
            if (dr == 2 * direction) {
                int start_row = is_white ? 6 : 1;
                if (move.from_row == start_row && 
                    board[move.from_row + direction][move.from_col] == EMPTY) {
                    return true;
                }
            }
            return false;
        }
        
        // Capture move
        if (abs(dc) == 1 && dr == direction) {
            if (target != EMPTY) return true;
            // En passant
            if (move.to_col == en_passant_col && 
                ((is_white && move.from_row == 3) || (!is_white && move.from_row == 4))) {
                return true;
            }
        }
        
        return false;
    }

    bool is_legal_king_move(const Move& move, bool is_white, int dr, int dc) {
        // Normal king move
        if (abs(dr) <= 1 && abs(dc) <= 1) return true;
        
        // Castling
        if (dr == 0 && abs(dc) == 2) {
            if (is_white && white_king_moved) return false;
            if (!is_white && black_king_moved) return false;
            
            int row = is_white ? 7 : 0;
            if (move.from_row != row || move.from_col != 4) return false;
            
            if (is_in_check(is_white)) return false;
            
            if (dc == 2) { // Kingside
                if (is_white && white_rook_h_moved) return false;
                if (!is_white && black_rook_h_moved) return false;
                if (board[row][5] != EMPTY || board[row][6] != EMPTY) return false;
                return !is_square_attacked(row, 5, !is_white);
            } else { // Queenside
                if (is_white && white_rook_a_moved) return false;
                if (!is_white && black_rook_a_moved) return false;
                if (board[row][1] != EMPTY || board[row][2] != EMPTY || 
                    board[row][3] != EMPTY) return false;
                return !is_square_attacked(row, 3, !is_white);
            }
        }
        
        return false;
    }

    bool is_path_clear(const Move& move) {
        int dr = (move.to_row > move.from_row) ? 1 : ((move.to_row < move.from_row) ? -1 : 0);
        int dc = (move.to_col > move.from_col) ? 1 : ((move.to_col < move.from_col) ? -1 : 0);
        
        int r = move.from_row + dr;
        int c = move.from_col + dc;
        
        while (r != move.to_row || c != move.to_col) {
            if (board[r][c] != EMPTY) return false;
            r += dr;
            c += dc;
        }
        
        return true;
    }

    bool is_square_attacked(int row, int col, bool by_white) {
        // Check all opponent pieces to see if they can attack this square
        for (int i = 0; i < 8; i++) {
            for (int j = 0; j < 8; j++) {
                int piece = board[i][j];
                if (piece == EMPTY) continue;
                
                bool piece_is_white = (piece & WHITE) != 0;
                if (piece_is_white != by_white) continue;
                
                Move test_move;
                test_move.from_row = i;
                test_move.from_col = j;
                test_move.to_row = row;
                test_move.to_col = col;
                
                int type = piece & 7;
                int dr = row - i;
                int dc = col - j;
                
                bool can_attack = false;
                switch (type) {
                    case PAWN: {
                        int direction = by_white ? -1 : 1;
                        can_attack = (dr == direction && abs(dc) == 1);
                        break;
                    }
                    case KNIGHT:
                        can_attack = (abs(dr) == 2 && abs(dc) == 1) || 
                                   (abs(dr) == 1 && abs(dc) == 2);
                        break;
                    case BISHOP:
                        can_attack = abs(dr) == abs(dc) && is_path_clear(test_move);
                        break;
                    case ROOK:
                        can_attack = (dr == 0 || dc == 0) && is_path_clear(test_move);
                        break;
                    case QUEEN:
                        can_attack = ((dr == 0 || dc == 0) || (abs(dr) == abs(dc))) && 
                                   is_path_clear(test_move);
                        break;
                    case KING:
                        can_attack = abs(dr) <= 1 && abs(dc) <= 1;
                        break;
                }
                
                if (can_attack) return true;
            }
        }
        return false;
    }

    bool is_in_check(bool white_king) {
        // Find king position
        int king_row = -1, king_col = -1;
        int king_piece = (white_king ? WHITE : BLACK) | KING;
        
        for (int i = 0; i < 8; i++) {
            for (int j = 0; j < 8; j++) {
                if (board[i][j] == king_piece) {
                    king_row = i;
                    king_col = j;
                    break;
                }
            }
            if (king_row != -1) break;
        }
        
        if (king_row == -1) return false;
        
        return is_square_attacked(king_row, king_col, !white_king);
    }

    vector<Move> get_legal_moves() {
        vector<Move> moves;
        
        for (int fr = 0; fr < 8; fr++) {
            for (int fc = 0; fc < 8; fc++) {
                int piece = board[fr][fc];
                if (piece == EMPTY) continue;
                
                bool is_white = (piece & WHITE) != 0;
                if (is_white != white_to_move) continue;
                
                for (int tr = 0; tr < 8; tr++) {
                    for (int tc = 0; tc < 8; tc++) {
                        Move move;
                        move.from_row = fr;
                        move.from_col = fc;
                        move.to_row = tr;
                        move.to_col = tc;
                        
                        if (is_legal_move(move)) {
                            save_state();
                            execute_move(move);
                            if (!is_in_check(!white_to_move)) {
                                moves.push_back(move);
                            }
                            undo_move();
                        }
                    }
                }
            }
        }
        
        return moves;
    }

    bool is_checkmate() {
        return get_legal_moves().empty();
    }

    bool is_stalemate() {
        return get_legal_moves().empty();
    }

    string export_fen() {
        ostringstream oss;
        
        // Board position
        for (int i = 0; i < 8; i++) {
            int empty_count = 0;
            for (int j = 0; j < 8; j++) {
                if (board[i][j] == EMPTY) {
                    empty_count++;
                } else {
                    if (empty_count > 0) {
                        oss << empty_count;
                        empty_count = 0;
                    }
                    oss << piece_to_char(board[i][j]);
                }
            }
            if (empty_count > 0) {
                oss << empty_count;
            }
            if (i < 7) oss << "/";
        }
        
        // Active color
        oss << " " << (white_to_move ? "w" : "b");
        
        // Castling availability
        oss << " ";
        string castling = "";
        if (!white_king_moved) {
            if (!white_rook_h_moved) castling += "K";
            if (!white_rook_a_moved) castling += "Q";
        }
        if (!black_king_moved) {
            if (!black_rook_h_moved) castling += "k";
            if (!black_rook_a_moved) castling += "q";
        }
        oss << (castling.empty() ? "-" : castling);
        
        // En passant target
        oss << " ";
        if (en_passant_col >= 0) {
            char file = 'a' + en_passant_col;
            int rank = white_to_move ? 6 : 3;
            oss << file << rank;
        } else {
            oss << "-";
        }
        
        // Halfmove and fullmove (simplified)
        oss << " 0 1";
        
        return oss.str();
    }

    bool load_fen(const string& fen) {
        istringstream iss(fen);
        string board_str, color, castling, en_passant;
        
        iss >> board_str >> color >> castling >> en_passant;
        
        // Clear board
        for (int i = 0; i < 8; i++) {
            for (int j = 0; j < 8; j++) {
                board[i][j] = EMPTY;
            }
        }
        
        // Parse board
        int row = 0, col = 0;
        for (char c : board_str) {
            if (c == '/') {
                row++;
                col = 0;
            } else if (isdigit(c)) {
                col += (c - '0');
            } else {
                int piece = char_to_piece(c);
                if (piece != EMPTY && row < 8 && col < 8) {
                    board[row][col] = piece;
                    col++;
                }
            }
        }
        
        // Parse color
        white_to_move = (color == "w");
        
        // Parse castling
        white_king_moved = true;
        white_rook_a_moved = true;
        white_rook_h_moved = true;
        black_king_moved = true;
        black_rook_a_moved = true;
        black_rook_h_moved = true;
        
        for (char c : castling) {
            if (c == 'K') { white_king_moved = false; white_rook_h_moved = false; }
            if (c == 'Q') { white_king_moved = false; white_rook_a_moved = false; }
            if (c == 'k') { black_king_moved = false; black_rook_h_moved = false; }
            if (c == 'q') { black_king_moved = false; black_rook_a_moved = false; }
        }
        
        // Parse en passant
        en_passant_col = -1;
        if (en_passant != "-" && en_passant.length() >= 2) {
            en_passant_col = en_passant[0] - 'a';
        }
        
        history.clear();
        return true;
    }

    int char_to_piece(char c) {
        bool is_white = isupper(c);
        c = toupper(c);
        
        int type;
        switch (c) {
            case 'P': type = PAWN; break;
            case 'N': type = KNIGHT; break;
            case 'B': type = BISHOP; break;
            case 'R': type = ROOK; break;
            case 'Q': type = QUEEN; break;
            case 'K': type = KING; break;
            default: return EMPTY;
        }
        
        return (is_white ? WHITE : BLACK) | type;
    }

    int evaluate() {
        int score = 0;
        
        for (int i = 0; i < 8; i++) {
            for (int j = 0; j < 8; j++) {
                int piece = board[i][j];
                if (piece == EMPTY) continue;
                
                int type = piece & 7;
                bool is_white = (piece & WHITE) != 0;
                int value = PIECE_VALUES[type];
                
                // Position bonuses
                if (type == PAWN) {
                    value += 5 * (is_white ? (6 - i) : i);
                }
                
                // Center control bonus
                if ((i >= 3 && i <= 4) && (j >= 3 && j <= 4)) {
                    value += 10;
                }
                
                score += is_white ? value : -value;
            }
        }
        
        return score;
    }

    int minimax(int depth, int alpha, int beta, bool maximizing) {
        if (depth == 0) {
            return evaluate();
        }
        
        vector<Move> moves = get_legal_moves();
        
        if (moves.empty()) {
            if (is_in_check(white_to_move)) {
                return maximizing ? -100000 : 100000;
            }
            return 0; // Stalemate
        }
        
        if (maximizing) {
            int max_eval = INT_MIN;
            for (const Move& move : moves) {
                save_state();
                Move m = move;
                execute_move(m);
                int eval = minimax(depth - 1, alpha, beta, false);
                undo_move();
                
                max_eval = max(max_eval, eval);
                alpha = max(alpha, eval);
                if (beta <= alpha) break;
            }
            return max_eval;
        } else {
            int min_eval = INT_MAX;
            for (const Move& move : moves) {
                save_state();
                Move m = move;
                execute_move(m);
                int eval = minimax(depth - 1, alpha, beta, true);
                undo_move();
                
                min_eval = min(min_eval, eval);
                beta = min(beta, eval);
                if (beta <= alpha) break;
            }
            return min_eval;
        }
    }

    bool ai_move(int depth) {
        if (depth < 1 || depth > 5) {
            cout << "ERROR: AI depth must be 1-5\n";
            return false;
        }
        
        clock_t start = clock();
        
        vector<Move> moves = get_legal_moves();
        if (moves.empty()) {
            cout << "ERROR: No legal moves available\n";
            return false;
        }
        
        Move best_move = moves[0];
        int best_eval = white_to_move ? INT_MIN : INT_MAX;
        
        for (const Move& move : moves) {
            save_state();
            Move m = move;
            execute_move(m);
            int eval = minimax(depth - 1, INT_MIN, INT_MAX, !white_to_move);
            undo_move();
            
            if (white_to_move) {
                if (eval > best_eval) {
                    best_eval = eval;
                    best_move = move;
                }
            } else {
                if (eval < best_eval) {
                    best_eval = eval;
                    best_move = move;
                }
            }
        }
        
        clock_t end = clock();
        double time_ms = 1000.0 * (end - start) / CLOCKS_PER_SEC;
        
        // Format move string
        char move_str[10];
        sprintf(move_str, "%c%d%c%d", 
                'a' + best_move.from_col, 8 - best_move.from_row,
                'a' + best_move.to_col, 8 - best_move.to_row);
        
        cout << "AI: " << move_str << " (depth=" << depth 
             << ", eval=" << best_eval << ", time=" << (int)time_ms << "ms)\n";
        
        save_state();
        execute_move(best_move);
        display();
        
        // Check for checkmate or stalemate
        if (is_in_check(white_to_move)) {
            if (is_checkmate()) {
                cout << "CHECKMATE: " << (white_to_move ? "Black" : "White") << " wins\n";
            }
        } else if (is_stalemate()) {
            cout << "STALEMATE: Draw\n";
        }
        
        return true;
    }

    long long perft(int depth) {
        if (depth == 0) return 1;
        
        vector<Move> moves = get_legal_moves();
        long long nodes = 0;
        
        for (const Move& move : moves) {
            save_state();
            Move m = move;
            execute_move(m);
            nodes += perft(depth - 1);
            undo_move();
        }
        
        return nodes;
    }
};

void print_help() {
    cout << "Available commands:\n";
    cout << "  new                  - Start a new game\n";
    cout << "  move <from><to>      - Make a move (e.g., move e2e4)\n";
    cout << "  undo                 - Undo the last move\n";
    cout << "  ai <depth>           - Let AI make a move (depth 1-5)\n";
    cout << "  fen <string>         - Load position from FEN\n";
    cout << "  export               - Export current position as FEN\n";
    cout << "  eval                 - Display position evaluation\n";
    cout << "  perft <depth>        - Performance test\n";
    cout << "  help                 - Display this help message\n";
    cout << "  quit                 - Exit the program\n";
}

int main() {
    ChessBoard chess;
    chess.display();
    cout.flush();
    
    string line;
    while (getline(cin, line)) {
        if (line.empty()) continue;
        
        istringstream iss(line);
        string cmd;
        iss >> cmd;
        
        // Convert command to lowercase
        transform(cmd.begin(), cmd.end(), cmd.begin(), ::tolower);
        
        if (cmd == "new") {
            chess.init_board();
            chess.display();
        }
        else if (cmd == "move") {
            string move_str;
            iss >> move_str;
            if (!move_str.empty()) {
                chess.make_move(move_str);
            } else {
                cout << "ERROR: Invalid move format\n";
            }
        }
        else if (cmd == "undo") {
            chess.undo_move();
            chess.display();
        }
        else if (cmd == "ai") {
            int depth = 3;
            iss >> depth;
            chess.ai_move(depth);
        }
        else if (cmd == "fen") {
            string fen;
            getline(iss, fen);
            if (!fen.empty()) {
                fen = fen.substr(1); // Remove leading space
                if (chess.load_fen(fen)) {
                    chess.display();
                } else {
                    cout << "ERROR: Invalid FEN string\n";
                }
            } else {
                cout << "ERROR: Invalid FEN string\n";
            }
        }
        else if (cmd == "export") {
            cout << "FEN: " << chess.export_fen() << "\n";
        }
        else if (cmd == "eval") {
            int score = chess.evaluate();
            cout << "Evaluation: " << score << " (positive = white advantage)\n";
        }
        else if (cmd == "perft") {
            int depth = 4;
            iss >> depth;
            clock_t start = clock();
            long long nodes = chess.perft(depth);
            clock_t end = clock();
            double time_ms = 1000.0 * (end - start) / CLOCKS_PER_SEC;
            cout << "Perft(" << depth << "): " << nodes << " nodes in " 
                 << (int)time_ms << "ms\n";
        }
        else if (cmd == "help") {
            print_help();
        }
        else if (cmd == "quit" || cmd == "exit") {
            cout << "Goodbye!\n";
            break;
        }
        else {
            cout << "ERROR: Invalid command. Type 'help' for available commands.\n";
        }
        
        cout.flush();
    }
    
    return 0;
}
