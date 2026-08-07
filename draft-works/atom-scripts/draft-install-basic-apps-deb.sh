#!/bin/sh
# install-basic-apps-deb.sh — BẢN DRAFT: chỉ in lựa chọn, không cài đặt thật.
# Script thật: sudo ./atom-scripts/install-basic-apps-deb.sh
# Gỡ sạch LibreOffice, cài fcitx5 (purge ibus, autostart) + FreeOffice

set -e

info() { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m      %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m    %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m   %s\n' "$*" >&2; exit 1; }

# --- Trợ giúp (không cần root) ---
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--all|-a] [--help|-h]  (draft — không cần sudo)"
        echo ""
        echo "  (không đối số)  Hiện menu tương tác để chọn app"
        echo "  --all, -a       Chọn tất cả, không hiện menu"
        echo "  --help, -h      In trợ giúp này"
        echo ""
        echo "  Các app có thể chọn trong menu:"
        echo "    1) LibreOffice → FreeOffice (gỡ LO, cài FreeOffice)"
        echo "    2) Google Chrome"
        echo "    3) Chromium (.deb thật)"
        echo "    4) Visual Studio Code"
        exit 0
        ;;
esac

# Bản draft: không kiểm tra root (script thật yêu cầu sudo).

# ============================================================
# Các hàm (stub — chỉ in lựa chọn)
# ============================================================

install_freeoffice() {
    ok "DRAFT: Selected LibreOffice → FreeOffice (gỡ LO, cài FreeOffice) → install_freeoffice()"
}

install_chrome() {
    ok "DRAFT: Selected Google Chrome → install_chrome()"
}

install_chromium() {
    ok "DRAFT: Selected Chromium (.deb thật) → install_chromium()"
}

install_vscode() {
    ok "DRAFT: Selected Visual Studio Code → install_vscode()"
}

# ============================================================
# Menu & chọn app
# ============================================================

# Định nghĩa các mục có thể chọn (label|hàm)
MENU_ITEMS="
LibreOffice → FreeOffice (gỡ LO, cài FreeOffice)|install_freeoffice
Google Chrome|install_chrome
Chromium (.deb thật)|install_chromium
Visual Studio Code|install_vscode
"

show_menu() {
    printf '\n'
    printf '\033[1;36m══════════════════════════════════════════\033[0m\n'
    printf '\033[1;36m  [DRAFT] Chọn app muốn cài đặt\033[0m\n'
    printf '\033[1;36m══════════════════════════════════════════\033[0m\n'
    i=1
    while IFS='|' read -r label func; do
        [ -z "$label" ] && continue
        printf '  \033[1;33m%d)\033[0m %s\n' "$i" "$label"
        i=$((i + 1))
    done <<EOF
$MENU_ITEMS
EOF
    printf '  \033[1;33ma)\033[0m Cài tất cả (mặc định)\n'
    printf '  \033[1;33mq)\033[0m Thoát (không cài gì thêm)\n'
    printf '\033[1;36m══════════════════════════════════════════\033[0m\n'
    printf 'Nhập số (vd: 1 3 4) hoặc Enter để cài tất cả: '
}

parse_menu_choice() {
    _input="$1"

    if [ -z "$_input" ] || [ "$_input" = "a" ]; then
        echo "1 2 3 4"
        return
    fi

    if [ "$_input" = "q" ]; then
        echo "quit"
        return
    fi

    echo "$_input"
}

# ============================================================
# Argument parsing
# ============================================================

ALL=0

case "${1:-}" in
    --all|-a) ALL=1 ;;
    "")       ;;  # Mặc định: hiện menu
    *)        die "Không rõ tuỳ chọn: $1. Dùng --help để xem hướng dẫn." ;;
esac

# ============================================================
# Luôn chạy (stub — script thật cài fcitx5 + purge ibus)
# ============================================================

info "Bước 1: Cài fcitx5 + purge ibus + autostart... (stub — script thật làm thật)"
info "Bước 2: Cập nhật danh sách gói... (stub)"

# ============================================================
# Chọn app để cài
# ============================================================

if [ "$ALL" -eq 1 ]; then
    SELECTED="1 2 3 4"
    info "Chế độ --all: chọn tất cả"
else
    show_menu
    # Debug: kiểm tra tty trước khi đọc
    if [ -t 0 ]; then
        info "TTY CHECK: stdin là terminal ($(tty 2>/dev/null))"
    else
        warn "TTY CHECK: stdin KHÔNG phải terminal (bị pipe/redirect)"
    fi
    if : </dev/tty 2>/dev/null; then
        info "TTY CHECK: /dev/tty mở được (reachable)"
    else
        warn "TTY CHECK: /dev/tty KHÔNG mở được (không có controlling terminal)"
    fi
    info "TRƯỚC READ: chờ nhập lựa chọn (từ /dev/tty)..."
    read -r USER_CHOICE </dev/tty
    info "SAU READ: nhận được: '$USER_CHOICE'"

    SELECTED=$(parse_menu_choice "$USER_CHOICE")

    if [ "$SELECTED" = "quit" ]; then
        printf '\n\033[1;33m[DRAFT] Đã thoát. Các bước đã chạy: fcitx5 + purge ibus (stub).\033[0m\n'
        exit 0
    fi
    info "Đã nhận input: '$USER_CHOICE' → chọn mục: $SELECTED"
fi

# Chạy các mục đã chọn
for num in $SELECTED; do
    i=1
    while IFS='|' read -r label func; do
        [ -z "$label" ] && continue
        if [ "$i" -eq "$num" ]; then
            printf '\n'
            info "PROCESSING mục $num ($label) — hàm: $func"
            $func
            break
        fi
        i=$((i + 1))
    done <<EOF
$MENU_ITEMS
EOF
done

printf '\n\033[1;32m[DRAFT] Hoàn tất!\033[0m Tóm tắt các mục đã chọn:\n'
for num in $SELECTED; do
    i=1
    while IFS='|' read -r label func; do
        [ -z "$label" ] && continue
        if [ "$i" -eq "$num" ]; then
            printf '  - %s (stub)\n' "$label"
            break
        fi
        i=$((i + 1))
    done <<EOF
$MENU_ITEMS
EOF
done
