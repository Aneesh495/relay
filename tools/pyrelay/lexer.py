"""
Lexical analyzer for Structured BASIC dialect in Relay.
"""

from enum import Enum, auto
from typing import List, Optional

class TokenType(Enum):
    EOF = auto()
    NEWLINE = auto()
    COLON = auto()

    IDENTIFIER = auto()
    INT_LIT = auto()
    FLOAT_LIT = auto()
    STRING_LIT = auto()

    # Keywords
    SUB = auto()
    FUNCTION = auto()
    END = auto()
    DIM = auto()
    AS = auto()
    INTEGER = auto()
    DOUBLE = auto()
    STRING = auto()
    TYPE = auto()
    IF = auto()
    THEN = auto()
    ELSE = auto()
    ELSEIF = auto()
    FOR = auto()
    TO = auto()
    STEP = auto()
    NEXT = auto()
    WHILE = auto()
    WEND = auto()
    DO = auto()
    LOOP = auto()
    UNTIL = auto()
    SELECT = auto()
    CASE = auto()
    PRINT = auto()
    INPUT = auto()
    RETURN = auto()
    CONST = auto()
    CALL = auto()
    EXIT = auto()

    # Logical Operators
    AND = auto()
    OR = auto()
    NOT = auto()
    XOR = auto()
    MOD = auto()

    # Arithmetic & Relational Operators
    PLUS = auto()
    MINUS = auto()
    STAR = auto()
    SLASH = auto()
    BACKSLASH = auto()
    CARET = auto()
    EQUAL = auto()
    NOT_EQUAL = auto()
    LESS = auto()
    LESS_EQUAL = auto()
    GREATER = auto()
    GREATER_EQUAL = auto()

    # Delimiters
    LPAREN = auto()
    RPAREN = auto()
    COMMA = auto()
    SEMICOLON = auto()
    DOT = auto()

KEYWORDS = {
    "SUB": TokenType.SUB,
    "FUNCTION": TokenType.FUNCTION,
    "END": TokenType.END,
    "DIM": TokenType.DIM,
    "AS": TokenType.AS,
    "INTEGER": TokenType.INTEGER,
    "DOUBLE": TokenType.DOUBLE,
    "STRING": TokenType.STRING,
    "TYPE": TokenType.TYPE,
    "IF": TokenType.IF,
    "THEN": TokenType.THEN,
    "ELSE": TokenType.ELSE,
    "ELSEIF": TokenType.ELSEIF,
    "FOR": TokenType.FOR,
    "TO": TokenType.TO,
    "STEP": TokenType.STEP,
    "NEXT": TokenType.NEXT,
    "WHILE": TokenType.WHILE,
    "WEND": TokenType.WEND,
    "DO": TokenType.DO,
    "LOOP": TokenType.LOOP,
    "UNTIL": TokenType.UNTIL,
    "SELECT": TokenType.SELECT,
    "CASE": TokenType.CASE,
    "PRINT": TokenType.PRINT,
    "INPUT": TokenType.INPUT,
    "RETURN": TokenType.RETURN,
    "CONST": TokenType.CONST,
    "CALL": TokenType.CALL,
    "EXIT": TokenType.EXIT,
    "AND": TokenType.AND,
    "OR": TokenType.OR,
    "NOT": TokenType.NOT,
    "XOR": TokenType.XOR,
    "MOD": TokenType.MOD,
}

class Token:
    def __init__(self, type_: TokenType, value: any, line: int, col: int):
        self.type = type_
        self.value = value
        self.line = line
        self.col = col

    def __repr__(self) -> str:
        return f"Token({self.type.name}, {repr(self.value)}, L{self.line}:C{self.col})"

class Lexer:
    def __init__(self, source: str):
        self.source = source
        self.pos = 0
        self.line = 1
        self.col = 1
        self.length = len(source)

    def _peek(self) -> str:
        if self.pos >= self.length:
            return ""
        return self.source[self.pos]

    def _peek_next(self) -> str:
        if self.pos + 1 >= self.length:
            return ""
        return self.source[self.pos + 1]

    def _advance(self) -> str:
        c = self._peek()
        self.pos += 1
        self.col += 1
        return c

    def tokenize(self) -> List[Token]:
        tokens: List[Token] = []

        while self.pos < self.length:
            c = self._peek()

            # Skip spaces and tabs
            if c in (" ", "\t", "\r"):
                self._advance()
                continue

            # Skip comment line starting with ' or REM
            if c == "'":
                while self._peek() and self._peek() != "\n":
                    self._advance()
                continue

            start_line = self.line
            start_col = self.col

            if c == "\n":
                self._advance()
                self.line += 1
                self.col = 1
                tokens.append(Token(TokenType.NEWLINE, "\n", start_line, start_col))
                continue

            if c == ":":
                self._advance()
                tokens.append(Token(TokenType.COLON, ":", start_line, start_col))
                continue
            if c == "(":
                self._advance()
                tokens.append(Token(TokenType.LPAREN, "(", start_line, start_col))
                continue
            if c == ")":
                self._advance()
                tokens.append(Token(TokenType.RPAREN, ")", start_line, start_col))
                continue
            if c == ",":
                self._advance()
                tokens.append(Token(TokenType.COMMA, ",", start_line, start_col))
                continue
            if c == ";":
                self._advance()
                tokens.append(Token(TokenType.SEMICOLON, ";", start_line, start_col))
                continue
            if c == ".":
                self._advance()
                tokens.append(Token(TokenType.DOT, ".", start_line, start_col))
                continue
            if c == "+":
                self._advance()
                tokens.append(Token(TokenType.PLUS, "+", start_line, start_col))
                continue
            if c == "-":
                self._advance()
                tokens.append(Token(TokenType.MINUS, "-", start_line, start_col))
                continue
            if c == "*":
                self._advance()
                tokens.append(Token(TokenType.STAR, "*", start_line, start_col))
                continue
            if c == "/":
                self._advance()
                tokens.append(Token(TokenType.SLASH, "/", start_line, start_col))
                continue
            if c == "\\":
                self._advance()
                tokens.append(Token(TokenType.BACKSLASH, "\\", start_line, start_col))
                continue
            if c == "^":
                self._advance()
                tokens.append(Token(TokenType.CARET, "^", start_line, start_col))
                continue

            if c == "=":
                self._advance()
                tokens.append(Token(TokenType.EQUAL, "=", start_line, start_col))
                continue

            if c == "<":
                self._advance()
                if self._peek() == ">":
                    self._advance()
                    tokens.append(Token(TokenType.NOT_EQUAL, "<>", start_line, start_col))
                elif self._peek() == "=":
                    self._advance()
                    tokens.append(Token(TokenType.LESS_EQUAL, "<=", start_line, start_col))
                else:
                    tokens.append(Token(TokenType.LESS, "<", start_line, start_col))
                continue

            if c == ">":
                self._advance()
                if self._peek() == "=":
                    self._advance()
                    tokens.append(Token(TokenType.GREATER_EQUAL, ">=", start_line, start_col))
                else:
                    tokens.append(Token(TokenType.GREATER, ">", start_line, start_col))
                continue

            # String literal
            if c == '"':
                self._advance()
                chars = []
                while self._peek() and self._peek() != '"':
                    if self._peek() == "\n":
                        self.line += 1
                        self.col = 1
                    chars.append(self._advance())
                if self._peek() == '"':
                    self._advance()
                tokens.append(Token(TokenType.STRING_LIT, "".join(chars), start_line, start_col))
                continue

            # Number literal
            if c.isdigit() or (c == "." and self._peek_next().isdigit()):
                num_chars = []
                is_float = False
                while self._peek().isdigit():
                    num_chars.append(self._advance())
                if self._peek() == "." and self._peek_next().isdigit():
                    is_float = True
                    num_chars.append(self._advance())
                    while self._peek().isdigit():
                        num_chars.append(self._advance())
                if self._peek() in ("e", "E"):
                    is_float = True
                    num_chars.append(self._advance())
                    if self._peek() in ("+", "-"):
                        num_chars.append(self._advance())
                    while self._peek().isdigit():
                        num_chars.append(self._advance())
                s = "".join(num_chars)
                if is_float:
                    tokens.append(Token(TokenType.FLOAT_LIT, float(s), start_line, start_col))
                else:
                    tokens.append(Token(TokenType.INT_LIT, int(s), start_line, start_col))
                continue

            # Identifiers and Keywords
            if c.isalpha() or c == "_":
                ident_chars = []
                while self._peek().isalnum() or self._peek() in ("_", "$"):
                    ident_chars.append(self._advance())
                name = "".join(ident_chars)
                uname = name.upper()
                if uname == "REM":
                    while self._peek() and self._peek() != "\n":
                        self._advance()
                    continue
                if uname in KEYWORDS:
                    tokens.append(Token(KEYWORDS[uname], uname, start_line, start_col))
                else:
                    tokens.append(Token(TokenType.IDENTIFIER, name, start_line, start_col))
                continue

            # Unrecognized character
            self._advance()

        tokens.append(Token(TokenType.EOF, "", self.line, self.col))
        return tokens
