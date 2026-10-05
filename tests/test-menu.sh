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
        SETUP_TEST_KDE_FAIL="${SETUP_TEST_KDE_FAIL_VALUE:-0}" \
        SETUP_MENU_INPUT=- \
        SETUP_BASICS_DIR="$ROOT/tests/fixtures/atoms" \
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
        SETUP_BASICS_DIR="$ROOT/tests/fixtures/presets/atoms" \
        SETUP_EXTRA_DIR="$ROOT/tests/fixtures/presets/extras" \
        SETUP_TEST_LOG="$TMP_TEST/execution.log" \
        sh "$ROOT/setup-ubuntu-based.sh" "$@" > "$_output" 2>&1
}

. "$ROOT/lib/setup-contract.sh"

if setup_validate_metadata "$ROOT/tests/fixtures/atoms/4-items.sh" && \
   [ "$(setup_item_count "$ROOT/tests/fixtures/atoms/4-items.sh")" -eq 2 ]; then
    pass "metadata fixture hợp lệ và đếm item động"
else
    fail "metadata fixture hợp lệ và đếm item động"
fi

if setup_child_prepare "$ROOT/tests/fixtures/atoms/4-items.sh" 2 1 2 && \
   [ "$SETUP_SELECTED" = "1 2" ]; then
    pass "child argument được canonicalize và loại duplicate"
else
    fail "child argument được canonicalize và loại duplicate"
fi

if setup_child_prepare "$ROOT/tests/fixtures/atoms/4-items.sh" --all 1 >/dev/null 2>&1; then
    fail "child reject --all trộn item"
else
    pass "child reject --all trộn item"
fi

sed '/@setup-item: second_item/d' "$ROOT/tests/fixtures/atoms/4-items.sh" > "$TMP_TEST/one-item.sh"
if [ "$(setup_item_count "$TMP_TEST/one-item.sh")" -eq 1 ] && \
   ! setup_child_prepare "$TMP_TEST/one-item.sh" 2 >/dev/null 2>&1; then
    pass "xóa item tự cập nhật range"
else
    fail "xóa item tự cập nhật range"
fi

BASICS_FILE="$ROOT/basics/3-setup-basics-ubuntu-based.sh"
KDE_FILE="$ROOT/basics/1-switch-to-kde-deb.sh"
DEBLOAT_FILE="$ROOT/basics/2-debloat-ubuntu-based.sh"
FLATPAK_FILE="$BASICS_FILE"
SWAP_FILE="$ROOT/basics/4-expand-swapfile-deb.sh"
OFFICE_FILE="$ROOT/basics/5-setup-office-deb.sh"
BASIC_FILE="$ROOT/basics/6-install-basic-apps-deb.sh"
MISC_FILE="$ROOT/extras/5-setup-miscellaneous-ubuntu-based.sh"
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

if [ "$(setup_item_count "$BASICS_FILE")" -eq 3 ] && \
   [ -z "$(setup_core_description "$BASICS_FILE")" ]; then
    pass "Basics có ba item tùy chọn"
else
    fail "Basics có ba item tùy chọn"
fi

if [ "$(setup_item_count "$MISC_FILE")" -eq 2 ]; then
    pass "Miscellaneous có Flameshot và WARP"
else
    fail "Miscellaneous có Flameshot và WARP"
fi

assert_contains "$SWAP_FILE" 'SWAP_SKIP_BYTES=$((12 * 1024 * 1024 * 1024))' "Swap skip khi đạt 12 GiB"
assert_contains "$SWAP_FILE" 'TARGET_SWAP_BYTES=$((16 * 1024 * 1024 * 1024))' "Swap đặt mục tiêu 16 GiB"
assert_contains "$SWAP_FILE" 'EXPAND_BYTES=$((TARGET_SWAP_BYTES - CURRENT_SWAP_BYTES))' "Swap tính phần mở rộng trước thao tác"
assert_contains "$SWAP_FILE" '_replacement_file_bytes=$((_old_file_bytes + _expand_bytes))' "Swapfile thay thế bằng file cũ cộng phần mở rộng"
assert_contains "$SWAP_FILE" 'create_swapfile "$TEMP_SWAPFILE" "$_old_file_bytes"' "Swapfile tạm cùng dung lượng file cũ"
assert_contains "$SWAP_FILE" 'swapon "$TEMP_SWAPFILE"' "Bật swap tạm trước khi đổi file chính"
assert_contains "$SWAP_FILE" 'swapoff "$_swap_path"' "Tắt swapfile chính sau khi có swap tạm"
assert_contains "$SWAP_FILE" 'NEW_SWAPFILE=/swapfile-extra' "Swap mới dùng đường dẫn riêng an toàn"
assert_contains "$SWAP_FILE" 'main || warn' "Lỗi swap runtime không làm child thất bại"

# --- Swap chạy thật với stub: tổng phải đúng 16 GiB, mở rộng đúng file gốc ---
SW_BIN="$TMP_TEST/swap-stubs"
mkdir -p "$SW_BIN"
cat > "$SW_BIN/swapon" <<'EOF'
#!/bin/sh
if [ "$1" = --show ]; then
    case "$*" in *SIZE*) cat "$SW_ACTIVE" ;; *) awk '{print $1}' "$SW_ACTIVE" ;; esac
    exit 0
fi
printf '%s file %s\n' "$1" "$(awk -v p="$1" '$1 == p { print $2 }' "$SW_SIZES" | tail -1)" >> "$SW_ACTIVE"
EOF
cat > "$SW_BIN/swapoff" <<'EOF'
#!/bin/sh
grep -v "^$1 " "$SW_ACTIVE" > "$SW_ACTIVE.t"; mv "$SW_ACTIVE.t" "$SW_ACTIVE"
EOF
cat > "$SW_BIN/dd" <<'EOF'
#!/bin/sh
for a in "$@"; do
    case $a in of=*) of=${a#of=} ;; bs=1M) bs=1048576 ;; bs=1) bs=1 ;; count=*) count=${a#count=} ;; oflag=append) app=1 ;; esac
done
old=0
[ "${app:-0}" = 1 ] && old=$(awk -v p="$of" '$1 == p { print $2 }' "$SW_SIZES" | tail -1)
grep -v "^$of " "$SW_SIZES" > "$SW_SIZES.t"; mv "$SW_SIZES.t" "$SW_SIZES"
printf '%s %s\n' "$of" "$((old + bs * count))" >> "$SW_SIZES"; : > "$of"
EOF
cat > "$SW_BIN/stat" <<'EOF'
#!/bin/sh
for a in "$@"; do last=$a; done
awk -v p="$last" '$1 == p { print $2 }' "$SW_SIZES" | tail -1
EOF
printf '#!/bin/sh\necho "Filesystem 1-blocks Used Available"\necho "x 0 0 999999999999"\n' > "$SW_BIN/df"
printf '#!/bin/sh\necho ext4\n' > "$SW_BIN/findmnt"
for command_name in mkswap sync chmod; do printf '#!/bin/sh\nexit 0\n' > "$SW_BIN/$command_name"; done
chmod +x "$SW_BIN"/*
SW_ROOT="$TMP_TEST/swap-root"
mkdir -p "$SW_ROOT/basics"
ln -s "$ROOT/lib" "$SW_ROOT/lib"
sed "s#/swapfile-extra#$SW_ROOT/swapfile-extra#; s#/etc/fstab#$SW_ROOT/fstab#g" "$SWAP_FILE" > "$SW_ROOT/basics/4-expand-swapfile-deb.sh"
GIB=$((1024 * 1024 * 1024))
printf '%s/swap.img file %s\n' "$SW_ROOT" "$((4 * GIB))" > "$SW_ROOT/active"
printf '%s/swap.img %s\n' "$SW_ROOT" "$((4 * GIB))" > "$SW_ROOT/sizes"
: > "$SW_ROOT/swap.img"; : > "$SW_ROOT/fstab"
PATH="$SW_BIN:$PATH" SW_ACTIVE="$SW_ROOT/active" SW_SIZES="$SW_ROOT/sizes" \
    sh "$SW_ROOT/basics/4-expand-swapfile-deb.sh" > "$TMP_TEST/swap-run.out" 2>&1
if [ "$(awk '{ t += $3 } END { printf "%.0f", t }' "$SW_ROOT/active")" = "$((16 * GIB))" ] && \
   [ "$(wc -l < "$SW_ROOT/active")" -eq 1 ] && \
   grep -q "^$SW_ROOT/swap.img file $((16 * GIB))\$" "$SW_ROOT/active"; then
    pass "Swap 4 GiB được mở rộng chính file gốc lên tổng đúng 16 GiB"
else
    fail "Swap 4 GiB được mở rộng chính file gốc lên tổng đúng 16 GiB"
fi
if grep -q '\.expand\.' "$SW_ROOT/fstab" || ls -A "$SW_ROOT" | grep -q '\.expand\.'; then
    fail "Swap không để lại swapfile tạm trong fstab hoặc trên đĩa"
else
    pass "Swap không để lại swapfile tạm trong fstab hoặc trên đĩa"
fi
assert_contains "$KDE_FILE" 'DEBIAN_FRONTEND=noninteractive apt-get install -y kde-plasma-desktop sddm' "KDE cài noninteractive với SDDM"
assert_contains "$KDE_FILE" 'sddm shared/default-x-display-manager select sddm' "KDE preseed SDDM"
PURGE_GNOME_FILE="$ROOT/lib/purge-gnome.sh"
assert_contains "$PURGE_GNOME_FILE" 'GNOME_PACKAGES="gnome* gdm3 ubuntu-desktop*' "Purge GNOME gỡ các metapackage GNOME"
assert_contains "$PURGE_GNOME_FILE" 'apt-get purge -y --autoremove $GNOME_PACKAGES' "Purge GNOME dọn dependency cùng lúc"
assert_contains "$PURGE_GNOME_FILE" 'apt-get -s purge --autoremove $GNOME_PACKAGES' "Purge GNOME mô phỏng trước khi gỡ"
assert_not_contains "$KDE_FILE" 'apt-get purge' "KDE không purge GNOME ngay trong phiên hiện tại"
assert_contains "$KDE_FILE" 'systemctl disable gdm3.service' "KDE disable gdm3 trước khi enable sddm"
assert_contains "$KDE_FILE" 'install_deferred_purge' "KDE hẹn purge GNOME khi vào phiên Plasma"
assert_contains "$KDE_FILE" 'setup_child_skip "desktop hiện tại đã là KDE/Plasma"' "KDE skip khi đã dùng KDE"
assert_contains "$KDE_FILE" 'mark_kde_switch_succeeded' "KDE ghi marker sau khi KDE và SDDM sẵn sàng"
assert_contains "$KDE_FILE" 'return 1' "Lỗi chuyển KDE trước marker làm child thất bại"
assert_contains "$DEBLOAT_FILE" 'setup_is_kde_desktop' "Debloat dùng nhận diện KDE chung"
assert_contains "$BASICS_FILE" 'setup_is_kde_desktop' "Basics dùng nhận diện KDE chung"
assert_contains "$BASICS_FILE" '*/bash) SHELL_PROFILE="$HOME_USER/.bash_profile"' "Lotus ghi biến môi trường Bash vào ~/.bash_profile"
assert_contains "$BASICS_FILE" '*/zsh) SHELL_PROFILE="$HOME_USER/.zprofile"' "Lotus ghi biến môi trường Zsh vào ~/.zprofile"
assert_contains "$BASICS_FILE" 'rm -f /etc/environment.d/fcitx5.conf' "Lotus xoá biến môi trường bản cũ ở /etc/environment.d"
assert_not_contains "$BASICS_FILE" '> /etc/environment.d/fcitx5.conf' "Lotus không còn ghi /etc/environment.d"
for real_user_part in "bật kimpanel" "autostart fcitx5" "bật fcitx5-lotus-server" "kwinrc (chọn fcitx5 làm Virtual Keyboard)" "thêm Lotus vào profile fcitx5" "biến môi trường fcitx5"; do
    assert_contains "$BASICS_FILE" "warn_no_real_user \"$real_user_part\"" "Basics thiếu user sudo: warning và bỏ qua $real_user_part"
done
IME_CONFIGS_FILE="$ROOT/extras/3-set-ime-configs.sh"
assert_contains "$IME_CONFIGS_FILE" 'setup_is_kde_desktop' "IME shortcut dùng nhận diện KDE chung"
if setup_validate_metadata "$IME_CONFIGS_FILE" && \
   [ "$(setup_item_count "$IME_CONFIGS_FILE")" -eq 2 ] && \
   [ -z "$(setup_core_description "$IME_CONFIGS_FILE")" ]; then
    pass "IME configs có 2 item, không có core"
else
    fail "IME configs có 2 item, không có core"
fi
assert_contains "$IME_CONFIGS_FILE" 'Mode="Uinput (Super Smooth)"' "IME configs ghi lotus.conf Super Smooth"
assert_contains "$IME_CONFIGS_FILE" 'Chưa cài fcitx5-lotus' "IME configs báo lỗi khi chưa cài Lotus"
assert_not_contains "$BASICS_FILE" 'lotus.conf' "Basics không còn ghi lotus.conf"
assert_contains "$ROOT/setup-ubuntu-based.sh" 'setup_is_kde_desktop "$_desktop"' "GNOME notice dùng nhận diện KDE chung"

KDE_STUB_BIN="$TMP_TEST/kde-stubs"
mkdir -p "$KDE_STUB_BIN"
printf '#!/bin/sh\nprintf "0\\n"\n' > "$KDE_STUB_BIN/id"
printf '#!/bin/sh\nprintf "apt:%s\\n" "$*" >> "$SETUP_SIDE_EFFECT_LOG"\nexit 99\n' > "$KDE_STUB_BIN/apt-get"
chmod +x "$KDE_STUB_BIN/id" "$KDE_STUB_BIN/apt-get"
: > "$TMP_TEST/kde-skip-effects.log"
if PATH="$KDE_STUB_BIN:$PATH" XDG_CURRENT_DESKTOP=KDE \
    SETUP_SIDE_EFFECT_LOG="$TMP_TEST/kde-skip-effects.log" \
    sh "$KDE_FILE" > "$TMP_TEST/kde-skip.out" 2>&1 && \
   [ ! -s "$TMP_TEST/kde-skip-effects.log" ] && \
   grep -Fq -- '[SKIPPED]' "$TMP_TEST/kde-skip.out"; then
    pass "KDE hiện tại skip mà không gọi apt"
else
    fail "KDE hiện tại skip mà không gọi apt"
fi

# --- purge-gnome.sh với stub: phiên GNOME / Plasma / mô phỏng đụng gói KDE ---
PG_BIN="$TMP_TEST/pg-stubs"
PG_ROOT="$TMP_TEST/pg-root"
mkdir -p "$PG_BIN"
cat > "$PG_BIN/pgrep" <<'EOF'
#!/bin/sh
for a in "$@"; do last=$a; done
case " $PG_RUNNING " in *" $last "*) echo 4242; exit 0 ;; esac
exit 1
EOF
printf '#!/bin/sh\necho tester\n' > "$PG_BIN/ps"
printf '#!/bin/sh\necho 1000\n' > "$PG_BIN/id"
printf '#!/bin/sh\nexit 1\n' > "$PG_BIN/fuser"
printf '#!/bin/sh\necho "install ok installed"\n' > "$PG_BIN/dpkg-query"
printf '#!/bin/sh\necho "systemctl $*" >> "$PG_CALLS"\n' > "$PG_BIN/systemctl"
printf '#!/bin/sh\nshift 3\necho "notify $*" >> "$PG_CALLS"\n' > "$PG_BIN/runuser"
printf '#!/bin/sh\nexit 0\n' > "$PG_BIN/notify-send"
cat > "$PG_BIN/apt-get" <<'EOF'
#!/bin/sh
echo "apt-get $*" >> "$PG_CALLS"
if [ "$1" = -s ]; then echo "Purg gnome-shell [46]"; echo "Remv gdm3 [46]"; [ -z "$PG_SIM_EXTRA" ] || echo "Remv $PG_SIM_EXTRA [6]"; fi
exit 0
EOF
chmod +x "$PG_BIN"/*
run_purge_gnome() {
    rm -rf "$PG_ROOT"; mkdir -p "$PG_ROOT/lib" "$PG_ROOT/units"
    : > "$PG_ROOT/lib/purge-gnome.sh"; : > "$PG_ROOT/units/linux-post-install-purge-gnome.timer"
    : > "$TMP_TEST/pg-calls.log"
    PATH="$PG_BIN:$PATH" PG_CALLS="$TMP_TEST/pg-calls.log" PG_RUNNING="$1" PG_SIM_EXTRA="${2:-}" \
        PURGE_GNOME_INSTALL_DIR="$PG_ROOT/lib" PURGE_GNOME_UNIT_DIR="$PG_ROOT/units" \
        PURGE_GNOME_LOG="$PG_ROOT/purge.log" PURGE_GNOME_STATE_DIR="$PG_ROOT/state" \
        sh "$PURGE_GNOME_FILE" check > "$TMP_TEST/pg.out" 2>&1
}

run_purge_gnome "gnome-shell"
if grep -q 'Chưa hoàn tất chuyển sang KDE' "$TMP_TEST/pg-calls.log" && \
   ! grep -q '^apt-get' "$TMP_TEST/pg-calls.log" && \
   [ -f "$PG_ROOT/units/linux-post-install-purge-gnome.timer" ]; then
    pass "Purge GNOME: phiên GNOME chỉ nhắc chọn Plasma, không purge, giữ timer"
else
    fail "Purge GNOME: phiên GNOME chỉ nhắc chọn Plasma, không purge, giữ timer"
fi

run_purge_gnome "plasmashell"
if grep -q '^apt-get -s purge --autoremove gnome\* gdm3' "$TMP_TEST/pg-calls.log" && \
   grep -q '^apt-get purge -y --autoremove gnome\* gdm3' "$TMP_TEST/pg-calls.log" && \
   grep -q 'Đã gỡ GNOME' "$TMP_TEST/pg-calls.log" && \
   [ ! -f "$PG_ROOT/units/linux-post-install-purge-gnome.timer" ] && \
   [ ! -f "$PG_ROOT/lib/purge-gnome.sh" ]; then
    pass "Purge GNOME: phiên Plasma mô phỏng, purge rồi tự gỡ timer"
else
    fail "Purge GNOME: phiên Plasma mô phỏng, purge rồi tự gỡ timer"
fi

run_purge_gnome "plasmashell" "kde-plasma-desktop"
if ! grep -q '^apt-get purge' "$TMP_TEST/pg-calls.log" && \
   grep -q 'Gỡ GNOME thất bại' "$TMP_TEST/pg-calls.log" && \
   grep -q 'kde-plasma-desktop' "$PG_ROOT/purge.log" && \
   [ ! -f "$PG_ROOT/units/linux-post-install-purge-gnome.timer" ]; then
    pass "Purge GNOME: mô phỏng đụng gói KDE thì không purge, báo lỗi, gỡ timer"
else
    fail "Purge GNOME: mô phỏng đụng gói KDE thì không purge, báo lỗi, gỡ timer"
fi

run_purge_gnome ""
if [ ! -s "$TMP_TEST/pg-calls.log" ] && [ -f "$PG_ROOT/units/linux-post-install-purge-gnome.timer" ]; then
    pass "Purge GNOME: chưa có phiên đồ hoạ thì không làm gì"
else
    fail "Purge GNOME: chưa có phiên đồ hoạ thì không làm gì"
fi

if sh "$DEBLOAT_FILE" --help > "$TMP_TEST/debloat-help.out" 2>&1 && \
   grep -Fq -- "--keep-snap" "$TMP_TEST/debloat-help.out"; then
    pass "Debloat child hỗ trợ --keep-snap khi chạy trực tiếp"
else
    fail "Debloat child hỗ trợ --keep-snap khi chạy trực tiếp"
fi

sed 's/@setup-when: always/@setup-when: tuxedo/' "$DEBLOAT_FILE" > "$TMP_TEST/conditional-when.sh"
if ! setup_validate_metadata "$TMP_TEST/conditional-when.sh" >/dev/null 2>&1; then
    pass "contract chỉ chấp nhận @setup-when: always"
else
    fail "contract chỉ chấp nhận @setup-when: always"
fi

awk '/^run_best_effort\(\)/,/^}/' "$OFFICE_FILE" > "$TMP_TEST/run-best-effort.fn"
awk '/^reconcile_office_selection\(\)/,/^}/' "$OFFICE_FILE" > "$TMP_TEST/reconcile-office.fn"
awk '/^run_selected_best_effort\(\)/,/^}/' "$OFFICE_FILE" > "$TMP_TEST/run-selected-best-effort.fn"
awk '/^install_onlyoffice\(\)/,/^}/' "$OFFICE_FILE" > "$TMP_TEST/install-onlyoffice.fn"
awk '/^install_libreoffice\(\)/,/^}/' "$OFFICE_FILE" > "$TMP_TEST/install-libreoffice.fn"
awk '/^prepare_apt\(\)/,/^}/' "$OFFICE_FILE" > "$TMP_TEST/office-prepare-apt.fn"
awk '/^prepare_apt\(\)/,/^}/' "$BASIC_FILE" > "$TMP_TEST/basic-prepare-apt.fn"
awk '/^run_selected_best_effort\(\)/,/^}/' "$BASIC_FILE" > "$TMP_TEST/basic-run-selected-best-effort.fn"
awk '/^detect_desktop\(\)/,/^}/' "$FLATPAK_FILE" > "$TMP_TEST/flatpak-detect-desktop.fn"
awk '/^install_gui_backend\(\)/,/^}/' "$FLATPAK_FILE" > "$TMP_TEST/flatpak-install-gui-backend.fn"
awk '/^run_best_effort\(\)/,/^}/' "$MISC_FILE" > "$TMP_TEST/misc-run-best-effort.fn"
awk '/^run_selected_best_effort\(\)/,/^}/' "$MISC_FILE" > "$TMP_TEST/misc-run-selected-best-effort.fn"
awk '/^spectacle_is_installed\(\)/,/^}/' "$MISC_FILE" > "$TMP_TEST/misc-spectacle-installed.fn"
awk '/^install_flameshot\(\)/,/^}/' "$MISC_FILE" > "$TMP_TEST/misc-install-flameshot.fn"

assert_contains "$MISC_FILE" "apt-get install -y flameshot" "Flameshot cài từ apt"
assert_contains "$MISC_FILE" 'setup_is_kde_desktop "$XDG_CURRENT_DESKTOP"' "Flameshot dùng nhận diện KDE chung"
assert_contains "$MISC_FILE" "dpkg-query -W -f='\${db:Status-Status}' spectacle" "Flameshot kiểm tra Spectacle đã cài"
assert_contains "$MISC_FILE" "https://pkg.cloudflareclient.com/pubkey.gpg" "WARP dùng public key theo guide"
assert_contains "$MISC_FILE" "/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg" "WARP dùng keyring theo guide"
assert_contains "$MISC_FILE" '$(lsb_release -cs)' "WARP dùng codename theo guide"
assert_contains "$MISC_FILE" "signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg" "WARP source dùng signed-by"
assert_contains "$MISC_FILE" "apt-get install -y cloudflare-warp" "WARP cài package chính thức"

if (
    . "$ROOT/lib/setup-contract.sh"
    . "$TMP_TEST/misc-run-best-effort.fn"
    . "$TMP_TEST/misc-run-selected-best-effort.fn"
    warn() { printf 'warn:%s\n' "$*"; }
    install_flameshot() { printf 'called:flameshot\n'; return 1; }
    install_cloudflare_warp() { printf 'called:warp\n'; return 2; }
    CHILD_FILE="$MISC_FILE"
    SETUP_SELECTED='1 2'
    run_selected_best_effort
) > "$TMP_TEST/misc-best-effort.out" 2>&1; then
    pass "Miscellaneous item lỗi vẫn trả thành công"
else
    fail "Miscellaneous item lỗi vẫn trả thành công"
fi
assert_contains "$TMP_TEST/misc-best-effort.out" "(exit 1)" "Miscellaneous báo đúng exit code của Flameshot"
assert_contains "$TMP_TEST/misc-best-effort.out" "(exit 2)" "Miscellaneous báo đúng exit code của WARP"
assert_contains "$TMP_TEST/misc-best-effort.out" "called:flameshot" "Miscellaneous tiếp tục từ Flameshot"
assert_contains "$TMP_TEST/misc-best-effort.out" "called:warp" "Miscellaneous tiếp tục tới WARP"

run_flameshot_case() {
    _desktop=$1
    _spectacle_status=$2
    _marker=${3:-}
    _output=$4
    (
        . "$ROOT/lib/setup-contract.sh"
        . "$TMP_TEST/misc-spectacle-installed.fn"
        . "$TMP_TEST/misc-install-flameshot.fn"
        info() { printf 'info:%s\n' "$*"; }
        ok() { printf 'ok:%s\n' "$*"; }
        wait_apt() { printf 'wait-apt\n'; }
        apt-get() { printf 'apt:%s\n' "$*"; }
        dpkg-query() { printf '%s\n' "$TEST_SPECTACLE_STATUS"; }
        XDG_CURRENT_DESKTOP=$_desktop
        TEST_SPECTACLE_STATUS=$_spectacle_status
        SETUP_KDE_SWITCH_MARKER=$_marker
        install_flameshot
    ) > "$_output" 2>&1
}

KDE_SPECTACLE_MARKER="$TMP_TEST/kde-spectacle-marker"
: > "$KDE_SPECTACLE_MARKER"
run_flameshot_case KDE installed '' "$TMP_TEST/flameshot-kde.out"
assert_contains "$TMP_TEST/flameshot-kde.out" "[SKIPPED]" "KDE có Spectacle thì skip Flameshot"
assert_not_contains "$TMP_TEST/flameshot-kde.out" "apt:" "KDE có Spectacle không gọi apt"
assert_not_contains "$TMP_TEST/flameshot-kde.out" "wait-apt" "KDE có Spectacle không đợi apt lock"

run_flameshot_case GNOME installed "$KDE_SPECTACLE_MARKER" "$TMP_TEST/flameshot-marker.out"
assert_contains "$TMP_TEST/flameshot-marker.out" "[SKIPPED]" "marker KDE có Spectacle thì skip Flameshot"
assert_not_contains "$TMP_TEST/flameshot-marker.out" "apt:" "marker KDE có Spectacle không gọi apt"

run_flameshot_case KDE '' '' "$TMP_TEST/flameshot-no-spectacle.out"
assert_contains "$TMP_TEST/flameshot-no-spectacle.out" "apt:install -y flameshot" "KDE không có Spectacle vẫn cài Flameshot"

run_flameshot_case GNOME installed '' "$TMP_TEST/flameshot-non-kde.out"
assert_contains "$TMP_TEST/flameshot-non-kde.out" "apt:install -y flameshot" "non-KDE có Spectacle vẫn cài Flameshot"

assert_not_contains "$TMP_TEST/run-selected-best-effort.fn" "_i=" "Office runner không dùng iterator chung _i"
assert_contains "$TMP_TEST/run-selected-best-effort.fn" "_selected_item_index=1" "Office runner dùng iterator riêng"
assert_not_contains "$TMP_TEST/basic-run-selected-best-effort.fn" "_i=" "Basic Apps runner không dùng iterator chung _i"
assert_contains "$TMP_TEST/basic-run-selected-best-effort.fn" "_selected_item_index=1" "Basic Apps runner dùng iterator riêng"

# --- Chromium: chỉ xét bản Candidate, không bị bản snap cũ còn sót trong repo đánh lừa ---
awk '/^install_chromium\(\)/,/^}/; /^install_chromium_from_xtradeb\(\)/,/^}/; /^remove_xtradeb_source\(\)/,/^}/' "$BASIC_FILE" > "$TMP_TEST/install-chromium.fn"
CHR_BIN="$TMP_TEST/chromium-stubs"
mkdir -p "$CHR_BIN"
cat > "$CHR_BIN/apt-cache" <<'EOF'
#!/bin/sh
# CHR_CASE=tuxedo: chromium có bản .deb thật làm Candidate + bản snap cũ 131 còn trong repo
# CHR_CASE=ubuntu: chromium là gói ảo, chromium-browser chỉ có bản snap
case "$CHR_CASE:$1:$2" in
    tuxedo:policy:chromium) printf 'chromium:\n  Installed: (none)\n  Candidate: 2:153.0-1tux1\n' ;;
    tuxedo:policy:chromium-browser) printf 'chromium-browser:\n  Installed: (none)\n  Candidate: 2:153.0-1tux1\n' ;;
    tuxedo:show:chromium=2:153.0-1tux1) printf 'Package: chromium\nVersion: 2:153.0-1tux1\nDepends: libgtk-3-0, libnss3\n' ;;
    tuxedo:show:chromium) printf 'Package: chromium\nVersion: 2:153.0-1tux1\nDepends: libgtk-3-0\n\nPackage: chromium\nVersion: 2:131.0-1tux1-snap\nPre-Depends: debconf, snapd\n' ;;
    ubuntu:policy:chromium)
        if [ -f "$CHR_ROOT/ppa-updated" ]; then printf 'chromium:\n  Installed: (none)\n  Candidate: 154.0-1xtradeb1\n'
        else printf 'chromium:\n  Installed: (none)\n  Candidate: (none)\n'; fi ;;
    ubuntu:policy:chromium-browser) printf 'chromium-browser:\n  Installed: (none)\n  Candidate: 2:1snap1-0ubuntu2\n' ;;
    ubuntu:show:chromium-browser=2:1snap1-0ubuntu2) printf 'Package: chromium-browser\nVersion: 2:1snap1-0ubuntu2\nPre-Depends: debconf, snapd\n' ;;
esac
exit 0
EOF
cat > "$CHR_BIN/apt-get" <<'EOF'
#!/bin/sh
echo "apt-get $*" >> "$CHR_CALLS"
[ "$1" = update ] && [ "${CHR_UPDATE_FAIL:-0}" = 1 ] && exit 100
# Sau khi có source xtradeb và update: PPA có chromium (trừ khi giả lập codename chưa được build)
[ "$1" = update ] && [ -f "$CHR_ROOT/xtradeb-apps.sources" ] && [ "${CHR_PPA_NO_CHROMIUM:-0}" != 1 ] && : > "$CHR_ROOT/ppa-updated"
exit 0
EOF
cat > "$CHR_BIN/curl" <<'EOF'
#!/bin/sh
for a in "$@"; do [ "$prev" = -o ] && out=$a; prev=$a; done
echo "curl $*" >> "$CHR_CALLS"; echo key > "$out"
EOF
cat > "$CHR_BIN/gpg" <<'EOF'
#!/bin/sh
case "$*" in
    *--show-keys*) echo "fpr:::::::::${CHR_KEY_FPR:-5301FA4FD93244FBC6F6149982BB6851C64F6880}:" ;;
    *--dearmor*) for a in "$@"; do [ "$prev" = -o ] && out=$a; prev=$a; done; cat > "$out" ;;
esac
EOF
printf '#!/bin/sh\necho amd64\n' > "$CHR_BIN/dpkg"
chmod +x "$CHR_BIN"/*
CHR_ROOT="$TMP_TEST/chromium-root"
run_chromium_case() {
    : > "$TMP_TEST/chr-calls.log"
    rm -rf "$CHR_ROOT"; mkdir -p "$CHR_ROOT"
    [ "${CHR_OLD_MINT:-0}" != 1 ] || \
        printf '# Linux Mint repo — chỉ lấy chromium, không ảnh hưởng gì đến hệ thống\n' > "$CHR_ROOT/linuxmint.sources"
    (
        PATH="$CHR_BIN:$PATH"
        CHR_CASE=$1
        CHR_CALLS="$TMP_TEST/chr-calls.log"
        export CHR_CASE CHR_CALLS CHR_ROOT
        info() { printf 'info:%s\n' "$*"; }
        ok() { printf 'ok:%s\n' "$*"; }
        warn() { printf 'warn:%s\n' "$*"; }
        ensure_curl() { return 0; }
        XTRADEB_URI=https://ppa.launchpadcontent.net/xtradeb/apps/ubuntu
        XTRADEB_FINGERPRINT=5301FA4FD93244FBC6F6149982BB6851C64F6880
        XTRADEB_KEYRING="$CHR_ROOT/xtradeb-apps.gpg"
        XTRADEB_SOURCES="$CHR_ROOT/xtradeb-apps.sources"
        XTRADEB_PIN="$CHR_ROOT/xtradeb-apps-chromium"
        OLD_MINT_SOURCES="$CHR_ROOT/linuxmint.sources"
        . "$TMP_TEST/install-chromium.fn"
        install_chromium
    ) > "$TMP_TEST/chr.out" 2>&1
}
run_chromium_case tuxedo
if grep -q '^apt-get install -y chromium$' "$TMP_TEST/chr-calls.log" && \
   ! grep -q 'Linux Mint' "$TMP_TEST/chr.out"; then
    pass "Chromium: Candidate .deb thật thì cài thẳng, không bị bản snap cũ trong repo đánh lừa"
else
    fail "Chromium: Candidate .deb thật thì cài thẳng, không bị bản snap cũ trong repo đánh lừa"
fi
run_chromium_case ubuntu
UBUNTU_SUITE=$(grep -oP '^UBUNTU_CODENAME=\K.*' /etc/os-release 2>/dev/null || grep -oP '^VERSION_CODENAME=\K.*' /etc/os-release)
if grep -q 'thêm PPA xtradeb/apps' "$TMP_TEST/chr.out" && \
   grep -q '^apt-get install -y chromium$' "$TMP_TEST/chr-calls.log" && \
   grep -qx 'URIs: https://ppa.launchpadcontent.net/xtradeb/apps/ubuntu' "$CHR_ROOT/xtradeb-apps.sources" && \
   grep -qx "Suites: $UBUNTU_SUITE" "$CHR_ROOT/xtradeb-apps.sources" && \
   grep -qx "Signed-By: $CHR_ROOT/xtradeb-apps.gpg" "$CHR_ROOT/xtradeb-apps.sources" && \
   [ -s "$CHR_ROOT/xtradeb-apps.gpg" ] && \
   ! grep -qi 'linuxmint' "$TMP_TEST/chr-calls.log"; then
    pass "Chromium: chỉ có bản snap thì thêm PPA xtradeb/apps rồi cài chromium"
else
    fail "Chromium: chỉ có bản snap thì thêm PPA xtradeb/apps rồi cài chromium"
fi
if [ "$(tr '\n' '|' < "$CHR_ROOT/xtradeb-apps-chromium")" = 'Package: *|Pin: release o=LP-PPA-xtradeb-apps|Pin-Priority: -1||Package: chromium*|Pin: release o=LP-PPA-xtradeb-apps|Pin-Priority: 500|' ]; then
    pass "Chromium: pin chặn mọi gói xtradeb trừ chromium*"
else
    fail "Chromium: pin chặn mọi gói xtradeb trừ chromium*"
fi
CHR_KEY_FPR=0000000000000000000000000000000000000000 run_chromium_case ubuntu
if grep -q 'không khớp fingerprint' "$TMP_TEST/chr.out" && [ ! -e "$CHR_ROOT/xtradeb-apps.sources" ] && \
   ! grep -q '^apt-get install' "$TMP_TEST/chr-calls.log"; then
    pass "Chromium: khoá xtradeb sai fingerprint thì dừng, không thêm source"
else
    fail "Chromium: khoá xtradeb sai fingerprint thì dừng, không thêm source"
fi
CHR_UPDATE_FAIL=1 run_chromium_case ubuntu
if [ ! -e "$CHR_ROOT/xtradeb-apps.sources" ] && [ ! -e "$CHR_ROOT/xtradeb-apps-chromium" ] && \
   ! grep -q '^apt-get install' "$TMP_TEST/chr-calls.log"; then
    pass "Chromium: apt update lỗi thì gỡ PPA xtradeb vừa thêm"
else
    fail "Chromium: apt update lỗi thì gỡ PPA xtradeb vừa thêm"
fi
CHR_PPA_NO_CHROMIUM=1 run_chromium_case ubuntu
if grep -q 'Không lấy được chromium từ PPA xtradeb' "$TMP_TEST/chr.out" && [ ! -e "$CHR_ROOT/xtradeb-apps.sources" ] && \
   [ ! -e "$CHR_ROOT/xtradeb-apps-chromium" ] && ! grep -q '^apt-get install' "$TMP_TEST/chr-calls.log"; then
    pass "Chromium: PPA chưa build chromium cho codename thì gỡ PPA, không cài"
else
    fail "Chromium: PPA chưa build chromium cho codename thì gỡ PPA, không cài"
fi
CHR_OLD_MINT=1 run_chromium_case ubuntu
if [ ! -e "$CHR_ROOT/linuxmint.sources" ] && grep -q 'Đã gỡ source Linux Mint' "$TMP_TEST/chr.out"; then
    pass "Chromium: gỡ source Linux Mint do bản cũ của script thêm"
else
    fail "Chromium: gỡ source Linux Mint do bản cũ của script thêm"
fi

if (
    . "$ROOT/lib/setup-contract.sh"
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

KDE_MARKER="$TMP_TEST/kde-switch-complete"
: > "$KDE_MARKER"
if SETUP_KDE_SWITCH_MARKER="$KDE_MARKER" setup_is_kde_desktop GNOME; then
    pass "marker KDE ghi đè desktop GNOME"
else
    fail "marker KDE ghi đè desktop GNOME"
fi

: > "$TMP_TEST/kde-skip-effects.log"
if PATH="$KDE_STUB_BIN:$PATH" XDG_CURRENT_DESKTOP=GNOME \
    SETUP_KDE_SWITCH_MARKER="$KDE_MARKER" \
    SETUP_SIDE_EFFECT_LOG="$TMP_TEST/kde-skip-effects.log" \
    sh "$KDE_FILE" > "$TMP_TEST/kde-marker-skip.out" 2>&1 && \
   [ ! -s "$TMP_TEST/kde-skip-effects.log" ] && \
   grep -Fq -- '[SKIPPED]' "$TMP_TEST/kde-marker-skip.out"; then
    pass "marker KDE làm child chuyển KDE skip an toàn"
else
    fail "marker KDE làm child chuyển KDE skip an toàn"
fi

if (
    . "$ROOT/lib/setup-contract.sh"
    . "$TMP_TEST/flatpak-detect-desktop.fn"
    SETUP_KDE_SWITCH_MARKER="$KDE_MARKER"
    XDG_CURRENT_DESKTOP=GNOME
    detect_desktop
    [ "$DESKTOP" = KDE ]
); then
    pass "Basics nhận KDE từ marker"
else
    fail "Basics nhận KDE từ marker"
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
assert_contains "$TMP_TEST/install-onlyoffice.fn" "mkdir -p -m 700 ~/.gnupg" "ONLYOFFICE tạo GNUPG home theo guide"
assert_contains "$TMP_TEST/install-onlyoffice.fn" "gnupg-ring:/tmp/onlyoffice.gpg" "ONLYOFFICE dùng keyring theo guide"
assert_not_contains "$TMP_TEST/install-onlyoffice.fn" "--batch" "ONLYOFFICE không thêm batch ngoài guide"
assert_not_contains "$TMP_TEST/install-onlyoffice.fn" "mktemp" "ONLYOFFICE không dùng keyring tạm mới"
assert_contains "$TMP_TEST/install-onlyoffice.fn" "mv -f /tmp/onlyoffice.gpg /usr/share/keyrings/onlyoffice.gpg" "ONLYOFFICE chuyển keyring theo guide"
assert_contains "$TMP_TEST/install-onlyoffice.fn" "signed-by=/usr/share/keyrings/onlyoffice.gpg" "ONLYOFFICE source dùng signed-by theo guide"
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
if run_parent '2\n1\ns\nr\n' "$OUT"; then
    pass "interactive core-only và empty extra exit thành công"
else
    fail "interactive core-only và empty extra exit thành công"
fi
assert_contains "$OUT" "Skipped: no items selected" "review ghi rõ extra rỗng bị skip"
assert_contains "$TMP_TEST/execution.log" "2-debloat-ubuntu-based.sh|desnap|" "non-Tuxedo chạy nhánh desnap trong Basic hợp nhất"
assert_not_contains "$TMP_TEST/execution.log" "1-items.sh|" "extra không core và không item bị loại execution"

OUT="$TMP_TEST/keep-snap-interactive.out"
if run_parent '2 3\ns\nr\n' "$OUT" --keep-snap; then
    pass "--keep-snap chạy tương tác thành công"
else
    fail "--keep-snap chạy tương tác thành công"
fi
assert_contains "$TMP_TEST/execution.log" "2-debloat-ubuntu-based.sh|keep-snap|--keep-snap" "--keep-snap được chuyển vào Basic debloat non-Tuxedo"
assert_contains "$OUT" "SUCCESS" "--keep-snap để child hoàn tất thành công"
assert_contains "$TMP_TEST/execution.log" "3-core.sh|" "--keep-snap vẫn chạy Basic khác"

OUT="$TMP_TEST/keep-snap-tuxedo.out"
if SETUP_TEST_TUXEDO_VALUE=1 run_parent '2\ns\nr\n' "$OUT" --keep-snap; then
    pass "--keep-snap không lỗi trên Tuxedo"
else
    fail "--keep-snap không lỗi trên Tuxedo"
fi
assert_contains "$TMP_TEST/execution.log" "2-debloat-ubuntu-based.sh|tuxedo|--keep-snap" "--keep-snap vẫn chạy nhánh Tuxedo"

OUT="$TMP_TEST/back.out"
if run_parent '4\n1\nb\n4\ns\ns\nr\n' "$OUT"; then
    pass "Back quay lại và cho phép thay selection"
else
    fail "Back quay lại và cho phép thay selection"
fi
assert_contains "$TMP_TEST/execution.log" "4-items.sh|" "Basic item stage sau Back chạy core-only"
assert_not_contains "$TMP_TEST/execution.log" "4-items.sh|1" "selection cũ không bị thực thi sau khi đổi"

OUT="$TMP_TEST/required.out"
if run_parent '\n2\ns\ns\nr\n' "$OUT"; then
    pass "input rỗng được reprompt"
else
    fail "input rỗng được reprompt"
fi
assert_contains "$OUT" "Bắt buộc nhập lựa chọn" "menu báo lỗi khi Enter rỗng"

OUT="$TMP_TEST/kde-not-selected.out"
if run_parent '2\ns\nr\n' "$OUT"; then
    pass "bỏ chọn KDE vẫn tiếp tục chạy Basics khác"
else
    fail "bỏ chọn KDE vẫn tiếp tục chạy Basics khác"
fi
assert_contains "$OUT" "1. Switch KDE fixture" "review hiển thị KDE bị bỏ chọn"
assert_contains "$OUT" "Skipped: not selected" "review ghi lý do KDE không được chọn"
assert_contains "$TMP_TEST/execution.log" "2-debloat-ubuntu-based.sh|desnap|" "bỏ chọn KDE không chặn Debloat"

OUT="$TMP_TEST/kde-failure.out"
if (
    SETUP_TEST_KDE_FAIL_VALUE=1
    run_parent '' "$OUT" --all
); then
    fail "lỗi KDE trước marker phải dừng parent"
else
    pass "lỗi KDE trước marker dừng parent"
fi
assert_contains "$TMP_TEST/execution.log" "1-switch-kde.sh|" "KDE failing child đã được gọi"
assert_not_contains "$TMP_TEST/execution.log" "2-debloat-ubuntu-based.sh|" "parent không chạy Basic sau KDE lỗi"
assert_contains "$OUT" "failed=1" "KDE failure được ghi trong summary"

OUT="$TMP_TEST/preset-all.out"
if run_preset "$OUT" --all; then
    pass "--all áp selection và chạy không tương tác"
else
    fail "--all áp selection và chạy không tương tác"
fi
assert_not_contains "$OUT" "Review execution plan" "--all không hiện review"
assert_contains "$TMP_TEST/execution.log" "5-office.sh|--all" "--all chọn toàn bộ Office"
assert_contains "$TMP_TEST/execution.log" "4-expand-swapfile.sh|" "--all chọn Basic mở rộng swap"
assert_contains "$TMP_TEST/execution.log" "1-switch-kde.sh|" "--all chọn Basic chuyển KDE trước"
assert_contains "$TMP_TEST/execution.log" "3-basics.sh|--all" "--all chọn toàn bộ Basics"
assert_contains "$TMP_TEST/execution.log" "5-miscellaneous.sh|--all" "--all chọn cả Flameshot và WARP"
assert_contains "$TMP_TEST/execution.log" "6-basic-apps.sh|--all" "--all chọn toàn bộ Basic Apps"
assert_contains "$TMP_TEST/execution.log" "1-chat.sh|--all" "--all chọn toàn bộ Chat"
assert_contains "$TMP_TEST/execution.log" "2-dev.sh|" "--all enable Dev Tools core-only"
assert_not_contains "$TMP_TEST/execution.log" "2-dev.sh|--all" "--all không truyền argument cho extra core-only"
assert_contains "$TMP_TEST/execution.log" "4-ai.sh|--all" "--all chọn toàn bộ AI"
assert_contains "$TMP_TEST/execution.log" "3-ime-configs.sh|--all" "--all chọn toàn bộ IME configs"

OUT="$TMP_TEST/preset-all-keep-snap.out"
if run_preset "$OUT" --all --keep-snap; then
    pass "--keep-snap hoạt động cùng --all"
else
    fail "--keep-snap hoạt động cùng --all"
fi
assert_contains "$TMP_TEST/execution.log" "2-debloat-ubuntu-based.sh|keep-snap|--keep-snap" "--all chuyển --keep-snap vào Basic debloat"
assert_contains "$TMP_TEST/execution.log" "3-basics.sh|--all" "--all --keep-snap vẫn chọn Basics"

OUT="$TMP_TEST/preset-ms.out"
if run_preset "$OUT" --pack-ms; then
    pass "--pack-ms chạy không tương tác"
else
    fail "--pack-ms chạy không tương tác"
fi
assert_not_contains "$OUT" "Review execution plan" "--pack-ms không hiện review"
assert_contains "$TMP_TEST/execution.log" "5-office.sh|1" "--pack-ms chỉ chọn OnlyOffice"
assert_contains "$TMP_TEST/execution.log" "4-expand-swapfile.sh|" "--pack-ms chạy Basic mở rộng swap"
assert_contains "$TMP_TEST/execution.log" "3-basics.sh|--all" "--pack-ms chọn toàn bộ Basics"
assert_not_contains "$TMP_TEST/execution.log" "1-switch-kde.sh|" "--pack-ms không chạy Basic chuyển KDE"
assert_contains "$TMP_TEST/execution.log" "5-miscellaneous.sh|1" "--pack-ms chỉ chọn Flameshot"
assert_not_contains "$TMP_TEST/execution.log" "5-office.sh|--all" "--pack-ms không chọn Office khác"
assert_contains "$TMP_TEST/execution.log" "6-basic-apps.sh|--all" "--pack-ms chọn toàn bộ Basic Apps"
assert_contains "$TMP_TEST/execution.log" "1-chat.sh|--all" "--pack-ms chọn toàn bộ Chat"
assert_contains "$TMP_TEST/execution.log" "4-ai.sh|--all" "--pack-ms chọn toàn bộ AI"
assert_contains "$TMP_TEST/execution.log" "3-ime-configs.sh|--all" "--pack-ms chọn toàn bộ IME configs"

OUT="$TMP_TEST/preset-ms-keep-snap.out"
if run_preset "$OUT" --pack-ms --keep-snap; then
    pass "--keep-snap hoạt động cùng --pack-ms"
else
    fail "--keep-snap hoạt động cùng --pack-ms"
fi
assert_contains "$TMP_TEST/execution.log" "2-debloat-ubuntu-based.sh|keep-snap|--keep-snap" "--pack-ms chuyển --keep-snap vào Basic debloat"
assert_contains "$TMP_TEST/execution.log" "3-basics.sh|--all" "--pack-ms --keep-snap vẫn chọn Basics"

OUT="$TMP_TEST/preset-bs.out"
if run_preset "$OUT" --pack-bs; then
    pass "--pack-bs chạy không tương tác"
else
    fail "--pack-bs chạy không tương tác"
fi
assert_not_contains "$OUT" "Review execution plan" "--pack-bs không hiện review"
assert_contains "$TMP_TEST/execution.log" "4-expand-swapfile.sh|" "--pack-bs chạy Basic mở rộng swap"
assert_contains "$TMP_TEST/execution.log" "5-office.sh|1" "--pack-bs chọn OnlyOffice"
assert_contains "$TMP_TEST/execution.log" "6-basic-apps.sh|1" "--pack-bs chọn Chrome"
assert_contains "$TMP_TEST/execution.log" "3-basics.sh|--all" "--pack-bs chọn toàn bộ Basics"
assert_not_contains "$TMP_TEST/execution.log" "1-switch-kde.sh|" "--pack-bs không chạy Basic chuyển KDE"
assert_contains "$TMP_TEST/execution.log" "5-miscellaneous.sh|1" "--pack-bs chỉ chọn Flameshot"
assert_contains "$TMP_TEST/execution.log" "1-chat.sh|2" "--pack-bs chọn Mattermost"
assert_not_contains "$TMP_TEST/execution.log" "2-dev.sh|" "--pack-bs skip Dev Tools"
assert_not_contains "$TMP_TEST/execution.log" "3-ime-configs.sh|" "--pack-bs không chọn IME configs"
assert_contains "$TMP_TEST/execution.log" "4-ai.sh|1" "--pack-bs chọn Claude Desktop"

OUT="$TMP_TEST/preset-bs-keep-snap.out"
if run_preset "$OUT" --pack-bs --keep-snap; then
    pass "--keep-snap hoạt động cùng --pack-bs"
else
    fail "--keep-snap hoạt động cùng --pack-bs"
fi
assert_contains "$TMP_TEST/execution.log" "2-debloat-ubuntu-based.sh|keep-snap|--keep-snap" "--pack-bs chuyển --keep-snap vào Basic debloat"
assert_contains "$TMP_TEST/execution.log" "3-basics.sh|--all" "--pack-bs --keep-snap vẫn chọn Basics"

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
    sh "$BASICS_FILE" 2 > "$TMP_TEST/ime-core-failure.out" 2>&1; then
    fail "IME core failure phải trả non-zero"
else
    pass "IME core failure vẫn trả non-zero"
fi
assert_contains "$TMP_TEST/ime-core-failure.out" "(exit 99)" "Basics báo đúng exit code của item lỗi"
: > "$TMP_TEST/side-effects.log"

if PATH="$STUB_BIN:$PATH" SETUP_SIDE_EFFECT_LOG="$TMP_TEST/side-effects.log" \
    sh "$BASICS_FILE" > "$TMP_TEST/basics-empty.out" 2>&1 && \
   [ ! -s "$TMP_TEST/side-effects.log" ]; then
    pass "Basics no-argument không gọi apt/curl/gpg"
else
    fail "Basics no-argument không gọi apt/curl/gpg"
fi
: > "$TMP_TEST/side-effects.log"

if PATH="$STUB_BIN:$PATH" SETUP_SIDE_EFFECT_LOG="$TMP_TEST/side-effects.log" \
    sh "$MISC_FILE" > "$TMP_TEST/misc-empty.out" 2>&1 && \
   [ ! -s "$TMP_TEST/side-effects.log" ]; then
    pass "Miscellaneous no-argument không gọi apt/curl/gpg"
else
    fail "Miscellaneous no-argument không gọi apt/curl/gpg"
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
assert_contains "$TMP_TEST/claude-desktop.fn" "curl -fsSLo /usr/share/keyrings/claude-desktop-archive-keyring.asc" "Claude Desktop ghi keyring trực tiếp"
assert_contains "$TMP_TEST/claude-desktop.fn" "gpg --show-keys --with-colons /usr/share/keyrings/claude-desktop-archive-keyring.asc" "Claude Desktop xác minh keyring đích"
assert_not_contains "$TMP_TEST/claude-desktop.fn" "mktemp" "Claude Desktop không dùng keyring tạm"
assert_not_contains "$TMP_TEST/claude-desktop.fn" "mv -f" "Claude Desktop không move keyring tạm"
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

if (
    . "$ROOT/lib/setup-contract.sh"
    . "$TMP_TEST/ai-run-best-effort.fn"
    . "$TMP_TEST/ai-run-selected-best-effort.fn"
    warn() { printf 'warn:%s\n' "$*"; }
    install_claude_desktop() { printf 'called:claude-desktop\n'; _i=0; return 0; }
    install_claude_cli() { printf 'called:claude-cli\n'; return 0; }
    install_codex_cli() { printf 'called:codex-cli\n'; return 0; }
    CHILD_FILE="$AI_FILE"
    SETUP_SELECTED='1'
    run_selected_best_effort
) > "$TMP_TEST/ai-single-selection.out" 2>&1; then
    pass "AI selection 1 không bị biến _i trong installer làm lệch"
else
    fail "AI selection 1 không bị biến _i trong installer làm lệch"
fi
assert_contains "$TMP_TEST/ai-single-selection.out" "called:claude-desktop" "AI item 1 chạy Claude Desktop"
assert_not_contains "$TMP_TEST/ai-single-selection.out" "called:claude-cli" "AI item 1 không chạy Claude CLI"
assert_not_contains "$TMP_TEST/ai-single-selection.out" "called:codex-cli" "AI item 1 không chạy Codex CLI"

awk '/^install_slack\(\)/,/^}/' "$CHAT_FILE" > "$TMP_TEST/slack.fn"
awk '/^install_mattermost\(\)/,/^}/' "$CHAT_FILE" > "$TMP_TEST/mattermost.fn"
awk '/^install_discord\(\)/,/^}/' "$CHAT_FILE" > "$TMP_TEST/discord.fn"
awk '/^run_best_effort\(\)/,/^}/' "$CHAT_FILE" > "$TMP_TEST/chat-run-best-effort.fn"
awk '/^run_selected_best_effort\(\)/,/^}/' "$CHAT_FILE" > "$TMP_TEST/chat-run-selected-best-effort.fn"
assert_contains "$TMP_TEST/slack.fn" "ensure_gpg" "Slack tự bảo đảm gpg"
assert_contains "$TMP_TEST/slack.fn" "apt-get update" "Slack tự chạy apt update"
assert_contains "$TMP_TEST/slack.fn" "| gpg --yes --dearmor -o /etc/apt/keyrings/slack.gpg" "Slack dearmor key trực tiếp"
assert_not_contains "$TMP_TEST/slack.fn" "mktemp" "Slack không dùng keyring tạm"
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

if (
    . "$ROOT/lib/setup-contract.sh"
    . "$TMP_TEST/chat-run-best-effort.fn"
    . "$TMP_TEST/chat-run-selected-best-effort.fn"
    warn() { printf 'warn:%s\n' "$*"; }
    install_slack() { printf 'called:slack\n'; _i=0; return 0; }
    install_mattermost() { printf 'called:mattermost\n'; return 0; }
    install_discord() { printf 'called:discord\n'; return 0; }
    CHILD_FILE="$CHAT_FILE"
    SETUP_SELECTED='1'
    run_selected_best_effort
) > "$TMP_TEST/chat-single-selection.out" 2>&1; then
    pass "Chat selection 1 không bị biến _i trong installer làm lệch"
else
    fail "Chat selection 1 không bị biến _i trong installer làm lệch"
fi
assert_contains "$TMP_TEST/chat-single-selection.out" "called:slack" "Chat item 1 chạy Slack"
assert_not_contains "$TMP_TEST/chat-single-selection.out" "called:mattermost" "Chat item 1 không chạy Mattermost"
assert_not_contains "$TMP_TEST/chat-single-selection.out" "called:discord" "Chat item 1 không chạy Discord"

printf '\nTests: pass=%s fail=%s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
