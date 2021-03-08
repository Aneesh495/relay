#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "relay_vm.h"
#include "relay_compiler.h"
#include "relay_ffi.h"
#include "relay_tag_engine.h"
#include "relay_historian.h"

#define RELAY_VERSION "1.0.0"

static char *read_entire_file(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) {
        fprintf(stderr, "Error: Could not open file '%s'\n", path);
        return NULL;
    }
    fseek(f, 0, SEEK_END);
    long length = ftell(f);
    fseek(f, 0, SEEK_SET);

    char *buf = (char *)malloc(length + 1);
    if (!buf) {
        fclose(f);
        return NULL;
    }
    size_t read_bytes = fread(buf, 1, length, f);
    buf[read_bytes] = '\0';
    fclose(f);
    return buf;
}

static int run_file(const char *path) {
    char *source = read_entire_file(path);
    if (!source) {
        return 1;
    }

    Chunk chunk;
    chunk_init(&chunk);

    char err_buf[512] = {0};
    if (!relay_compile(source, &chunk, err_buf, sizeof(err_buf))) {
        fprintf(stderr, "Compilation failed: %s\n", err_buf);
        free(source);
        chunk_free(&chunk);
        return 1;
    }
    free(source);

    VM vm;
    vm_init(&vm);
    relay_register_host_syscalls(&vm);

    int result = vm_run(&vm, &chunk);

    chunk_free(&chunk);
    vm_free(&vm);
    return result;
}

static void print_banner(void) {
    printf("Relay SCADA Runtime v%s (Dartmouth/ANSI Structured BASIC Engine)\n", RELAY_VERSION);
    printf("Industrial Automation & Digital Twin Process Control Platform\n");
    printf("Type 'EXIT' or Ctrl+D to terminate session.\n\n");
}

static void run_repl(void) {
    print_banner();

    VM vm;
    vm_init(&vm);
    relay_register_host_syscalls(&vm);

    char line[1024];
    for (;;) {
        printf("relay> ");
        fflush(stdout);

        if (!fgets(line, sizeof(line), stdin)) {
            printf("\n");
            break;
        }

        size_t len = strlen(line);
        while (len > 0 && (line[len - 1] == '\n' || line[len - 1] == '\r')) {
            line[--len] = '\0';
        }

        if (len == 0) continue;
        if (strcasecmp(line, "EXIT") == 0 || strcasecmp(line, "QUIT") == 0) {
            break;
        }

        Chunk chunk;
        chunk_init(&chunk);

        char err_buf[512] = {0};
        if (!relay_compile(line, &chunk, err_buf, sizeof(err_buf))) {
            printf("Error: %s\n", err_buf);
            chunk_free(&chunk);
            continue;
        }

        vm_run(&vm, &chunk);
        chunk_free(&chunk);
    }

    vm_free(&vm);
}

int main(int argc, char **argv) {
    if (argc < 2) {
        run_repl();
        return 0;
    }

    const char *cmd = argv[1];
    if (strcmp(cmd, "run") == 0) {
        if (argc < 3) {
            fprintf(stderr, "Usage: relay run <program.bas>\n");
            return 1;
        }
        return run_file(argv[2]);
    } else if (strcmp(cmd, "repl") == 0) {
        run_repl();
        return 0;
    } else if (strcmp(cmd, "version") == 0 || strcmp(cmd, "-v") == 0 || strcmp(cmd, "--version") == 0) {
        printf("relay version %s\n", RELAY_VERSION);
        return 0;
    } else if (strcmp(cmd, "info") == 0) {
        print_banner();
        printf("Stack Max: %d | Frames Max: %d | Globals Max: %d\n",
               RELAY_STACK_MAX, RELAY_FRAMES_MAX, RELAY_GLOBALS_MAX);
        printf("Tag DB Max: %d | Historian Buffer: %d samples\n",
               RELAY_MAX_TAGS, RELAY_HIST_BUFFER_SIZE);
        return 0;
    } else {
        /* Assume first argument is a file to run */
        return run_file(cmd);
    }
}
