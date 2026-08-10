#!/bin/sh
# @setup-description: Cài các ứng dụng chat bản deb
# @setup-when: always
# @setup-item: install_slack|Slack (repo chính thức packagecloud)
# @setup-item: install_mattermost|Mattermost Desktop (.deb từ GitHub releases)
# @setup-item: install_discord|Discord (.deb từ discord.com)
# 3-install-chat-apps-deb.sh — Ubuntu/Debian: cài Slack, Mattermost, Discord bản .deb
# Chạy: sudo ./3-install-chat-apps-deb.sh [--all|-a|item-number ...]

set -e

# Debug mode: chạy với DEBUG=1 ./script.sh để thấy tất cả lệnh đang chạy
[ "${DEBUG:-0}" = "1" ] && set -x

info() { printf '\033[1;34m[chat]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m      %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m    %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m   %s\n' "$*" >&2; exit 1; }

CHILD_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CHILD_FILE="$CHILD_DIR/$(basename -- "$0")"
. "$CHILD_DIR/../lib/setup-contract.sh"
setup_child_prepare "$CHILD_FILE" "$@" || exit $?
if [ "$SETUP_SHOW_HELP" -eq 1 ]; then
    setup_print_help "$CHILD_FILE"
    exit 0
fi

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

# --- Kiểm tra quyền root ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

ensure_curl() {
    if ! command -v curl >/dev/null 2>&1; then
        wait_apt
        apt-get install -y curl
    fi
}

ensure_gpg() {
    if ! command -v gpg >/dev/null 2>&1; then
        wait_apt
        apt-get install -y gpg
    fi
}

# ============================================================
# Các hàm cài đặt (mỗi hàm = 1 mục trong menu)
# ============================================================

# --- Mục 1: Slack ---
install_slack() {
    ensure_curl
    ensure_gpg
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
    wait_apt
    apt-get update
    apt-get install -y slack-desktop
    ok "Đã cài Slack"
}

# --- Mục 2: Mattermost Desktop ---
install_mattermost() {
    ensure_curl
    info "Cài Mattermost Desktop..."
    MM_URL=$(curl -s https://api.github.com/repos/mattermost/desktop/releases/latest \
        | grep -oP '"browser_download_url":\s*"\K[^"]*amd64\.deb[^"]*' | head -1)
    if [ -z "$MM_URL" ]; then
        warn "Không lấy được URL tải Mattermost — bỏ qua"
    else
        MM_DEB=/tmp/mattermost-desktop.deb
        curl -fsSL -o "$MM_DEB" "$MM_URL"
        wait_apt
        apt-get install -y "$MM_DEB"
        rm -f "$MM_DEB"
        ok "Đã cài Mattermost Desktop"
    fi
}

# --- Mục 3: Discord ---
install_discord() {
    ensure_curl
    info "Cài Discord..."
    DISCORD_DEB=/tmp/discord.deb
    curl -fsSL -o "$DISCORD_DEB" 'https://discord.com/api/download/stable?platform=linux&format=deb'
    wait_apt
    apt-get install -y "$DISCORD_DEB"
    rm -f "$DISCORD_DEB"
    ok "Đã cài Discord"
}

if [ -z "$SETUP_SELECTED" ]; then
    warn "Không chọn chat app nào — không cài dependency và không cập nhật apt"
    exit 0
fi

setup_run_selected "$CHILD_FILE" "$SETUP_SELECTED"

printf '\n\033[1;32mHoàn tất các chat app đã chọn!\033[0m\n'
