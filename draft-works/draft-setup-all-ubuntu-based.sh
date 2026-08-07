#!/bin/sh
# setup-all-ubuntu-based.sh — BẢN DRAFT: chỉ in lựa chọn, không cài đặt thật.
# Script thật: sudo ./setup-all-ubuntu-based.sh
# Cài toàn bộ: chuỗi cơ bản + chọn extras qua menu

set -e

info() { printf '\033[1;36m[setup]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m     %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m   %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m  %s\n' "$*" >&2; exit 1; }

# --- Trợ giúp (không cần root) ---
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--all|-a] [--silent] [--help|-h]  (draft — không cần sudo)"
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

# Bản draft: không kiểm tra root (script thật yêu cầu sudo).

# Thư mục chứa script con (không phụ thuộc nơi gọi)
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

run_step() {
    name=$1
    file=$2
    extra_args=${3:-}
    info "=== Bắt đầu: $name ($file) ==="
    # Gán stdin của con từ /dev/tty: nếu chuỗi bị chạy qua pipe (vd: curl | sudo bash),
    # stdin của con là EOF → menu sẽ không nhận được input.
    "$SCRIPT_DIR/$file" $extra_args </dev/tty || die "$file thất bại — dừng chuỗi"
    ok "Hoàn tất: $name"
}

# ============================================================
# Các hàm extras (mỗi hàm = 1 mục trong menu)
# ============================================================

extra_ai_tools() {
    ok "DRAFT: Selected AI Tools (Claude Desktop + Claude Code CLI + Codex CLI) → extra_ai_tools()"
    run_step "AI Tools (Claude Desktop + Claude Code CLI + Codex CLI)" extras/draft-install-ai-tools-deb.sh ${SILENT:+--all}
}

extra_ime_shortcut() {
    ok "DRAFT: Selected Phím tắt chuyển input method → extra_ime_shortcut()"
    run_step "Phím tắt chuyển input method" extras/draft-set-ime-shortcut.sh ${SILENT:+--all}
}

extra_chat_apps() {
    ok "DRAFT: Selected Chat Apps (Slack, Mattermost, Discord) → extra_chat_apps()"
    run_step "Chat Apps (Slack, Mattermost, Discord)" extras/draft-install-chat-apps-deb.sh ${SILENT:+--all}
}

extra_dev_tools() {
    ok "DRAFT: Selected Dev Tools (Node.js LTS) → extra_dev_tools()"
    run_step "Dev Tools (Node.js LTS)" extras/draft-install-basic-dev-works.sh ${SILENT:+--all}
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
    printf '\033[1;36m  [DRAFT] Chọn extras muốn cài đặt\033[0m\n'
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

run_step "Chuỗi cài đặt cơ bản (del-snap, flatpak, apps, lotus)" draft-setup-basic-ubuntu-based.sh ${SILENT:+--silent}

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
        printf '\n\033[1;33m[DRAFT] Đã thoát. Chỉ chạy chuỗi cơ bản, bỏ qua extras.\033[0m\n'
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

printf '\n\033[1;32m[DRAFT] Hoàn tất toàn bộ!\033[0m (không có gì thực sự được cài đặt)\n'
