#ifndef RELAY_VM_H
#define RELAY_VM_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#define RELAY_STACK_MAX 65536
#define RELAY_FRAMES_MAX 2048
#define RELAY_GLOBALS_MAX 4096
#define RELAY_CONSTANTS_MAX 8192

typedef enum {
    OP_NOP = 0,
    OP_HALT,
    OP_POP,
    OP_DUP,
    OP_SWAP,

    /* Literals and Constants */
    OP_CONST_NIL,
    OP_CONST_INT,
    OP_CONST_DOUBLE,
    OP_CONST_STRING,

    /* Variable Access */
    OP_LOAD_LOCAL,
    OP_STORE_LOCAL,
    OP_LOAD_GLOBAL,
    OP_STORE_GLOBAL,

    /* Array Operations */
    OP_ARRAY_ALLOC,
    OP_ARRAY_GET,
    OP_ARRAY_SET,
    OP_ARRAY_LEN,

    /* Record / User-Defined Types */
    OP_RECORD_ALLOC,
    OP_RECORD_GET,
    OP_RECORD_SET,

    /* Arithmetic Operations */
    OP_ADD,
    OP_SUB,
    OP_MUL,
    OP_DIV,
    OP_IDIV,
    OP_MOD,
    OP_NEG,
    OP_POW,

    /* Logical and Comparison Operations */
    OP_EQ,
    OP_NE,
    OP_LT,
    OP_LE,
    OP_GT,
    OP_GE,
    OP_NOT,
    OP_AND,
    OP_OR,
    OP_XOR,

    /* Control Flow */
    OP_JUMP,
    OP_JUMP_IF_TRUE,
    OP_JUMP_IF_FALSE,

    /* Function and Subroutine Calls */
    OP_CALL,
    OP_RETURN,

    /* Native Host Calls */
    OP_SYSCALL,

    /* Standard I/O */
    OP_PRINT,
    OP_PRINT_STR,
    OP_PRINT_NL,
    OP_INPUT_INT,
    OP_INPUT_DOUBLE,
    OP_INPUT_STR
} OpCode;

typedef enum {
    VAL_NIL,
    VAL_INT,
    VAL_DOUBLE,
    VAL_STRING,
    VAL_ARRAY,
    VAL_RECORD
} ValueType;

typedef struct Value Value;

typedef struct {
    char *chars;
    size_t length;
    uint32_t ref_count;
} StringObj;

typedef struct {
    Value *items;
    size_t size;
    size_t capacity;
    uint32_t ref_count;
} ArrayObj;

typedef struct {
    Value *fields;
    size_t field_count;
    uint32_t ref_count;
} RecordObj;

struct Value {
    ValueType type;
    union {
        int64_t int_val;
        double double_val;
        StringObj *string_val;
        ArrayObj *array_val;
        RecordObj *record_val;
    } as;
};

/* Value Constructors and Memory Helpers */
Value val_nil(void);
Value val_int(int64_t v);
Value val_double(double v);
Value val_string(const char *str);
Value val_string_len(const char *str, size_t len);
Value val_array(size_t initial_size);
Value val_record(size_t field_count);

void val_retain(Value v);
void val_release(Value v);
bool val_equal(Value a, Value b);
void val_print(Value v);
const char *val_type_name(ValueType t);

/* Bytecode Container */
typedef struct {
    uint8_t *code;
    size_t count;
    size_t capacity;
    Value *constants;
    size_t const_count;
    size_t const_capacity;
    uint32_t *lines;
} Chunk;

void chunk_init(Chunk *chunk);
void chunk_free(Chunk *chunk);
void chunk_write(Chunk *chunk, uint8_t byte, uint32_t line);
size_t chunk_add_constant(Chunk *chunk, Value val);

/* Execution Call Frame */
typedef struct {
    Chunk *chunk;
    size_t ip;
    size_t slot_base;
} CallFrame;

/* Virtual Machine State */
typedef struct {
    Chunk *main_chunk;
    CallFrame frames[RELAY_FRAMES_MAX];
    size_t frame_count;

    Value stack[RELAY_STACK_MAX];
    size_t sp;

    Value globals[RELAY_GLOBALS_MAX];
    char *global_names[RELAY_GLOBALS_MAX];
    size_t global_count;

    bool trace_execution;
    bool halted;
    int exit_code;
    char error_msg[512];
} VM;

void vm_init(VM *vm);
void vm_free(VM *vm);
void vm_reset_stack(VM *vm);
void vm_push(VM *vm, Value v);
Value vm_pop(VM *vm);
Value vm_peek(VM *vm, size_t distance);

int vm_define_global(VM *vm, const char *name, Value val);
int vm_find_global(VM *vm, const char *name);

typedef Value (*SyscallFn)(VM *vm, int arg_count, Value *args);
void vm_register_syscall(uint8_t id, SyscallFn fn);

int vm_run(VM *vm, Chunk *chunk);

#endif /* RELAY_VM_H */
