#!/bin/sh
# install-basic-dev-tools.sh — Cài các công cụ dev cơ bản: Node.js (NodeSource LTS)
# Chạy: sudo ./install-basic-dev-tools.sh

set -e

info() { printf '\033[1;34m[dev-tools]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m        %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m      %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m     %s\n' "$*" >&2; exit 1; }

# --- Kiểm tra quyền root ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

# --- Bước 1: Cài Node.js LTS từ NodeSource ---
info "Bước 1: Cài Node.js LTS từ NodeSource..."
command -v curl >/dev/null 2>&1 || apt-get install -y curl
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs
ok "Đã cài Node.js $(node --version)"

printf '\n\033[1;32mHoàn tất!\033[0m\n'
printf '  - Node.js: %s (LTS từ NodeSource)\n' "$(node --version)"
printf '  - npm:     %s (đi kèm Node.js)\n'    "$(npm --version)"
