#!/bin/sh
# install-claude-deb.sh — Cài Claude Desktop (apt repo chính thức) + Claude Code CLI
# Theo: https://code.claude.com/docs/en/desktop-linux và /docs/en/quickstart
# Yêu cầu: Ubuntu 22.04+ / Debian 12+, kiến trúc amd64 hoặc arm64
# Chạy: sudo ./install-claude-deb.sh

set -e

info() { printf '\033[1;34m[claude]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m     %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m   %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m  %s\n' "$*" >&2; exit 1; }

# --- Kiểm tra quyền root ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

# --- Bước 1: Chuẩn bị curl + gpg (Desktop và CLI đều cần) ---
info "Bước 1: Chuẩn bị curl và gpg..."
command -v curl >/dev/null 2>&1 || apt-get install -y curl
command -v gpg  >/dev/null 2>&1 || apt-get install -y gnupg

# --- Bước 2: Thêm apt repo của Claude Desktop ---
info "Bước 2: Thêm apt repository của Claude Desktop..."
curl -fsSLo /usr/share/keyrings/claude-desktop-archive-keyring.asc \
    https://downloads.claude.ai/claude-desktop/key.asc

# Xác minh vân tay khóa theo guide (tránh khóa giả mạo)
FPR=$(gpg --show-keys --with-colons /usr/share/keyrings/claude-desktop-archive-keyring.asc 2>/dev/null \
      | awk -F: '$1=="fpr"{print $10; exit}')
[ "$FPR" = "31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE" ] \
    || die "Khóa tải về không khớp vân tay Anthropic (nhận: $FPR) — kiểm tra kết nối downloads.claude.ai"
ok "Đã xác minh khóa Anthropic"

echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main" \
    > /etc/apt/sources.list.d/claude-desktop.list

# --- Bước 3: Cài Claude Desktop ---
info "Bước 3: Cài Claude Desktop..."
apt-get update
apt-get install -y claude-desktop
ok "Đã cài claude-desktop (cập nhật qua apt như bình thường)"

# --- Bước 4: Cài Claude Code CLI (native installer, cài vào home của user) ---
# Native installer cài vào ~/.local nên phải chạy với user thật, không phải root
info "Bước 4: Cài Claude Code CLI..."
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    HOME_USER=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    curl -fsSL https://claude.ai/install.sh -o /tmp/claude-install.sh
    sudo -u "$SUDO_USER" -H bash /tmp/claude-install.sh
    rm -f /tmp/claude-install.sh
    if [ -x "$HOME_USER/.local/bin/claude" ]; then
        ok "Đã cài Claude Code CLI cho user $SUDO_USER (tự cập nhật trong nền)"
    else
        warn "Không thấy ~/.local/bin/claude — kiểm tra lại quá trình cài"
    fi
else
    warn "Không xác định được user (chạy không qua sudo) — bỏ qua CLI, chỉ cài Desktop"
fi

printf '\n\033[1;32mHoàn tất!\033[0m Bước tiếp theo:\n'
printf '  - Claude Desktop: mở từ app launcher hoặc lệnh \033[1mclaude-desktop\033[0m, đăng nhập tài khoản Anthropic\n'
printf '  - Claude Code: mở terminal mới, chạy \033[1mclaude\033[0m để đăng nhập lần đầu\n'
