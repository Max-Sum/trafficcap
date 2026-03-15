#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK_SH="${BASE_DIR}/check.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
FAKEBIN="${TMPDIR}/bin"
mkdir -p "$FAKEBIN"

cat >"${FAKEBIN}/vnstat" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "${VNSTAT_ARGS_FILE:?}"
exit "${VNSTAT_FAKE_RC:?}"
EOF
chmod +x "${FAKEBIN}/vnstat"

EXPECTED_ARGS='--alert 0 5 monthly total 240 GiB -i ens17'

run_case() {
  local name="$1"
  local fake_rc="$2"
  local expected_rc="$3"
  local expected_stdout="$4"
  local expected_stderr="$5"

  local stdout_file="${TMPDIR}/${name}.stdout"
  local stderr_file="${TMPDIR}/${name}.stderr"
  local args_file="${TMPDIR}/${name}.args"

  set +e
  PATH="${FAKEBIN}:$PATH" \
  VNSTAT_FAKE_RC="$fake_rc" \
  VNSTAT_ARGS_FILE="$args_file" \
  "$CHECK_SH" >"$stdout_file" 2>"$stderr_file"
  local rc=$?
  set -e

  local stdout
  stdout="$(cat "$stdout_file")"
  local stderr
  stderr="$(cat "$stderr_file")"
  local args
  args="$(cat "$args_file")"

  [[ "$rc" -eq "$expected_rc" ]] || fail "$name: expected rc=$expected_rc, got rc=$rc"
  [[ "$stdout" == "$expected_stdout" ]] || fail "$name: expected stdout '$expected_stdout', got '$stdout'"
  [[ "$stderr" == "$expected_stderr" ]] || fail "$name: expected stderr '$expected_stderr', got '$stderr'"
  [[ "$args" == "$EXPECTED_ARGS" ]] || fail "$name: expected args '$EXPECTED_ARGS', got '$args'"
}

run_case under_limit 0 0 normal ''
run_case over_limit 2 0 capped ''
run_case vnstat_error 1 1 '' 'vnstat failed (exit=1)'

echo 'PASS: check.sh regression tests'
