#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <unistd.h>
#include "relay_ffi.h"
#include "relay_tag_engine.h"
#include "relay_historian.h"
#include "relay_modbus.h"

static int64_t ffi_get_clock_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return (int64_t)ts.tv_sec * 1000 + (ts.tv_nsec / 1000000);
}

static int64_t ffi_get_clock_micros(void) {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return (int64_t)ts.tv_sec * 1000000 + (ts.tv_nsec / 1000);
}

static Value sys_clock_ms(VM *vm, int arg_count, Value *args) {
    (void)vm; (void)arg_count; (void)args;
    return val_int(ffi_get_clock_ms());
}

static Value sys_clock_micros(VM *vm, int arg_count, Value *args) {
    (void)vm; (void)arg_count; (void)args;
    return val_int(ffi_get_clock_micros());
}

static Value sys_sleep_ms(VM *vm, int arg_count, Value *args) {
    (void)vm;
    if (arg_count > 0 && (args[0].type == VAL_INT || args[0].type == VAL_DOUBLE)) {
        int64_t ms = args[0].type == VAL_INT ? args[0].as.int_val : (int64_t)args[0].as.double_val;
        if (ms > 0) {
            usleep((useconds_t)(ms * 1000));
        }
    }
    return val_nil();
}

static Value sys_tag_register(VM *vm, int arg_count, Value *args) {
    (void)vm;
    if (arg_count < 5) return val_int(-1);
    const char *name = (args[0].type == VAL_STRING && args[0].as.string_val) ? args[0].as.string_val->chars : "";
    int type = (int)(args[1].type == VAL_INT ? args[1].as.int_val : 0);
    const char *units = (args[2].type == VAL_STRING && args[2].as.string_val) ? args[2].as.string_val->chars : "";
    double min_eu = args[3].type == VAL_DOUBLE ? args[3].as.double_val : (double)args[3].as.int_val;
    double max_eu = args[4].type == VAL_DOUBLE ? args[4].as.double_val : (double)args[4].as.int_val;

    int id = tag_db_register(relay_global_tag_db(), name, (TagType)type, units, min_eu, max_eu);
    return val_int(id);
}

static Value sys_tag_read(VM *vm, int arg_count, Value *args) {
    (void)vm;
    if (arg_count < 1) return val_double(0.0);
    int id = (int)(args[0].type == VAL_INT ? args[0].as.int_val : 0);
    double v = tag_db_get_eu(relay_global_tag_db(), id);
    return val_double(v);
}

static Value sys_tag_write(VM *vm, int arg_count, Value *args) {
    (void)vm;
    if (arg_count < 2) return val_int(0);
    int id = (int)(args[0].type == VAL_INT ? args[0].as.int_val : 0);
    double v = args[1].type == VAL_DOUBLE ? args[1].as.double_val : (double)args[1].as.int_val;
    bool ok = tag_db_set_eu(relay_global_tag_db(), id, v);
    return val_int(ok ? 1 : 0);
}

static Value sys_tag_get_quality(VM *vm, int arg_count, Value *args) {
    (void)vm;
    if (arg_count < 1) return val_int(0);
    int id = (int)(args[0].type == VAL_INT ? args[0].as.int_val : 0);
    TagQuality q = tag_db_get_quality(relay_global_tag_db(), id);
    return val_int((int64_t)q);
}

static Value sys_tag_set_quality(VM *vm, int arg_count, Value *args) {
    (void)vm;
    if (arg_count < 2) return val_int(0);
    int id = (int)(args[0].type == VAL_INT ? args[0].as.int_val : 0);
    int q = (int)(args[1].type == VAL_INT ? args[1].as.int_val : 0);
    bool ok = tag_db_set_quality(relay_global_tag_db(), id, (TagQuality)q);
    return val_int(ok ? 1 : 0);
}

static Value sys_hist_ingest(VM *vm, int arg_count, Value *args) {
    (void)vm;
    if (arg_count < 4) return val_int(0);
    int sid = (int)(args[0].type == VAL_INT ? args[0].as.int_val : 0);
    int64_t ts = args[1].type == VAL_INT ? args[1].as.int_val : (int64_t)args[1].as.double_val;
    double val = args[2].type == VAL_DOUBLE ? args[2].as.double_val : (double)args[2].as.int_val;
    int q = (int)(args[3].type == VAL_INT ? args[3].as.int_val : 192);

    bool ok = historian_ingest(relay_global_historian(), sid, ts, val, (TagQuality)q);
    return val_int(ok ? 1 : 0);
}

static Value sys_hist_twa(VM *vm, int arg_count, Value *args) {
    (void)vm;
    if (arg_count < 3) return val_double(0.0);
    int sid = (int)(args[0].type == VAL_INT ? args[0].as.int_val : 0);
    int64_t t0 = args[1].type == VAL_INT ? args[1].as.int_val : (int64_t)args[1].as.double_val;
    int64_t t1 = args[2].type == VAL_INT ? args[2].as.int_val : (int64_t)args[2].as.double_val;

    double avg = historian_time_weighted_average(relay_global_historian(), sid, t0, t1);
    return val_double(avg);
}

static Value sys_hist_total(VM *vm, int arg_count, Value *args) {
    (void)vm;
    if (arg_count < 3) return val_double(0.0);
    int sid = (int)(args[0].type == VAL_INT ? args[0].as.int_val : 0);
    int64_t t0 = args[1].type == VAL_INT ? args[1].as.int_val : (int64_t)args[1].as.double_val;
    int64_t t1 = args[2].type == VAL_INT ? args[2].as.int_val : (int64_t)args[2].as.double_val;

    double tot = historian_trapezoidal_total(relay_global_historian(), sid, t0, t1);
    return val_double(tot);
}

static Value sys_modbus_crc(VM *vm, int arg_count, Value *args) {
    (void)vm;
    if (arg_count < 1 || args[0].type != VAL_STRING || !args[0].as.string_val) {
        return val_int(0);
    }
    const uint8_t *buf = (const uint8_t *)args[0].as.string_val->chars;
    size_t len = args[0].as.string_val->length;
    uint16_t crc = modbus_crc16(buf, len);
    return val_int(crc);
}

static Value sys_math_sin(VM *vm, int arg_count, Value *args) {
    (void)vm;
    if (arg_count < 1) return val_double(0.0);
    double x = args[0].type == VAL_DOUBLE ? args[0].as.double_val : (double)args[0].as.int_val;
    return val_double(sin(x));
}

static Value sys_math_cos(VM *vm, int arg_count, Value *args) {
    (void)vm;
    if (arg_count < 1) return val_double(0.0);
    double x = args[0].type == VAL_DOUBLE ? args[0].as.double_val : (double)args[0].as.int_val;
    return val_double(cos(x));
}

static Value sys_math_exp(VM *vm, int arg_count, Value *args) {
    (void)vm;
    if (arg_count < 1) return val_double(0.0);
    double x = args[0].type == VAL_DOUBLE ? args[0].as.double_val : (double)args[0].as.int_val;
    return val_double(exp(x));
}

static Value sys_math_log(VM *vm, int arg_count, Value *args) {
    (void)vm;
    if (arg_count < 1) return val_double(0.0);
    double x = args[0].type == VAL_DOUBLE ? args[0].as.double_val : (double)args[0].as.int_val;
    return val_double(x > 0 ? log(x) : 0.0);
}

static Value sys_math_sqr(VM *vm, int arg_count, Value *args) {
    (void)vm;
    if (arg_count < 1) return val_double(0.0);
    double x = args[0].type == VAL_DOUBLE ? args[0].as.double_val : (double)args[0].as.int_val;
    return val_double(x >= 0 ? sqrt(x) : 0.0);
}

static Value sys_math_rnd(VM *vm, int arg_count, Value *args) {
    (void)vm; (void)arg_count; (void)args;
    double r = (double)rand() / (double)RAND_MAX;
    return val_double(r);
}

static Value sys_console_color(VM *vm, int arg_count, Value *args) {
    (void)vm;
    if (arg_count > 0 && args[0].type == VAL_INT) {
        int c = (int)args[0].as.int_val;
        /* ANSI color escape sequences */
        switch (c) {
            case 0: printf("\033[0m"); break;  /* Reset */
            case 1: printf("\033[31m"); break; /* Red */
            case 2: printf("\033[32m"); break; /* Green */
            case 3: printf("\033[33m"); break; /* Yellow */
            case 4: printf("\033[34m"); break; /* Blue */
            case 5: printf("\033[35m"); break; /* Magenta */
            case 6: printf("\033[36m"); break; /* Cyan */
            case 7: printf("\033[37m"); break; /* White */
            case 8: printf("\033[1;30m"); break; /* Bright Black / Grey */
            default: break;
        }
    }
    return val_nil();
}

static Value sys_console_clear(VM *vm, int arg_count, Value *args) {
    (void)vm; (void)arg_count; (void)args;
    printf("\033[2J\033[H");
    fflush(stdout);
    return val_nil();
}

static Value sys_console_gotoxy(VM *vm, int arg_count, Value *args) {
    (void)vm;
    if (arg_count >= 2) {
        int x = (int)(args[0].type == VAL_INT ? args[0].as.int_val : 1);
        int y = (int)(args[1].type == VAL_INT ? args[1].as.int_val : 1);
        printf("\033[%d;%dH", y, x);
        fflush(stdout);
    }
    return val_nil();
}

void relay_register_host_syscalls(VM *vm) {
    (void)vm;
    vm_register_syscall(SYS_CLOCK_MS, sys_clock_ms);
    vm_register_syscall(SYS_CLOCK_MICROS, sys_clock_micros);
    vm_register_syscall(SYS_SLEEP_MS, sys_sleep_ms);

    vm_register_syscall(SYS_TAG_REGISTER, sys_tag_register);
    vm_register_syscall(SYS_TAG_READ, sys_tag_read);
    vm_register_syscall(SYS_TAG_WRITE, sys_tag_write);
    vm_register_syscall(SYS_TAG_GET_QUALITY, sys_tag_get_quality);
    vm_register_syscall(SYS_TAG_SET_QUALITY, sys_tag_set_quality);

    vm_register_syscall(SYS_HIST_INGEST, sys_hist_ingest);
    vm_register_syscall(SYS_HIST_TWA, sys_hist_twa);
    vm_register_syscall(SYS_HIST_TOTAL, sys_hist_total);

    vm_register_syscall(SYS_MODBUS_CRC, sys_modbus_crc);

    vm_register_syscall(SYS_MATH_SIN, sys_math_sin);
    vm_register_syscall(SYS_MATH_COS, sys_math_cos);
    vm_register_syscall(SYS_MATH_EXP, sys_math_exp);
    vm_register_syscall(SYS_MATH_LOG, sys_math_log);
    vm_register_syscall(SYS_MATH_SQR, sys_math_sqr);
    vm_register_syscall(SYS_MATH_RND, sys_math_rnd);

    vm_register_syscall(SYS_CONSOLE_COLOR, sys_console_color);
    vm_register_syscall(SYS_CONSOLE_CLEAR, sys_console_clear);
    vm_register_syscall(SYS_CONSOLE_GOTOXY, sys_console_gotoxy);
}
