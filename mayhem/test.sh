#!/usr/bin/env bash
#
# mayhem/test.sh — RUN the known-answer cases for ethos's serial-line frame decoder against
# $SRC/ethos_frames_test (built by mayhem/build.sh with normal flags). Each case feeds a byte stream and asserts
# the exact frames the decoder reports (type, length, payload), so a no-op binary fails.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

BIN="$SRC/ethos_frames_test"
[ -x "$BIN" ] || { echo "missing $BIN — mayhem/build.sh did not build it" >&2; emit_ctrf ethos-frames 0 1; exit 1; }

passed=0; failed=0
# check <name> <printf input> <expected output>
check() {
  local name="$1" input="$2" want="$3" got
  got=$(printf "$input" | timeout 20 "$BIN" 2>&1)
  if [ "$got" = "$want" ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    printf 'FAIL %s\n  want: %s\n  got:  %s\n' "$name" "$want" "$got"
  fi
}

check hello       '\x7e\x7d\x22\x02\x00\x00\x00\x00\x01\x7e' 'type=2 len=6 hex=020000000001'
check hello_reply '\x7e\x7d\x23\x02\x00\x00\x00\x00\x01\x7e' 'type=3 len=6 hex=020000000001'
check text        '\x7e\x7d\x21hello ethos\x7e'               'type=1 len=11 hex=68656c6c6f206574686f73'
check escapes     '\x7e\x45\x00\x7d\x5e\x7d\x5d\x01\x7e'      'type=0 len=5 hex=45007e7d01'
check two_frames  '\x7e\x7d\x21up\x7e\x7e\x01\x02\x03\x7e'    $'type=1 len=2 hex=7570\ntype=0 len=3 hex=010203'
check no_start    'garbage without a delimiter'              ''
check empty_frame '\x7e\x7e\x01\x7e'                         'type=0 len=1 hex=01'

echo "ethos frame decoder: $passed passed, $failed failed"
emit_ctrf ethos-frames "$passed" "$failed"
