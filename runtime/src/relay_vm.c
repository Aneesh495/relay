#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "relay_vm.h"

static SyscallFn g_syscall_table[256] = {0};

Value val_nil(void) {
    Value v;
    v.type = VAL_NIL;
    v.as.int_val = 0;
    return v;
}

Value val_int(int64_t v) {
    Value val;
    val.type = VAL_INT;
    val.as.int_val = v;
    return val;
}

Value val_double(double v) {
    Value val;
    val.type = VAL_DOUBLE;
    val.as.double_val = v;
    return val;
}

Value val_string_len(const char *str, size_t len) {
    Value val;
    val.type = VAL_STRING;
    StringObj *obj = (StringObj *)malloc(sizeof(StringObj));
    if (!obj) {
        return val_nil();
    }
    obj->chars = (char *)malloc(len + 1);
    if (!obj->chars) {
        free(obj);
        return val_nil();
    }
    if (str && len > 0) {
        memcpy(obj->chars, str, len);
    }
    obj->chars[len] = '\0';
    obj->length = len;
    obj->ref_count = 1;
    val.as.string_val = obj;
    return val;
}

Value val_string(const char *str) {
    if (!str) {
        return val_string_len("", 0);
    }
    return val_string_len(str, strlen(str));
}

Value val_array(size_t initial_size) {
    Value val;
    val.type = VAL_ARRAY;
    ArrayObj *obj = (ArrayObj *)malloc(sizeof(ArrayObj));
    if (!obj) {
        return val_nil();
    }
    obj->size = initial_size;
    obj->capacity = initial_size > 8 ? initial_size : 8;
    obj->items = (Value *)calloc(obj->capacity, sizeof(Value));
    obj->ref_count = 1;
    val.as.array_val = obj;
    return val;
}

Value val_record(size_t field_count) {
    Value val;
    val.type = VAL_RECORD;
    RecordObj *obj = (RecordObj *)malloc(sizeof(RecordObj));
    if (!obj) {
        return val_nil();
    }
    obj->field_count = field_count;
    obj->fields = (Value *)calloc(field_count, sizeof(Value));
    obj->ref_count = 1;
    val.as.record_val = obj;
    return val;
}

void val_retain(Value v) {
    if (v.type == VAL_STRING && v.as.string_val) {
        v.as.string_val->ref_count++;
    } else if (v.type == VAL_ARRAY && v.as.array_val) {
        v.as.array_val->ref_count++;
    } else if (v.type == VAL_RECORD && v.as.record_val) {
        v.as.record_val->ref_count++;
    }
}

void val_release(Value v) {
    if (v.type == VAL_STRING && v.as.string_val) {
        if (--v.as.string_val->ref_count == 0) {
            free(v.as.string_val->chars);
            free(v.as.string_val);
        }
    } else if (v.type == VAL_ARRAY && v.as.array_val) {
        if (--v.as.array_val->ref_count == 0) {
            for (size_t i = 0; i < v.as.array_val->size; ++i) {
                val_release(v.as.array_val->items[i]);
            }
            free(v.as.array_val->items);
            free(v.as.array_val);
        }
    } else if (v.type == VAL_RECORD && v.as.record_val) {
        if (--v.as.record_val->ref_count == 0) {
            for (size_t i = 0; i < v.as.record_val->field_count; ++i) {
                val_release(v.as.record_val->fields[i]);
            }
            free(v.as.record_val->fields);
            free(v.as.record_val);
        }
    }
}

bool val_equal(Value a, Value b) {
    if (a.type != b.type) {
        if ((a.type == VAL_INT || a.type == VAL_DOUBLE) &&
            (b.type == VAL_INT || b.type == VAL_DOUBLE)) {
            double da = (a.type == VAL_INT) ? (double)a.as.int_val : a.as.double_val;
            double db = (b.type == VAL_INT) ? (double)b.as.int_val : b.as.double_val;
            return fabs(da - db) < 1e-9;
        }
        return false;
    }
    switch (a.type) {
        case VAL_NIL: return true;
        case VAL_INT: return a.as.int_val == b.as.int_val;
        case VAL_DOUBLE: return fabs(a.as.double_val - b.as.double_val) < 1e-9;
        case VAL_STRING:
            return (a.as.string_val->length == b.as.string_val->length) &&
                   (strcmp(a.as.string_val->chars, b.as.string_val->chars) == 0);
        case VAL_ARRAY: return a.as.array_val == b.as.array_val;
        case VAL_RECORD: return a.as.record_val == b.as.record_val;
        default: return false;
    }
}

void val_print(Value v) {
    switch (v.type) {
        case VAL_NIL: printf("NIL"); break;
        case VAL_INT: printf("%lld", (long long)v.as.int_val); break;
        case VAL_DOUBLE: printf("%.6f", v.as.double_val); break;
        case VAL_STRING: printf("%s", v.as.string_val ? v.as.string_val->chars : ""); break;
        case VAL_ARRAY: printf("<ARRAY[%zu]>", v.as.array_val ? v.as.array_val->size : 0); break;
        case VAL_RECORD: printf("<RECORD[%zu]>", v.as.record_val ? v.as.record_val->field_count : 0); break;
    }
}

const char *val_type_name(ValueType t) {
    switch (t) {
        case VAL_NIL: return "NIL";
        case VAL_INT: return "INTEGER";
        case VAL_DOUBLE: return "DOUBLE";
        case VAL_STRING: return "STRING";
        case VAL_ARRAY: return "ARRAY";
        case VAL_RECORD: return "RECORD";
        default: return "UNKNOWN";
    }
}

void chunk_init(Chunk *chunk) {
    chunk->code = NULL;
    chunk->count = 0;
    chunk->capacity = 0;
    chunk->constants = NULL;
    chunk->const_count = 0;
    chunk->const_capacity = 0;
    chunk->lines = NULL;
}

void chunk_free(Chunk *chunk) {
    if (chunk->code) free(chunk->code);
    if (chunk->lines) free(chunk->lines);
    for (size_t i = 0; i < chunk->const_count; ++i) {
        val_release(chunk->constants[i]);
    }
    if (chunk->constants) free(chunk->constants);
    chunk_init(chunk);
}

void chunk_write(Chunk *chunk, uint8_t byte, uint32_t line) {
    if (chunk->count >= chunk->capacity) {
        size_t old_cap = chunk->capacity;
        chunk->capacity = old_cap < 8 ? 8 : old_cap * 2;
        chunk->code = (uint8_t *)realloc(chunk->code, chunk->capacity);
        chunk->lines = (uint32_t *)realloc(chunk->lines, chunk->capacity * sizeof(uint32_t));
    }
    chunk->code[chunk->count] = byte;
    chunk->lines[chunk->count] = line;
    chunk->count++;
}

size_t chunk_add_constant(Chunk *chunk, Value val) {
    if (chunk->const_count >= chunk->const_capacity) {
        size_t old_cap = chunk->const_capacity;
        chunk->const_capacity = old_cap < 8 ? 8 : old_cap * 2;
        chunk->constants = (Value *)realloc(chunk->constants, chunk->const_capacity * sizeof(Value));
    }
    val_retain(val);
    chunk->constants[chunk->const_count] = val;
    return chunk->const_count++;
}

void vm_init(VM *vm) {
    vm->main_chunk = NULL;
    vm->frame_count = 0;
    vm->sp = 0;
    vm->global_count = 0;
    vm->trace_execution = false;
    vm->halted = false;
    vm->exit_code = 0;
    memset(vm->error_msg, 0, sizeof(vm->error_msg));
    for (size_t i = 0; i < RELAY_GLOBALS_MAX; ++i) {
        vm->globals[i] = val_nil();
        vm->global_names[i] = NULL;
    }
}

void vm_free(VM *vm) {
    vm_reset_stack(vm);
    for (size_t i = 0; i < vm->global_count; ++i) {
        val_release(vm->globals[i]);
        if (vm->global_names[i]) {
            free(vm->global_names[i]);
        }
    }
    vm->global_count = 0;
}

void vm_reset_stack(VM *vm) {
    while (vm->sp > 0) {
        val_release(vm->stack[--vm->sp]);
    }
    vm->frame_count = 0;
}

void vm_push(VM *vm, Value v) {
    if (vm->sp >= RELAY_STACK_MAX) {
        fprintf(stderr, "Fatal: VM stack overflow\n");
        exit(1);
    }
    val_retain(v);
    vm->stack[vm->sp++] = v;
}

Value vm_pop(VM *vm) {
    if (vm->sp == 0) {
        fprintf(stderr, "Fatal: VM stack underflow\n");
        exit(1);
    }
    Value v = vm->stack[--vm->sp];
    return v;
}

Value vm_peek(VM *vm, size_t distance) {
    if (vm->sp <= distance) {
        return val_nil();
    }
    return vm->stack[vm->sp - 1 - distance];
}

int vm_define_global(VM *vm, const char *name, Value val) {
    for (size_t i = 0; i < vm->global_count; ++i) {
        if (strcmp(vm->global_names[i], name) == 0) {
            val_release(vm->globals[i]);
            val_retain(val);
            vm->globals[i] = val;
            return (int)i;
        }
    }
    if (vm->global_count >= RELAY_GLOBALS_MAX) {
        return -1;
    }
    int idx = (int)vm->global_count++;
    vm->global_names[idx] = strdup(name);
    val_retain(val);
    vm->globals[idx] = val;
    return idx;
}

int vm_find_global(VM *vm, const char *name) {
    for (size_t i = 0; i < vm->global_count; ++i) {
        if (strcmp(vm->global_names[i], name) == 0) {
            return (int)i;
        }
    }
    return -1;
}

void vm_register_syscall(uint8_t id, SyscallFn fn) {
    g_syscall_table[id] = fn;
}

static inline double to_double(Value v) {
    if (v.type == VAL_DOUBLE) return v.as.double_val;
    if (v.type == VAL_INT) return (double)v.as.int_val;
    return 0.0;
}

static inline int64_t to_int(Value v) {
    if (v.type == VAL_INT) return v.as.int_val;
    if (v.type == VAL_DOUBLE) return (int64_t)v.as.double_val;
    return 0;
}

int vm_run(VM *vm, Chunk *chunk) {
    if (!chunk || chunk->count == 0) {
        return 0;
    }
    vm->main_chunk = chunk;
    vm->frame_count = 1;
    vm->frames[0].chunk = chunk;
    vm->frames[0].ip = 0;
    vm->frames[0].slot_base = 0;

    CallFrame *frame = &vm->frames[0];

    while (!vm->halted) {
        if (frame->ip >= frame->chunk->count) {
            break;
        }

        uint8_t op = frame->chunk->code[frame->ip++];
        switch (op) {
            case OP_NOP:
                break;

            case OP_HALT:
                vm->halted = true;
                break;

            case OP_POP: {
                Value v = vm_pop(vm);
                val_release(v);
                break;
            }

            case OP_DUP: {
                Value v = vm_peek(vm, 0);
                vm_push(vm, v);
                break;
            }

            case OP_SWAP: {
                Value a = vm_pop(vm);
                Value b = vm_pop(vm);
                vm_push(vm, a);
                vm_push(vm, b);
                val_release(a);
                val_release(b);
                break;
            }

            case OP_CONST_NIL:
                vm_push(vm, val_nil());
                break;

            case OP_CONST_INT: {
                uint8_t idx = frame->chunk->code[frame->ip++];
                Value val = frame->chunk->constants[idx];
                vm_push(vm, val);
                break;
            }

            case OP_CONST_DOUBLE: {
                uint8_t idx = frame->chunk->code[frame->ip++];
                Value val = frame->chunk->constants[idx];
                vm_push(vm, val);
                break;
            }

            case OP_CONST_STRING: {
                uint8_t idx = frame->chunk->code[frame->ip++];
                Value val = frame->chunk->constants[idx];
                vm_push(vm, val);
                break;
            }

            case OP_LOAD_LOCAL: {
                uint8_t slot = frame->chunk->code[frame->ip++];
                size_t index = frame->slot_base + slot;
                vm_push(vm, vm->stack[index]);
                break;
            }

            case OP_STORE_LOCAL: {
                uint8_t slot = frame->chunk->code[frame->ip++];
                size_t index = frame->slot_base + slot;
                Value v = vm_peek(vm, 0);
                val_release(vm->stack[index]);
                val_retain(v);
                vm->stack[index] = v;
                break;
            }

            case OP_LOAD_GLOBAL: {
                uint8_t idx = frame->chunk->code[frame->ip++];
                vm_push(vm, vm->globals[idx]);
                break;
            }

            case OP_STORE_GLOBAL: {
                uint8_t idx = frame->chunk->code[frame->ip++];
                Value v = vm_peek(vm, 0);
                val_release(vm->globals[idx]);
                val_retain(v);
                vm->globals[idx] = v;
                break;
            }

            case OP_ARRAY_ALLOC: {
                Value sz = vm_pop(vm);
                int64_t n = to_int(sz);
                val_release(sz);
                vm_push(vm, val_array(n > 0 ? (size_t)n : 0));
                break;
            }

            case OP_ARRAY_GET: {
                Value idx_val = vm_pop(vm);
                Value arr_val = vm_pop(vm);
                int64_t idx = to_int(idx_val);
                if (arr_val.type == VAL_ARRAY && arr_val.as.array_val &&
                    idx >= 0 && (size_t)idx < arr_val.as.array_val->size) {
                    vm_push(vm, arr_val.as.array_val->items[idx]);
                } else {
                    vm_push(vm, val_nil());
                }
                val_release(idx_val);
                val_release(arr_val);
                break;
            }

            case OP_ARRAY_SET: {
                Value val = vm_pop(vm);
                Value idx_val = vm_pop(vm);
                Value arr_val = vm_pop(vm);
                int64_t idx = to_int(idx_val);
                if (arr_val.type == VAL_ARRAY && arr_val.as.array_val &&
                    idx >= 0 && (size_t)idx < arr_val.as.array_val->size) {
                    val_release(arr_val.as.array_val->items[idx]);
                    val_retain(val);
                    arr_val.as.array_val->items[idx] = val;
                }
                vm_push(vm, val);
                val_release(val);
                val_release(idx_val);
                val_release(arr_val);
                break;
            }

            case OP_ARRAY_LEN: {
                Value arr_val = vm_pop(vm);
                if (arr_val.type == VAL_ARRAY && arr_val.as.array_val) {
                    vm_push(vm, val_int((int64_t)arr_val.as.array_val->size));
                } else {
                    vm_push(vm, val_int(0));
                }
                val_release(arr_val);
                break;
            }

            case OP_RECORD_ALLOC: {
                uint8_t count = frame->chunk->code[frame->ip++];
                vm_push(vm, val_record(count));
                break;
            }

            case OP_RECORD_GET: {
                uint8_t f_idx = frame->chunk->code[frame->ip++];
                Value rec = vm_pop(vm);
                if (rec.type == VAL_RECORD && rec.as.record_val &&
                    f_idx < rec.as.record_val->field_count) {
                    vm_push(vm, rec.as.record_val->fields[f_idx]);
                } else {
                    vm_push(vm, val_nil());
                }
                val_release(rec);
                break;
            }

            case OP_RECORD_SET: {
                uint8_t f_idx = frame->chunk->code[frame->ip++];
                Value val = vm_pop(vm);
                Value rec = vm_pop(vm);
                if (rec.type == VAL_RECORD && rec.as.record_val &&
                    f_idx < rec.as.record_val->field_count) {
                    val_release(rec.as.record_val->fields[f_idx]);
                    val_retain(val);
                    rec.as.record_val->fields[f_idx] = val;
                }
                vm_push(vm, val);
                val_release(val);
                val_release(rec);
                break;
            }

            case OP_ADD: {
                Value b = vm_pop(vm);
                Value a = vm_pop(vm);
                if (a.type == VAL_STRING || b.type == VAL_STRING) {
                    char buf_a[128];
                    char buf_b[128];
                    const char *sa = (a.type == VAL_STRING && a.as.string_val) ? a.as.string_val->chars : "";
                    const char *sb = (b.type == VAL_STRING && b.as.string_val) ? b.as.string_val->chars : "";
                    if (a.type != VAL_STRING) {
                        if (a.type == VAL_INT) {
                            snprintf(buf_a, sizeof(buf_a), "%lld", (long long)a.as.int_val);
                        } else {
                            snprintf(buf_a, sizeof(buf_a), "%.6f", a.as.double_val);
                        }
                        sa = buf_a;
                    }
                    if (b.type != VAL_STRING) {
                        if (b.type == VAL_INT) {
                            snprintf(buf_b, sizeof(buf_b), "%lld", (long long)b.as.int_val);
                        } else {
                            snprintf(buf_b, sizeof(buf_b), "%.6f", b.as.double_val);
                        }
                        sb = buf_b;
                    }
                    size_t la = strlen(sa);
                    size_t lb = strlen(sb);
                    char *merged = (char *)malloc(la + lb + 1);
                    strcpy(merged, sa);
                    strcat(merged, sb);
                    Value res = val_string_len(merged, la + lb);
                    free(merged);
                    vm_push(vm, res);
                    val_release(res);
                } else if (a.type == VAL_DOUBLE || b.type == VAL_DOUBLE) {
                    vm_push(vm, val_double(to_double(a) + to_double(b)));
                } else {
                    vm_push(vm, val_int(to_int(a) + to_int(b)));
                }
                val_release(a);
                val_release(b);
                break;
            }

            case OP_SUB: {
                Value b = vm_pop(vm);
                Value a = vm_pop(vm);
                if (a.type == VAL_DOUBLE || b.type == VAL_DOUBLE) {
                    vm_push(vm, val_double(to_double(a) - to_double(b)));
                } else {
                    vm_push(vm, val_int(to_int(a) - to_int(b)));
                }
                val_release(a);
                val_release(b);
                break;
            }

            case OP_MUL: {
                Value b = vm_pop(vm);
                Value a = vm_pop(vm);
                if (a.type == VAL_DOUBLE || b.type == VAL_DOUBLE) {
                    vm_push(vm, val_double(to_double(a) * to_double(b)));
                } else {
                    vm_push(vm, val_int(to_int(a) * to_int(b)));
                }
                val_release(a);
                val_release(b);
                break;
            }

            case OP_DIV: {
                Value b = vm_pop(vm);
                Value a = vm_pop(vm);
                double denom = to_double(b);
                if (fabs(denom) < 1e-15) {
                    vm_push(vm, val_double(0.0));
                } else {
                    vm_push(vm, val_double(to_double(a) / denom));
                }
                val_release(a);
                val_release(b);
                break;
            }

            case OP_IDIV: {
                Value b = vm_pop(vm);
                Value a = vm_pop(vm);
                int64_t denom = to_int(b);
                if (denom == 0) {
                    vm_push(vm, val_int(0));
                } else {
                    vm_push(vm, val_int(to_int(a) / denom));
                }
                val_release(a);
                val_release(b);
                break;
            }

            case OP_MOD: {
                Value b = vm_pop(vm);
                Value a = vm_pop(vm);
                int64_t denom = to_int(b);
                if (denom == 0) {
                    vm_push(vm, val_int(0));
                } else {
                    vm_push(vm, val_int(to_int(a) % denom));
                }
                val_release(a);
                val_release(b);
                break;
            }

            case OP_NEG: {
                Value a = vm_pop(vm);
                if (a.type == VAL_DOUBLE) {
                    vm_push(vm, val_double(-a.as.double_val));
                } else {
                    vm_push(vm, val_int(-a.as.int_val));
                }
                val_release(a);
                break;
            }

            case OP_POW: {
                Value b = vm_pop(vm);
                Value a = vm_pop(vm);
                vm_push(vm, val_double(pow(to_double(a), to_double(b))));
                val_release(a);
                val_release(b);
                break;
            }

            case OP_EQ: {
                Value b = vm_pop(vm);
                Value a = vm_pop(vm);
                vm_push(vm, val_int(val_equal(a, b) ? 1 : 0));
                val_release(a);
                val_release(b);
                break;
            }

            case OP_NE: {
                Value b = vm_pop(vm);
                Value a = vm_pop(vm);
                vm_push(vm, val_int(!val_equal(a, b) ? 1 : 0));
                val_release(a);
                val_release(b);
                break;
            }

            case OP_LT: {
                Value b = vm_pop(vm);
                Value a = vm_pop(vm);
                vm_push(vm, val_int((to_double(a) < to_double(b)) ? 1 : 0));
                val_release(a);
                val_release(b);
                break;
            }

            case OP_LE: {
                Value b = vm_pop(vm);
                Value a = vm_pop(vm);
                vm_push(vm, val_int((to_double(a) <= to_double(b)) ? 1 : 0));
                val_release(a);
                val_release(b);
                break;
            }

            case OP_GT: {
                Value b = vm_pop(vm);
                Value a = vm_pop(vm);
                vm_push(vm, val_int((to_double(a) > to_double(b)) ? 1 : 0));
                val_release(a);
                val_release(b);
                break;
            }

            case OP_GE: {
                Value b = vm_pop(vm);
                Value a = vm_pop(vm);
                vm_push(vm, val_int((to_double(a) >= to_double(b)) ? 1 : 0));
                val_release(a);
                val_release(b);
                break;
            }

            case OP_NOT: {
                Value a = vm_pop(vm);
                vm_push(vm, val_int(!to_int(a) ? 1 : 0));
                val_release(a);
                break;
            }

            case OP_AND: {
                Value b = vm_pop(vm);
                Value a = vm_pop(vm);
                vm_push(vm, val_int((to_int(a) && to_int(b)) ? 1 : 0));
                val_release(a);
                val_release(b);
                break;
            }

            case OP_OR: {
                Value b = vm_pop(vm);
                Value a = vm_pop(vm);
                vm_push(vm, val_int((to_int(a) || to_int(b)) ? 1 : 0));
                val_release(a);
                val_release(b);
                break;
            }

            case OP_XOR: {
                Value b = vm_pop(vm);
                Value a = vm_pop(vm);
                vm_push(vm, val_int((to_int(a) ^ to_int(b)) ? 1 : 0));
                val_release(a);
                val_release(b);
                break;
            }

            case OP_JUMP: {
                uint16_t offset = (uint16_t)((frame->chunk->code[frame->ip] << 8) |
                                            frame->chunk->code[frame->ip + 1]);
                frame->ip += 2 + offset;
                break;
            }

            case OP_JUMP_IF_TRUE: {
                uint16_t offset = (uint16_t)((frame->chunk->code[frame->ip] << 8) |
                                            frame->chunk->code[frame->ip + 1]);
                frame->ip += 2;
                Value cond = vm_pop(vm);
                if (to_int(cond) != 0) {
                    frame->ip += offset;
                }
                val_release(cond);
                break;
            }

            case OP_JUMP_IF_FALSE: {
                uint16_t offset = (uint16_t)((frame->chunk->code[frame->ip] << 8) |
                                            frame->chunk->code[frame->ip + 1]);
                frame->ip += 2;
                Value cond = vm_pop(vm);
                if (to_int(cond) == 0) {
                    frame->ip += offset;
                }
                val_release(cond);
                break;
            }

            case OP_CALL: {
                uint8_t arg_count = frame->chunk->code[frame->ip++];
                uint16_t target_ip = (uint16_t)((frame->chunk->code[frame->ip] << 8) |
                                                frame->chunk->code[frame->ip + 1]);
                frame->ip += 2;

                if (vm->frame_count >= RELAY_FRAMES_MAX) {
                    fprintf(stderr, "Fatal: Call stack overflow\n");
                    return -1;
                }
                CallFrame *new_frame = &vm->frames[vm->frame_count++];
                new_frame->chunk = frame->chunk;
                new_frame->ip = target_ip;
                new_frame->slot_base = vm->sp - arg_count;
                frame = new_frame;
                break;
            }

            case OP_RETURN: {
                Value ret_val = vm_pop(vm);
                while (vm->sp > frame->slot_base) {
                    Value discarded = vm_pop(vm);
                    val_release(discarded);
                }
                vm->frame_count--;
                if (vm->frame_count == 0) {
                    val_release(ret_val);
                    return 0;
                }
                frame = &vm->frames[vm->frame_count - 1];
                vm_push(vm, ret_val);
                val_release(ret_val);
                break;
            }

            case OP_SYSCALL: {
                uint8_t sys_id = frame->chunk->code[frame->ip++];
                uint8_t arg_count = frame->chunk->code[frame->ip++];
                Value args[16];
                for (int i = arg_count - 1; i >= 0; --i) {
                    args[i] = vm_pop(vm);
                }
                SyscallFn fn = g_syscall_table[sys_id];
                Value result = val_nil();
                if (fn) {
                    result = fn(vm, arg_count, args);
                } else {
                    fprintf(stderr, "Warning: Unhandled syscall id %d\n", sys_id);
                }
                for (int i = 0; i < arg_count; ++i) {
                    val_release(args[i]);
                }
                vm_push(vm, result);
                val_release(result);
                break;
            }

            case OP_PRINT: {
                Value v = vm_pop(vm);
                val_print(v);
                val_release(v);
                break;
            }

            case OP_PRINT_STR: {
                uint8_t idx = frame->chunk->code[frame->ip++];
                Value str = frame->chunk->constants[idx];
                val_print(str);
                break;
            }

            case OP_PRINT_NL:
                printf("\n");
                fflush(stdout);
                break;

            default:
                fprintf(stderr, "Unknown opcode: %d at IP %zu\n", op, frame->ip - 1);
                return -1;
        }
    }

    return 0;
}
