#!/bin/sh
# install-chat-apps.sh — Ubuntu/Debian: cài Slack, Mattermost, Discord bản .deb
# Chạy: sudo ./install-chat-apps.sh

set -e

info() { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m      %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m    %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m   %s\n' "$*" >&2; exit 1; }

# --- Kiểm tra quyền root ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

# --- Cập nhật danh sách gói ---
info "Cập nhật danh sách gói..."
apt-get update

# --- Cài các phụ thuộc chung ---
command -v curl >/dev/null 2>&1 || apt-get install -y curl
command -v gpg  >/dev/null 2>&1 || apt-get install -y gpg

# ======================================================================
# Slack — repo chính thức (packagecloud)
# ======================================================================
info "Cài Slack..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://packagecloud.io/slacktechnologies/slack/gpgkey \
    | gpg --dearmor -o /etc/apt/keyrings/slack.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/slack.gpg] https://packagecloud.io/slacktechnologies/slack/debian/ jessie main" \
    > /etc/apt/sources.list.d/slack.list
apt-get update
apt-get install -y slack-desktop
ok "Đã cài Slack"

# ======================================================================
# Mattermost — tải .deb trực tiếp từ GitHub releases
# ======================================================================
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

# ======================================================================
# Discord — tải .deb trực tiếp từ discord.com
# ======================================================================
info "Cài Discord..."
DISCORD_DEB=/tmp/discord.deb
curl -fsSL -o "$DISCORD_DEB" 'https://discord.com/api/download/stable?platform=linux&format=deb'
apt-get install -y "$DISCORD_DEB"
rm -f "$DISCORD_DEB"
ok "Đã cài Discord"

printf '\n\033[1;32mHoàn tất!\033[0m Tóm tắt:\n'
printf '  - Slack: repo chính thức (packagecloud)\n'
printf '  - Mattermost Desktop: .deb từ GitHub releases\n'
printf '  - Discord: .deb từ discord.com\n'
