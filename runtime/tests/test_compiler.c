#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "relay_compiler.h"
#include "relay_vm.h"
#include "relay_ffi.h"

static int g_tests_run = 0;
static int g_tests_passed = 0;

#define TEST_ASSERT(cond, msg) do { \
    g_tests_run++; \
    if (cond) { \
        g_tests_passed++; \
    } else { \
        fprintf(stderr, "FAIL: %s (line %d)\n", msg, __LINE__); \
    } \
} while (0)

static void test_lexer_tokens(void) {
    const char *source = "DIM temp AS DOUBLE\nIF temp >= 100.5 THEN PRINT \"ALARM\" END IF";
    Lexer lex;
    lexer_init(&lex, source);

    Token t = lexer_next_token(&lex);
    TEST_ASSERT(t.type == TOK_DIM, "Lexed DIM keyword");

    t = lexer_next_token(&lex);
    TEST_ASSERT(t.type == TOK_IDENTIFIER, "Lexed identifier 'temp'");

    t = lexer_next_token(&lex);
    TEST_ASSERT(t.type == TOK_AS, "Lexed AS keyword");

    t = lexer_next_token(&lex);
    TEST_ASSERT(t.type == TOK_DOUBLE, "Lexed DOUBLE keyword");

    t = lexer_next_token(&lex);
    TEST_ASSERT(t.type == TOK_NEWLINE, "Lexed NEWLINE");

    t = lexer_next_token(&lex);
    TEST_ASSERT(t.type == TOK_IF, "Lexed IF keyword");
}

static void test_compiler_and_run(void) {
    const char *source =
        "DIM x AS INTEGER\n"
        "x = 15 + 25\n"
        "PRINT x\n";

    Chunk chunk;
    chunk_init(&chunk);

    char err_buf[256] = {0};
    bool ok = relay_compile(source, &chunk, err_buf, sizeof(err_buf));
    TEST_ASSERT(ok, "Compilation of assignment and print succeeded");

    VM vm;
    vm_init(&vm);
    relay_register_host_syscalls(&vm);

    int res = vm_run(&vm, &chunk);
    TEST_ASSERT(res == 0, "VM executed compiled BASIC chunk");

    chunk_free(&chunk);
    vm_free(&vm);
}

int main(void) {
    printf("=== Running Relay Compiler Unit Tests ===\n");
    test_lexer_tokens();
    test_compiler_and_run();

    printf("Results: %d/%d tests passed.\n", g_tests_passed, g_tests_run);
    return (g_tests_passed == g_tests_run) ? 0 : 1;
}
