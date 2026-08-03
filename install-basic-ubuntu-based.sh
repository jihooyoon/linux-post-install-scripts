#!/bin/sh
# install-basic-ubuntu-based.sh — Chạy chuỗi script cài đặt cơ bản cho Ubuntu-based
# Thứ tự: de-snap → flatpak → basic apps → lotus
#   - de-snap trước: gỡ sạch snap/snapd để các bước sau không vướng snap
#   - flatpak: Flatpak + Flathub + GNOME Software
#   - basic apps: LibreOffice, fcitx5, FreeOffice, Firefox/TB, Chrome, VS Code
#   - lotus: bộ gõ tiếng Việt Lotus cho fcitx5 + env
# Lưu ý: các script đơn vị nằm trong thư mục con atom-scripts/ cạnh file này.
# Chạy: sudo ./install-basic-ubuntu-based.sh   (dùng sudo, KHÔNG dùng su — cần SUDO_USER)

set -e

info() { printf '\033[1;36m[master]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m      %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m    %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m   %s\n' "$*" >&2; exit 1; }

# --- Kiểm tra quyền root và user thật ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"
[ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ] \
    || die "Phải chạy bằng sudo (su sẽ mất SUDO_USER): sudo $0"

# Thư mục chứa script con (không phụ thuộc nơi gọi)
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

run_step() {
    name=$1
    file=$2
    info "=== Bắt đầu: $name ($file) ==="
    # Không dùng sudo lồng nhau: master đã là root, gọi thẳng để giữ SUDO_USER
    "$SCRIPT_DIR/$file" || die "$file thất bại — dừng chuỗi"
    ok "Hoàn tất: $name"
}

run_step "Gỡ snap và snapd"                 atom-scripts/de-snap.sh
run_step "Flatpak + Flathub"                atom-scripts/enable-flatpak-flathub-deb.sh
run_step "Ứng dụng cơ bản"                  atom-scripts/install-basic-apps-deb.sh
run_step "Bộ gõ tiếng Việt Lotus"           atom-scripts/install-lotus-ubuntu-based.sh

printf '\n\033[1;32mHoàn tất toàn bộ chuỗi!\033[0m Nên khởi động lại máy để áp dụng.\n'
printf 'Script tùy chọn khác (chạy riêng nếu cần):\n'
printf '  - set-ime-shortcut-win-space.sh — Super+Space chuyển input method\n'
printf '  - install-claude-deb.sh         — Claude Desktop + Claude Code CLI\n'
