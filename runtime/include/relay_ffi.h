#ifndef RELAY_FFI_H
#define RELAY_FFI_H

#include <stdint.h>
#include "relay_vm.h"

enum {
    SYS_CLOCK_MS        = 1,
    SYS_CLOCK_MICROS    = 2,
    SYS_SLEEP_MS        = 3,

    SYS_TAG_REGISTER    = 10,
    SYS_TAG_READ        = 11,
    SYS_TAG_WRITE       = 12,
    SYS_TAG_GET_QUALITY = 13,
    SYS_TAG_SET_QUALITY = 14,

    SYS_HIST_INGEST     = 20,
    SYS_HIST_TWA        = 21,
    SYS_HIST_TOTAL      = 22,

    SYS_MODBUS_CRC      = 30,

    SYS_MATH_SIN        = 40,
    SYS_MATH_COS        = 41,
    SYS_MATH_EXP        = 42,
    SYS_MATH_LOG        = 43,
    SYS_MATH_SQR        = 44,
    SYS_MATH_POW        = 45,
    SYS_MATH_RND        = 46,

    SYS_CONSOLE_COLOR   = 50,
    SYS_CONSOLE_CLEAR   = 51,
    SYS_CONSOLE_GOTOXY  = 52
};

void relay_register_host_syscalls(VM *vm);

#endif /* RELAY_FFI_H */
