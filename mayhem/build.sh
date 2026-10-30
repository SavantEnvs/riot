#!/usr/bin/env bash
#
# mayhem/build.sh — build the RIOT native fuzzing apps (AFL + ASan + UBSan) and the unit-test oracle.
# Runs inside the commit image as `mayhem` in /mayhem. Air-gapped: RIOT's build needs nothing from the net.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"

ROOT="$SRC"
cd "$ROOT"
# The base image exports SRC=/mayhem, which RIOT's make treats as its own source-list variable.
unset SRC

RIOT_BOARD=native64      # native32 needs multilib, which the image does not have

# 1) Oracle: RIOT's own embunit suite for the modules the fuzz apps exercise, built with RIOT's NORMAL flags.
#    Built first and stashed, so the sanitized build below never shares objects with it.
UNIT_TESTS="tests-uri_parser tests-nanocoap tests-gcoap tests-base64 tests-fmt tests-checksum tests-hashes"
rm -rf tests/unittests/bin
env -u CFLAGS -u LINKFLAGS -u USEMODULE CFLAGS="$COVERAGE_FLAGS" LINKFLAGS="$COVERAGE_FLAGS" \
  make -C tests/unittests BOARD=$RIOT_BOARD TOOLCHAIN=llvm UNIT_TESTS="$UNIT_TESTS" -j"$MAYHEM_JOBS"
cp tests/unittests/bin/$RIOT_BOARD/tests_unittests.elf "$ROOT/riot_unittests"
rm -rf tests/unittests/bin

# 2) Fuzz apps: instrumented with AFL (coverage) and $SANITIZER_FLAGS, so the RIOT code under test is sanitized
#    too. These are file-input targets (stdin) driven by Mayhem's AFL support; they are runnable as-is, so
#    there is no separate standalone reproducer.
#    - CFLAGS/LINKFLAGS must be ENV vars: on the make command line they would wipe the makefiles' own `+=`s
#      (e.g. -D_GNU_SOURCE). CC/LINK must be on the command line: the toolchain file assigns CC itself.
#    - -fno-sanitize=function: RIOT's auto_init calls through casted function pointers.
#    - USE_AFTER_RETURN=never: RIOT's thread stacks are swapcontext()ed, which ASan's fake stacks break.
#    - ucontext_wrap.o + --wrap: keeps ASan's swapcontext / __asan_handle_no_return stderr warnings (printed on
#      every run, RIOT threads are ucontext stacks) from being reported as defects; see mayhem/ucontext_wrap.c.
#    - AFL's guard sections keep otherwise garbage-collected functions alive, so their link-time deps must exist.
SAN="$SANITIZER_FLAGS -fno-sanitize=function"
case "$SANITIZER_FLAGS" in *address*) SAN="$SAN -fsanitize-address-use-after-return=never" ;; esac

$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -c mayhem/lsan_off.cc -o "$ROOT/lsan_off.o"
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c mayhem/ucontext_wrap.c -o "$ROOT/ucontext_wrap.o"

export AFL_QUIET=1
export CFLAGS="$SAN $DEBUG_FLAGS -DNATIVE_MEMORY"
export LINKFLAGS="$SAN $ROOT/lsan_off.o $ROOT/ucontext_wrap.o -Wl,--wrap=swapcontext -Wl,--wrap=__asan_handle_no_return"
export CFLAGS_DBG="$DEBUG_FLAGS"

build_fuzz_app() {
  local app=$1; shift
  rm -rf fuzzing/$app/bin
  USEMODULE="$*" make -C fuzzing/$app BOARD=$RIOT_BOARD TOOLCHAIN=llvm \
    CC=afl-clang-fast CXX=afl-clang++-fast LINK=afl-clang-fast LINKXX=afl-clang++-fast -j"$MAYHEM_JOBS"
  cp fuzzing/$app/bin/$RIOT_BOARD/fuzzing_$app.elf "$ROOT/fuzzing_$app"
  rm -rf fuzzing/$app/bin
}

build_fuzz_app uri_parser sema_inv
build_fuzz_app gcoap      sema_inv nanocoap_resources
build_fuzz_app gnrc_tcp   sema_inv
