#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <math.h>
#include "relay_vm.h"
#include "relay_tag_engine.h"
#include "relay_historian.h"
#include "relay_modbus.h"
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

static void test_vm_values(void) {
    Value vi = val_int(42);
    TEST_ASSERT(vi.type == VAL_INT && vi.as.int_val == 42, "Integer value construction");

    Value vd = val_double(3.141592);
    TEST_ASSERT(vd.type == VAL_DOUBLE && fabs(vd.as.double_val - 3.141592) < 1e-6, "Double value construction");

    Value vs = val_string("Industrial SCADA");
    TEST_ASSERT(vs.type == VAL_STRING && vs.as.string_val->length == 16, "String value construction");
    TEST_ASSERT(strcmp(vs.as.string_val->chars, "Industrial SCADA") == 0, "String contents match");

    val_release(vs);
}

static void test_vm_arithmetic(void) {
    VM vm;
    vm_init(&vm);
    Chunk chunk;
    chunk_init(&chunk);

    /* Push 20, push 22, add -> should be 42 */
    chunk_write(&chunk, OP_CONST_INT, 1);
    chunk_write(&chunk, chunk_add_constant(&chunk, val_int(20)), 1);

    chunk_write(&chunk, OP_CONST_INT, 1);
    chunk_write(&chunk, chunk_add_constant(&chunk, val_int(22)), 1);

    chunk_write(&chunk, OP_ADD, 1);
    chunk_write(&chunk, OP_HALT, 1);

    int res = vm_run(&vm, &chunk);
    TEST_ASSERT(res == 0, "VM execution succeeded");
    TEST_ASSERT(vm.sp == 1, "Stack has single result");
    Value r = vm_peek(&vm, 0);
    TEST_ASSERT(r.type == VAL_INT && r.as.int_val == 42, "20 + 22 == 42");

    chunk_free(&chunk);
    vm_free(&vm);
}

static void test_tag_engine(void) {
    TagDatabase db;
    tag_db_init(&db);

    int t_temp = tag_db_register(&db, "TT-101", TAG_AI, "degC", 0.0, 150.0);
    TEST_ASSERT(t_temp == 0, "Register tag TT-101 at index 0");

    int t_found = tag_db_find(&db, "TT-101");
    TEST_ASSERT(t_found == 0, "Find tag TT-101");

    /* Raw counts 32767.5 (midpoint) should scale to 75 degC */
    tag_db_set_raw(&db, t_temp, 32767.5);
    double eu = tag_db_get_eu(&db, t_temp);
    TEST_ASSERT(fabs(eu - 75.0) < 0.1, "Scaled engineering units match midpoint");

    tag_db_set_quality(&db, t_temp, QUALITY_GOOD);
    TagQuality q = tag_db_get_quality(&db, t_temp);
    TEST_ASSERT(q == QUALITY_GOOD, "Tag quality is good");

    tag_db_free(&db);
}

static void test_historian_sdt(void) {
    Historian hist;
    historian_init(&hist, NULL);

    int s_id = historian_add_series(&hist, 0, 0.5, 10, 10000);
    TEST_ASSERT(s_id == 0, "Historian added series 0");

    /* Ingest 10 points on a perfectly flat line (y = 50.0) */
    for (int i = 0; i < 10; ++i) {
        historian_ingest(&hist, s_id, i * 1000, 50.0, QUALITY_GOOD);
    }

    /* Swinging door compression should discard intermediate colinear points */
    SdtCompressor *comp = &hist.compressors[s_id];
    TEST_ASSERT(comp->raw_count == 10, "Raw points count is 10");
    TEST_ASSERT(comp->archived_count <= 2, "SDT successfully compressed colinear stream");

    /* Time-weighted average should equal 50.0 */
    double twa = historian_time_weighted_average(&hist, s_id, 0, 9000);
    TEST_ASSERT(fabs(twa - 50.0) < 0.01, "TWA of constant 50.0 is 50.0");

    historian_free(&hist);
}

static void test_modbus_crc(void) {
    /* Standard Modbus query: Unit 1, Function 3, Start 0, Count 1 */
    uint8_t test_frame[] = { 0x01, 0x03, 0x00, 0x00, 0x00, 0x01 };
    uint16_t crc = modbus_crc16(test_frame, sizeof(test_frame));

    /* Expected CRC-16 for this frame is 0x0A84 */
    TEST_ASSERT(crc == 0x0A84, "Modbus RTU CRC-16 calculation matches standard test vector");
}

int main(void) {
    printf("=== Running Relay VM & Subsystem Unit Tests ===\n");
    test_vm_values();
    test_vm_arithmetic();
    test_tag_engine();
    test_historian_sdt();
    test_modbus_crc();

    printf("Results: %d/%d tests passed.\n", g_tests_passed, g_tests_run);
    return (g_tests_passed == g_tests_run) ? 0 : 1;
}
