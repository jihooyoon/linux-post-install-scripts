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

run_preset() {
    _output=$1
    shift
    : > "$TMP_TEST/execution.log"
    env \
        SETUP_TEST_MODE=1 \
        SETUP_TEST_TUXEDO=0 \
        SETUP_ATOM_DIR="$ROOT/tests/fixtures/presets/atoms" \
        SETUP_EXTRA_DIR="$ROOT/tests/fixtures/presets/extras" \
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

IME_FILE="$ROOT/atom-scripts/3-setup-ime-deb.sh"
FLATPAK_FILE="$ROOT/atom-scripts/2-enable-flatpak-flathub-deb.sh"
OFFICE_FILE="$ROOT/atom-scripts/4-setup-office-deb.sh"
BASIC_FILE="$ROOT/atom-scripts/5-install-basic-apps-deb.sh"
if setup_child_prepare "$OFFICE_FILE" --all && \
   [ "$SETUP_SELECTED" = "1 2 3" ]; then
    pass "Office --all chọn đủ ba item"
else
    fail "Office --all chọn đủ ba item"
fi

if setup_child_prepare "$BASIC_FILE" --all && \
   [ "$SETUP_SELECTED" = "1 2 3" ]; then
    pass "Basic Apps --all chọn đủ ba item"
else
    fail "Basic Apps --all chọn đủ ba item"
fi

if [ "$(setup_item_count "$IME_FILE")" -eq 0 ] && \
   [ -n "$(setup_core_description "$IME_FILE")" ]; then
    pass "IME là script core-only"
else
    fail "IME là script core-only"
fi

awk '/^run_best_effort\(\)/,/^}/' "$OFFICE_FILE" > "$TMP_TEST/run-best-effort.fn"
awk '/^reconcile_office_selection\(\)/,/^}/' "$OFFICE_FILE" > "$TMP_TEST/reconcile-office.fn"
awk '/^run_selected_best_effort\(\)/,/^}/' "$OFFICE_FILE" > "$TMP_TEST/run-selected-best-effort.fn"
awk '/^install_onlyoffice\(\)/,/^}/' "$OFFICE_FILE" > "$TMP_TEST/install-onlyoffice.fn"
awk '/^install_libreoffice\(\)/,/^}/' "$OFFICE_FILE" > "$TMP_TEST/install-libreoffice.fn"
awk '/^prepare_apt\(\)/,/^}/' "$OFFICE_FILE" > "$TMP_TEST/office-prepare-apt.fn"
awk '/^prepare_apt\(\)/,/^}/' "$BASIC_FILE" > "$TMP_TEST/basic-prepare-apt.fn"
awk '/^detect_desktop\(\)/,/^}/' "$FLATPAK_FILE" > "$TMP_TEST/flatpak-detect-desktop.fn"
awk '/^install_gui_backend\(\)/,/^}/' "$FLATPAK_FILE" > "$TMP_TEST/flatpak-install-gui-backend.fn"

if (
    . "$TMP_TEST/flatpak-detect-desktop.fn"
    pgrep() { return 0; }
    XDG_CURRENT_DESKTOP=""
    SUDO_USER=tester
    detect_desktop
    [ "$DESKTOP" = "GNOME" ]
); then
    pass "Flatpak nhận diện GNOME qua session khi XDG rỗng"
else
    fail "Flatpak nhận diện GNOME qua session khi XDG rỗng"
fi

FLATPAK_STUB_BIN="$TMP_TEST/flatpak-stubs"
mkdir -p "$FLATPAK_STUB_BIN"
printf '#!/bin/sh\nexit 0\n' > "$FLATPAK_STUB_BIN/apt-get"
chmod +x "$FLATPAK_STUB_BIN/apt-get"

if (
    . "$TMP_TEST/flatpak-install-gui-backend.fn"
    info() { :; }
    ok() { printf 'ok:%s\n' "$*"; }
    warn() { printf 'warn:%s\n' "$*"; }
    PATH="$FLATPAK_STUB_BIN:$PATH"
    DESKTOP=GNOME
    install_gui_backend
) > "$TMP_TEST/flatpak-plugin-ok.out" 2>&1; then
    pass "Flatpak báo thành công khi plugin GNOME cài được"
else
    fail "Flatpak báo thành công khi plugin GNOME cài được"
fi
assert_contains "$TMP_TEST/flatpak-plugin-ok.out" "ok:Đã cài plugin cho GNOME Software" \
    "Flatpak không cảnh báo lỗi khi plugin GNOME cài được"

printf '#!/bin/sh\nexit 1\n' > "$FLATPAK_STUB_BIN/apt-get"

if (
    . "$TMP_TEST/flatpak-install-gui-backend.fn"
    info() { :; }
    ok() { printf 'ok:%s\n' "$*"; }
    warn() { printf 'warn:%s\n' "$*"; }
    PATH="$FLATPAK_STUB_BIN:$PATH"
    DESKTOP=GNOME
    install_gui_backend
) > "$TMP_TEST/flatpak-plugin-failure.out" 2>&1; then
    pass "Flatpak tiếp tục khi plugin GNOME cài lỗi"
else
    fail "Flatpak tiếp tục khi plugin GNOME cài lỗi"
fi
assert_contains "$TMP_TEST/flatpak-plugin-failure.out" "warn:Không cài được plugin Flatpak cho GNOME Software" \
    "Flatpak cảnh báo chính xác khi plugin GNOME cài lỗi"

run_office_case() {
    _selection=$1
    _output=$2
    _purge_failure=${3:-0}
    (
        . "$ROOT/lib/setup-contract.sh"
        . "$TMP_TEST/run-best-effort.fn"
        . "$TMP_TEST/reconcile-office.fn"
        warn() { printf 'warn:%s\n' "$*"; }
        purge_onlyoffice() { printf 'purge-onlyoffice\n'; return "$_purge_failure"; }
        purge_libreoffice() { printf 'purge-libreoffice\n'; return "$_purge_failure"; }
        purge_freeoffice() { printf 'purge-freeoffice\n'; return "$_purge_failure"; }
        SETUP_SELECTED=$_selection
        reconcile_office_selection
    ) > "$_output" 2>&1
}

run_office_case '1 2 3' "$TMP_TEST/office-all.out"
assert_not_contains "$TMP_TEST/office-all.out" "purge-" "chọn cả ba Office không purge"

run_office_case '1' "$TMP_TEST/office-onlyoffice.out"
assert_contains "$TMP_TEST/office-onlyoffice.out" "purge-freeoffice" "chỉ ONLYOFFICE thì purge FreeOffice"
assert_contains "$TMP_TEST/office-onlyoffice.out" "purge-libreoffice" "chỉ ONLYOFFICE thì purge LibreOffice"
assert_not_contains "$TMP_TEST/office-onlyoffice.out" "purge-onlyoffice" "chỉ ONLYOFFICE không purge ONLYOFFICE"

run_office_case '2' "$TMP_TEST/office-free.out"
assert_contains "$TMP_TEST/office-free.out" "purge-onlyoffice" "chỉ FreeOffice thì purge ONLYOFFICE"
assert_contains "$TMP_TEST/office-free.out" "purge-libreoffice" "chỉ FreeOffice thì purge LibreOffice"
assert_not_contains "$TMP_TEST/office-free.out" "purge-freeoffice" "chỉ FreeOffice không purge FreeOffice"

run_office_case '3' "$TMP_TEST/office-libre.out"
assert_contains "$TMP_TEST/office-libre.out" "purge-onlyoffice" "chỉ LibreOffice thì purge ONLYOFFICE"
assert_contains "$TMP_TEST/office-libre.out" "purge-freeoffice" "chỉ LibreOffice thì purge FreeOffice"
assert_not_contains "$TMP_TEST/office-libre.out" "purge-libreoffice" "chỉ LibreOffice không purge LibreOffice"

run_office_case '1 2' "$TMP_TEST/office-only-free.out"
assert_contains "$TMP_TEST/office-only-free.out" "purge-libreoffice" "chọn ONLYOFFICE và FreeOffice thì purge LibreOffice"
assert_not_contains "$TMP_TEST/office-only-free.out" "purge-onlyoffice" "chọn ONLYOFFICE và FreeOffice không purge ONLYOFFICE"
assert_not_contains "$TMP_TEST/office-only-free.out" "purge-freeoffice" "chọn ONLYOFFICE và FreeOffice không purge FreeOffice"

run_office_case '1 3' "$TMP_TEST/office-only-libre.out"
assert_contains "$TMP_TEST/office-only-libre.out" "purge-freeoffice" "chọn ONLYOFFICE và LibreOffice thì purge FreeOffice"

run_office_case '2 3' "$TMP_TEST/office-free-libre.out"
assert_contains "$TMP_TEST/office-free-libre.out" "purge-onlyoffice" "chọn FreeOffice và LibreOffice thì purge ONLYOFFICE"

if run_office_case '1' "$TMP_TEST/office-purge-failure.out" 9; then
    pass "lỗi purge Office không làm child thất bại"
else
    fail "lỗi purge Office không làm child thất bại"
fi
assert_contains "$TMP_TEST/office-purge-failure.out" "exit 9" "lỗi purge Office được cảnh báo"
assert_contains "$TMP_TEST/install-onlyoffice.fn" "getconf LONG_BIT" "ONLYOFFICE kiểm tra hệ thống 64-bit"
assert_contains "$TMP_TEST/install-onlyoffice.fn" "ONLYOFFICE_REPO_PATTERN" "ONLYOFFICE kiểm tra source trùng"
assert_contains "$TMP_TEST/install-onlyoffice.fn" 'gnupg-ring:$ONLYOFFICE_KEY' "ONLYOFFICE tạo keyring tạm"
assert_contains "$TMP_TEST/install-onlyoffice.fn" 'mv -f "$ONLYOFFICE_KEY" /etc/apt/keyrings/onlyoffice.gpg' "ONLYOFFICE ghi keyring atomically"
assert_contains "$TMP_TEST/install-onlyoffice.fn" "signed-by=/etc/apt/keyrings/onlyoffice.gpg" "ONLYOFFICE source dùng signed-by"
assert_contains "$TMP_TEST/install-onlyoffice.fn" "apt-get install -y onlyoffice-desktopeditors" "ONLYOFFICE cài package chính thức"
assert_contains "$TMP_TEST/install-libreoffice.fn" "apt-get install -y libreoffice" "LibreOffice dùng repo mặc định"
assert_contains "$TMP_TEST/office-prepare-apt.fn" "wait_apt" "Office đợi apt lock trước khi cài"
assert_contains "$TMP_TEST/office-prepare-apt.fn" "apt-get update" "Office cập nhật apt cache trước khi cài"
assert_contains "$TMP_TEST/basic-prepare-apt.fn" "wait_apt" "Basic Apps đợi apt lock trước khi cài"
assert_contains "$TMP_TEST/basic-prepare-apt.fn" "apt-get update" "Basic Apps cập nhật apt cache trước khi cài"

if (
    . "$ROOT/lib/setup-contract.sh"
    . "$TMP_TEST/run-best-effort.fn"
    . "$TMP_TEST/run-selected-best-effort.fn"
    warn() { printf 'warn:%s\n' "$*"; }
    install_onlyoffice() { printf 'called:onlyoffice\n'; return 1; }
    install_freeoffice() { printf 'called:freeoffice\n'; return 2; }
    install_libreoffice() { printf 'called:libreoffice\n'; return 3; }
    CHILD_FILE="$OFFICE_FILE"
    SETUP_SELECTED='1 2 3'
    run_selected_best_effort
) > "$TMP_TEST/office-best-effort.out" 2>&1; then
    pass "optional apps lỗi vẫn trả thành công"
else
    fail "optional apps lỗi vẫn trả thành công"
fi
for app_name in onlyoffice freeoffice libreoffice; do
    assert_contains "$TMP_TEST/office-best-effort.out" "called:$app_name" \
        "Office runner tiếp tục tới $app_name"
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

OUT="$TMP_TEST/keep-snap-interactive.out"
if run_parent 's\n1\ns\nr\n' "$OUT" --keep-snap; then
    pass "--keep-snap chạy tương tác thành công"
else
    fail "--keep-snap chạy tương tác thành công"
fi
assert_contains "$OUT" "Skipped: --keep-snap" "review hiển thị atom 1 bị skip"
assert_contains "$OUT" "Non-Tuxedo variant — --keep-snap" "summary ghi lý do skip keep-snap"
assert_not_contains "$TMP_TEST/execution.log" "1-non-tuxedo.sh|" "--keep-snap không chạy atom 1 non-Tuxedo"
assert_contains "$TMP_TEST/execution.log" "2-core.sh|" "--keep-snap vẫn chạy atom 2"

OUT="$TMP_TEST/keep-snap-tuxedo.out"
if SETUP_TEST_TUXEDO_VALUE=1 run_parent 's\n1\ns\nr\n' "$OUT" --keep-snap; then
    pass "--keep-snap không lỗi trên Tuxedo"
else
    fail "--keep-snap không lỗi trên Tuxedo"
fi
assert_contains "$TMP_TEST/execution.log" "1-tuxedo.sh|" "--keep-snap không skip atom 1 Tuxedo"

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

OUT="$TMP_TEST/preset-all.out"
if run_preset "$OUT" --all; then
    pass "--all áp selection và chạy không tương tác"
else
    fail "--all áp selection và chạy không tương tác"
fi
assert_not_contains "$OUT" "Review execution plan" "--all không hiện review"
assert_contains "$TMP_TEST/execution.log" "4-office.sh|--all" "--all chọn toàn bộ Office"
assert_contains "$TMP_TEST/execution.log" "5-basic-apps.sh|--all" "--all chọn toàn bộ Basic Apps"
assert_contains "$TMP_TEST/execution.log" "1-chat.sh|--all" "--all chọn toàn bộ Chat"
assert_contains "$TMP_TEST/execution.log" "2-dev.sh|" "--all enable Dev Tools core-only"
assert_not_contains "$TMP_TEST/execution.log" "2-dev.sh|--all" "--all không truyền argument cho extra core-only"
assert_contains "$TMP_TEST/execution.log" "4-ai.sh|--all" "--all chọn toàn bộ AI"

OUT="$TMP_TEST/preset-all-keep-snap.out"
if run_preset "$OUT" --all --keep-snap; then
    pass "--keep-snap hoạt động cùng --all"
else
    fail "--keep-snap hoạt động cùng --all"
fi
assert_not_contains "$TMP_TEST/execution.log" "1-non-tuxedo.sh|" "--all --keep-snap skip atom 1"
assert_contains "$TMP_TEST/execution.log" "2-flatpak.sh|" "--all --keep-snap vẫn chạy atom 2"

OUT="$TMP_TEST/preset-ms.out"
if run_preset "$OUT" --pack-ms; then
    pass "--pack-ms chạy không tương tác"
else
    fail "--pack-ms chạy không tương tác"
fi
assert_not_contains "$OUT" "Review execution plan" "--pack-ms không hiện review"
assert_contains "$TMP_TEST/execution.log" "4-office.sh|1" "--pack-ms chỉ chọn OnlyOffice"
assert_not_contains "$TMP_TEST/execution.log" "4-office.sh|--all" "--pack-ms không chọn Office khác"
assert_contains "$TMP_TEST/execution.log" "5-basic-apps.sh|--all" "--pack-ms chọn toàn bộ Basic Apps"
assert_contains "$TMP_TEST/execution.log" "1-chat.sh|--all" "--pack-ms chọn toàn bộ Chat"
assert_contains "$TMP_TEST/execution.log" "4-ai.sh|--all" "--pack-ms chọn toàn bộ AI"

OUT="$TMP_TEST/preset-ms-keep-snap.out"
if run_preset "$OUT" --pack-ms --keep-snap; then
    pass "--keep-snap hoạt động cùng --pack-ms"
else
    fail "--keep-snap hoạt động cùng --pack-ms"
fi
assert_not_contains "$TMP_TEST/execution.log" "1-non-tuxedo.sh|" "--pack-ms --keep-snap skip atom 1"
assert_contains "$TMP_TEST/execution.log" "2-flatpak.sh|" "--pack-ms --keep-snap vẫn chạy atom 2"

OUT="$TMP_TEST/preset-bs.out"
if run_preset "$OUT" --pack-bs; then
    pass "--pack-bs chạy không tương tác"
else
    fail "--pack-bs chạy không tương tác"
fi
assert_not_contains "$OUT" "Review execution plan" "--pack-bs không hiện review"
assert_contains "$TMP_TEST/execution.log" "4-office.sh|1" "--pack-bs chọn OnlyOffice"
assert_contains "$TMP_TEST/execution.log" "5-basic-apps.sh|1" "--pack-bs chọn Chrome"
assert_contains "$TMP_TEST/execution.log" "2-flatpak.sh|" "--pack-bs vẫn chạy atom core"
assert_contains "$TMP_TEST/execution.log" "1-chat.sh|2" "--pack-bs chọn Mattermost"
assert_not_contains "$TMP_TEST/execution.log" "2-dev.sh|" "--pack-bs skip Dev Tools"
assert_contains "$TMP_TEST/execution.log" "3-ime-shortcut.sh|" "--pack-bs enable shortcut IME"
assert_contains "$TMP_TEST/execution.log" "4-ai.sh|1" "--pack-bs chọn Claude Desktop"

OUT="$TMP_TEST/preset-bs-keep-snap.out"
if run_preset "$OUT" --pack-bs --keep-snap; then
    pass "--keep-snap hoạt động cùng --pack-bs"
else
    fail "--keep-snap hoạt động cùng --pack-bs"
fi
assert_not_contains "$TMP_TEST/execution.log" "1-non-tuxedo.sh|" "--pack-bs --keep-snap skip atom 1"
assert_contains "$TMP_TEST/execution.log" "2-flatpak.sh|" "--pack-bs --keep-snap vẫn chạy atom 2"

OUT="$TMP_TEST/preset-invalid.out"
if run_preset "$OUT" --all --pack-ms; then
    fail "preset trộn phải bị reject"
else
    pass "preset trộn bị reject"
fi
assert_contains "$OUT" "Chỉ được dùng một preset" "preset trộn báo lỗi rõ ràng"

if run_preset "$OUT" --pack-bs --pack-bs; then
    fail "preset lặp phải bị reject"
else
    pass "preset lặp bị reject"
fi
assert_contains "$OUT" "Chỉ được dùng một preset" "preset lặp báo lỗi rõ ràng"

for removed_flag in --basic --silent --dev --no-debloat; do
    OUT="$TMP_TEST/removed-${removed_flag#--}.out"
    if run_preset "$OUT" "$removed_flag"; then
        fail "$removed_flag phải bị reject"
    else
        pass "$removed_flag bị reject"
    fi
    assert_contains "$OUT" "Không rõ tuỳ chọn" "$removed_flag báo lỗi unknown option"
done

OUT="$TMP_TEST/help.out"
if run_preset "$OUT" --help; then
    pass "--help chạy thành công"
else
    fail "--help chạy thành công"
fi
assert_contains "$OUT" "--keep-snap     Giữ Snap" "--help mô tả --keep-snap"

REMOTE_FILE="$ROOT/remote-setup.sh"
assert_contains "$REMOTE_FILE" '--dev) BRANCH="dev" ;;' "remote chỉ tách --dev để chọn branch"
assert_contains "$REMOTE_FILE" '*) SETUP_ARGS="${SETUP_ARGS}${SETUP_ARGS:+ }$arg" ;;' \
    "remote passthrough argument setup khác"
assert_contains "$REMOTE_FILE" '--preserve-env=DEBUG' "remote giữ DEBUG qua sudo"
assert_not_contains "$REMOTE_FILE" 'MODE_BASIC' "remote không còn xử lý basic mode"
assert_not_contains "$REMOTE_FILE" 'MODE_SILENT' "remote không còn xử lý silent mode"

OUT="$TMP_TEST/failure.out"
if run_parent '' "$OUT" --all; then
    fail "runtime failure phải tạo exit non-zero tổng hợp"
else
    pass "runtime failure tạo exit non-zero tổng hợp"
fi
assert_contains "$TMP_TEST/execution.log" "2-failure.sh|" "failing child đã được gọi"
assert_contains "$TMP_TEST/execution.log" "3-core.sh|" "parent tiếp tục sau failing child"
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
    sh "$IME_FILE" > "$TMP_TEST/ime-core-failure.out" 2>&1; then
    fail "IME core failure phải trả non-zero"
else
    pass "IME core failure vẫn trả non-zero"
fi
: > "$TMP_TEST/side-effects.log"

if PATH="$STUB_BIN:$PATH" SETUP_SIDE_EFFECT_LOG="$TMP_TEST/side-effects.log" \
    sh "$BASIC_FILE" > "$TMP_TEST/basic-empty.out" 2>&1 && \
   [ ! -s "$TMP_TEST/side-effects.log" ]; then
    pass "Basic Apps no-argument không gọi apt/curl/gpg"
else
    fail "Basic Apps no-argument không gọi apt/curl/gpg"
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
awk '/^run_best_effort\(\)/,/^}/' "$AI_FILE" > "$TMP_TEST/ai-run-best-effort.fn"
awk '/^run_selected_best_effort\(\)/,/^}/' "$AI_FILE" > "$TMP_TEST/ai-run-selected-best-effort.fn"
assert_not_contains "$TMP_TEST/claude-desktop.fn" "ensure_local_bin_path" "Claude Desktop không sửa PATH"
assert_not_contains "$TMP_TEST/claude-desktop.fn" "die " "Claude Desktop trả lỗi item thay vì exit child"
assert_contains "$TMP_TEST/claude-desktop.fn" "return 1" "Claude Desktop trả lỗi để runner tiếp tục"
assert_not_contains "$TMP_TEST/claude-cli.fn" "ensure_gpg" "Claude CLI không cài gpg"
assert_not_contains "$TMP_TEST/codex.fn" "ensure_gpg" "Codex CLI không cài gpg"
assert_contains "$AI_FILE" 'sudo -u "$SUDO_USER" -H sh -c' "PATH được ghi dưới user thật"
assert_not_contains "$AI_FILE" "setup_run_selected" "AI dùng runner best-effort riêng"
assert_contains "$AI_FILE" "run_selected_best_effort" "AI tiếp tục sau item lỗi"

if (
    . "$ROOT/lib/setup-contract.sh"
    . "$TMP_TEST/ai-run-best-effort.fn"
    . "$TMP_TEST/ai-run-selected-best-effort.fn"
    warn() { printf 'warn:%s\n' "$*"; }
    install_claude_desktop() { printf 'called:claude-desktop\n'; return 1; }
    install_claude_cli() { printf 'called:claude-cli\n'; return 2; }
    install_codex_cli() { printf 'called:codex-cli\n'; return 3; }
    CHILD_FILE="$AI_FILE"
    SETUP_SELECTED='1 2 3'
    run_selected_best_effort
) > "$TMP_TEST/ai-best-effort.out" 2>&1; then
    pass "AI item lỗi vẫn trả thành công"
else
    fail "AI item lỗi vẫn trả thành công"
fi
for app_name in claude-desktop claude-cli codex-cli; do
    assert_contains "$TMP_TEST/ai-best-effort.out" "called:$app_name" \
        "AI runner tiếp tục tới $app_name"
done

awk '/^install_slack\(\)/,/^}/' "$CHAT_FILE" > "$TMP_TEST/slack.fn"
awk '/^install_mattermost\(\)/,/^}/' "$CHAT_FILE" > "$TMP_TEST/mattermost.fn"
awk '/^install_discord\(\)/,/^}/' "$CHAT_FILE" > "$TMP_TEST/discord.fn"
awk '/^run_best_effort\(\)/,/^}/' "$CHAT_FILE" > "$TMP_TEST/chat-run-best-effort.fn"
awk '/^run_selected_best_effort\(\)/,/^}/' "$CHAT_FILE" > "$TMP_TEST/chat-run-selected-best-effort.fn"
assert_contains "$TMP_TEST/slack.fn" "ensure_gpg" "Slack tự bảo đảm gpg"
assert_contains "$TMP_TEST/slack.fn" "apt-get update" "Slack tự chạy apt update"
assert_not_contains "$TMP_TEST/mattermost.fn" "ensure_gpg" "Mattermost không cài gpg"
assert_not_contains "$TMP_TEST/mattermost.fn" "apt-get update" "Mattermost không apt update"
assert_not_contains "$TMP_TEST/discord.fn" "ensure_gpg" "Discord không cài gpg"
assert_not_contains "$TMP_TEST/discord.fn" "apt-get update" "Discord không apt update"
assert_not_contains "$CHAT_FILE" "setup_run_selected" "Chat dùng runner best-effort riêng"
assert_contains "$CHAT_FILE" "run_selected_best_effort" "Chat tiếp tục sau item lỗi"

if (
    . "$ROOT/lib/setup-contract.sh"
    . "$TMP_TEST/chat-run-best-effort.fn"
    . "$TMP_TEST/chat-run-selected-best-effort.fn"
    warn() { printf 'warn:%s\n' "$*"; }
    install_slack() { printf 'called:slack\n'; return 1; }
    install_mattermost() { printf 'called:mattermost\n'; return 2; }
    install_discord() { printf 'called:discord\n'; return 3; }
    CHILD_FILE="$CHAT_FILE"
    SETUP_SELECTED='1 2 3'
    run_selected_best_effort
) > "$TMP_TEST/chat-best-effort.out" 2>&1; then
    pass "Chat item lỗi vẫn trả thành công"
else
    fail "Chat item lỗi vẫn trả thành công"
fi
for app_name in slack mattermost discord; do
    assert_contains "$TMP_TEST/chat-best-effort.out" "called:$app_name" \
        "Chat runner tiếp tục tới $app_name"
done

printf '\nTests: pass=%s fail=%s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
