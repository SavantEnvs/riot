#!/usr/bin/env bash
#
# mayhem/build.sh — build the ethos serial-line decoder harness (AFL + ASan + UBSan, stdin input) and the
# frame-dump oracle test.sh asserts on. Runs inside the commit image as `mayhem` in /mayhem.
# Air-gapped: nothing is fetched.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}"

ROOT="$SRC"
cd "$ROOT"

# 1) Oracle: the same decoder loop with the project's NORMAL flags (no sanitizers), printing each frame.
$CC -O1 -DETHOS_FRAME_DUMP mayhem/ethos_serial.c -o "$ROOT/ethos_frames_test"

# 2) Fuzz target: ethos.c compiled into the harness TU, so the decoder itself is instrumented (AFL coverage +
#    $SANITIZER_FLAGS). A stdin file-input target driven by Mayhem's AFL support; runnable as-is, so there
#    is no separate standalone reproducer.
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -c mayhem/lsan_off.cc -o "$ROOT/lsan_off.o"
export AFL_QUIET=1
afl-clang-fast $SANITIZER_FLAGS $DEBUG_FLAGS mayhem/ethos_serial.c "$ROOT/lsan_off.o" -o "$ROOT/ethos_serial"
