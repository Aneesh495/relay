"""
Recursive descent parser building Abstract Syntax Trees for Relay BASIC.
"""

from typing import List, Optional, Any
from .lexer import Token, TokenType

class ASTNode:
    pass

class ProgramNode(ASTNode):
    def __init__(self, statements: List[ASTNode]):
        self.statements = statements

class DimNode(ASTNode):
    def __init__(self, name: str, var_type: str, array_dim: Optional[ASTNode] = None):
        self.name = name
        self.var_type = var_type
        self.array_dim = array_dim

class TypeDefNode(ASTNode):
    def __init__(self, name: str, fields: List[tuple]):
        self.name = name
        self.fields = fields  # List of (field_name, field_type)

class SubDefNode(ASTNode):
    def __init__(self, name: str, params: List[tuple], body: List[ASTNode], return_type: Optional[str] = None):
        self.name = name
        self.params = params  # List of (param_name, param_type)
        self.body = body
        self.return_type = return_type

class AssignNode(ASTNode):
    def __init__(self, target: ASTNode, expr: ASTNode):
        self.target = target
        self.expr = expr

class IfNode(ASTNode):
    def __init__(self, condition: ASTNode, then_body: List[ASTNode], else_body: Optional[List[ASTNode]] = None):
        self.condition = condition
        self.then_body = then_body
        self.else_body = else_body or []

class WhileNode(ASTNode):
    def __init__(self, condition: ASTNode, body: List[ASTNode]):
        self.condition = condition
        self.body = body

class ForNode(ASTNode):
    def __init__(self, var_name: str, start_expr: ASTNode, end_expr: ASTNode, step_expr: Optional[ASTNode], body: List[ASTNode]):
        self.var_name = var_name
        self.start_expr = start_expr
        self.end_expr = end_expr
        self.step_expr = step_expr
        self.body = body

class PrintNode(ASTNode):
    def __init__(self, expressions: List[ASTNode], newline: bool = True):
        self.expressions = expressions
        self.newline = newline

class ReturnNode(ASTNode):
    def __init__(self, expr: Optional[ASTNode] = None):
        self.expr = expr

class CallNode(ASTNode):
    def __init__(self, name: str, args: List[ASTNode]):
        self.name = name
        self.args = args

class BinaryOpNode(ASTNode):
    def __init__(self, left: ASTNode, op: TokenType, right: ASTNode):
        self.left = left
        self.op = op
        self.right = right

class UnaryOpNode(ASTNode):
    def __init__(self, op: TokenType, operand: ASTNode):
        self.op = op
        self.operand = operand

class LiteralNode(ASTNode):
    def __init__(self, value: Any, val_type: str):
        self.value = value
        self.val_type = val_type

class VariableNode(ASTNode):
    def __init__(self, name: str):
        self.name = name

class ArrayAccessNode(ASTNode):
    def __init__(self, array_expr: ASTNode, index_expr: ASTNode):
        self.array_expr = array_expr
        self.index_expr = index_expr

class FieldAccessNode(ASTNode):
    def __init__(self, record_expr: ASTNode, field_name: str):
        self.record_expr = record_expr
        self.field_name = field_name


class Parser:
    def __init__(self, tokens: List[Token]):
        self.tokens = tokens
        self.pos = 0

    def _peek(self) -> Token:
        if self.pos < len(self.tokens):
            return self.tokens[self.pos]
        return Token(TokenType.EOF, "", 0, 0)

    def _advance(self) -> Token:
        t = self._peek()
        self.pos += 1
        return t

    def _check(self, type_: TokenType) -> bool:
        return self._peek().type == type_

    def _match(self, *types: TokenType) -> bool:
        for t in types:
            if self._check(t):
                self._advance()
                return True
        return False

    def _consume(self, type_: TokenType, err_msg: str) -> Token:
        if self._check(type_):
            return self._advance()
        tok = self._peek()
        raise SyntaxError(f"[Line {tok.line}, Col {tok.col}] {err_msg} (got {tok.type.name})")

    def _skip_terminators(self):
        while self._match(TokenType.NEWLINE, TokenType.COLON):
            pass

    def parse(self) -> ProgramNode:
        statements = []
        while not self._check(TokenType.EOF):
            self._skip_terminators()
            if self._check(TokenType.EOF):
                break
            stmt = self._statement()
            if stmt:
                statements.append(stmt)
            self._skip_terminators()
        return ProgramNode(statements)

    def _statement(self) -> Optional[ASTNode]:
        if self._match(TokenType.PRINT):
            return self._print_statement()
        if self._match(TokenType.DIM):
            return self._dim_statement()
        if self._match(TokenType.TYPE):
            return self._type_statement()
        if self._match(TokenType.SUB):
            return self._sub_statement(is_func=False)
        if self._match(TokenType.FUNCTION):
            return self._sub_statement(is_func=True)
        if self._match(TokenType.IF):
            return self._if_statement()
        if self._match(TokenType.WHILE):
            return self._while_statement()
        if self._match(TokenType.FOR):
            return self._for_statement()
        if self._match(TokenType.RETURN):
            expr = None
            if not self._check(TokenType.NEWLINE) and not self._check(TokenType.COLON) and not self._check(TokenType.EOF):
                expr = self._expression()
            return ReturnNode(expr)
        if self._match(TokenType.CALL):
            name_tok = self._consume(TokenType.IDENTIFIER, "Expected procedure name after CALL")
            args = []
            if self._match(TokenType.LPAREN):
                if not self._check(TokenType.RPAREN):
                    while True:
                        args.append(self._expression())
                        if not self._match(TokenType.COMMA):
                            break
                self._consume(TokenType.RPAREN, "Expected ')' after procedure arguments")
            return CallNode(name_tok.value, args)

        # Check for assignment statement starting with identifier:
        # id = expr, id(index) = expr, id.field = expr
        if self._check(TokenType.IDENTIFIER):
            saved_pos = self.pos
            target = self._parse_target()
            if self._match(TokenType.EQUAL):
                val_expr = self._expression()
                return AssignNode(target, val_expr)
            # Not an assignment, backtrack and parse as expression / call
            self.pos = saved_pos

        return self._expr_or_assign()

    def _parse_target(self) -> ASTNode:
        name_tok = self._consume(TokenType.IDENTIFIER, "Expected identifier")
        node = VariableNode(name_tok.value)
        while True:
            if self._match(TokenType.LPAREN):
                args = []
                if not self._check(TokenType.RPAREN):
                    while True:
                        args.append(self._expression())
                        if not self._match(TokenType.COMMA):
                            break
                self._consume(TokenType.RPAREN, "Expected ')'")
                node = CallNode(name_tok.value, args)
            elif self._match(TokenType.DOT):
                f_name = self._consume(TokenType.IDENTIFIER, "Expected field name")
                node = FieldAccessNode(node, f_name.value)
            else:
                break
        return node

    def _print_statement(self) -> PrintNode:
        exprs = []
        newline = True
        while not self._check(TokenType.NEWLINE) and not self._check(TokenType.COLON) and not self._check(TokenType.EOF):
            exprs.append(self._expression())
            if self._match(TokenType.COMMA):
                newline = False
                if self._check(TokenType.NEWLINE) or self._check(TokenType.COLON):
                    break
            elif self._match(TokenType.SEMICOLON):
                newline = False
                if self._check(TokenType.NEWLINE) or self._check(TokenType.COLON):
                    break
            else:
                newline = True
                break
        return PrintNode(exprs, newline)

    def _dim_statement(self) -> DimNode:
        name_tok = self._consume(TokenType.IDENTIFIER, "Expected variable name after DIM")
        array_dim = None
        if self._match(TokenType.LPAREN):
            array_dim = self._expression()
            self._consume(TokenType.RPAREN, "Expected ')' after array dimension")

        var_type = "DOUBLE"
        if self._match(TokenType.AS):
            type_tok = self._advance()
            var_type = type_tok.value if isinstance(type_tok.value, str) else type_tok.type.name

        return DimNode(name_tok.value, var_type, array_dim)

    def _type_statement(self) -> TypeDefNode:
        name_tok = self._consume(TokenType.IDENTIFIER, "Expected type name after TYPE")
        self._skip_terminators()
        fields = []
        while not self._check(TokenType.END) and not self._check(TokenType.EOF):
            f_name = self._consume(TokenType.IDENTIFIER, "Expected field name")
            f_type = "DOUBLE"
            if self._match(TokenType.AS):
                t_tok = self._advance()
                f_type = t_tok.value if isinstance(t_tok.value, str) else t_tok.type.name
            fields.append((f_name.value, f_type))
            self._skip_terminators()
        self._consume(TokenType.END, "Expected END TYPE")
        self._consume(TokenType.TYPE, "Expected TYPE after END")
        return TypeDefNode(name_tok.value, fields)

    def _sub_statement(self, is_func: bool) -> SubDefNode:
        name_tok = self._consume(TokenType.IDENTIFIER, "Expected function or subroutine name")
        params = []
        if self._match(TokenType.LPAREN):
            if not self._check(TokenType.RPAREN):
                while True:
                    p_name = self._consume(TokenType.IDENTIFIER, "Expected parameter name")
                    p_type = "DOUBLE"
                    if self._match(TokenType.AS):
                        t_tok = self._advance()
                        p_type = t_tok.value if isinstance(t_tok.value, str) else t_tok.type.name
                    params.append((p_name.value, p_type))
                    if not self._match(TokenType.COMMA):
                        break
            self._consume(TokenType.RPAREN, "Expected ')' after parameters")

        ret_type = None
        if is_func and self._match(TokenType.AS):
            t_tok = self._advance()
            ret_type = t_tok.value if isinstance(t_tok.value, str) else t_tok.type.name

        self._skip_terminators()
        body = []
        while not self._check(TokenType.END) and not self._check(TokenType.EOF):
            stmt = self._statement()
            if stmt:
                body.append(stmt)
            self._skip_terminators()

        self._consume(TokenType.END, "Expected END after subroutine body")
        if is_func:
            self._consume(TokenType.FUNCTION, "Expected FUNCTION after END")
        else:
            self._consume(TokenType.SUB, "Expected SUB after END")

        return SubDefNode(name_tok.value, params, body, ret_type)

    def _if_statement(self) -> IfNode:
        cond = self._expression()
        self._consume(TokenType.THEN, "Expected THEN after IF condition")

        if not self._check(TokenType.NEWLINE) and not self._check(TokenType.COLON) and not self._check(TokenType.EOF):
            # Single-line IF statement
            then_stmt = self._statement()
            then_body = [then_stmt] if then_stmt else []
            else_body = []
            if self._match(TokenType.ELSE):
                else_stmt = self._statement()
                if else_stmt:
                    else_body = [else_stmt]
            return IfNode(cond, then_body, else_body)

        self._skip_terminators()

        then_body = []
        while not self._check(TokenType.ELSE) and not self._check(TokenType.ELSEIF) and not self._check(TokenType.END) and not self._check(TokenType.EOF):
            stmt = self._statement()
            if stmt:
                then_body.append(stmt)
            self._skip_terminators()

        else_body = []
        if self._match(TokenType.ELSE):
            self._skip_terminators()
            while not self._check(TokenType.END) and not self._check(TokenType.EOF):
                stmt = self._statement()
                if stmt:
                    else_body.append(stmt)
                self._skip_terminators()

        self._consume(TokenType.END, "Expected END IF")
        self._consume(TokenType.IF, "Expected IF after END")
        return IfNode(cond, then_body, else_body)

    def _while_statement(self) -> WhileNode:
        cond = self._expression()
        self._skip_terminators()
        body = []
        while not self._check(TokenType.WEND) and not self._check(TokenType.EOF):
            stmt = self._statement()
            if stmt:
                body.append(stmt)
            self._skip_terminators()
        self._consume(TokenType.WEND, "Expected WEND")
        return WhileNode(cond, body)

    def _for_statement(self) -> ForNode:
        var_tok = self._consume(TokenType.IDENTIFIER, "Expected loop variable after FOR")
        self._consume(TokenType.EQUAL, "Expected '=' in FOR statement")
        start_expr = self._expression()
        self._consume(TokenType.TO, "Expected TO in FOR statement")
        end_expr = self._expression()
        step_expr = None
        if self._match(TokenType.STEP):
            step_expr = self._expression()

        self._skip_terminators()
        body = []
        while not self._check(TokenType.NEXT) and not self._check(TokenType.EOF):
            stmt = self._statement()
            if stmt:
                body.append(stmt)
            self._skip_terminators()

        self._consume(TokenType.NEXT, "Expected NEXT")
        if self._check(TokenType.IDENTIFIER):
            self._advance()  # Optional variable name after NEXT

        return ForNode(var_tok.value, start_expr, end_expr, step_expr, body)

    def _expr_or_assign(self) -> ASTNode:
        expr = self._expression()
        if self._match(TokenType.EQUAL):
            val = self._expression()
            return AssignNode(expr, val)
        return expr

    def _expression(self) -> ASTNode:
        return self._logical()

    def _logical(self) -> ASTNode:
        expr = self._relational()
        while self._match(TokenType.AND, TokenType.OR, TokenType.XOR):
            op = self.tokens[self.pos - 1].type
            right = self._relational()
            expr = BinaryOpNode(expr, op, right)
        return expr

    def _relational(self) -> ASTNode:
        expr = self._additive()
        while self._match(TokenType.EQUAL, TokenType.NOT_EQUAL, TokenType.LESS, TokenType.LESS_EQUAL, TokenType.GREATER, TokenType.GREATER_EQUAL):
            op = self.tokens[self.pos - 1].type
            right = self._additive()
            expr = BinaryOpNode(expr, op, right)
        return expr

    def _additive(self) -> ASTNode:
        expr = self._multiplicative()
        while self._match(TokenType.PLUS, TokenType.MINUS):
            op = self.tokens[self.pos - 1].type
            right = self._multiplicative()
            expr = BinaryOpNode(expr, op, right)
        return expr

    def _multiplicative(self) -> ASTNode:
        expr = self._unary()
        while self._match(TokenType.STAR, TokenType.SLASH, TokenType.BACKSLASH, TokenType.MOD):
            op = self.tokens[self.pos - 1].type
            right = self._unary()
            expr = BinaryOpNode(expr, op, right)
        return expr

    def _unary(self) -> ASTNode:
        if self._match(TokenType.MINUS, TokenType.NOT):
            op = self.tokens[self.pos - 1].type
            operand = self._unary()
            return UnaryOpNode(op, operand)
        return self._power()

    def _power(self) -> ASTNode:
        expr = self._primary()
        if self._match(TokenType.CARET):
            right = self._unary()
            return BinaryOpNode(expr, TokenType.CARET, right)
        return expr

    def _primary(self) -> ASTNode:
        if self._match(TokenType.INT_LIT):
            return LiteralNode(self.tokens[self.pos - 1].value, "INTEGER")
        if self._match(TokenType.FLOAT_LIT):
            return LiteralNode(self.tokens[self.pos - 1].value, "DOUBLE")
        if self._match(TokenType.STRING_LIT):
            return LiteralNode(self.tokens[self.pos - 1].value, "STRING")
        if self._match(TokenType.LPAREN):
            e = self._expression()
            self._consume(TokenType.RPAREN, "Expected ')' after expression")
            return e

        if self._match(TokenType.IDENTIFIER):
            name = self.tokens[self.pos - 1].value
            # Check for function call or array access
            if self._match(TokenType.LPAREN):
                args = []
                if not self._check(TokenType.RPAREN):
                    while True:
                        args.append(self._expression())
                        if not self._match(TokenType.COMMA):
                            break
                self._consume(TokenType.RPAREN, "Expected ')' after call/index")
                node = CallNode(name, args)
            else:
                node = VariableNode(name)

            # Check for member access .field
            while self._match(TokenType.DOT):
                f_name = self._consume(TokenType.IDENTIFIER, "Expected field name after '.'")
                node = FieldAccessNode(node, f_name.value)

            return node

        tok = self._peek()
        raise SyntaxError(f"[Line {tok.line}, Col {tok.col}] Expected expression, got {tok.type.name}")
