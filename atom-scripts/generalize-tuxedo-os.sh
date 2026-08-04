#!/bin/sh
# generalize-tuxedo-os.sh — Gỡ các app Tuxedo (Control Center, WebFAI) khỏi Tuxedo OS
# Dùng khi muốn biến Tuxedo OS thành Ubuntu/Debian "thuần" hơn.
# Chạy: sudo ./generalize-tuxedo-os.sh

set -e

info() { printf '\033[1;34m[tuxedo-generalize]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m                %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m              %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m             %s\n' "$*" >&2; exit 1; }

# --- Kiểm tra quyền root ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

# --- Bước 1: Gỡ các app GUI đặc thù phần cứng Tuxedo ---
# Chỉ gỡ các app hiện trong start menu (Control Center, WebFAI Creator) —
# không gỡ driver/system packages tránh lỗi hệ thống.
info "Bước 1: Gỡ các app Tuxedo (Control Center, WebFAI Creator)..."
TUXX_GUI="tuxedo-control-center"

for pkg in $TUXX_GUI; do
    if dpkg -l "$pkg" >/dev/null 2>&1; then
        info "Đang gỡ $pkg..."
        apt-get purge -y "$pkg"
        ok "Đã gỡ $pkg"
    else
        ok "$pkg chưa được cài — bỏ qua"
    fi
done

# WebFAI Creator: có thể không phải là package riêng mà nằm trong panel applet
if dpkg -l tuxedo-webfai-creator >/dev/null 2>&1; then
    info "Đang gỡ tuxedo-webfai-creator..."
    apt-get purge -y tuxedo-webfai-creator
    ok "Đã gỡ tuxedo-webfai-creator"
fi

apt-get autoremove -y --purge || true

printf '\n\033[1;32mHoàn tất!\033[0m\n'
printf '  - Tuxedo apps: đã gỡ (Control Center, WebFAI Creator)\n'
