#!/bin/sh
# setup-all-ubuntu-based — Cài toàn bộ: chuỗi cơ bản + chọn extras qua menu
#  1. setup-basic-ubuntu-based.sh              — del-snap, flatpak, basic apps, lotus (luôn chạy)
#  2. extras/install-ai-tools-deb.sh           — Claude Desktop + Claude Code CLI + Codex CLI
#  3. extras/set-ime-shortcut.sh             — Phím tắt chuyển input method (GNOME: Alt+Space / KDE: Super+Space)
#  4. extras/install-chat-apps-deb.sh         — Slack, Mattermost, Discord
#  5. extras/install-basic-dev-works.sh        — Node.js LTS (NodeSource)
# Chạy: sudo ./setup-all-ubuntu-based               (hiện menu chọn extras)
#       sudo ./setup-all-ubuntu-based --all | -a    (cài tất cả, không hỏi)
#       sudo ./setup-all-ubuntu-based --silent       (không tương tác, truyền --all/-a xuống script con)
#       sudo ./setup-all-ubuntu-based --help | -h    (trợ giúp)

set -e

info() { printf '\033[1;36m[setup]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m     %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m   %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m  %s\n' "$*" >&2; exit 1; }

# --- Trợ giúp (không cần root) ---
case "${1:-}" in
    --help|-h)
        echo "Usage: sudo $0 [--all|-a] [--silent] [--help|-h]"
        echo ""
        echo "  (không đối số)  Chạy chuỗi cơ bản, sau đó hiện menu chọn extras"
        echo "  --all, -a       Chạy tất cả (cơ bản + extras), không hiện menu"
		echo "  --silent        Như --all, đồng thời truyền --all xuống các script con"
        echo "  --help, -h      In trợ giúp này"
        echo ""
        echo "  Các extras có thể chọn trong menu:"
        echo "    1) AI Tools (Claude Desktop + Claude Code CLI + Codex CLI)"
        echo "    2) Phím tắt chuyển input method (GNOME/KDE)"
        echo "    3) Chat Apps (Slack, Mattermost, Discord)"
        echo "    4) Dev Tools (Node.js LTS)"
        exit 0
        ;;
esac

# --- Kiểm tra quyền root và user thật ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"
[ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ] \
    || die "Phải chạy bằng sudo (su sẽ mất SUDO_USER): sudo $0"

# Thư mục chứa script con (không phụ thuộc nơi gọi)
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

run_step() {
    name=$1
    file=$2
    extra_args=${3:-}
    info "=== Bắt đầu: $name ($file) ==="
    "$SCRIPT_DIR/$file" $extra_args || die "$file thất bại — dừng chuỗi"
    ok "Hoàn tất: $name"
}

# ============================================================
# Các hàm extras (mỗi hàm = 1 mục trong menu)
# ============================================================

extra_ai_tools() {
    run_step "AI Tools (Claude Desktop + Claude Code CLI + Codex CLI)" extras/install-ai-tools-deb.sh ${SILENT:+--all}
}

extra_ime_shortcut() {
    run_step "Phím tắt chuyển input method" extras/set-ime-shortcut.sh ${SILENT:+--all}
}

extra_chat_apps() {
    run_step "Chat Apps (Slack, Mattermost, Discord)" extras/install-chat-apps-deb.sh ${SILENT:+--all}
}

extra_dev_tools() {
    run_step "Dev Tools (Node.js LTS)" extras/install-basic-dev-works.sh ${SILENT:+--all}
}

# ============================================================
# Menu & chọn extras
# ============================================================

MENU_ITEMS="
AI Tools (Claude Desktop + Claude Code CLI + Codex CLI)|extra_ai_tools
Phím tắt chuyển input method (GNOME: Alt+Space / KDE: Super+Space)|extra_ime_shortcut
Chat Apps (Slack, Mattermost, Discord)|extra_chat_apps
Dev Tools (Node.js LTS)|extra_dev_tools
"

show_menu() {
    printf '\n'
    printf '\033[1;36m══════════════════════════════════════════\033[0m\n'
    printf '\033[1;36m  Chọn extras muốn cài đặt\033[0m\n'
    printf '\033[1;36m══════════════════════════════════════════\033[0m\n'
    i=1
    while IFS='|' read -r label func; do
        [ -z "$label" ] && continue
        printf '  \033[1;33m%d)\033[0m %s\n' "$i" "$label"
        i=$((i + 1))
    done <<EOF
$MENU_ITEMS
EOF
    printf '  \033[1;33ma)\033[0m Cài tất cả extras (mặc định)\n'
    printf '  \033[1;33mq)\033[0m Thoát (chỉ chạy chuỗi cơ bản)\n'
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
SILENT=""

case "${1:-}" in
    --all|-a) ALL=1 ;;
    --silent) ALL=1; SILENT="--all" ;;
    "")       ;;  # Mặc định: hiện menu
    *)        die "Không rõ tuỳ chọn: $1. Dùng --help để xem hướng dẫn." ;;
esac

# ============================================================
# Luôn chạy: chuỗi cơ bản
# ============================================================

run_step "Chuỗi cài đặt cơ bản (del-snap, flatpak, apps, lotus)" setup-basic-ubuntu-based.sh ${SILENT:+--silent}

# ============================================================
# Chọn extras để cài
# ============================================================

if [ "$ALL" -eq 1 ]; then
    SELECTED="1 2 3 4"
    if [ -n "$SILENT" ]; then
        info "Chế độ --silent: cài tất cả, truyền --all xuống script con"
    else
        info "Chế độ --all: cài tất cả extras"
    fi
else
    show_menu
    info "TRƯỚC READ: chờ nhập lựa chọn..."
    read -r USER_CHOICE
    info "SAU READ: nhận được: '$USER_CHOICE'"

    SELECTED=$(parse_menu_choice "$USER_CHOICE")

    if [ "$SELECTED" = "quit" ]; then
        printf '\n\033[1;33mĐã thoát. Chỉ chạy chuỗi cơ bản, bỏ qua extras.\033[0m\n'
        exit 0
    fi
    info "Đã nhận input: '$USER_CHOICE' → chọn mục: $SELECTED"
fi

# Chạy các extras đã chọn
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

printf '\n\033[1;32mHoàn tất toàn bộ!\033[0m Khởi động lại máy để áp dụng mọi thứ.\n'
printf 'Sau khi khởi động lại:\n'
printf '  - Chạy \033[1mclaude\033[0m để đăng nhập Claude Code lần đầu\n'
printf '  - Bật bộ gõ Lotus trong fcitx5-config nếu chưa có\n'
case "$XDG_CURRENT_DESKTOP" in
    *GNOME*)
        printf '  - Mở \033[1mExtension Manager\033[0m để cài 2 extension GNOME:\n'
        printf '      + KIMPanel: extensions.gnome.org/extension/261/kimpanel\n'
        printf '      + Copyous:  extensions.gnome.org/extension/8834/copyous\n'
        ;;
esac
