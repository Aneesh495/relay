"""
CLI Runner for executing Relay BASIC programs with the Python Reference Engine.
"""

import sys
try:
    from .lexer import Lexer
    from .parser import Parser
    from .interpreter import Interpreter
except (ImportError, ValueError):
    from tools.pyrelay.lexer import Lexer
    from tools.pyrelay.parser import Parser
    from tools.pyrelay.interpreter import Interpreter

def run_source(source: str) -> Interpreter:
    lexer = Lexer(source)
    tokens = lexer.tokenize()
    parser = Parser(tokens)
    ast = parser.parse()
    interp = Interpreter()
    interp.run(ast)
    return interp

def run_file(file_path: str) -> Interpreter:
    with open(file_path, "r", encoding="utf-8") as f:
        source = f.read()
    return run_source(source)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 -m tools.pyrelay.runner <source.bas>")
        sys.exit(1)

    file_path = sys.argv[1]
    try:
        run_file(file_path)
    except Exception as e:
        print(f"Execution Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
