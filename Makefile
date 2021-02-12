# Relay: Industrial SCADA & Digital Twin Process Automation Engine
# Build system definition

CC ?= clang
CFLAGS ?= -std=c99 -Wall -Wextra -pedantic -O3 -Iruntime/include -pthread -lm
DEBUG_CFLAGS ?= -std=c99 -Wall -Wextra -pedantic -g -O0 -Iruntime/include -pthread -lm

BIN_DIR := bin
SRC_DIR := runtime/src
INC_DIR := runtime/include
TEST_DIR := runtime/tests

SRCS := $(wildcard $(SRC_DIR)/*.c)
OBJS := $(patsubst $(SRC_DIR)/%.c, $(BIN_DIR)/%.o, $(filter-out $(SRC_DIR)/relay_main.c, $(SRCS)))

TARGET := $(BIN_DIR)/relay
TEST_VM_TARGET := $(BIN_DIR)/test_vm
TEST_COMPILER_TARGET := $(BIN_DIR)/test_compiler

.PHONY: all clean test test-native test-basic test-integration bench verify help

all: $(TARGET)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(BIN_DIR)/%.o: $(SRC_DIR)/%.c | $(BIN_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET): $(SRCS) | $(BIN_DIR)
	$(CC) $(CFLAGS) $(SRCS) -o $(TARGET)

test-native: $(TEST_VM_TARGET) $(TEST_COMPILER_TARGET)
	@echo "==> Running native C runtime tests..."
	./$(TEST_VM_TARGET)
	./$(TEST_COMPILER_TARGET)

$(TEST_VM_TARGET): $(TEST_DIR)/test_vm.c $(OBJS) | $(BIN_DIR)
	$(CC) $(CFLAGS) $< $(OBJS) -o $@

$(TEST_COMPILER_TARGET): $(TEST_DIR)/test_compiler.c $(OBJS) | $(BIN_DIR)
	$(CC) $(CFLAGS) $< $(OBJS) -o $@

test-basic: $(TARGET)
	@echo "==> Running BASIC test suite via native engine and Python runner..."
	python3 tools/run_all_tests.py

test: test-native test-basic

verify: test
	@echo "==> Verifying structural constraints and line counts..."
	python3 tests/structural/test_zero_em_dashes.py
	python3 tests/structural/test_line_counts.py

bench: $(TARGET)
	@echo "==> Running high-frequency SCADA benchmarks..."
	$(TARGET) run benchmarks/bench_pid_loop.bas
	$(TARGET) run benchmarks/bench_sdt_speed.bas
	$(TARGET) run benchmarks/bench_tag_lookup.bas

clean:
	rm -rf $(BIN_DIR)
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.wal" -delete
	find . -type f -name "*.log" -delete

help:
	@echo "Relay Build Targets:"
	@echo "  all          Build native runtime engine (bin/relay)"
	@echo "  test         Run native C and BASIC test suites"
	@echo "  test-native  Run C runtime unit tests"
	@echo "  test-basic   Run BASIC integration tests"
	@echo "  verify       Run strict zero em-dash and scale verifications"
	@echo "  bench        Run execution benchmarks"
	@echo "  clean        Remove build artifacts and transient logs"
