#ifndef RELAY_COMPILER_H
#define RELAY_COMPILER_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "relay_vm.h"

typedef enum {
    /* Special Tokens */
    TOK_EOF = 0,
    TOK_ERROR,
    TOK_NEWLINE,
    TOK_COLON,

    /* Literals */
    TOK_IDENTIFIER,
    TOK_INT_LITERAL,
    TOK_FLOAT_LITERAL,
    TOK_STRING_LITERAL,

    /* Keywords */
    TOK_SUB,
    TOK_FUNCTION,
    TOK_END,
    TOK_DIM,
    TOK_AS,
    TOK_INTEGER,
    TOK_DOUBLE,
    TOK_STRING,
    TOK_TYPE,
    TOK_IF,
    TOK_THEN,
    TOK_ELSE,
    TOK_ELSEIF,
    TOK_FOR,
    TOK_TO,
    TOK_STEP,
    TOK_NEXT,
    TOK_WHILE,
    TOK_WEND,
    TOK_DO,
    TOK_LOOP,
    TOK_UNTIL,
    TOK_SELECT,
    TOK_CASE,
    TOK_PRINT,
    TOK_INPUT,
    TOK_RETURN,
    TOK_CONST,
    TOK_CALL,
    TOK_EXIT,

    /* Logical Operators */
    TOK_AND,
    TOK_OR,
    TOK_NOT,
    TOK_XOR,
    TOK_MOD,

    /* Arithmetic and Relational Operators */
    TOK_PLUS,
    TOK_MINUS,
    TOK_STAR,
    TOK_SLASH,
    TOK_BACKSLASH,
    TOK_CARET,
    TOK_EQUAL,
    TOK_NOT_EQUAL,
    TOK_LESS,
    TOK_LESS_EQUAL,
    TOK_GREATER,
    TOK_GREATER_EQUAL,

    /* Delimiters */
    TOK_LPAREN,
    TOK_RPAREN,
    TOK_COMMA,
    TOK_SEMICOLON,
    TOK_DOT
} TokenType;

typedef struct {
    TokenType type;
    const char *start;
    size_t length;
    uint32_t line;
    uint32_t col;
} Token;

typedef struct {
    const char *source;
    const char *current;
    uint32_t line;
    uint32_t col;
} Lexer;

void lexer_init(Lexer *lexer, const char *source);
Token lexer_next_token(Lexer *lexer);
const char *token_type_name(TokenType type);

/* Compilation Interface */
bool relay_compile(const char *source, Chunk *out_chunk, char *err_buffer, size_t err_size);

#endif /* RELAY_COMPILER_H */
