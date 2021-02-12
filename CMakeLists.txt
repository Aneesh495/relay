cmake_minimum_required(VERSION 3.16)
project(relay VERSION 1.0.0 LANGUAGES C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

add_compile_options(-Wall -Wextra -pedantic -O3)

include_directories(runtime/include)

file(GLOB RUNTIME_SOURCES "runtime/src/*.c")
list(FILTER RUNTIME_SOURCES EXCLUDE REGEX ".*relay_main\\.c$")

add_executable(relay runtime/src/relay_main.c ${RUNTIME_SOURCES})
target_link_libraries(relay m pthread)

enable_testing()

add_executable(test_vm runtime/tests/test_vm.c ${RUNTIME_SOURCES})
target_link_libraries(test_vm m pthread)
add_test(NAME test_vm COMMAND test_vm)

add_executable(test_compiler runtime/tests/test_compiler.c ${RUNTIME_SOURCES})
target_link_libraries(test_compiler m pthread)
add_test(NAME test_compiler COMMAND test_compiler)
