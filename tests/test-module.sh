#!/system/bin/sh
set -eu
SRC=$1
ROOT=/data/local/tmp/gps-fix-tests-$$
mkdir -p "$ROOT/bin"
export TEST_ROOT="$ROOT"
export PATH="$ROOT/bin:$PATH"
cat > "$ROOT/bin/getprop" <<'EOF'
#!/system/bin/sh
case "$1" in
  sys.boot_completed) echo 1 ;;
  sys.shutdown.requested) [ "${MOCK_SHUTDOWN:-0}" != 1 ] || echo reboot ;;
esac
exit 0
EOF
cat > "$ROOT/bin/cmd" <<'EOF'
#!/system/bin/sh
case "$*" in
  'location is-location-enabled') echo "${MOCK_LOCATION:-true}"; exit 0 ;;
  'location help')
    if [ "${MOCK_LEGACY:-0}" = 1 ]; then echo 'send-extra-command'
    else echo 'The providers command: send-extra-command'; fi
    exit 0 ;;
esac
case "$(readlink /proc/$$/fd/1)" in
    pipe:*) ;;
    *) echo 'Mock Binder rejects module-file output descriptors'; exit 2 ;;
esac
echo "$*" >> "$TEST_ROOT/calls"
case "$*" in
  *force_psds_injection)
    [ "${MOCK_DELAY:-0}" = 0 ] || /system/bin/sleep 1
    [ "${MOCK_FAIL:-0}" = 0 ] || exit 1 ;;
esac
exit 0
EOF
cat > "$ROOT/bin/sleep" <<'EOF'
#!/system/bin/sh
echo "$1" >> "$TEST_ROOT/backoff"
exit 0
EOF
cat > "$ROOT/bin/dumpsys" <<'EOF'
#!/system/bin/sh
[ "$1" = connectivity ] || exit 1
count_file="$TEST_ROOT/network_calls"
count=0
[ -f "$count_file" ] && count=$(cat "$count_file")
count=$((count + 1))
printf '%s\n' "$count" > "$count_file"
case "${MOCK_NETWORK:-ready}" in
  ready) echo 'NetworkAgentInfo{ ni{WIFI CONNECTED} Score(Policies : IS_VALIDATED )' ;;
  delayed)
    [ "$count" -lt 2 ] || echo 'NetworkAgentInfo{ ni{WIFI CONNECTED} Score(Policies : IS_VALIDATED )'
    ;;
esac
EOF
chmod 755 "$ROOT/bin/"*
new_case() {
    CASE="$ROOT/$1"
    mkdir -p "$CASE"
    cp "$SRC/service.sh" "$CASE/service.sh"
    : > "$ROOT/calls"
    : > "$ROOT/backoff"
    : > "$ROOT/network_calls"
    unset MOCK_LOCATION MOCK_FAIL MOCK_DELAY MOCK_LEGACY MOCK_SHUTDOWN MOCK_NETWORK
}
assert_count() {
    count=$(wc -l < "$ROOT/calls")
    [ "$count" -eq "$1" ] || { echo "FAIL $CASE calls=$count expected=$1"; exit 1; }
}
new_case once
sh "$CASE/service.sh"
sh "$CASE/service.sh"
assert_count 2
[ -s "$CASE/runtime/requested_boot" ]
echo 'PASS one request pair per boot and idempotent rerun'
new_case network_ready
export MOCK_NETWORK=delayed
sh "$CASE/service.sh"
assert_count 2
[ "$(cat "$ROOT/backoff" | tr '\n' ' ')" = '5 ' ]
grep -q 'validated network available' "$CASE/runtime/service.log"
echo 'PASS waits for validated network before the bounded request'
new_case disabled
export MOCK_LOCATION=false
sh "$CASE/service.sh"
assert_count 0
[ ! -f "$CASE/runtime/requested_boot" ]
unset MOCK_LOCATION
sh "$CASE/service.sh"
assert_count 2
echo 'PASS location disabled skips without consuming boot request'
new_case retry
export MOCK_FAIL=1
if sh "$CASE/service.sh"; then echo 'FAIL retries should fail'; exit 1; fi
assert_count 3
[ ! -f "$CASE/runtime/requested_boot" ]
[ "$(cat "$ROOT/backoff" | tr '\n' ' ')" = '15 30 ' ]
echo 'PASS bounded failure retries and no false success marker'
new_case concurrent
export MOCK_DELAY=1
sh "$CASE/service.sh" &
first=$!
/system/bin/sleep 0.2
sh "$CASE/service.sh" || [ "$?" -eq 1 ]
wait "$first"
assert_count 2
echo 'PASS concurrent invocation lock'
new_case legacy
export MOCK_LEGACY=1
sh "$CASE/service.sh"
assert_count 2
grep -q '^location send-extra-command gps force_psds_injection$' "$ROOT/calls"
echo 'PASS legacy command selection'
new_case shutdown
export MOCK_SHUTDOWN=1
sh "$CASE/service.sh"
assert_count 0
echo 'PASS shutdown exits without commands'
new_case deferred
mkdir -p "$CASE/runtime"
cat /proc/sys/kernel/random/boot_id > "$CASE/runtime/defer_boot"
sh "$CASE/service.sh"
assert_count 0
echo 'PASS live upgrade defers until reboot'
new_case module_disabled
touch "$CASE/disable"
sh "$CASE/service.sh"
assert_count 0
echo 'PASS module disable respected'
# Exercise the actual merge implementation, including duplicates and empty input.
cat > "$ROOT/override" <<'EOF'
NTP_SERVER=domestic
LONGTERM_PSDS_SERVER_1=https://example.invalid/long
EOF
cat > "$ROOT/baseline" <<'EOF'
# retain comment
CAPABILITIES=0x17
NTP_SERVER = old
NTP_SERVER=duplicate
NORMAL_PSDS_SERVER=native-normal
REALTIME_PSDS_SERVER=native-real
RF_LOSS_BDS = 7
EOF
/data/adb/ap/bin/busybox awk -f "$SRC/merge-config.awk" "$ROOT/override" "$ROOT/baseline" > "$ROOT/merged"
[ "$(grep -c '^NTP_SERVER' "$ROOT/merged")" -eq 1 ]
grep -q '^CAPABILITIES=0x17$' "$ROOT/merged"
grep -q '^NORMAL_PSDS_SERVER=native-normal$' "$ROOT/merged"
grep -q '^REALTIME_PSDS_SERVER=native-real$' "$ROOT/merged"
grep -q '^RF_LOSS_BDS = 7$' "$ROOT/merged"
grep -q '^# retain comment$' "$ROOT/merged"
: > "$ROOT/empty"
/data/adb/ap/bin/busybox awk -f "$SRC/merge-config.awk" "$ROOT/override" "$ROOT/empty" > "$ROOT/from-empty"
cmp "$ROOT/override" "$ROOT/from-empty"
echo 'PASS selective merge preserves hardware, PSDS types, comments; deduplicates overrides'

! grep -qE 'curl|/data/vendor/location|mount[[:space:]]+-o[[:space:]]+bind|while[[:space:]]+true' "$SRC/service.sh"
grep -q 'force_psds_injection' "$SRC/service.sh"
grep -q 'service.lock' "$SRC/service.sh"
grep -q 'no validated network within 90 seconds' "$SRC/service.sh"
grep -q '^allow vendor_location vendor_location_xtra_daemon process { transition siginh rlimitinh }$' "$SRC/sepolicy.rule"
grep -q '^allow vendor_location vendor_location_xtra_daemon process signal$' "$SRC/sepolicy.rule"
grep -q '^dontaudit vendor_location vendor_location_xtra_daemon process noatsecure$' "$SRC/sepolicy.rule"
grep -q '^type_transition vendor_location vendor_location_xtra_daemon_exec process vendor_location_xtra_daemon$' "$SRC/sepolicy.rule"
grep -q '^allow vendor_location_xtra_daemon vendor_location fd use$' "$SRC/sepolicy.rule"
grep -q '^allow vendor_location_xtra_daemon vendor_location process sigchld$' "$SRC/sepolicy.rule"
grep -q '^allow vendor_location vendor_location_lowi_server process { transition siginh rlimitinh }$' "$SRC/sepolicy.rule"
grep -q '^dontaudit vendor_location vendor_location_lowi_server process noatsecure$' "$SRC/sepolicy.rule"
grep -q '^type_transition vendor_location vendor_location_lowi_server_exec process vendor_location_lowi_server$' "$SRC/sepolicy.rule"
grep -q '^allow vendor_location_lowi_server vendor_location fd use$' "$SRC/sepolicy.rule"
grep -q '^allow vendor_location_lowi_server vendor_location process sigchld$' "$SRC/sepolicy.rule"
! grep -q 'execute_no_trans' "$SRC/sepolicy.rule"
! grep -qE 'system_file|vendor_configs_file' "$SRC/sepolicy.rule"
echo 'PASS no manual XTRA/cache/bind daemon; dedicated SELinux domain transitions only'
echo "ALL TESTS PASSED ($ROOT)"
