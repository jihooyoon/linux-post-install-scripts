#!/bin/sh

set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_TEST=$(mktemp -d /tmp/setup-menu-test.XXXXXX) || exit 1
trap 'rm -rf "$TMP_TEST"' EXIT INT TERM

PASS=0
FAIL=0

pass() {
    PASS=$((PASS + 1))
    printf 'ok - %s\n' "$1"
}

fail() {
    FAIL=$((FAIL + 1))
    printf 'not ok - %s\n' "$1" >&2
}

assert_contains() {
    _file=$1
    _pattern=$2
    _name=$3
    if grep -Fq -- "$_pattern" "$_file"; then pass "$_name"; else fail "$_name"; fi
}

assert_not_contains() {
    _file=$1
    _pattern=$2
    _name=$3
    if grep -Fq -- "$_pattern" "$_file"; then fail "$_name"; else pass "$_name"; fi
}

run_parent() {
    _input=$1
    _output=$2
    shift 2
    : > "$TMP_TEST/execution.log"
    printf '%b' "$_input" | env \
        SETUP_TEST_MODE=1 \
        SETUP_TEST_TUXEDO="${SETUP_TEST_TUXEDO_VALUE:-0}" \
        SETUP_MENU_INPUT=- \
        SETUP_ATOM_DIR="$ROOT/tests/fixtures/atoms" \
        SETUP_EXTRA_DIR="$ROOT/tests/fixtures/extras" \
        SETUP_TEST_LOG="$TMP_TEST/execution.log" \
        sh "$ROOT/setup-ubuntu-based.sh" "$@" > "$_output" 2>&1
}

. "$ROOT/lib/setup-contract.sh"

if setup_validate_metadata "$ROOT/tests/fixtures/atoms/3-items.sh" && \
   [ "$(setup_item_count "$ROOT/tests/fixtures/atoms/3-items.sh")" -eq 2 ]; then
    pass "metadata fixture hợp lệ và đếm item động"
else
    fail "metadata fixture hợp lệ và đếm item động"
fi

if setup_child_prepare "$ROOT/tests/fixtures/atoms/3-items.sh" 2 1 2 && \
   [ "$SETUP_SELECTED" = "1 2" ]; then
    pass "child argument được canonicalize và loại duplicate"
else
    fail "child argument được canonicalize và loại duplicate"
fi

if setup_child_prepare "$ROOT/tests/fixtures/atoms/3-items.sh" --all 1 >/dev/null 2>&1; then
    fail "child reject --all trộn item"
else
    pass "child reject --all trộn item"
fi

sed '/@setup-item: second_item/d' "$ROOT/tests/fixtures/atoms/3-items.sh" > "$TMP_TEST/one-item.sh"
if [ "$(setup_item_count "$TMP_TEST/one-item.sh")" -eq 1 ] && \
   ! setup_child_prepare "$TMP_TEST/one-item.sh" 2 >/dev/null 2>&1; then
    pass "xóa item tự cập nhật range"
else
    fail "xóa item tự cập nhật range"
fi

BASIC_FILE="$ROOT/atom-scripts/3-install-basic-apps-deb.sh"
if setup_child_prepare "$BASIC_FILE" --all && \
   [ "$SETUP_SELECTED" = "1 2 3 4 5" ]; then
    pass "Basic Apps --all chọn đủ năm item"
else
    fail "Basic Apps --all chọn đủ năm item"
fi

awk '/^run_best_effort\(\)/,/^}/' "$BASIC_FILE" > "$TMP_TEST/run-best-effort.fn"
awk '/^reconcile_office_selection\(\)/,/^}/' "$BASIC_FILE" > "$TMP_TEST/reconcile-office.fn"
awk '/^run_selected_best_effort\(\)/,/^}/' "$BASIC_FILE" > "$TMP_TEST/run-selected-best-effort.fn"
awk '/^install_libreoffice\(\)/,/^}/' "$BASIC_FILE" > "$TMP_TEST/install-libreoffice.fn"

run_office_case() {
    _selection=$1
    _output=$2
    _purge_failure=${3:-0}
    (
        . "$ROOT/lib/setup-contract.sh"
        . "$TMP_TEST/run-best-effort.fn"
        . "$TMP_TEST/reconcile-office.fn"
        warn() { printf 'warn:%s\n' "$*"; }
        purge_libreoffice() { printf 'purge-libreoffice\n'; return "$_purge_failure"; }
        purge_freeoffice() { printf 'purge-freeoffice\n'; return "$_purge_failure"; }
        SETUP_SELECTED=$_selection
        reconcile_office_selection
    ) > "$_output" 2>&1
}

run_office_case '1 2' "$TMP_TEST/office-both.out"
assert_not_contains "$TMP_TEST/office-both.out" "purge-" "chọn cả hai Office không purge"

run_office_case '1' "$TMP_TEST/office-free.out"
assert_contains "$TMP_TEST/office-free.out" "purge-libreoffice" "chỉ FreeOffice thì purge LibreOffice"
assert_not_contains "$TMP_TEST/office-free.out" "purge-freeoffice" "chỉ FreeOffice không purge FreeOffice"

run_office_case '2' "$TMP_TEST/office-libre.out"
assert_contains "$TMP_TEST/office-libre.out" "purge-freeoffice" "chỉ LibreOffice thì purge FreeOffice"
assert_not_contains "$TMP_TEST/office-libre.out" "purge-libreoffice" "chỉ LibreOffice không purge LibreOffice"

run_office_case '3' "$TMP_TEST/office-none.out"
assert_not_contains "$TMP_TEST/office-none.out" "purge-" "không chọn Office thì không purge"

if run_office_case '1' "$TMP_TEST/office-purge-failure.out" 9; then
    pass "lỗi purge Office không làm child thất bại"
else
    fail "lỗi purge Office không làm child thất bại"
fi
assert_contains "$TMP_TEST/office-purge-failure.out" "exit 9" "lỗi purge Office được cảnh báo"
assert_contains "$TMP_TEST/install-libreoffice.fn" "apt-get install -y libreoffice" "LibreOffice dùng repo mặc định"

if (
    . "$ROOT/lib/setup-contract.sh"
    . "$TMP_TEST/run-best-effort.fn"
    . "$TMP_TEST/run-selected-best-effort.fn"
    warn() { printf 'warn:%s\n' "$*"; }
    install_freeoffice() { printf 'called:freeoffice\n'; return 1; }
    install_libreoffice() { printf 'called:libreoffice\n'; return 2; }
    install_chrome() { printf 'called:chrome\n'; return 3; }
    install_chromium() { printf 'called:chromium\n'; return 4; }
    install_vscode() { printf 'called:vscode\n'; return 5; }
    CHILD_FILE="$BASIC_FILE"
    SETUP_SELECTED='1 2 3 4 5'
    run_selected_best_effort
) > "$TMP_TEST/basic-best-effort.out" 2>&1; then
    pass "optional apps lỗi vẫn trả thành công"
else
    fail "optional apps lỗi vẫn trả thành công"
fi
for app_name in freeoffice libreoffice chrome chromium vscode; do
    assert_contains "$TMP_TEST/basic-best-effort.out" "called:$app_name" \
        "optional runner tiếp tục tới $app_name"
done

OUT="$TMP_TEST/interactive.out"
if run_parent 's\n1\ns\nr\n' "$OUT"; then
    pass "interactive core-only và empty extra exit thành công"
else
    fail "interactive core-only và empty extra exit thành công"
fi
assert_contains "$OUT" "Skipped: no items selected" "review ghi rõ extra rỗng bị skip"
assert_contains "$TMP_TEST/execution.log" "1-non-tuxedo.sh|" "non-Tuxedo variant được chạy"
assert_not_contains "$TMP_TEST/execution.log" "1-tuxedo.sh|" "Tuxedo variant không chạy trên non-Tuxedo"
assert_not_contains "$TMP_TEST/execution.log" "1-items.sh|" "extra không core và không item bị loại execution"

OUT="$TMP_TEST/back.out"
if run_parent '1\nb\ns\ns\nr\n' "$OUT"; then
    pass "Back quay lại và cho phép thay selection"
else
    fail "Back quay lại và cho phép thay selection"
fi
assert_contains "$TMP_TEST/execution.log" "3-items.sh|" "atom item stage sau Back chạy core-only"
assert_not_contains "$TMP_TEST/execution.log" "3-items.sh|1" "selection cũ không bị thực thi sau khi đổi"

OUT="$TMP_TEST/required.out"
if run_parent '\ns\ns\nr\n' "$OUT"; then
    pass "input rỗng được reprompt"
else
    fail "input rỗng được reprompt"
fi
assert_contains "$OUT" "Bắt buộc nhập lựa chọn" "menu báo lỗi khi Enter rỗng"

SETUP_TEST_TUXEDO_VALUE=1
OUT="$TMP_TEST/tuxedo.out"
if run_parent '' "$OUT" --all --basic; then
    pass "--basic --all chạy không tương tác"
else
    fail "--basic --all chạy không tương tác"
fi
assert_contains "$TMP_TEST/execution.log" "1-tuxedo.sh|--all" "Tuxedo variant nhận --all"
assert_not_contains "$TMP_TEST/execution.log" "1-non-tuxedo.sh" "non-Tuxedo variant bị lọc"
assert_not_contains "$TMP_TEST/execution.log" "1-items.sh" "--basic không chạy extras"
unset SETUP_TEST_TUXEDO_VALUE

OUT="$TMP_TEST/basic-interactive.out"
if run_parent 's\nr\n' "$OUT" --basic; then
    pass "--basic tương tác chỉ có atom stages và review"
else
    fail "--basic tương tác chỉ có atom stages và review"
fi
assert_contains "$OUT" "Extras: Skipped (--basic)" "review --basic ghi rõ extras bị skip"
assert_not_contains "$TMP_TEST/execution.log" "1-items.sh" "--basic tương tác không chạy extras"

OUT="$TMP_TEST/basic-silent.out"
if run_parent '' "$OUT" --basic --silent; then
    pass "--basic --silent chạy atom với --all"
else
    fail "--basic --silent chạy atom với --all"
fi
assert_contains "$TMP_TEST/execution.log" "3-items.sh|--all" "--silent truyền --all xuống child"
assert_not_contains "$TMP_TEST/execution.log" "1-items.sh" "--basic --silent không chạy extras"

OUT="$TMP_TEST/failure.out"
if run_parent '' "$OUT" --all; then
    fail "runtime failure phải tạo exit non-zero tổng hợp"
else
    pass "runtime failure tạo exit non-zero tổng hợp"
fi
assert_contains "$TMP_TEST/execution.log" "2-failure.sh|--all" "failing child đã được gọi"
assert_contains "$TMP_TEST/execution.log" "3-core.sh|--all" "parent tiếp tục sau failing child"
assert_contains "$OUT" "failed=1" "summary tổng hợp failure"

STUB_BIN="$TMP_TEST/stubs"
mkdir -p "$STUB_BIN"
printf '#!/bin/sh\nprintf "0\\n"\n' > "$STUB_BIN/id"
chmod +x "$STUB_BIN/id"
: > "$TMP_TEST/side-effects.log"
for command_name in apt-get curl gpg; do
    printf '#!/bin/sh\nprintf "%%s\\n" "$0 $*" >> "$SETUP_SIDE_EFFECT_LOG"\nexit 99\n' \
        > "$STUB_BIN/$command_name"
    chmod +x "$STUB_BIN/$command_name"
done

if PATH="$STUB_BIN:$PATH" SETUP_SIDE_EFFECT_LOG="$TMP_TEST/side-effects.log" \
    sh "$BASIC_FILE" > "$TMP_TEST/basic-core-failure.out" 2>&1; then
    fail "Basic Apps core failure phải trả non-zero"
else
    pass "Basic Apps core failure vẫn trả non-zero"
fi
: > "$TMP_TEST/side-effects.log"

if PATH="$STUB_BIN:$PATH" SETUP_SIDE_EFFECT_LOG="$TMP_TEST/side-effects.log" \
    sh "$ROOT/extras/4-install-ai-tools-deb.sh" > "$TMP_TEST/ai-empty.out" 2>&1 && \
   [ ! -s "$TMP_TEST/side-effects.log" ]; then
    pass "AI no-argument không gọi apt/curl/gpg"
else
    fail "AI no-argument không gọi apt/curl/gpg"
fi

: > "$TMP_TEST/side-effects.log"
if PATH="$STUB_BIN:$PATH" SETUP_SIDE_EFFECT_LOG="$TMP_TEST/side-effects.log" \
    sh "$ROOT/extras/1-install-chat-apps-deb.sh" > "$TMP_TEST/chat-empty.out" 2>&1 && \
   [ ! -s "$TMP_TEST/side-effects.log" ]; then
    pass "Chat no-argument không gọi apt/curl/gpg"
else
    fail "Chat no-argument không gọi apt/curl/gpg"
fi

AI_FILE="$ROOT/extras/4-install-ai-tools-deb.sh"
CHAT_FILE="$ROOT/extras/1-install-chat-apps-deb.sh"
awk '/^install_claude_desktop\(\)/,/^}/' "$AI_FILE" > "$TMP_TEST/claude-desktop.fn"
awk '/^install_claude_cli\(\)/,/^}/' "$AI_FILE" > "$TMP_TEST/claude-cli.fn"
awk '/^install_codex_cli\(\)/,/^}/' "$AI_FILE" > "$TMP_TEST/codex.fn"
assert_not_contains "$TMP_TEST/claude-desktop.fn" "ensure_local_bin_path" "Claude Desktop không sửa PATH"
assert_not_contains "$TMP_TEST/claude-cli.fn" "ensure_gpg" "Claude CLI không cài gpg"
assert_not_contains "$TMP_TEST/codex.fn" "ensure_gpg" "Codex CLI không cài gpg"
assert_contains "$AI_FILE" 'sudo -u "$SUDO_USER" -H sh -c' "PATH được ghi dưới user thật"

awk '/^install_slack\(\)/,/^}/' "$CHAT_FILE" > "$TMP_TEST/slack.fn"
awk '/^install_mattermost\(\)/,/^}/' "$CHAT_FILE" > "$TMP_TEST/mattermost.fn"
awk '/^install_discord\(\)/,/^}/' "$CHAT_FILE" > "$TMP_TEST/discord.fn"
assert_contains "$TMP_TEST/slack.fn" "ensure_gpg" "Slack tự bảo đảm gpg"
assert_contains "$TMP_TEST/slack.fn" "apt-get update" "Slack tự chạy apt update"
assert_not_contains "$TMP_TEST/mattermost.fn" "ensure_gpg" "Mattermost không cài gpg"
assert_not_contains "$TMP_TEST/mattermost.fn" "apt-get update" "Mattermost không apt update"
assert_not_contains "$TMP_TEST/discord.fn" "ensure_gpg" "Discord không cài gpg"
assert_not_contains "$TMP_TEST/discord.fn" "apt-get update" "Discord không apt update"

printf '\nTests: pass=%s fail=%s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
