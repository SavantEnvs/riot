#!/usr/bin/env bash
#
# mayhem/test.sh — RUN RIOT's embunit suite (tests/unittests, native64) that mayhem/build.sh already built
# with RIOT's normal flags. The suite is asserted: embunit prints "OK (N tests)" only if every assertion of
# the selected modules (uri_parser, nanocoap, gcoap, base64, fmt, checksum, hashes) held; a binary that exits 0
# without running them prints nothing and fails here.
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

BIN="$SRC/riot_unittests"
[ -x "$BIN" ] || { echo "missing $BIN — mayhem/build.sh did not build the unit tests" >&2; emit_ctrf embunit 0 1; exit 1; }

out=$(timeout 300 "$BIN" </dev/null 2>&1); rc=$?
printf '%s\n' "$out" | tail -n 12

# embunit: success is "OK (N tests)"; failures print "Run: N failures: M".
if ok=$(printf '%s\n' "$out" | sed -n 's/^OK (\([0-9][0-9]*\) tests)$/\1/p' | tail -n1) && [ -n "$ok" ] && [ "$rc" -eq 0 ]; then
  emit_ctrf embunit "$ok" 0
else
  fails=$(printf '%s\n' "$out" | sed -n 's/^Run: [0-9]* failures: \([0-9][0-9]*\).*/\1/p' | tail -n1)
  emit_ctrf embunit 0 "${fails:-1}"
fi
