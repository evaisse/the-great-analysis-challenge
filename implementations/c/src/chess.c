#include <ctype.h>
#include <errno.h>
#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>

#define MAX_MOVES 256
#define MAX_HISTORY 2048
#define MAX_POSITIONS 4096
#define FEN_BUFFER_SIZE 128
#define PGN_SAN_SIZE 32
#define PGN_RESULT_SIZE 16
#define PGN_TAG_NAME_SIZE 32
#define PGN_TAG_VALUE_SIZE 256
#define PGN_SOURCE_SIZE 512
#define MAX_PGN_TAGS 32
#define START_FEN "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
#define MATE_SCORE 100000
#define INF_SCORE 1000000000

typedef struct {
    char squares[64];
    bool white_to_move;
    bool white_kingside;
    bool white_queenside;
    bool black_kingside;
    bool black_queenside;
    int en_passant;
    int halfmove_clock;
    int fullmove_number;
} Board;

typedef struct {
    int from;
    int to;
    char promotion;
    bool is_castling;
    bool is_en_passant;
    char captured;
} Move;

typedef struct {
    Move moves[MAX_MOVES];
    int count;
} MoveList;

typedef struct {
    char name[PGN_TAG_NAME_SIZE];
    char value[PGN_TAG_VALUE_SIZE];
} PgnTag;

typedef struct {
    char san[PGN_SAN_SIZE];
    Move move;
    char fen_before[FEN_BUFFER_SIZE];
    char fen_after[FEN_BUFFER_SIZE];
} PgnMoveNode;

typedef struct {
    PgnTag tags[MAX_PGN_TAGS];
    int tag_count;
    PgnMoveNode moves[MAX_HISTORY];
    int move_count;
    char result[PGN_RESULT_SIZE];
    char source[PGN_SOURCE_SIZE];
    char initial_fen[FEN_BUFFER_SIZE];
} PgnGame;

typedef struct {
    Board board;
    Board history[MAX_HISTORY];
    int history_len;
    Move move_history[MAX_HISTORY];
    int move_history_len;
    uint64_t position_history[MAX_POSITIONS];
    int position_count;
    char initial_fen[FEN_BUFFER_SIZE];
    PgnGame pgn_game;
    int chess960_id;
    bool chess960_mode;
} Engine;

typedef enum {
    STATUS_ONGOING,
    STATUS_CHECK,
    STATUS_CHECKMATE_WHITE,
    STATUS_CHECKMATE_BLACK,
    STATUS_STALEMATE,
    STATUS_DRAW_REPETITION,
    STATUS_DRAW_FIFTY,
} GameStatus;

static GameStatus engine_status(const Engine *engine);
static void copy_text(char *destination, size_t destination_size, const char *source);
static void pgn_init_game(PgnGame *game, const char *initial_fen, const char *source);
static void pgn_set_result(PgnGame *game, const char *result);
static bool pgn_build_from_history(PgnGame *game, const Move *move_history, int move_count, const char *initial_fen, const char *source);
static void chess960_fen(int chess960_id, char buffer[FEN_BUFFER_SIZE]);

static const int KNIGHT_DELTAS[8][2] = {
    {-2, -1}, {-2, 1}, {-1, -2}, {-1, 2},
    {1, -2}, {1, 2}, {2, -1}, {2, 1},
};

static const int KING_DELTAS[8][2] = {
    {-1, -1}, {-1, 0}, {-1, 1},
    {0, -1},           {0, 1},
    {1, -1},  {1, 0},  {1, 1},
};

static const int PAWN_TABLE[8][8] = {
    {0, 0, 0, 0, 0, 0, 0, 0},
    {50, 50, 50, 50, 50, 50, 50, 50},
    {10, 10, 20, 30, 30, 20, 10, 10},
    {5, 5, 10, 25, 25, 10, 5, 5},
    {0, 0, 0, 20, 20, 0, 0, 0},
    {5, -5, -10, 0, 0, -10, -5, 5},
    {5, 10, 10, -20, -20, 10, 10, 5},
    {0, 0, 0, 0, 0, 0, 0, 0},
};

static const int KNIGHT_TABLE[8][8] = {
    {-50, -40, -30, -30, -30, -30, -40, -50},
    {-40, -20, 0, 0, 0, 0, -20, -40},
    {-30, 0, 10, 15, 15, 10, 0, -30},
    {-30, 5, 15, 20, 20, 15, 5, -30},
    {-30, 0, 15, 20, 20, 15, 0, -30},
    {-30, 5, 10, 15, 15, 10, 5, -30},
    {-40, -20, 0, 5, 5, 0, -20, -40},
    {-50, -40, -30, -30, -30, -30, -40, -50},
};

static const int BISHOP_TABLE[8][8] = {
    {-20, -10, -10, -10, -10, -10, -10, -20},
    {-10, 0, 0, 0, 0, 0, 0, -10},
    {-10, 0, 5, 10, 10, 5, 0, -10},
    {-10, 5, 5, 10, 10, 5, 5, -10},
    {-10, 0, 10, 10, 10, 10, 0, -10},
    {-10, 10, 10, 10, 10, 10, 10, -10},
    {-10, 5, 0, 0, 0, 0, 5, -10},
    {-20, -10, -10, -10, -10, -10, -10, -20},
};

static const int ROOK_TABLE[8][8] = {
    {0, 0, 0, 0, 0, 0, 0, 0},
    {5, 10, 10, 10, 10, 10, 10, 5},
    {-5, 0, 0, 0, 0, 0, 0, -5},
    {-5, 0, 0, 0, 0, 0, 0, -5},
    {-5, 0, 0, 0, 0, 0, 0, -5},
    {-5, 0, 0, 0, 0, 0, 0, -5},
    {-5, 0, 0, 0, 0, 0, 0, -5},
    {0, 0, 0, 5, 5, 0, 0, 0},
};

static const int QUEEN_TABLE[8][8] = {
    {-20, -10, -10, -5, -5, -10, -10, -20},
    {-10, 0, 0, 0, 0, 0, 0, -10},
    {-10, 0, 5, 5, 5, 5, 0, -10},
    {-5, 0, 5, 5, 5, 5, 0, -5},
    {0, 0, 5, 5, 5, 5, 0, -5},
    {-10, 5, 5, 5, 5, 5, 0, -10},
    {-10, 0, 5, 0, 0, 0, 0, -10},
    {-20, -10, -10, -5, -5, -10, -10, -20},
};

static const int KING_TABLE[8][8] = {
    {-30, -40, -40, -50, -50, -40, -40, -30},
    {-30, -40, -40, -50, -50, -40, -40, -30},
    {-30, -40, -40, -50, -50, -40, -40, -30},
    {-30, -40, -40, -50, -50, -40, -40, -30},
    {-20, -30, -30, -40, -40, -30, -30, -20},
    {-10, -20, -20, -20, -20, -20, -20, -10},
    {20, 20, 0, 0, 0, 0, 20, 20},
    {20, 30, 10, 0, 0, 10, 30, 20},
};

static long long current_time_ms(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (long long) tv.tv_sec * 1000LL + (long long) tv.tv_usec / 1000LL;
}

static void append_format(char **cursor, size_t *remaining, const char *format, ...) {
    if (*remaining == 0) {
        return;
    }

    va_list args;
    va_start(args, format);
    int written = vsnprintf(*cursor, *remaining, format, args);
    va_end(args);

    if (written < 0) {
        return;
    }

    size_t advance = (size_t) written;
    if (advance >= *remaining) {
        advance = *remaining - 1;
    }

    *cursor += advance;
    *remaining -= advance;
}

static bool in_bounds(int row, int col) {
    return row >= 0 && row < 8 && col >= 0 && col < 8;
}

static int make_square(int row, int col) {
    return row * 8 + col;
}

static int square_row(int square) {
    return square / 8;
}

static int square_col(int square) {
    return square % 8;
}

static bool is_white_piece(char piece) {
    return piece >= 'A' && piece <= 'Z';
}

static bool is_black_piece(char piece) {
    return piece >= 'a' && piece <= 'z';
}

static bool same_side(char first, char second) {
    if (first == '.' || second == '.') {
        return false;
    }
    return (is_white_piece(first) && is_white_piece(second)) ||
           (is_black_piece(first) && is_black_piece(second));
}

static int piece_value(char piece) {
    switch (toupper((unsigned char) piece)) {
        case 'P':
            return 100;
        case 'N':
            return 320;
        case 'B':
            return 330;
        case 'R':
            return 500;
        case 'Q':
            return 900;
        case 'K':
            return 20000;
        default:
            return 0;
    }
}

static int piece_square_bonus(char piece, int row, int col) {
    int eval_row = is_white_piece(piece) ? row : 7 - row;
    switch (toupper((unsigned char) piece)) {
        case 'P':
            return PAWN_TABLE[eval_row][col];
        case 'N':
            return KNIGHT_TABLE[eval_row][col];
        case 'B':
            return BISHOP_TABLE[eval_row][col];
        case 'R':
            return ROOK_TABLE[eval_row][col];
        case 'Q':
            return QUEEN_TABLE[eval_row][col];
        case 'K':
            return KING_TABLE[eval_row][col];
        default:
            return 0;
    }
}

static void board_clear(Board *board) {
    for (int index = 0; index < 64; ++index) {
        board->squares[index] = '.';
    }
    board->white_to_move = true;
    board->white_kingside = true;
    board->white_queenside = true;
    board->black_kingside = true;
    board->black_queenside = true;
    board->en_passant = -1;
    board->halfmove_clock = 0;
    board->fullmove_number = 1;
}

static void board_set_starting_position(Board *board) {
    static const char *back_rank = "RNBQKBNR";

    board_clear(board);

    for (int file = 0; file < 8; ++file) {
        board->squares[file] = back_rank[file];
        board->squares[8 + file] = 'P';
        board->squares[48 + file] = 'p';
        board->squares[56 + file] = (char) tolower((unsigned char) back_rank[file]);
    }
}

static void board_export_fen(const Board *board, char *buffer, size_t buffer_size) {
    char *cursor = buffer;
    size_t remaining = buffer_size;

    if (buffer_size == 0) {
        return;
    }
    buffer[0] = '\0';

    for (int rank = 7; rank >= 0; --rank) {
        int empty_count = 0;
        for (int file = 0; file < 8; ++file) {
            char piece = board->squares[rank * 8 + file];
            if (piece == '.') {
                empty_count += 1;
                continue;
            }

            if (empty_count > 0) {
                append_format(&cursor, &remaining, "%c", (char) ('0' + empty_count));
                empty_count = 0;
            }

            append_format(&cursor, &remaining, "%c", piece);
        }

        if (empty_count > 0) {
            append_format(&cursor, &remaining, "%c", (char) ('0' + empty_count));
        }

        if (rank > 0) {
            append_format(&cursor, &remaining, "/");
        }
    }

    append_format(&cursor, &remaining, " %c ", board->white_to_move ? 'w' : 'b');

    bool any_castling = false;
    if (board->white_kingside) {
        append_format(&cursor, &remaining, "K");
        any_castling = true;
    }
    if (board->white_queenside) {
        append_format(&cursor, &remaining, "Q");
        any_castling = true;
    }
    if (board->black_kingside) {
        append_format(&cursor, &remaining, "k");
        any_castling = true;
    }
    if (board->black_queenside) {
        append_format(&cursor, &remaining, "q");
        any_castling = true;
    }
    if (!any_castling) {
        append_format(&cursor, &remaining, "-");
    }

    append_format(&cursor, &remaining, " ");
    if (board->en_passant >= 0) {
        append_format(&cursor, &remaining, "%c%c",
                      (char) ('a' + square_col(board->en_passant)),
                      (char) ('1' + square_row(board->en_passant)));
    } else {
        append_format(&cursor, &remaining, "-");
    }

    append_format(&cursor, &remaining, " %d %d", board->halfmove_clock, board->fullmove_number);
}

static void board_export_position_key(const Board *board, char *buffer, size_t buffer_size) {
    char fen[FEN_BUFFER_SIZE];
    char *fields[6] = {0};
    char *token = NULL;
    int field_count = 0;

    board_export_fen(board, fen, sizeof(fen));
    token = strtok(fen, " ");
    while (token != NULL && field_count < 6) {
        fields[field_count++] = token;
        token = strtok(NULL, " ");
    }

    if (field_count >= 4) {
        snprintf(buffer, buffer_size, "%s %s %s %s", fields[0], fields[1], fields[2], fields[3]);
    } else {
        snprintf(buffer, buffer_size, "invalid");
    }
}

static uint64_t board_hash(const Board *board) {
    char key[FEN_BUFFER_SIZE];
    uint64_t hash = 1469598103934665603ULL;

    board_export_position_key(board, key, sizeof(key));
    for (size_t index = 0; key[index] != '\0'; ++index) {
        hash ^= (unsigned char) key[index];
        hash *= 1099511628211ULL;
    }

    return hash;
}

static bool board_load_fen(Board *board, const char *fen_string) {
    char copy[256];
    char *parts[6] = {0};
    char *token = NULL;
    int part_count = 0;

    if (strlen(fen_string) >= sizeof(copy)) {
        return false;
    }

    strcpy(copy, fen_string);

    token = strtok(copy, " ");
    while (token != NULL && part_count < 6) {
        parts[part_count++] = token;
        token = strtok(NULL, " ");
    }

    if (part_count != 6 || strtok(NULL, " ") != NULL) {
        return false;
    }

    board_clear(board);

    int rank = 7;
    int file = 0;
    for (const char *cursor = parts[0]; *cursor != '\0'; ++cursor) {
        char value = *cursor;
        if (value == '/') {
            if (file != 8 || rank == 0) {
                return false;
            }
            rank -= 1;
            file = 0;
            continue;
        }

        if (value >= '1' && value <= '8') {
            file += value - '0';
            if (file > 8) {
                return false;
            }
            continue;
        }

        if (strchr("PNBRQKpnbrqk", value) == NULL || file >= 8) {
            return false;
        }

        board->squares[rank * 8 + file] = value;
        file += 1;
    }

    if (rank != 0 || file != 8) {
        return false;
    }

    if (strcmp(parts[1], "w") == 0) {
        board->white_to_move = true;
    } else if (strcmp(parts[1], "b") == 0) {
        board->white_to_move = false;
    } else {
        return false;
    }

    board->white_kingside = false;
    board->white_queenside = false;
    board->black_kingside = false;
    board->black_queenside = false;
    if (strcmp(parts[2], "-") != 0) {
        for (const char *cursor = parts[2]; *cursor != '\0'; ++cursor) {
            switch (*cursor) {
                case 'K':
                    board->white_kingside = true;
                    break;
                case 'Q':
                    board->white_queenside = true;
                    break;
                case 'k':
                    board->black_kingside = true;
                    break;
                case 'q':
                    board->black_queenside = true;
                    break;
                default:
                    return false;
            }
        }
    }

    if (strcmp(parts[3], "-") == 0) {
        board->en_passant = -1;
    } else if (strlen(parts[3]) == 2 && parts[3][0] >= 'a' && parts[3][0] <= 'h' &&
               parts[3][1] >= '1' && parts[3][1] <= '8') {
        board->en_passant = make_square(parts[3][1] - '1', parts[3][0] - 'a');
    } else {
        return false;
    }

    char *clock_end = NULL;
    long halfmove = strtol(parts[4], &clock_end, 10);
    if (*clock_end != '\0' || halfmove < 0) {
        return false;
    }

    long fullmove = strtol(parts[5], &clock_end, 10);
    if (*clock_end != '\0' || fullmove < 1) {
        return false;
    }

    board->halfmove_clock = (int) halfmove;
    board->fullmove_number = (int) fullmove;
    return true;
}

static int find_king(const Board *board, bool white_king) {
    char target = white_king ? 'K' : 'k';
    for (int square = 0; square < 64; ++square) {
        if (board->squares[square] == target) {
            return square;
        }
    }
    return -1;
}

static bool is_square_attacked(const Board *board, int square, bool by_white) {
    int row = square_row(square);
    int col = square_col(square);

    int pawn_row = row + (by_white ? -1 : 1);
    if (in_bounds(pawn_row, col - 1)) {
        char piece = board->squares[make_square(pawn_row, col - 1)];
        if (piece == (by_white ? 'P' : 'p')) {
            return true;
        }
    }
    if (in_bounds(pawn_row, col + 1)) {
        char piece = board->squares[make_square(pawn_row, col + 1)];
        if (piece == (by_white ? 'P' : 'p')) {
            return true;
        }
    }

    for (int index = 0; index < 8; ++index) {
        int target_row = row + KNIGHT_DELTAS[index][0];
        int target_col = col + KNIGHT_DELTAS[index][1];
        if (!in_bounds(target_row, target_col)) {
            continue;
        }

        char piece = board->squares[make_square(target_row, target_col)];
        if (piece == (by_white ? 'N' : 'n')) {
            return true;
        }
    }

    const int bishop_dirs[4][2] = {{1, 1}, {1, -1}, {-1, 1}, {-1, -1}};
    const int rook_dirs[4][2] = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};

    for (int dir_index = 0; dir_index < 4; ++dir_index) {
        int target_row = row + bishop_dirs[dir_index][0];
        int target_col = col + bishop_dirs[dir_index][1];
        while (in_bounds(target_row, target_col)) {
            char piece = board->squares[make_square(target_row, target_col)];
            if (piece != '.') {
                if (piece == (by_white ? 'B' : 'b') || piece == (by_white ? 'Q' : 'q')) {
                    return true;
                }
                break;
            }
            target_row += bishop_dirs[dir_index][0];
            target_col += bishop_dirs[dir_index][1];
        }
    }

    for (int dir_index = 0; dir_index < 4; ++dir_index) {
        int target_row = row + rook_dirs[dir_index][0];
        int target_col = col + rook_dirs[dir_index][1];
        while (in_bounds(target_row, target_col)) {
            char piece = board->squares[make_square(target_row, target_col)];
            if (piece != '.') {
                if (piece == (by_white ? 'R' : 'r') || piece == (by_white ? 'Q' : 'q')) {
                    return true;
                }
                break;
            }
            target_row += rook_dirs[dir_index][0];
            target_col += rook_dirs[dir_index][1];
        }
    }

    for (int index = 0; index < 8; ++index) {
        int target_row = row + KING_DELTAS[index][0];
        int target_col = col + KING_DELTAS[index][1];
        if (!in_bounds(target_row, target_col)) {
            continue;
        }

        char piece = board->squares[make_square(target_row, target_col)];
        if (piece == (by_white ? 'K' : 'k')) {
            return true;
        }
    }

    return false;
}

static bool is_in_check(const Board *board, bool white_king) {
    int king_square = find_king(board, white_king);
    if (king_square < 0) {
        return false;
    }

    return is_square_attacked(board, king_square, !white_king);
}

static void move_list_add(MoveList *list, int from, int to, char promotion, bool is_castling, bool is_en_passant, char captured) {
    if (list->count >= MAX_MOVES) {
        return;
    }

    list->moves[list->count].from = from;
    list->moves[list->count].to = to;
    list->moves[list->count].promotion = promotion;
    list->moves[list->count].is_castling = is_castling;
    list->moves[list->count].is_en_passant = is_en_passant;
    list->moves[list->count].captured = captured;
    list->count += 1;
}

static void apply_move(Board *board, const Move *move) {
    char piece = board->squares[move->from];
    char captured = move->captured;
    bool white_move = is_white_piece(piece);
    bool pawn_move = toupper((unsigned char) piece) == 'P';

    if (toupper((unsigned char) piece) == 'K') {
        if (white_move) {
            board->white_kingside = false;
            board->white_queenside = false;
        } else {
            board->black_kingside = false;
            board->black_queenside = false;
        }
    }

    if (piece == 'R') {
        if (move->from == 0) {
            board->white_queenside = false;
        } else if (move->from == 7) {
            board->white_kingside = false;
        }
    } else if (piece == 'r') {
        if (move->from == 56) {
            board->black_queenside = false;
        } else if (move->from == 63) {
            board->black_kingside = false;
        }
    }

    if (captured == 'R') {
        if (move->to == 0) {
            board->white_queenside = false;
        } else if (move->to == 7) {
            board->white_kingside = false;
        }
    } else if (captured == 'r') {
        if (move->to == 56) {
            board->black_queenside = false;
        } else if (move->to == 63) {
            board->black_kingside = false;
        }
    }

    board->en_passant = -1;

    if (move->is_en_passant) {
        int captured_square = white_move ? move->to - 8 : move->to + 8;
        board->squares[captured_square] = '.';
    }

    board->squares[move->from] = '.';

    if (move->is_castling) {
        if (piece == 'K' && move->to == 6) {
            board->squares[7] = '.';
            board->squares[5] = 'R';
        } else if (piece == 'K' && move->to == 2) {
            board->squares[0] = '.';
            board->squares[3] = 'R';
        } else if (piece == 'k' && move->to == 62) {
            board->squares[63] = '.';
            board->squares[61] = 'r';
        } else if (piece == 'k' && move->to == 58) {
            board->squares[56] = '.';
            board->squares[59] = 'r';
        }
    }

    if (pawn_move && abs(move->to - move->from) == 16) {
        board->en_passant = white_move ? move->from + 8 : move->from - 8;
    }

    char placed_piece = piece;
    if (move->promotion != '\0') {
        placed_piece = white_move ? move->promotion : (char) tolower((unsigned char) move->promotion);
    }
    board->squares[move->to] = placed_piece;

    if (pawn_move || captured != '.') {
        board->halfmove_clock = 0;
    } else {
        board->halfmove_clock += 1;
    }

    if (!board->white_to_move) {
        board->fullmove_number += 1;
    }

    board->white_to_move = !board->white_to_move;
}

static void generate_pawn_moves(const Board *board, int square, MoveList *list) {
    char piece = board->squares[square];
    bool white = is_white_piece(piece);
    int row = square_row(square);
    int col = square_col(square);
    int direction = white ? 1 : -1;
    int start_row = white ? 1 : 6;
    int promotion_row = white ? 7 : 0;
    int next_row = row + direction;

    if (in_bounds(next_row, col) && board->squares[make_square(next_row, col)] == '.') {
        int target = make_square(next_row, col);
        if (next_row == promotion_row) {
            move_list_add(list, square, target, 'Q', false, false, '.');
            move_list_add(list, square, target, 'R', false, false, '.');
            move_list_add(list, square, target, 'B', false, false, '.');
            move_list_add(list, square, target, 'N', false, false, '.');
        } else {
            move_list_add(list, square, target, '\0', false, false, '.');
        }

        if (row == start_row) {
            int jump_row = row + direction * 2;
            if (in_bounds(jump_row, col) && board->squares[make_square(jump_row, col)] == '.') {
                move_list_add(list, square, make_square(jump_row, col), '\0', false, false, '.');
            }
        }
    }

    for (int delta_col = -1; delta_col <= 1; delta_col += 2) {
        int target_row = row + direction;
        int target_col = col + delta_col;
        if (!in_bounds(target_row, target_col)) {
            continue;
        }

        int target = make_square(target_row, target_col);
        char captured = board->squares[target];
        if (captured != '.' && !same_side(piece, captured)) {
            if (target_row == promotion_row) {
                move_list_add(list, square, target, 'Q', false, false, captured);
                move_list_add(list, square, target, 'R', false, false, captured);
                move_list_add(list, square, target, 'B', false, false, captured);
                move_list_add(list, square, target, 'N', false, false, captured);
            } else {
                move_list_add(list, square, target, '\0', false, false, captured);
            }
        } else if (target == board->en_passant) {
            char ep_captured = white ? 'p' : 'P';
            move_list_add(list, square, target, '\0', false, true, ep_captured);
        }
    }
}

static void generate_knight_moves(const Board *board, int square, MoveList *list) {
    char piece = board->squares[square];
    int row = square_row(square);
    int col = square_col(square);

    for (int index = 0; index < 8; ++index) {
        int target_row = row + KNIGHT_DELTAS[index][0];
        int target_col = col + KNIGHT_DELTAS[index][1];
        if (!in_bounds(target_row, target_col)) {
            continue;
        }

        int target = make_square(target_row, target_col);
        char captured = board->squares[target];
        if (captured == '.' || !same_side(piece, captured)) {
            move_list_add(list, square, target, '\0', false, false, captured);
        }
    }
}

static void generate_sliding_moves(const Board *board, int square, MoveList *list, const int directions[][2], int direction_count) {
    char piece = board->squares[square];
    int row = square_row(square);
    int col = square_col(square);

    for (int dir_index = 0; dir_index < direction_count; ++dir_index) {
        int target_row = row + directions[dir_index][0];
        int target_col = col + directions[dir_index][1];
        while (in_bounds(target_row, target_col)) {
            int target = make_square(target_row, target_col);
            char captured = board->squares[target];
            if (captured == '.') {
                move_list_add(list, square, target, '\0', false, false, '.');
            } else {
                if (!same_side(piece, captured)) {
                    move_list_add(list, square, target, '\0', false, false, captured);
                }
                break;
            }
            target_row += directions[dir_index][0];
            target_col += directions[dir_index][1];
        }
    }
}

static void generate_king_moves(const Board *board, int square, MoveList *list) {
    char piece = board->squares[square];
    bool white = is_white_piece(piece);
    int row = square_row(square);
    int col = square_col(square);

    for (int index = 0; index < 8; ++index) {
        int target_row = row + KING_DELTAS[index][0];
        int target_col = col + KING_DELTAS[index][1];
        if (!in_bounds(target_row, target_col)) {
            continue;
        }

        int target = make_square(target_row, target_col);
        char captured = board->squares[target];
        if (captured == '.' || !same_side(piece, captured)) {
            move_list_add(list, square, target, '\0', false, false, captured);
        }
    }

    if (white && square == 4 && !is_in_check(board, true)) {
        if (board->white_kingside && board->squares[5] == '.' && board->squares[6] == '.' &&
            board->squares[7] == 'R' &&
            !is_square_attacked(board, 5, false) && !is_square_attacked(board, 6, false)) {
            move_list_add(list, square, 6, '\0', true, false, '.');
        }
        if (board->white_queenside && board->squares[3] == '.' && board->squares[2] == '.' &&
            board->squares[1] == '.' && board->squares[0] == 'R' &&
            !is_square_attacked(board, 3, false) && !is_square_attacked(board, 2, false)) {
            move_list_add(list, square, 2, '\0', true, false, '.');
        }
    } else if (!white && square == 60 && !is_in_check(board, false)) {
        if (board->black_kingside && board->squares[61] == '.' && board->squares[62] == '.' &&
            board->squares[63] == 'r' &&
            !is_square_attacked(board, 61, true) && !is_square_attacked(board, 62, true)) {
            move_list_add(list, square, 62, '\0', true, false, '.');
        }
        if (board->black_queenside && board->squares[59] == '.' && board->squares[58] == '.' &&
            board->squares[57] == '.' && board->squares[56] == 'r' &&
            !is_square_attacked(board, 59, true) && !is_square_attacked(board, 58, true)) {
            move_list_add(list, square, 58, '\0', true, false, '.');
        }
    }
}

static void generate_pseudo_legal_moves(const Board *board, MoveList *list) {
    const int bishop_dirs[4][2] = {{1, 1}, {1, -1}, {-1, 1}, {-1, -1}};
    const int rook_dirs[4][2] = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};
    const int queen_dirs[8][2] = {{1, 1}, {1, -1}, {-1, 1}, {-1, -1}, {1, 0}, {-1, 0}, {0, 1}, {0, -1}};

    list->count = 0;

    for (int square = 0; square < 64; ++square) {
        char piece = board->squares[square];
        if (piece == '.') {
            continue;
        }
        if (board->white_to_move != is_white_piece(piece)) {
            continue;
        }

        switch (toupper((unsigned char) piece)) {
            case 'P':
                generate_pawn_moves(board, square, list);
                break;
            case 'N':
                generate_knight_moves(board, square, list);
                break;
            case 'B':
                generate_sliding_moves(board, square, list, bishop_dirs, 4);
                break;
            case 'R':
                generate_sliding_moves(board, square, list, rook_dirs, 4);
                break;
            case 'Q':
                generate_sliding_moves(board, square, list, queen_dirs, 8);
                break;
            case 'K':
                generate_king_moves(board, square, list);
                break;
            default:
                break;
        }
    }
}

static void generate_legal_moves(const Board *board, MoveList *list) {
    MoveList pseudo;
    bool moving_white = board->white_to_move;

    list->count = 0;
    generate_pseudo_legal_moves(board, &pseudo);

    for (int index = 0; index < pseudo.count; ++index) {
        Board next = *board;
        apply_move(&next, &pseudo.moves[index]);
        if (!is_in_check(&next, moving_white)) {
            list->moves[list->count++] = pseudo.moves[index];
        }
    }
}

static void move_to_string(const Move *move, char buffer[6]) {
    buffer[0] = (char) ('a' + square_col(move->from));
    buffer[1] = (char) ('1' + square_row(move->from));
    buffer[2] = (char) ('a' + square_col(move->to));
    buffer[3] = (char) ('1' + square_row(move->to));
    if (move->promotion != '\0') {
        buffer[4] = (char) tolower((unsigned char) move->promotion);
        buffer[5] = '\0';
    } else {
        buffer[4] = '\0';
    }
}

static bool is_center_square(int square) {
    int row = square_row(square);
    int col = square_col(square);
    return (row == 3 || row == 4) && (col == 3 || col == 4);
}

static int move_order_score(const Board *board, const Move *move) {
    char piece = board->squares[move->from];
    int score = 0;

    if (move->captured != '.') {
        score += 10 * piece_value(move->captured) - piece_value(piece);
    }
    if (move->promotion != '\0') {
        score += piece_value(move->promotion) * 10;
    }
    if (is_center_square(move->to)) {
        score += 10;
    }
    if (move->is_castling) {
        score += 50;
    }

    return score;
}

static void order_moves(const Board *board, MoveList *list) {
    for (int index = 1; index < list->count; ++index) {
        Move candidate = list->moves[index];
        int candidate_score = move_order_score(board, &candidate);
        char candidate_notation[6];
        move_to_string(&candidate, candidate_notation);

        int insert_at = index - 1;
        while (insert_at >= 0) {
            int existing_score = move_order_score(board, &list->moves[insert_at]);
            char existing_notation[6];
            move_to_string(&list->moves[insert_at], existing_notation);

            if (candidate_score < existing_score) {
                break;
            }
            if (candidate_score == existing_score && strcmp(candidate_notation, existing_notation) >= 0) {
                break;
            }

            list->moves[insert_at + 1] = list->moves[insert_at];
            insert_at -= 1;
        }
        list->moves[insert_at + 1] = candidate;
    }
}

static int evaluate_board(const Board *board) {
    int score = 0;

    for (int square = 0; square < 64; ++square) {
        char piece = board->squares[square];
        if (piece == '.') {
            continue;
        }

        int row = square_row(square);
        int col = square_col(square);
        int total = piece_value(piece) + piece_square_bonus(piece, row, col);
        if (is_white_piece(piece)) {
            score += total;
        } else {
            score -= total;
        }
    }

    return score;
}

static int minimax(const Board *board, int depth, int alpha, int beta, bool maximizing_player) {
    if (board->halfmove_clock >= 100) {
        return 0;
    }

    if (depth == 0) {
        return evaluate_board(board);
    }

    MoveList legal_moves;
    generate_legal_moves(board, &legal_moves);

    if (legal_moves.count == 0) {
        if (is_in_check(board, board->white_to_move)) {
            return maximizing_player ? -MATE_SCORE : MATE_SCORE;
        }
        return 0;
    }

    order_moves(board, &legal_moves);

    if (maximizing_player) {
        int best = -INF_SCORE;
        for (int index = 0; index < legal_moves.count; ++index) {
            Board next = *board;
            apply_move(&next, &legal_moves.moves[index]);
            int score = minimax(&next, depth - 1, alpha, beta, false);
            if (score > best) {
                best = score;
            }
            if (score > alpha) {
                alpha = score;
            }
            if (beta <= alpha) {
                break;
            }
        }
        return best;
    }

    int best = INF_SCORE;
    for (int index = 0; index < legal_moves.count; ++index) {
        Board next = *board;
        apply_move(&next, &legal_moves.moves[index]);
        int score = minimax(&next, depth - 1, alpha, beta, true);
        if (score < best) {
            best = score;
        }
        if (score < beta) {
            beta = score;
        }
        if (beta <= alpha) {
            break;
        }
    }
    return best;
}

static bool select_best_move(const Board *board, int depth, Move *best_move, int *best_score) {
    MoveList legal_moves;
    bool maximizing = board->white_to_move;
    int alpha = -INF_SCORE;
    int beta = INF_SCORE;
    bool found = false;

    if (depth < 1) {
        depth = 1;
    }
    if (depth > 5) {
        depth = 5;
    }

    generate_legal_moves(board, &legal_moves);
    if (legal_moves.count == 0) {
        return false;
    }

    order_moves(board, &legal_moves);
    *best_score = maximizing ? -INF_SCORE : INF_SCORE;

    for (int index = 0; index < legal_moves.count; ++index) {
        Board next = *board;
        int score;

        apply_move(&next, &legal_moves.moves[index]);
        score = minimax(&next, depth - 1, alpha, beta, !maximizing);

        if (!found) {
            *best_move = legal_moves.moves[index];
            *best_score = score;
            found = true;
        } else if (maximizing) {
            if (score > *best_score) {
                *best_score = score;
                *best_move = legal_moves.moves[index];
            }
        } else {
            if (score < *best_score) {
                *best_score = score;
                *best_move = legal_moves.moves[index];
            }
        }

        if (maximizing) {
            if (score > alpha) {
                alpha = score;
            }
        } else if (score < beta) {
            beta = score;
        }
    }

    return found;
}

static uint64_t perft(const Board *board, int depth) {
    if (depth == 0) {
        return 1ULL;
    }

    MoveList legal_moves;
    uint64_t nodes = 0;

    generate_legal_moves(board, &legal_moves);
    for (int index = 0; index < legal_moves.count; ++index) {
        Board next = *board;
        apply_move(&next, &legal_moves.moves[index]);
        nodes += perft(&next, depth - 1);
    }

    return nodes;
}

static const char *result_for_status(GameStatus status) {
    switch (status) {
        case STATUS_CHECKMATE_WHITE:
            return "1-0";
        case STATUS_CHECKMATE_BLACK:
            return "0-1";
        case STATUS_STALEMATE:
        case STATUS_DRAW_REPETITION:
        case STATUS_DRAW_FIFTY:
            return "1/2-1/2";
        case STATUS_CHECK:
        case STATUS_ONGOING:
        default:
            return "*";
    }
}

static void engine_rebuild_pgn(Engine *engine) {
    const char *source = engine->pgn_game.source[0] != '\0' ? engine->pgn_game.source : "current-game";
    if (pgn_build_from_history(&engine->pgn_game, engine->move_history, engine->move_history_len, engine->initial_fen, source)) {
        pgn_set_result(&engine->pgn_game, result_for_status(engine_status(engine)));
    }
}

static void engine_init(Engine *engine) {
    board_set_starting_position(&engine->board);
    engine->history_len = 0;
    engine->move_history_len = 0;
    engine->position_count = 1;
    engine->position_history[0] = board_hash(&engine->board);
    copy_text(engine->initial_fen, sizeof(engine->initial_fen), START_FEN);
    engine->chess960_id = 0;
    engine->chess960_mode = false;
    pgn_init_game(&engine->pgn_game, START_FEN, "current-game");
}

static bool engine_store_snapshot(Engine *engine) {
    if (engine->history_len >= MAX_HISTORY || engine->position_count >= MAX_POSITIONS) {
        return false;
    }
    engine->history[engine->history_len++] = engine->board;
    return true;
}

static bool engine_apply_move(Engine *engine, const Move *move) {
    if (engine->move_history_len >= MAX_HISTORY) {
        return false;
    }
    if (!engine_store_snapshot(engine)) {
        return false;
    }

    engine->move_history[engine->move_history_len++] = *move;
    apply_move(&engine->board, move);
    engine->position_history[engine->position_count++] = board_hash(&engine->board);
    engine_rebuild_pgn(engine);
    return true;
}

static bool engine_undo(Engine *engine) {
    if (engine->history_len == 0) {
        return false;
    }

    engine->board = engine->history[engine->history_len - 1];
    engine->history_len -= 1;
    if (engine->move_history_len > 0) {
        engine->move_history_len -= 1;
    }
    if (engine->position_count > 1) {
        engine->position_count -= 1;
    }
    engine_rebuild_pgn(engine);
    return true;
}

static void engine_reset(Engine *engine) {
    board_set_starting_position(&engine->board);
    engine->history_len = 0;
    engine->move_history_len = 0;
    engine->position_count = 1;
    engine->position_history[0] = board_hash(&engine->board);
    copy_text(engine->initial_fen, sizeof(engine->initial_fen), START_FEN);
    engine->chess960_id = 0;
    engine->chess960_mode = false;
    pgn_init_game(&engine->pgn_game, START_FEN, "current-game");
}

static bool engine_load_position(Engine *engine, const char *fen_string) {
    if (!board_load_fen(&engine->board, fen_string)) {
        return false;
    }
    engine->history_len = 0;
    engine->move_history_len = 0;
    engine->position_count = 1;
    engine->position_history[0] = board_hash(&engine->board);
    copy_text(engine->initial_fen, sizeof(engine->initial_fen), fen_string);
    engine->chess960_id = 0;
    engine->chess960_mode = false;
    pgn_init_game(&engine->pgn_game, fen_string, "current-game");
    return true;
}

static bool engine_load_pgn_game(Engine *engine, const PgnGame *game) {
    if (!board_load_fen(&engine->board, game->initial_fen)) {
        return false;
    }

    engine->history_len = 0;
    engine->move_history_len = 0;
    engine->position_count = 1;
    engine->position_history[0] = board_hash(&engine->board);
    copy_text(engine->initial_fen, sizeof(engine->initial_fen), game->initial_fen);
    engine->pgn_game = *game;
    engine->chess960_id = 0;
    engine->chess960_mode = false;

    for (int index = 0; index < game->move_count; ++index) {
        if (engine->move_history_len >= MAX_HISTORY || !engine_store_snapshot(engine)) {
            return false;
        }
        engine->move_history[engine->move_history_len++] = game->moves[index].move;
        apply_move(&engine->board, &game->moves[index].move);
        engine->position_history[engine->position_count++] = board_hash(&engine->board);
    }

    pgn_set_result(&engine->pgn_game, result_for_status(engine_status(engine)));
    return true;
}

static bool engine_load_chess960(Engine *engine, int chess960_id) {
    char fen[FEN_BUFFER_SIZE];

    chess960_fen(chess960_id, fen);
    if (!engine_load_position(engine, fen)) {
        return false;
    }

    engine->chess960_id = chess960_id;
    engine->chess960_mode = true;
    return true;
}

static int engine_repetition_count(const Engine *engine) {
    if (engine->position_count <= 0) {
        return 0;
    }

    uint64_t current = engine->position_history[engine->position_count - 1];
    int count = 0;
    for (int index = 0; index < engine->position_count; ++index) {
        if (engine->position_history[index] == current) {
            count += 1;
        }
    }
    return count;
}

static GameStatus engine_status(const Engine *engine) {
    if (engine->board.halfmove_clock >= 100) {
        return STATUS_DRAW_FIFTY;
    }
    if (engine_repetition_count(engine) >= 3) {
        return STATUS_DRAW_REPETITION;
    }

    MoveList legal_moves;
    bool moving_white = engine->board.white_to_move;
    bool in_check = is_in_check(&engine->board, moving_white);

    generate_legal_moves(&engine->board, &legal_moves);
    if (legal_moves.count == 0) {
        if (in_check) {
            return moving_white ? STATUS_CHECKMATE_BLACK : STATUS_CHECKMATE_WHITE;
        }
        return STATUS_STALEMATE;
    }

    return in_check ? STATUS_CHECK : STATUS_ONGOING;
}

static void copy_text(char *destination, size_t destination_size, const char *source) {
    if (destination_size == 0) {
        return;
    }
    if (source == NULL) {
        destination[0] = '\0';
        return;
    }
    snprintf(destination, destination_size, "%s", source);
}

static bool same_move(const Move *first, const Move *second) {
    return first->from == second->from &&
           first->to == second->to &&
           first->promotion == second->promotion &&
           first->is_castling == second->is_castling &&
           first->is_en_passant == second->is_en_passant;
}

static void square_to_text(int square, char buffer[3]) {
    buffer[0] = (char) ('a' + square_col(square));
    buffer[1] = (char) ('1' + square_row(square));
    buffer[2] = '\0';
}

static void pgn_put_tag(PgnGame *game, const char *name, const char *value) {
    for (int index = 0; index < game->tag_count; ++index) {
        if (strcmp(game->tags[index].name, name) == 0) {
            copy_text(game->tags[index].value, sizeof(game->tags[index].value), value);
            return;
        }
    }

    if (game->tag_count >= MAX_PGN_TAGS) {
        return;
    }

    copy_text(game->tags[game->tag_count].name, sizeof(game->tags[game->tag_count].name), name);
    copy_text(game->tags[game->tag_count].value, sizeof(game->tags[game->tag_count].value), value);
    game->tag_count += 1;
}

static const char *pgn_get_tag(const PgnGame *game, const char *name) {
    for (int index = 0; index < game->tag_count; ++index) {
        if (strcmp(game->tags[index].name, name) == 0) {
            return game->tags[index].value;
        }
    }
    return NULL;
}

static void pgn_init_game(PgnGame *game, const char *initial_fen, const char *source) {
    memset(game, 0, sizeof(*game));
    copy_text(game->initial_fen, sizeof(game->initial_fen), initial_fen);
    copy_text(game->source, sizeof(game->source), source != NULL ? source : "current-game");
    copy_text(game->result, sizeof(game->result), "*");
    pgn_put_tag(game, "Event", "CLI Game");
    pgn_put_tag(game, "Site", "Local");
    if (strcmp(initial_fen, START_FEN) != 0) {
        pgn_put_tag(game, "SetUp", "1");
        pgn_put_tag(game, "FEN", initial_fen);
    }
    pgn_put_tag(game, "Result", "*");
}

static void pgn_set_result(PgnGame *game, const char *result) {
    copy_text(game->result, sizeof(game->result), result);
    pgn_put_tag(game, "Result", result);
}

static void normalize_san(const char *san, char buffer[PGN_SAN_SIZE]) {
    size_t length = strlen(san);
    size_t cursor = 0;

    while (cursor < length && isdigit((unsigned char) san[cursor])) {
        cursor += 1;
    }
    while (cursor < length && san[cursor] == '.') {
        cursor += 1;
    }

    size_t out = 0;
    for (; cursor < length && out + 1 < PGN_SAN_SIZE; ++cursor) {
        char value = san[cursor];
        if (value == '0' && cursor + 2 < length && san[cursor + 1] == '-' && san[cursor + 2] == '0') {
            buffer[out++] = 'O';
        } else if (value != '!' && value != '?') {
            buffer[out++] = value;
        }
    }
    buffer[out] = '\0';

    while (out > 0 && (buffer[out - 1] == '+' || buffer[out - 1] == '#')) {
        buffer[--out] = '\0';
    }
    if (strcmp(buffer, "0-0") == 0) {
        copy_text(buffer, PGN_SAN_SIZE, "O-O");
    } else if (strcmp(buffer, "0-0-0") == 0) {
        copy_text(buffer, PGN_SAN_SIZE, "O-O-O");
    }
}

static void san_disambiguation(const Board *board, const Move *move, char buffer[3]) {
    MoveList legal_moves;
    char moving_piece = board->squares[move->from];
    bool same_file = false;
    bool same_rank = false;
    int count = 0;

    generate_legal_moves(board, &legal_moves);
    for (int index = 0; index < legal_moves.count; ++index) {
        Move candidate = legal_moves.moves[index];
        if (same_move(&candidate, move) ||
            candidate.to != move->to ||
            board->squares[candidate.from] != moving_piece) {
            continue;
        }
        count += 1;
        if (square_col(candidate.from) == square_col(move->from)) {
            same_file = true;
        }
        if (square_row(candidate.from) == square_row(move->from)) {
            same_rank = true;
        }
    }

    if (count == 0) {
        buffer[0] = '\0';
        return;
    }

    if (!same_file) {
        buffer[0] = (char) ('a' + square_col(move->from));
        buffer[1] = '\0';
        return;
    }
    if (!same_rank) {
        buffer[0] = (char) ('1' + square_row(move->from));
        buffer[1] = '\0';
        return;
    }

    buffer[0] = (char) ('a' + square_col(move->from));
    buffer[1] = (char) ('1' + square_row(move->from));
    buffer[2] = '\0';
}

static bool move_to_san(const Board *board, const Move *move, char buffer[PGN_SAN_SIZE]) {
    char piece = board->squares[move->from];
    char destination[3];
    bool is_capture = board->squares[move->to] != '.' || move->is_en_passant;
    char disambiguation[3] = "";
    char promotion[3] = "";
    Board next_board;
    MoveList legal_moves;

    if (piece == '.') {
        return false;
    }

    square_to_text(move->to, destination);

    if (move->promotion != '\0') {
        promotion[0] = '=';
        promotion[1] = (char) toupper((unsigned char) move->promotion);
        promotion[2] = '\0';
    }

    if (move->is_castling) {
        copy_text(buffer, PGN_SAN_SIZE, square_col(move->to) == 6 ? "O-O" : "O-O-O");
    } else if (toupper((unsigned char) piece) == 'P') {
        char prefix[3] = "";
        if (is_capture) {
            prefix[0] = (char) ('a' + square_col(move->from));
            prefix[1] = 'x';
            prefix[2] = '\0';
        }
        snprintf(buffer, PGN_SAN_SIZE, "%s%s%s", prefix, destination, promotion);
    } else {
        san_disambiguation(board, move, disambiguation);
        snprintf(buffer, PGN_SAN_SIZE, "%c%s%s%s%s",
                 (char) toupper((unsigned char) piece),
                 disambiguation,
                 is_capture ? "x" : "",
                 destination,
                 promotion);
    }

    next_board = *board;
    apply_move(&next_board, move);
    if (is_in_check(&next_board, next_board.white_to_move)) {
        generate_legal_moves(&next_board, &legal_moves);
        strncat(buffer, legal_moves.count == 0 ? "#" : "+", PGN_SAN_SIZE - strlen(buffer) - 1);
    }
    return true;
}

static bool san_to_move(const Board *board, const char *san, Move *resolved) {
    MoveList legal_moves;
    char expected[PGN_SAN_SIZE];
    char actual[PGN_SAN_SIZE];

    normalize_san(san, expected);
    generate_legal_moves(board, &legal_moves);
    for (int index = 0; index < legal_moves.count; ++index) {
        if (!move_to_san(board, &legal_moves.moves[index], actual)) {
            continue;
        }
        normalize_san(actual, actual);
        if (strcmp(expected, actual) == 0) {
            *resolved = legal_moves.moves[index];
            return true;
        }
    }
    return false;
}

static bool is_result_token(const char *token) {
    return strcmp(token, "1-0") == 0 ||
           strcmp(token, "0-1") == 0 ||
           strcmp(token, "1/2-1/2") == 0 ||
           strcmp(token, "*") == 0;
}

static bool is_move_number_token(const char *token) {
    size_t length = strlen(token);
    size_t index = 0;

    if (length == 0) {
        return false;
    }
    while (index < length && isdigit((unsigned char) token[index])) {
        index += 1;
    }
    if (index == 0) {
        return false;
    }
    while (index < length && token[index] == '.') {
        index += 1;
    }
    return index == length;
}

static bool is_nag_token(const char *token) {
    if (token[0] != '$' || token[1] == '\0') {
        return false;
    }
    for (size_t index = 1; token[index] != '\0'; ++index) {
        if (!isdigit((unsigned char) token[index])) {
            return false;
        }
    }
    return true;
}

static void strip_comments_and_variations(const char *input, char *output) {
    int variation_depth = 0;
    bool in_braces = false;
    bool in_semicolon = false;
    size_t out = 0;

    for (size_t index = 0; input[index] != '\0'; ++index) {
        char value = input[index];

        if (in_semicolon) {
            if (value == '\n') {
                in_semicolon = false;
                output[out++] = value;
            }
            continue;
        }
        if (in_braces) {
            if (value == '}') {
                in_braces = false;
            }
            continue;
        }
        if (variation_depth > 0) {
            if (value == '(') {
                variation_depth += 1;
            } else if (value == ')') {
                variation_depth -= 1;
            }
            continue;
        }

        if (value == '{') {
            in_braces = true;
            continue;
        }
        if (value == ';') {
            in_semicolon = true;
            continue;
        }
        if (value == '(') {
            variation_depth = 1;
            continue;
        }
        output[out++] = value;
    }
    output[out] = '\0';
}

static bool pgn_parse_tag_line(PgnGame *game, const char *line) {
    const char *cursor = line;
    const char *space = NULL;
    const char *quote_start = NULL;
    const char *quote_end = NULL;
    char name[PGN_TAG_NAME_SIZE];
    char value[PGN_TAG_VALUE_SIZE];

    if (*cursor != '[') {
        return false;
    }
    cursor += 1;
    space = strchr(cursor, ' ');
    if (space == NULL) {
        return false;
    }

    size_t name_length = (size_t) (space - cursor);
    if (name_length == 0 || name_length >= sizeof(name)) {
        return false;
    }
    memcpy(name, cursor, name_length);
    name[name_length] = '\0';

    quote_start = strchr(space, '"');
    quote_end = strrchr(space, '"');
    if (quote_start == NULL || quote_end == NULL || quote_end <= quote_start) {
        return false;
    }
    size_t value_length = (size_t) (quote_end - quote_start - 1);
    if (value_length >= sizeof(value)) {
        value_length = sizeof(value) - 1;
    }
    memcpy(value, quote_start + 1, value_length);
    value[value_length] = '\0';

    pgn_put_tag(game, name, value);
    return true;
}

static bool pgn_build_from_history(PgnGame *game, const Move *move_history, int move_count, const char *initial_fen, const char *source) {
    Board board;

    if (!board_load_fen(&board, initial_fen)) {
        return false;
    }

    pgn_init_game(game, initial_fen, source);
    for (int index = 0; index < move_count && index < MAX_HISTORY; ++index) {
        PgnMoveNode *node = &game->moves[game->move_count];
        if (!move_to_san(&board, &move_history[index], node->san)) {
            return false;
        }
        board_export_fen(&board, node->fen_before, sizeof(node->fen_before));
        node->move = move_history[index];
        apply_move(&board, &move_history[index]);
        board_export_fen(&board, node->fen_after, sizeof(node->fen_after));
        game->move_count += 1;
    }
    return true;
}

static void starting_ply_from_fen(const char *fen, int *move_number, bool *white_to_move) {
    char board_part[80];
    char side = 'w';
    char castling[16];
    char en_passant[16];
    int halfmove = 0;
    int fullmove = 1;

    if (sscanf(fen, "%79s %c %15s %15s %d %d", board_part, &side, castling, en_passant, &halfmove, &fullmove) == 6) {
        *move_number = fullmove > 0 ? fullmove : 1;
        *white_to_move = side != 'b';
        return;
    }

    *move_number = 1;
    *white_to_move = true;
}

static void pgn_serialize(const PgnGame *game, char *buffer, size_t buffer_size) {
    char *cursor = buffer;
    size_t remaining = buffer_size;
    int move_number = 1;
    bool white_to_move = true;

    if (buffer_size == 0) {
        return;
    }
    buffer[0] = '\0';

    for (int index = 0; index < game->tag_count; ++index) {
        append_format(&cursor, &remaining, "[%s \"%s\"]\n", game->tags[index].name, game->tags[index].value);
    }
    if (game->tag_count > 0) {
        append_format(&cursor, &remaining, "\n");
    }

    starting_ply_from_fen(game->initial_fen, &move_number, &white_to_move);
    for (int index = 0; index < game->move_count; ++index) {
        if (white_to_move) {
            append_format(&cursor, &remaining, "%d. %s", move_number, game->moves[index].san);
        } else if (index == 0) {
            append_format(&cursor, &remaining, "%d... %s", move_number, game->moves[index].san);
        } else {
            append_format(&cursor, &remaining, "%s", game->moves[index].san);
        }

        if (index + 1 < game->move_count || game->result[0] != '\0') {
            append_format(&cursor, &remaining, " ");
        }

        if (!white_to_move) {
            move_number += 1;
        }
        white_to_move = !white_to_move;
    }

    append_format(&cursor, &remaining, "%s\n", game->result[0] != '\0' ? game->result : "*");
}

static bool pgn_parse(const char *content, const char *source, PgnGame *game, char *error, size_t error_size) {
    size_t content_length = strlen(content);
    char *movetext = calloc(content_length + 1, sizeof(char));
    char *stripped = calloc(content_length + 1, sizeof(char));
    Board board;
    bool success = false;

    if (movetext == NULL || stripped == NULL) {
        copy_text(error, error_size, "out of memory");
        goto cleanup;
    }

    pgn_init_game(game, START_FEN, source);

    const char *cursor = content;
    size_t movetext_length = 0;
    while (*cursor != '\0') {
        const char *line_end = cursor;
        while (*line_end != '\0' && *line_end != '\n') {
            line_end += 1;
        }

        size_t line_length = (size_t) (line_end - cursor);
        while (line_length > 0 && (cursor[line_length - 1] == '\r' || isspace((unsigned char) cursor[line_length - 1]))) {
            line_length -= 1;
        }

        size_t start = 0;
        while (start < line_length && isspace((unsigned char) cursor[start])) {
            start += 1;
        }

        if (start < line_length && cursor[start] == '[' && cursor[line_length - 1] == ']') {
            char line_buffer[PGN_TAG_VALUE_SIZE + PGN_TAG_NAME_SIZE + 8];
            size_t trimmed_length = line_length - start;
            if (trimmed_length >= sizeof(line_buffer)) {
                trimmed_length = sizeof(line_buffer) - 1;
            }
            memcpy(line_buffer, cursor + start, trimmed_length);
            line_buffer[trimmed_length] = '\0';
            if (!pgn_parse_tag_line(game, line_buffer)) {
                copy_text(error, error_size, "invalid PGN tag");
                goto cleanup;
            }
        } else if (start < line_length) {
            size_t trimmed_length = line_length - start;
            memcpy(movetext + movetext_length, cursor + start, trimmed_length);
            movetext_length += trimmed_length;
            movetext[movetext_length++] = ' ';
        }

        cursor = *line_end == '\n' ? line_end + 1 : line_end;
    }
    movetext[movetext_length] = '\0';

    const char *initial_fen = pgn_get_tag(game, "FEN");
    if (initial_fen == NULL) {
        initial_fen = START_FEN;
    }
    copy_text(game->initial_fen, sizeof(game->initial_fen), initial_fen);

    if (!board_load_fen(&board, initial_fen)) {
        copy_text(error, error_size, "invalid PGN FEN");
        goto cleanup;
    }

    strip_comments_and_variations(movetext, stripped);

    for (char *token = strtok(stripped, " \t\r\n"); token != NULL; token = strtok(NULL, " \t\r\n")) {
        if (is_move_number_token(token) || is_nag_token(token)) {
            continue;
        }
        if (is_result_token(token)) {
            pgn_set_result(game, token);
            continue;
        }

        if (game->move_count >= MAX_HISTORY) {
            copy_text(error, error_size, "PGN move limit exceeded");
            goto cleanup;
        }

        PgnMoveNode *node = &game->moves[game->move_count];
        if (!san_to_move(&board, token, &node->move) || !move_to_san(&board, &node->move, node->san)) {
            copy_text(error, error_size, "unresolved SAN move");
            goto cleanup;
        }
        board_export_fen(&board, node->fen_before, sizeof(node->fen_before));
        apply_move(&board, &node->move);
        board_export_fen(&board, node->fen_after, sizeof(node->fen_after));
        game->move_count += 1;
    }

    if (pgn_get_tag(game, "Result") == NULL) {
        pgn_put_tag(game, "Result", game->result[0] != '\0' ? game->result : "*");
    }
    if (game->result[0] == '\0') {
        copy_text(game->result, sizeof(game->result), pgn_get_tag(game, "Result"));
    }
    success = true;

cleanup:
    free(movetext);
    free(stripped);
    return success;
}

static void chess960_backrank(int chess960_id, char buffer[9]) {
    static const int knight_table[10][2] = {
        {0, 1}, {0, 2}, {0, 3}, {0, 4}, {1, 2},
        {1, 3}, {1, 4}, {2, 3}, {2, 4}, {3, 4},
    };
    char pieces[8] = {0};
    int empty[8];
    int empty_count = 0;
    int remainder = chess960_id % 4;
    int value = chess960_id / 4;

    pieces[2 * remainder + 1] = 'b';
    remainder = value % 4;
    value /= 4;
    pieces[2 * remainder] = 'b';

    remainder = value % 6;
    value /= 6;
    for (int index = 0; index < 8; ++index) {
        if (pieces[index] == 0) {
            empty[empty_count++] = index;
        }
    }
    pieces[empty[remainder]] = 'q';

    empty_count = 0;
    for (int index = 0; index < 8; ++index) {
        if (pieces[index] == 0) {
            empty[empty_count++] = index;
        }
    }
    pieces[empty[knight_table[value][0]]] = 'n';
    pieces[empty[knight_table[value][1]]] = 'n';

    empty_count = 0;
    for (int index = 0; index < 8; ++index) {
        if (pieces[index] == 0) {
            empty[empty_count++] = index;
        }
    }
    pieces[empty[0]] = 'r';
    pieces[empty[1]] = 'k';
    pieces[empty[2]] = 'r';

    for (int index = 0; index < 8; ++index) {
        buffer[index] = pieces[index];
    }
    buffer[8] = '\0';
}

static void chess960_fen(int chess960_id, char buffer[FEN_BUFFER_SIZE]) {
    char backrank[9];
    char white_backrank[9];
    chess960_backrank(chess960_id, backrank);
    for (int index = 0; index < 8; ++index) {
        white_backrank[index] = (char) toupper((unsigned char) backrank[index]);
    }
    white_backrank[8] = '\0';
    snprintf(buffer, FEN_BUFFER_SIZE, "%s/pppppppp/8/8/8/8/PPPPPPPP/%s w - - 0 1", backrank, white_backrank);
}

static void print_status(const Engine *engine) {
    switch (engine_status(engine)) {
        case STATUS_CHECKMATE_WHITE:
            printf("CHECKMATE: White wins\n");
            break;
        case STATUS_CHECKMATE_BLACK:
            printf("CHECKMATE: Black wins\n");
            break;
        case STATUS_STALEMATE:
            printf("STALEMATE: Draw\n");
            break;
        case STATUS_DRAW_REPETITION:
            printf("DRAW: REPETITION\n");
            break;
        case STATUS_DRAW_FIFTY:
            printf("DRAW: 50-MOVE\n");
            break;
        case STATUS_CHECK:
            printf("OK: CHECK\n");
            break;
        case STATUS_ONGOING:
        default:
            printf("OK: ONGOING\n");
            break;
    }
}

static bool parse_square_text(const char *text, int *square) {
    if (text[0] < 'a' || text[0] > 'h' || text[1] < '1' || text[1] > '8') {
        return false;
    }
    *square = make_square(text[1] - '1', text[0] - 'a');
    return true;
}

static bool resolve_user_move(const Engine *engine, const char *move_text, Move *resolved) {
    MoveList legal_moves;
    int from = -1;
    int to = -1;
    char promotion = '\0';
    Move queen_fallback;
    bool has_queen_fallback = false;

    if (strlen(move_text) < 4 || strlen(move_text) > 5) {
        return false;
    }
    if (!parse_square_text(move_text, &from) || !parse_square_text(move_text + 2, &to)) {
        return false;
    }
    if (strlen(move_text) == 5) {
        promotion = (char) toupper((unsigned char) move_text[4]);
        if (strchr("QRBN", promotion) == NULL) {
            return false;
        }
    }

    generate_legal_moves(&engine->board, &legal_moves);
    for (int index = 0; index < legal_moves.count; ++index) {
        Move candidate = legal_moves.moves[index];
        if (candidate.from != from || candidate.to != to) {
            continue;
        }

        if (promotion != '\0') {
            if (candidate.promotion == promotion) {
                *resolved = candidate;
                return true;
            }
            continue;
        }

        if (candidate.promotion == '\0') {
            *resolved = candidate;
            return true;
        }
        if (candidate.promotion == 'Q' && !has_queen_fallback) {
            queen_fallback = candidate;
            has_queen_fallback = true;
        }
    }

    if (has_queen_fallback) {
        *resolved = queen_fallback;
        return true;
    }

    return false;
}

static bool parse_int_argument(const char *text, int *value) {
    char *end = NULL;
    long parsed = 0;

    if (text == NULL || *text == '\0') {
        return false;
    }

    errno = 0;
    parsed = strtol(text, &end, 10);
    if (end == text || *end != '\0' || errno == ERANGE || parsed < INT_MIN || parsed > INT_MAX) {
        return false;
    }
    *value = (int) parsed;
    return true;
}

static void trim_line(char *line) {
    size_t length = strlen(line);
    while (length > 0 && (line[length - 1] == '\n' || line[length - 1] == '\r' || isspace((unsigned char) line[length - 1]))) {
        line[length - 1] = '\0';
        length -= 1;
    }

    char *start = line;
    while (*start != '\0' && isspace((unsigned char) *start)) {
        start += 1;
    }
    if (start != line) {
        memmove(line, start, strlen(start) + 1);
    }
}

static bool starts_with(const char *text, const char *prefix) {
    return strncmp(text, prefix, strlen(prefix)) == 0;
}

static const char *draw_reason_text(const Engine *engine) {
    if (engine->board.halfmove_clock >= 100) {
        return "fifty_moves";
    }
    if (engine_repetition_count(engine) >= 3) {
        return "repetition";
    }
    return "none";
}

static bool run_self_test(void) {
    Engine engine;
    char fen[FEN_BUFFER_SIZE];
    Move move;

    engine_init(&engine);
    board_export_fen(&engine.board, fen, sizeof(fen));
    if (strcmp(fen, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1") != 0) {
        fprintf(stderr, "Self-test failed: starting FEN mismatch\n");
        return false;
    }

    if (!resolve_user_move(&engine, "e2e4", &move) || !engine_apply_move(&engine, &move)) {
        fprintf(stderr, "Self-test failed: e2e4\n");
        return false;
    }
    board_export_fen(&engine.board, fen, sizeof(fen));
    if (strcmp(fen, "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1") != 0) {
        fprintf(stderr, "Self-test failed: e2e4 FEN mismatch\n");
        return false;
    }

    if (!engine_load_position(&engine, "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1") ||
        !resolve_user_move(&engine, "e1g1", &move) || !engine_apply_move(&engine, &move)) {
        fprintf(stderr, "Self-test failed: castling\n");
        return false;
    }
    board_export_fen(&engine.board, fen, sizeof(fen));
    if (strcmp(fen, "r3k2r/8/8/8/8/8/8/R4RK1 b kq - 1 1") != 0) {
        fprintf(stderr, "Self-test failed: castling FEN mismatch\n");
        return false;
    }

    if (!engine_load_position(&engine, "rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3") ||
        !resolve_user_move(&engine, "e5f6", &move) || !engine_apply_move(&engine, &move)) {
        fprintf(stderr, "Self-test failed: en passant\n");
        return false;
    }
    board_export_fen(&engine.board, fen, sizeof(fen));
    if (strcmp(fen, "rnbqkbnr/ppp1p1pp/5P2/3p4/8/8/PPPP1PPP/RNBQKBNR b KQkq - 0 3") != 0) {
        fprintf(stderr, "Self-test failed: en passant FEN mismatch\n");
        return false;
    }

    engine_reset(&engine);
    if (perft(&engine.board, 3) != 8902ULL) {
        fprintf(stderr, "Self-test failed: perft(3)\n");
        return false;
    }

    printf("Self-test passed\n");
    return true;
}

static bool process_command(Engine *engine, char *line) {
    if (strcmp(line, "quit") == 0 || strcmp(line, "exit") == 0) {
        return false;
    }

    if (strcmp(line, "new") == 0) {
        engine_reset(engine);
        printf("OK: New game started\n");
        return true;
    }

    if (strcmp(line, "undo") == 0) {
        if (engine_undo(engine)) {
            printf("OK: undo\n");
        } else {
            printf("ERROR: No moves to undo\n");
        }
        return true;
    }

    if (strcmp(line, "status") == 0) {
        print_status(engine);
        return true;
    }

    if (strcmp(line, "export") == 0) {
        char fen[FEN_BUFFER_SIZE];
        board_export_fen(&engine->board, fen, sizeof(fen));
        printf("FEN: %s\n", fen);
        return true;
    }

    if (strcmp(line, "eval") == 0) {
        printf("EVALUATION: %d\n", evaluate_board(&engine->board));
        return true;
    }

    if (strcmp(line, "hash") == 0) {
        printf("HASH: %016llx\n", (unsigned long long) board_hash(&engine->board));
        return true;
    }

    if (strcmp(line, "draws") == 0) {
        const char *reason = draw_reason_text(engine);
        bool is_draw = strcmp(reason, "none") != 0;
        printf("DRAWS: repetition=%d; halfmove=%d; draw=%s; reason=%s\n",
               engine_repetition_count(engine),
               engine->board.halfmove_clock,
               is_draw ? "true" : "false",
               reason);
        return true;
    }

    if (strcmp(line, "history") == 0) {
        printf("HISTORY: count=%d; current=%016llx\n",
               engine->position_count,
               (unsigned long long) board_hash(&engine->board));
        return true;
    }

    if (strcmp(line, "help") == 0) {
        printf("OK: commands=new move undo status fen export eval hash draws history ai perft pgn uci isready new960 position960 help quit\n");
        return true;
    }

    if (strcmp(line, "uci") == 0) {
        printf("id name C Chess Engine\n");
        printf("id author The Great Analysis Challenge\n");
        printf("uciok\n");
        return true;
    }

    if (strcmp(line, "isready") == 0) {
        printf("readyok\n");
        return true;
    }

    if (strcmp(line, "new960") == 0) {
        char backrank[9];
        if (!engine_load_chess960(engine, 0)) {
            printf("ERROR: Could not load Chess960 position\n");
            return true;
        }
        chess960_backrank(0, backrank);
        printf("OK: New game started\n");
        printf("960: new game id=0; backrank=%s\n", backrank);
        return true;
    }

    if (strcmp(line, "position960") == 0) {
        char backrank[9];
        char fen[FEN_BUFFER_SIZE];
        chess960_backrank(engine->chess960_id, backrank);
        chess960_fen(engine->chess960_id, fen);
        printf("960: id=%d; mode=%s; backrank=%s; fen=%s\n",
               engine->chess960_id,
               engine->chess960_mode ? "chess960" : "standard",
               backrank,
               fen);
        return true;
    }

    if (starts_with(line, "move ")) {
        Move move;
        if (!resolve_user_move(engine, line + 5, &move)) {
            printf("ERROR: Illegal move\n");
            return true;
        }
        if (!engine_apply_move(engine, &move)) {
            printf("ERROR: History capacity exceeded\n");
            return true;
        }
        char move_text[6];
        move_to_string(&move, move_text);
        printf("OK: %s\n", move_text);
        return true;
    }

    if (starts_with(line, "fen ")) {
        if (engine_load_position(engine, line + 4)) {
            printf("OK: position loaded\n");
        } else {
            printf("ERROR: Invalid FEN string\n");
        }
        return true;
    }

    if (starts_with(line, "ai ")) {
        int depth = 0;
        Move best_move;
        int best_score = 0;
        long long started_at = current_time_ms();

        if (!parse_int_argument(line + 3, &depth) || depth < 1 || depth > 5) {
            printf("ERROR: AI depth must be 1-5\n");
            return true;
        }
        if (!select_best_move(&engine->board, depth, &best_move, &best_score)) {
            printf("ERROR: No legal moves available\n");
            return true;
        }
        if (!engine_apply_move(engine, &best_move)) {
            printf("ERROR: History capacity exceeded\n");
            return true;
        }

        char move_text[6];
        move_to_string(&best_move, move_text);
        printf("AI: %s (depth=%d, eval=%d, time=%lldms)\n",
               move_text, depth, best_score, current_time_ms() - started_at);
        return true;
    }

    if (starts_with(line, "perft ")) {
        int depth = 0;
        if (!parse_int_argument(line + 6, &depth) || depth < 0 || depth > 6) {
            printf("ERROR: Invalid perft depth\n");
            return true;
        }
        printf("NODES: depth=%d; count=%llu; time=0ms\n",
               depth, (unsigned long long) perft(&engine->board, depth));
        return true;
    }

    if (starts_with(line, "new960 ")) {
        int chess960_id = 0;
        char backrank[9];
        if (!parse_int_argument(line + 7, &chess960_id) || chess960_id < 0 || chess960_id > 959) {
            printf("ERROR: new960 id must be between 0 and 959\n");
            return true;
        }
        if (!engine_load_chess960(engine, chess960_id)) {
            printf("ERROR: Could not load Chess960 position\n");
            return true;
        }
        chess960_backrank(chess960_id, backrank);
        printf("OK: New game started\n");
        printf("960: new game id=%d; backrank=%s\n", chess960_id, backrank);
        return true;
    }

    if (starts_with(line, "pgn ")) {
        if (starts_with(line, "pgn load ")) {
            PgnGame game;
            char error[128] = "";
            char *content = NULL;
            const char *path = line + 9;
            FILE *handle = fopen(path, "rb");
            if (handle == NULL) {
                printf("ERROR: pgn load failed: file not found: %s\n", path);
                return true;
            }

            if (fseek(handle, 0, SEEK_END) != 0) {
                fclose(handle);
                printf("ERROR: pgn load failed: could not seek\n");
                return true;
            }
            long length = ftell(handle);
            rewind(handle);
            if (length < 0) {
                fclose(handle);
                printf("ERROR: pgn load failed: could not read size\n");
                return true;
            }

            content = calloc((size_t) length + 1U, sizeof(char));
            if (content == NULL) {
                fclose(handle);
                printf("ERROR: pgn load failed: out of memory\n");
                return true;
            }
            if (fread(content, 1, (size_t) length, handle) != (size_t) length) {
                free(content);
                fclose(handle);
                printf("ERROR: pgn load failed: could not read file\n");
                return true;
            }
            fclose(handle);

            if (!pgn_parse(content, path, &game, error, sizeof(error)) || !engine_load_pgn_game(engine, &game)) {
                printf("ERROR: pgn load failed: %s\n", error[0] != '\0' ? error : "could not load PGN");
                free(content);
                return true;
            }
            free(content);
            printf("PGN: loaded source=%s\n", path);
            return true;
        }

        if (strcmp(line, "pgn show") == 0) {
            size_t buffer_size = (size_t) engine->pgn_game.move_count * 96U + (size_t) engine->pgn_game.tag_count * 320U + 512U;
            char *buffer = calloc(buffer_size, sizeof(char));
            if (buffer == NULL) {
                printf("ERROR: pgn show failed: out of memory\n");
                return true;
            }
            pgn_serialize(&engine->pgn_game, buffer, buffer_size);
            printf("PGN: source=%s; moves=%d\n", engine->pgn_game.source, engine->pgn_game.move_count);
            fputs(buffer, stdout);
            free(buffer);
            return true;
        }

        if (strcmp(line, "pgn moves") == 0) {
            if (engine->pgn_game.move_count == 0) {
                printf("PGN: moves (none)\n");
                return true;
            }
            printf("PGN: moves");
            for (int index = 0; index < engine->pgn_game.move_count; ++index) {
                printf(" %s", engine->pgn_game.moves[index].san);
            }
            printf("\n");
            return true;
        }

        printf("ERROR: Unsupported pgn command\n");
        return true;
    }

    printf("ERROR: Invalid command\n");
    return true;
}

int main(int argc, char **argv) {
    Engine engine;
    char line[512];

    if (argc > 1 && strcmp(argv[1], "--self-test") == 0) {
        return run_self_test() ? 0 : 1;
    }

    engine_init(&engine);
    while (fgets(line, sizeof(line), stdin) != NULL) {
        trim_line(line);
        if (line[0] == '\0') {
            continue;
        }
        if (!process_command(&engine, line)) {
            break;
        }
        fflush(stdout);
    }

    return 0;
}
