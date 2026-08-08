#!/bin/sh
# install-chat-apps-deb.sh — Ubuntu/Debian: cài Slack, Mattermost, Discord bản .deb
# Chạy: sudo ./install-chat-apps-deb.sh            (hiện menu chọn app)
#       sudo ./install-chat-apps-deb.sh --all | -a (cài tất cả, không hỏi)
#       sudo ./install-chat-apps-deb.sh --help | -h (trợ giúp)

set -e

# Debug mode: chạy với DEBUG=1 ./script.sh để thấy tất cả lệnh đang chạy
[ "${DEBUG:-0}" = "1" ] && set -x

info() { printf '\033[1;34m[chat]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m      %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m    %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m   %s\n' "$*" >&2; exit 1; }

wait_apt() {
    _i=0
    while [ "$_i" -lt 60 ]; do
        if ! fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/lib/dpkg/lock >/dev/null 2>&1; then
            return 0
        fi
        if [ "$_i" -eq 0 ]; then
            info "apt/dpkg đang bị lock — đợi giải phóng (tối đa 60s)..."
        fi
        sleep 1
        _i=$((_i + 1))
    done
    warn "apt/dpkg vẫn bị lock sau 60s — thử kill process giữ lock..."
    fuser -k /var/lib/dpkg/lock-frontend 2>/dev/null || true
    fuser -k /var/lib/apt/lists/lock 2>/dev/null || true
    fuser -k /var/lib/dpkg/lock 2>/dev/null || true
    sleep 2
}

# --- Trợ giúp (không cần root) ---
case "${1:-}" in
    --help|-h)
        echo "Usage: sudo $0 [--all|-a] [--help|-h]"
        echo ""
        echo "  (không đối số)  Hiện menu tương tác để chọn app cài đặt"
        echo "  --all, -a       Cài tất cả, không hiện menu"
        echo "  --help, -h      In trợ giúp này"
        echo ""
        echo "  Các app có thể chọn trong menu:"
        echo "    1) Slack (repo chính thức packagecloud)"
        echo "    2) Mattermost Desktop (.deb từ GitHub releases)"
        echo "    3) Discord (.deb từ discord.com)"
        exit 0
        ;;
esac

# --- Kiểm tra quyền root ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

# ============================================================
# Các hàm cài đặt (mỗi hàm = 1 mục trong menu)
# ============================================================

# --- Mục 1: Slack ---
install_slack() {
    info "Cài Slack..."
    SLACK_REPO_PATTERN='https?://packagecloud\.io/slacktechnologies/slack/debian/?([[:space:]]|$)'
    SLACK_REPO_FILES=$(grep -rslE "$SLACK_REPO_PATTERN" /etc/apt/sources.list.d/ /etc/apt/sources.list 2>/dev/null || true)
    if [ -n "$SLACK_REPO_FILES" ]; then
        warn "Đã có source Slack; giữ nguyên và không thêm source mới: $(printf '%s' "$SLACK_REPO_FILES" | tr '\n' ' ')"
    else
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://packagecloud.io/slacktechnologies/slack/gpgkey \
            | gpg --yes --dearmor -o /etc/apt/keyrings/slack.gpg
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/slack.gpg] https://packagecloud.io/slacktechnologies/slack/debian/ jessie main" \
            > /etc/apt/sources.list.d/slack.list
    fi
    apt-get update
    apt-get install -y slack-desktop
    ok "Đã cài Slack"
}

# --- Mục 2: Mattermost Desktop ---
install_mattermost() {
    info "Cài Mattermost Desktop..."
    MM_URL=$(curl -s https://api.github.com/repos/mattermost/desktop/releases/latest \
        | grep -oP '"browser_download_url":\s*"\K[^"]*amd64\.deb[^"]*' | head -1)
    if [ -z "$MM_URL" ]; then
        warn "Không lấy được URL tải Mattermost — bỏ qua"
    else
        MM_DEB=/tmp/mattermost-desktop.deb
        curl -fsSL -o "$MM_DEB" "$MM_URL"
        apt-get install -y "$MM_DEB"
        rm -f "$MM_DEB"
        ok "Đã cài Mattermost Desktop"
    fi
}

# --- Mục 3: Discord ---
install_discord() {
    info "Cài Discord..."
    DISCORD_DEB=/tmp/discord.deb
    curl -fsSL -o "$DISCORD_DEB" 'https://discord.com/api/download/stable?platform=linux&format=deb'
    apt-get install -y "$DISCORD_DEB"
    rm -f "$DISCORD_DEB"
    ok "Đã cài Discord"
}

# ============================================================
# Menu & chọn app
# ============================================================

# Định nghĩa các mục có thể chọn (label|hàm)
MENU_ITEMS="
Slack (repo chính thức packagecloud)|install_slack
Mattermost Desktop (.deb từ GitHub releases)|install_mattermost
Discord (.deb từ discord.com)|install_discord
"

show_menu() {
    printf '\n'
    printf '\033[1;36m══════════════════════════════════════════\033[0m\n'
    printf '\033[1;36m  Chọn chat app muốn cài đặt\033[0m\n'
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
    printf 'Nhập số (vd: 1 3) hoặc Enter để cài tất cả: '
}

parse_menu_choice() {
    _input="$1"

    if [ -z "$_input" ] || [ "$_input" = "a" ]; then
        echo "1 2 3"
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
# Luôn chạy (không cần chọn)
# ============================================================

info "Cập nhật danh sách gói..."
wait_apt
apt-get update

command -v curl >/dev/null 2>&1 || apt-get install -y curl
command -v gpg  >/dev/null 2>&1 || apt-get install -y gpg

# ============================================================
# Chọn app để cài
# ============================================================

if [ "$ALL" -eq 1 ]; then
    SELECTED="1 2 3"
    info "Chế độ --all: cài tất cả"
else
    show_menu
    read -r USER_CHOICE </dev/tty

    SELECTED=$(parse_menu_choice "$USER_CHOICE")

    if [ "$SELECTED" = "quit" ]; then
        printf '\n\033[1;33mĐã thoát. Các bước đã chạy: cập nhật gói + curl + gpg.\033[0m\n'
        exit 0
    fi
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

printf '\n\033[1;32mHoàn tất!\033[0m Tóm tắt:\n'
for num in $SELECTED; do
    i=1
    while IFS='|' read -r label func; do
        [ -z "$label" ] && continue
        case "$i-$num" in
            1-1) printf '  - Slack: repo chính thức (packagecloud)\n' ;;
            2-2) printf '  - Mattermost Desktop: .deb từ GitHub releases\n' ;;
            3-3) printf '  - Discord: .deb từ discord.com\n' ;;
        esac
        i=$((i + 1))
    done <<EOF
$MENU_ITEMS
EOF
done
