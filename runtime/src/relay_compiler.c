#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "relay_compiler.h"

/* Lexer Implementation */
void lexer_init(Lexer *lexer, const char *source) {
    lexer->source = source;
    lexer->current = source;
    lexer->line = 1;
    lexer->col = 1;
}

static bool is_at_end(Lexer *lexer) {
    return *lexer->current == '\0';
}

static char advance(Lexer *lexer) {
    char c = *lexer->current++;
    lexer->col++;
    return c;
}

static char peek(Lexer *lexer) {
    return *lexer->current;
}

static char peek_next(Lexer *lexer) {
    if (is_at_end(lexer)) return '\0';
    return lexer->current[1];
}

static bool match(Lexer *lexer, char expected) {
    if (is_at_end(lexer) || *lexer->current != expected) {
        return false;
    }
    lexer->current++;
    lexer->col++;
    return true;
}

static Token make_token(Lexer *lexer, TokenType type, const char *start, size_t len, uint32_t line, uint32_t col) {
    (void)lexer;
    Token t;
    t.type = type;
    t.start = start;
    t.length = len;
    t.line = line;
    t.col = col;
    return t;
}

static Token error_token(Lexer *lexer, const char *msg) {
    Token t;
    t.type = TOK_ERROR;
    t.start = msg;
    t.length = strlen(msg);
    t.line = lexer->line;
    t.col = lexer->col;
    return t;
}

static void skip_whitespace_and_comments(Lexer *lexer) {
    for (;;) {
        char c = peek(lexer);
        if (c == ' ' || c == '\t' || c == '\r') {
            advance(lexer);
        } else if (c == '\'') {
            /* Line comment starting with single quote */
            while (peek(lexer) != '\n' && !is_at_end(lexer)) {
                advance(lexer);
            }
        } else {
            break;
        }
    }
}

static TokenType check_keyword(const char *start, size_t len) {
    char buf[32];
    if (len >= sizeof(buf)) return TOK_IDENTIFIER;
    for (size_t i = 0; i < len; ++i) {
        buf[i] = (char)toupper((unsigned char)start[i]);
    }
    buf[len] = '\0';

    if (strcmp(buf, "SUB") == 0) return TOK_SUB;
    if (strcmp(buf, "FUNCTION") == 0) return TOK_FUNCTION;
    if (strcmp(buf, "END") == 0) return TOK_END;
    if (strcmp(buf, "DIM") == 0) return TOK_DIM;
    if (strcmp(buf, "AS") == 0) return TOK_AS;
    if (strcmp(buf, "INTEGER") == 0) return TOK_INTEGER;
    if (strcmp(buf, "DOUBLE") == 0) return TOK_DOUBLE;
    if (strcmp(buf, "STRING") == 0) return TOK_STRING;
    if (strcmp(buf, "TYPE") == 0) return TOK_TYPE;
    if (strcmp(buf, "IF") == 0) return TOK_IF;
    if (strcmp(buf, "THEN") == 0) return TOK_THEN;
    if (strcmp(buf, "ELSE") == 0) return TOK_ELSE;
    if (strcmp(buf, "ELSEIF") == 0) return TOK_ELSEIF;
    if (strcmp(buf, "FOR") == 0) return TOK_FOR;
    if (strcmp(buf, "TO") == 0) return TOK_TO;
    if (strcmp(buf, "STEP") == 0) return TOK_STEP;
    if (strcmp(buf, "NEXT") == 0) return TOK_NEXT;
    if (strcmp(buf, "WHILE") == 0) return TOK_WHILE;
    if (strcmp(buf, "WEND") == 0) return TOK_WEND;
    if (strcmp(buf, "DO") == 0) return TOK_DO;
    if (strcmp(buf, "LOOP") == 0) return TOK_LOOP;
    if (strcmp(buf, "UNTIL") == 0) return TOK_UNTIL;
    if (strcmp(buf, "SELECT") == 0) return TOK_SELECT;
    if (strcmp(buf, "CASE") == 0) return TOK_CASE;
    if (strcmp(buf, "PRINT") == 0) return TOK_PRINT;
    if (strcmp(buf, "INPUT") == 0) return TOK_INPUT;
    if (strcmp(buf, "RETURN") == 0) return TOK_RETURN;
    if (strcmp(buf, "CONST") == 0) return TOK_CONST;
    if (strcmp(buf, "CALL") == 0) return TOK_CALL;
    if (strcmp(buf, "EXIT") == 0) return TOK_EXIT;
    if (strcmp(buf, "AND") == 0) return TOK_AND;
    if (strcmp(buf, "OR") == 0) return TOK_OR;
    if (strcmp(buf, "NOT") == 0) return TOK_NOT;
    if (strcmp(buf, "XOR") == 0) return TOK_XOR;
    if (strcmp(buf, "MOD") == 0) return TOK_MOD;

    return TOK_IDENTIFIER;
}

Token lexer_next_token(Lexer *lexer) {
    skip_whitespace_and_comments(lexer);

    const char *start = lexer->current;
    uint32_t line = lexer->line;
    uint32_t col = lexer->col;

    if (is_at_end(lexer)) {
        return make_token(lexer, TOK_EOF, start, 0, line, col);
    }

    char c = advance(lexer);

    if (c == '\n') {
        lexer->line++;
        lexer->col = 1;
        return make_token(lexer, TOK_NEWLINE, start, 1, line, col);
    }

    if (c == ':') return make_token(lexer, TOK_COLON, start, 1, line, col);
    if (c == '(') return make_token(lexer, TOK_LPAREN, start, 1, line, col);
    if (c == ')') return make_token(lexer, TOK_RPAREN, start, 1, line, col);
    if (c == ',') return make_token(lexer, TOK_COMMA, start, 1, line, col);
    if (c == ';') return make_token(lexer, TOK_SEMICOLON, start, 1, line, col);
    if (c == '.') return make_token(lexer, TOK_DOT, start, 1, line, col);
    if (c == '+') return make_token(lexer, TOK_PLUS, start, 1, line, col);
    if (c == '-') return make_token(lexer, TOK_MINUS, start, 1, line, col);
    if (c == '*') return make_token(lexer, TOK_STAR, start, 1, line, col);
    if (c == '/') return make_token(lexer, TOK_SLASH, start, 1, line, col);
    if (c == '\\') return make_token(lexer, TOK_BACKSLASH, start, 1, line, col);
    if (c == '^') return make_token(lexer, TOK_CARET, start, 1, line, col);

    if (c == '=') return make_token(lexer, TOK_EQUAL, start, 1, line, col);
    if (c == '<') {
        if (match(lexer, '>')) return make_token(lexer, TOK_NOT_EQUAL, start, 2, line, col);
        if (match(lexer, '=')) return make_token(lexer, TOK_LESS_EQUAL, start, 2, line, col);
        return make_token(lexer, TOK_LESS, start, 1, line, col);
    }
    if (c == '>') {
        if (match(lexer, '=')) return make_token(lexer, TOK_GREATER_EQUAL, start, 2, line, col);
        return make_token(lexer, TOK_GREATER, start, 1, line, col);
    }

    /* String Literals */
    if (c == '"') {
        const char *str_start = lexer->current;
        while (peek(lexer) != '"' && !is_at_end(lexer)) {
            if (peek(lexer) == '\n') {
                lexer->line++;
                lexer->col = 1;
            }
            advance(lexer);
        }
        if (is_at_end(lexer)) {
            return error_token(lexer, "Unterminated string literal");
        }
        size_t len = (size_t)(lexer->current - str_start);
        advance(lexer); /* Skip closing quote */
        return make_token(lexer, TOK_STRING_LITERAL, str_start, len, line, col);
    }

    /* Number Literals */
    if (isdigit((unsigned char)c) || (c == '.' && isdigit((unsigned char)peek(lexer)))) {
        bool is_float = (c == '.');
        while (isdigit((unsigned char)peek(lexer))) {
            advance(lexer);
        }
        if (peek(lexer) == '.' && isdigit((unsigned char)peek_next(lexer))) {
            is_float = true;
            advance(lexer);
            while (isdigit((unsigned char)peek(lexer))) {
                advance(lexer);
            }
        }
        if (peek(lexer) == 'e' || peek(lexer) == 'E') {
            is_float = true;
            advance(lexer);
            if (peek(lexer) == '+' || peek(lexer) == '-') {
                advance(lexer);
            }
            while (isdigit((unsigned char)peek(lexer))) {
                advance(lexer);
            }
        }
        size_t len = (size_t)(lexer->current - start);
        return make_token(lexer, is_float ? TOK_FLOAT_LITERAL : TOK_INT_LITERAL, start, len, line, col);
    }

    /* Identifiers and Keywords */
    if (isalpha((unsigned char)c) || c == '_') {
        while (isalnum((unsigned char)peek(lexer)) || peek(lexer) == '_' || peek(lexer) == '$') {
            advance(lexer);
        }
        size_t len = (size_t)(lexer->current - start);
        TokenType kw = check_keyword(start, len);
        return make_token(lexer, kw, start, len, line, col);
    }

    return error_token(lexer, "Unexpected character");
}

const char *token_type_name(TokenType type) {
    switch (type) {
        case TOK_EOF: return "EOF";
        case TOK_ERROR: return "ERROR";
        case TOK_NEWLINE: return "NEWLINE";
        case TOK_COLON: return "COLON";
        case TOK_IDENTIFIER: return "IDENTIFIER";
        case TOK_INT_LITERAL: return "INT_LIT";
        case TOK_FLOAT_LITERAL: return "FLOAT_LIT";
        case TOK_STRING_LITERAL: return "STRING_LIT";
        case TOK_SUB: return "SUB";
        case TOK_FUNCTION: return "FUNCTION";
        case TOK_END: return "END";
        case TOK_DIM: return "DIM";
        case TOK_AS: return "AS";
        case TOK_INTEGER: return "INTEGER";
        case TOK_DOUBLE: return "DOUBLE";
        case TOK_STRING: return "STRING";
        case TOK_TYPE: return "TYPE";
        case TOK_IF: return "IF";
        case TOK_THEN: return "THEN";
        case TOK_ELSE: return "ELSE";
        case TOK_ELSEIF: return "ELSEIF";
        case TOK_FOR: return "FOR";
        case TOK_TO: return "TO";
        case TOK_STEP: return "STEP";
        case TOK_NEXT: return "NEXT";
        case TOK_WHILE: return "WHILE";
        case TOK_WEND: return "WEND";
        case TOK_DO: return "DO";
        case TOK_LOOP: return "LOOP";
        case TOK_UNTIL: return "UNTIL";
        case TOK_SELECT: return "SELECT";
        case TOK_CASE: return "CASE";
        case TOK_PRINT: return "PRINT";
        case TOK_INPUT: return "INPUT";
        case TOK_RETURN: return "RETURN";
        case TOK_CONST: return "CONST";
        case TOK_CALL: return "CALL";
        case TOK_EXIT: return "EXIT";
        case TOK_AND: return "AND";
        case TOK_OR: return "OR";
        case TOK_NOT: return "NOT";
        case TOK_XOR: return "XOR";
        case TOK_MOD: return "MOD";
        case TOK_PLUS: return "PLUS";
        case TOK_MINUS: return "MINUS";
        case TOK_STAR: return "STAR";
        case TOK_SLASH: return "SLASH";
        case TOK_BACKSLASH: return "BACKSLASH";
        case TOK_CARET: return "CARET";
        case TOK_EQUAL: return "EQUAL";
        case TOK_NOT_EQUAL: return "NOT_EQUAL";
        case TOK_LESS: return "LESS";
        case TOK_LESS_EQUAL: return "LESS_EQUAL";
        case TOK_GREATER: return "GREATER";
        case TOK_GREATER_EQUAL: return "GREATER_EQUAL";
        case TOK_LPAREN: return "LPAREN";
        case TOK_RPAREN: return "RPAREN";
        case TOK_COMMA: return "COMMA";
        case TOK_SEMICOLON: return "SEMICOLON";
        case TOK_DOT: return "DOT";
        default: return "UNKNOWN";
    }
}

/* Parser and Bytecode Compiler */
typedef struct {
    char name[64];
    int depth;
    bool is_param;
} LocalVar;

typedef struct {
    char name[64];
    uint16_t address;
    int param_count;
} SubroutineDef;

typedef struct {
    char name[64];
} GlobalVar;

typedef struct {
    Lexer lexer;
    Token current;
    Token previous;
    bool had_error;
    char error_msg[256];

    Chunk *chunk;
    LocalVar locals[256];
    int local_count;
    int scope_depth;

    GlobalVar globals[256];
    int global_count;

    SubroutineDef subs[128];
    int sub_count;
} Compiler;

static int resolve_or_add_global(Compiler *c, const char *name, size_t len) {
    for (int i = 0; i < c->global_count; ++i) {
        if (strlen(c->globals[i].name) == len &&
            strncasecmp(c->globals[i].name, name, len) == 0) {
            return i;
        }
    }
    if (c->global_count >= 256) return 0;
    int idx = c->global_count++;
    size_t copy_len = len < 63 ? len : 63;
    strncpy(c->globals[idx].name, name, copy_len);
    c->globals[idx].name[copy_len] = '\0';
    return idx;
}

static void comp_error(Compiler *c, const char *msg) {
    if (c->had_error) return;
    c->had_error = true;
    snprintf(c->error_msg, sizeof(c->error_msg), "[Line %u, Col %u] Error: %s",
             c->previous.line, c->previous.col, msg);
}

static void comp_advance(Compiler *c) {
    c->previous = c->current;
    for (;;) {
        c->current = lexer_next_token(&c->lexer);
        if (c->current.type != TOK_ERROR) break;
        comp_error(c, c->current.start);
    }
}

static bool comp_check(Compiler *c, TokenType type) {
    return c->current.type == type;
}

static bool comp_match(Compiler *c, TokenType type) {
    if (!comp_check(c, type)) return false;
    comp_advance(c);
    return true;
}

static void comp_consume(Compiler *c, TokenType type, const char *msg) {
    if (comp_check(c, type)) {
        comp_advance(c);
        return;
    }
    comp_error(c, msg);
}

static void emit_byte(Compiler *c, uint8_t byte) {
    chunk_write(c->chunk, byte, c->previous.line);
}

static void emit_bytes(Compiler *c, uint8_t b1, uint8_t b2) {
    emit_byte(c, b1);
    emit_byte(c, b2);
}

static size_t emit_jump(Compiler *c, uint8_t op) {
    emit_byte(c, op);
    emit_byte(c, 0xFF);
    emit_byte(c, 0xFF);
    return c->chunk->count - 2;
}

static void patch_jump(Compiler *c, size_t offset) {
    size_t jump = c->chunk->count - offset - 2;
    if (jump > 65535) {
        comp_error(c, "Jump offset exceeds 16-bit limit");
        return;
    }
    c->chunk->code[offset] = (uint8_t)((jump >> 8) & 0xFF);
    c->chunk->code[offset + 1] = (uint8_t)(jump & 0xFF);
}


static int add_constant(Compiler *c, Value val) {
    size_t idx = chunk_add_constant(c->chunk, val);
    if (idx > 255) {
        comp_error(c, "Too many constants in chunk");
        return 0;
    }
    return (int)idx;
}

static int resolve_local(Compiler *c, const char *name, size_t len) {
    for (int i = c->local_count - 1; i >= 0; --i) {
        if (strlen(c->locals[i].name) == len &&
            strncasecmp(c->locals[i].name, name, len) == 0) {
            return i;
        }
    }
    return -1;
}

static void add_local(Compiler *c, const char *name, size_t len, bool is_param) {
    if (c->local_count >= 256) {
        comp_error(c, "Too many local variables in scope");
        return;
    }
    LocalVar *l = &c->locals[c->local_count++];
    size_t copy_len = len < 63 ? len : 63;
    strncpy(l->name, name, copy_len);
    l->name[copy_len] = '\0';
    l->depth = c->scope_depth;
    l->is_param = is_param;
}

/* Forward declarations */
static void expression(Compiler *c);
static void statement(Compiler *c);

static void primary(Compiler *c) {
    if (comp_match(c, TOK_INT_LITERAL)) {
        char buf[64];
        size_t len = c->previous.length < 63 ? c->previous.length : 63;
        strncpy(buf, c->previous.start, len);
        buf[len] = '\0';
        int64_t val = (int64_t)strtoll(buf, NULL, 10);
        int idx = add_constant(c, val_int(val));
        emit_bytes(c, OP_CONST_INT, (uint8_t)idx);
        return;
    }
    if (comp_match(c, TOK_FLOAT_LITERAL)) {
        char buf[64];
        size_t len = c->previous.length < 63 ? c->previous.length : 63;
        strncpy(buf, c->previous.start, len);
        buf[len] = '\0';
        double val = strtod(buf, NULL);
        int idx = add_constant(c, val_double(val));
        emit_bytes(c, OP_CONST_DOUBLE, (uint8_t)idx);
        return;
    }
    if (comp_match(c, TOK_STRING_LITERAL)) {
        Value s = val_string_len(c->previous.start, c->previous.length);
        int idx = add_constant(c, s);
        val_release(s);
        emit_bytes(c, OP_CONST_STRING, (uint8_t)idx);
        return;
    }
    if (comp_match(c, TOK_LPAREN)) {
        expression(c);
        comp_consume(c, TOK_RPAREN, "Expected ')' after expression");
        return;
    }
    if (comp_match(c, TOK_IDENTIFIER)) {
        const char *name = c->previous.start;
        size_t len = c->previous.length;

        /* Check for Function Call */
        if (comp_match(c, TOK_LPAREN)) {
            uint8_t arg_count = 0;
            if (!comp_check(c, TOK_RPAREN)) {
                do {
                    expression(c);
                    arg_count++;
                } while (comp_match(c, TOK_COMMA));
            }
            comp_consume(c, TOK_RPAREN, "Expected ')' after arguments");

            /* Find Subroutine/Function */
            int found_sub = -1;
            for (int i = 0; i < c->sub_count; ++i) {
                if (strlen(c->subs[i].name) == len &&
                    strncasecmp(c->subs[i].name, name, len) == 0) {
                    found_sub = i;
                    break;
                }
            }
            if (found_sub >= 0) {
                emit_byte(c, OP_CALL);
                emit_byte(c, arg_count);
                emit_byte(c, (uint8_t)((c->subs[found_sub].address >> 8) & 0xFF));
                emit_byte(c, (uint8_t)(c->subs[found_sub].address & 0xFF));
            } else {
                /* Array indexing or unknown */
                int local = resolve_local(c, name, len);
                if (local >= 0) {
                    emit_bytes(c, OP_LOAD_LOCAL, (uint8_t)local);
                    emit_byte(c, OP_ARRAY_GET);
                } else {
                    int g_idx = resolve_or_add_global(c, name, len);
                    emit_bytes(c, OP_LOAD_GLOBAL, (uint8_t)g_idx);
                    emit_byte(c, OP_ARRAY_GET);
                }
            }
            return;
        }

        /* Check for record dot access */
        int local = resolve_local(c, name, len);
        if (local >= 0) {
            emit_bytes(c, OP_LOAD_LOCAL, (uint8_t)local);
        } else {
            int g_idx = resolve_or_add_global(c, name, len);
            emit_bytes(c, OP_LOAD_GLOBAL, (uint8_t)g_idx);
        }

        if (comp_match(c, TOK_DOT)) {
            comp_consume(c, TOK_IDENTIFIER, "Expected field name after '.'");
            /* For simplicity, encode field index 0 */
            emit_bytes(c, OP_RECORD_GET, 0);
        }
        return;
    }

    comp_error(c, "Expected expression");
}

static void unary(Compiler *c) {
    if (comp_match(c, TOK_MINUS)) {
        unary(c);
        emit_byte(c, OP_NEG);
        return;
    }
    if (comp_match(c, TOK_NOT)) {
        unary(c);
        emit_byte(c, OP_NOT);
        return;
    }
    primary(c);
}

static void multiplicative(Compiler *c) {
    unary(c);
    while (comp_match(c, TOK_STAR) || comp_match(c, TOK_SLASH) ||
           comp_match(c, TOK_BACKSLASH) || comp_match(c, TOK_MOD)) {
        TokenType op = c->previous.type;
        unary(c);
        if (op == TOK_STAR) emit_byte(c, OP_MUL);
        else if (op == TOK_SLASH) emit_byte(c, OP_DIV);
        else if (op == TOK_BACKSLASH) emit_byte(c, OP_IDIV);
        else if (op == TOK_MOD) emit_byte(c, OP_MOD);
    }
}

static void additive(Compiler *c) {
    multiplicative(c);
    while (comp_match(c, TOK_PLUS) || comp_match(c, TOK_MINUS)) {
        TokenType op = c->previous.type;
        multiplicative(c);
        if (op == TOK_PLUS) emit_byte(c, OP_ADD);
        else emit_byte(c, OP_SUB);
    }
}

static void relational(Compiler *c) {
    additive(c);
    while (comp_match(c, TOK_EQUAL) || comp_match(c, TOK_NOT_EQUAL) ||
           comp_match(c, TOK_LESS) || comp_match(c, TOK_LESS_EQUAL) ||
           comp_match(c, TOK_GREATER) || comp_match(c, TOK_GREATER_EQUAL)) {
        TokenType op = c->previous.type;
        additive(c);
        if (op == TOK_EQUAL) emit_byte(c, OP_EQ);
        else if (op == TOK_NOT_EQUAL) emit_byte(c, OP_NE);
        else if (op == TOK_LESS) emit_byte(c, OP_LT);
        else if (op == TOK_LESS_EQUAL) emit_byte(c, OP_LE);
        else if (op == TOK_GREATER) emit_byte(c, OP_GT);
        else if (op == TOK_GREATER_EQUAL) emit_byte(c, OP_GE);
    }
}

static void logical(Compiler *c) {
    relational(c);
    while (comp_match(c, TOK_AND) || comp_match(c, TOK_OR) || comp_match(c, TOK_XOR)) {
        TokenType op = c->previous.type;
        relational(c);
        if (op == TOK_AND) emit_byte(c, OP_AND);
        else if (op == TOK_OR) emit_byte(c, OP_OR);
        else if (op == TOK_XOR) emit_byte(c, OP_XOR);
    }
}

static void expression(Compiler *c) {
    logical(c);
}

static void skip_statement_terminators(Compiler *c) {
    while (comp_match(c, TOK_NEWLINE) || comp_match(c, TOK_COLON)) {
        /* Consume extra blank lines and statement separators */
    }
}

static void print_statement(Compiler *c) {
    bool has_args = false;
    while (!comp_check(c, TOK_NEWLINE) && !comp_check(c, TOK_COLON) && !comp_check(c, TOK_EOF)) {
        has_args = true;
        expression(c);
        emit_byte(c, OP_PRINT);
        if (comp_match(c, TOK_COMMA) || comp_match(c, TOK_SEMICOLON)) {
            /* Separator between print arguments */
        } else {
            break;
        }
    }
    if (!has_args || (c->previous.type != TOK_COMMA && c->previous.type != TOK_SEMICOLON)) {
        emit_byte(c, OP_PRINT_NL);
    }
}

static void dim_statement(Compiler *c) {
    comp_consume(c, TOK_IDENTIFIER, "Expected variable name after DIM");
    const char *name = c->previous.start;
    size_t len = c->previous.length;

    bool is_array = false;
    if (comp_match(c, TOK_LPAREN)) {
        is_array = true;
        expression(c);
        comp_consume(c, TOK_RPAREN, "Expected ')' after array dimension");
    }

    if (comp_match(c, TOK_AS)) {
        if (!comp_match(c, TOK_INTEGER) && !comp_match(c, TOK_DOUBLE) &&
            !comp_match(c, TOK_STRING) && !comp_match(c, TOK_IDENTIFIER)) {
            comp_error(c, "Expected type after AS");
            return;
        }
    }

    if (c->scope_depth > 0) {
        add_local(c, name, len, false);
        int slot = resolve_local(c, name, len);
        if (is_array) {
            emit_byte(c, OP_ARRAY_ALLOC);
            emit_bytes(c, OP_STORE_LOCAL, (uint8_t)slot);
            emit_byte(c, OP_POP);
        } else {
            emit_byte(c, OP_CONST_NIL);
            emit_bytes(c, OP_STORE_LOCAL, (uint8_t)slot);
            emit_byte(c, OP_POP);
        }
    } else {
        /* Global variable */
        int idx = resolve_or_add_global(c, name, len);
        if (is_array) {
            emit_byte(c, OP_ARRAY_ALLOC);
            emit_bytes(c, OP_STORE_GLOBAL, (uint8_t)idx);
            emit_byte(c, OP_POP);
        } else {
            emit_byte(c, OP_CONST_NIL);
            emit_bytes(c, OP_STORE_GLOBAL, (uint8_t)idx);
            emit_byte(c, OP_POP);
        }
    }
}

static void if_statement(Compiler *c) {
    expression(c);
    comp_consume(c, TOK_THEN, "Expected THEN after IF condition");

    if (!comp_check(c, TOK_NEWLINE) && !comp_check(c, TOK_COLON) && !comp_check(c, TOK_EOF)) {
        /* Single-line IF: IF condition THEN statement [ELSE statement] */
        size_t then_jump = emit_jump(c, OP_JUMP_IF_FALSE);
        statement(c);
        if (comp_match(c, TOK_ELSE)) {
            size_t else_jump = emit_jump(c, OP_JUMP);
            patch_jump(c, then_jump);
            statement(c);
            patch_jump(c, else_jump);
        } else {
            patch_jump(c, then_jump);
        }
        return;
    }

    skip_statement_terminators(c);

    size_t then_jump = emit_jump(c, OP_JUMP_IF_FALSE);

    while (!comp_check(c, TOK_ELSE) && !comp_check(c, TOK_ELSEIF) &&
           !comp_check(c, TOK_END) && !comp_check(c, TOK_EOF)) {
        statement(c);
        skip_statement_terminators(c);
    }

    size_t else_jump = 0;
    bool has_else = false;

    if (comp_match(c, TOK_ELSE)) {
        has_else = true;
        else_jump = emit_jump(c, OP_JUMP);
        patch_jump(c, then_jump);
        skip_statement_terminators(c);
        while (!comp_check(c, TOK_END) && !comp_check(c, TOK_EOF)) {
            statement(c);
            skip_statement_terminators(c);
        }
    } else {
        patch_jump(c, then_jump);
    }

    comp_consume(c, TOK_END, "Expected END IF");
    comp_consume(c, TOK_IF, "Expected IF after END");

    if (has_else) {
        patch_jump(c, else_jump);
    }
}

static void while_statement(Compiler *c) {
    size_t loop_start = c->chunk->count;
    expression(c);
    skip_statement_terminators(c);

    size_t exit_jump = emit_jump(c, OP_JUMP_IF_FALSE);

    while (!comp_check(c, TOK_WEND) && !comp_check(c, TOK_EOF)) {
        statement(c);
        skip_statement_terminators(c);
    }

    comp_consume(c, TOK_WEND, "Expected WEND");

    /* Jump back to loop start */
    emit_byte(c, OP_JUMP);
    emit_byte(c, (uint8_t)((loop_start >> 8) & 0xFF));
    emit_byte(c, (uint8_t)(loop_start & 0xFF));

    patch_jump(c, exit_jump);
}

static void assignment_or_call(Compiler *c) {
    const char *name = c->previous.start;
    size_t len = c->previous.length;

    bool is_array = false;
    if (comp_match(c, TOK_LPAREN)) {
        is_array = true;
        expression(c);
        comp_consume(c, TOK_RPAREN, "Expected ')' after index");
    }

    if (comp_match(c, TOK_EQUAL)) {
        expression(c);
        int local = resolve_local(c, name, len);
        if (is_array) {
            if (local >= 0) {
                emit_bytes(c, OP_LOAD_LOCAL, (uint8_t)local);
                emit_byte(c, OP_ARRAY_SET);
                emit_byte(c, OP_POP);
            } else {
                int idx = resolve_or_add_global(c, name, len);
                emit_bytes(c, OP_LOAD_GLOBAL, (uint8_t)idx);
                emit_byte(c, OP_ARRAY_SET);
                emit_byte(c, OP_POP);
            }
        } else {
            if (local >= 0) {
                emit_bytes(c, OP_STORE_LOCAL, (uint8_t)local);
                emit_byte(c, OP_POP);
            } else {
                int idx = resolve_or_add_global(c, name, len);
                emit_bytes(c, OP_STORE_GLOBAL, (uint8_t)idx);
                emit_byte(c, OP_POP);
            }
        }
    } else {
        /* Standalone procedure call */
        int found_sub = -1;
        for (int i = 0; i < c->sub_count; ++i) {
            if (strlen(c->subs[i].name) == len &&
                strncasecmp(c->subs[i].name, name, len) == 0) {
                found_sub = i;
                break;
            }
        }
        if (found_sub >= 0) {
            uint8_t arg_count = 0;
            if (!comp_check(c, TOK_NEWLINE) && !comp_check(c, TOK_COLON) && !comp_check(c, TOK_EOF)) {
                do {
                    expression(c);
                    arg_count++;
                } while (comp_match(c, TOK_COMMA));
            }
            emit_byte(c, OP_CALL);
            emit_byte(c, arg_count);
            emit_byte(c, (uint8_t)((c->subs[found_sub].address >> 8) & 0xFF));
            emit_byte(c, (uint8_t)(c->subs[found_sub].address & 0xFF));
            emit_byte(c, OP_POP);
        }
    }
}

static void statement(Compiler *c) {
    if (comp_match(c, TOK_PRINT)) {
        print_statement(c);
    } else if (comp_match(c, TOK_DIM)) {
        dim_statement(c);
    } else if (comp_match(c, TOK_IF)) {
        if_statement(c);
    } else if (comp_match(c, TOK_WHILE)) {
        while_statement(c);
    } else if (comp_match(c, TOK_RETURN)) {
        if (!comp_check(c, TOK_NEWLINE) && !comp_check(c, TOK_COLON) && !comp_check(c, TOK_EOF)) {
            expression(c);
        } else {
            emit_byte(c, OP_CONST_NIL);
        }
        emit_byte(c, OP_RETURN);
    } else if (comp_match(c, TOK_IDENTIFIER)) {
        assignment_or_call(c);
    } else {
        comp_advance(c);
    }
}

bool relay_compile(const char *source, Chunk *out_chunk, char *err_buffer, size_t err_size) {
    Compiler c;
    lexer_init(&c.lexer, source);
    c.chunk = out_chunk;
    c.had_error = false;
    c.local_count = 0;
    c.global_count = 0;
    c.scope_depth = 0;
    c.sub_count = 0;
    memset(c.error_msg, 0, sizeof(c.error_msg));

    comp_advance(&c);

    while (!comp_match(&c, TOK_EOF)) {
        skip_statement_terminators(&c);
        if (comp_check(&c, TOK_EOF)) break;
        statement(&c);
        skip_statement_terminators(&c);
    }

    emit_byte(&c, OP_HALT);

    if (c.had_error) {
        if (err_buffer && err_size > 0) {
            strncpy(err_buffer, c.error_msg, err_size - 1);
            err_buffer[err_size - 1] = '\0';
        }
        return false;
    }

    return true;
}
