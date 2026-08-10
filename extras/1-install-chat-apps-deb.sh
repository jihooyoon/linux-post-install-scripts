#!/bin/sh
# @setup-description: Cài chat apps (Mattermost, Slack, Discord,...)
# @setup-when: always
# @setup-item: install_slack|Slack
# @setup-item: install_mattermost|Mattermost Desktop
# @setup-item: install_discord|Discord
# 1-install-chat-apps-deb.sh — Ubuntu/Debian: cài Slack, Mattermost, Discord bản .deb
# Chạy: sudo ./1-install-chat-apps-deb.sh [--all|-a|item-number ...]

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
        wait_apt || return $?
        apt-get install -y curl || return $?
    fi
}

ensure_gpg() {
    if ! command -v gpg >/dev/null 2>&1; then
        wait_apt || return $?
        apt-get install -y gpg || return $?
    fi
}

run_best_effort() {
    _label=$1
    _function=$2
    if "$_function"; then
        return 0
    else
        _code=$?
    fi
    warn "$_label thất bại (exit $_code) — tiếp tục"
    return 0
}

# ============================================================
# Các hàm cài đặt (mỗi hàm = 1 mục trong menu)
# ============================================================

# --- Mục 1: Slack ---
install_slack() {
    ensure_curl || return $?
    ensure_gpg || return $?
    info "Cài Slack..."
    SLACK_REPO_PATTERN='https?://packagecloud\.io/slacktechnologies/slack/debian/?([[:space:]]|$)'
    SLACK_REPO_FILES=$(grep -rslE "$SLACK_REPO_PATTERN" /etc/apt/sources.list.d/ /etc/apt/sources.list 2>/dev/null || true)
    if [ -n "$SLACK_REPO_FILES" ]; then
        warn "Đã có source Slack; giữ nguyên và không thêm source mới: $(printf '%s' "$SLACK_REPO_FILES" | tr '\n' ' ')"
    else
        mkdir -p /etc/apt/keyrings || return $?
        SLACK_KEY=$(mktemp /tmp/slack-key.XXXXXX.asc) || return 1
        if ! curl -fsSL https://packagecloud.io/slacktechnologies/slack/gpgkey -o "$SLACK_KEY"; then
            rm -f "$SLACK_KEY"
            return 1
        fi
        if ! gpg --yes --dearmor -o /etc/apt/keyrings/slack.gpg "$SLACK_KEY"; then
            rm -f "$SLACK_KEY"
            return 1
        fi
        rm -f "$SLACK_KEY"
        if ! printf '%s\n' \
            "deb [arch=amd64 signed-by=/etc/apt/keyrings/slack.gpg] https://packagecloud.io/slacktechnologies/slack/debian/ jessie main" \
            > /etc/apt/sources.list.d/slack.list; then
            return 1
        fi
    fi
    wait_apt || return $?
    apt-get update || return $?
    apt-get install -y slack-desktop || return $?
    ok "Đã cài Slack"
}

# --- Mục 2: Mattermost Desktop ---
install_mattermost() {
    ensure_curl || return $?
    info "Cài Mattermost Desktop..."
    MM_URL=$(curl -s https://api.github.com/repos/mattermost/desktop/releases/latest \
        | grep -oP '"browser_download_url":\s*"\K[^"]*amd64\.deb[^"]*' | head -1)
    if [ -z "$MM_URL" ]; then
        warn "Không lấy được URL tải Mattermost — bỏ qua"
        return 1
    else
        MM_DEB=$(mktemp /tmp/mattermost-desktop.XXXXXX.deb) || return 1
        if ! curl -fsSL -o "$MM_DEB" "$MM_URL"; then
            rm -f "$MM_DEB"
            return 1
        fi
        wait_apt || { rm -f "$MM_DEB"; return 1; }
        if ! apt-get install -y "$MM_DEB"; then
            rm -f "$MM_DEB"
            return 1
        fi
        rm -f "$MM_DEB"
        ok "Đã cài Mattermost Desktop"
    fi
}

# --- Mục 3: Discord ---
install_discord() {
    ensure_curl || return $?
    info "Cài Discord..."
    DISCORD_DEB=$(mktemp /tmp/discord.XXXXXX.deb) || return 1
    if ! curl -fsSL -o "$DISCORD_DEB" 'https://discord.com/api/download/stable?platform=linux&format=deb'; then
        rm -f "$DISCORD_DEB"
        return 1
    fi
    wait_apt || { rm -f "$DISCORD_DEB"; return 1; }
    if ! apt-get install -y "$DISCORD_DEB"; then
        rm -f "$DISCORD_DEB"
        return 1
    fi
    rm -f "$DISCORD_DEB"
    ok "Đã cài Discord"
}

run_selected_best_effort() {
    _items=$(setup_items "$CHILD_FILE")
    _i=1
    while IFS='|' read -r _function _label; do
        [ -n "$_function" ] || continue
        if setup_has_word "$SETUP_SELECTED" "$_i"; then
            printf '\n\033[1;36m[item]\033[0m %d) %s\n' "$_i" "$_label"
            run_best_effort "$_label" "$_function"
        fi
        _i=$((_i + 1))
    done <<EOF
$_items
EOF
}

if [ -z "$SETUP_SELECTED" ]; then
    warn "Không chọn chat app nào — không cài dependency và không cập nhật apt"
    exit 0
fi

run_selected_best_effort

printf '\n\033[1;32mHoàn tất các chat app đã chọn!\033[0m\n'
