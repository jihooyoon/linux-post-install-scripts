#!/bin/sh
# setup-all-ubuntu-based — Cài toàn bộ: chuỗi cơ bản + Claude + phím tắt Super+Space
#  1. setup-basic-ubuntu-based.sh             — de-snap, flatpak, basic apps, lotus
#  2. extras/install-claude-deb.sh           — Claude Desktop + Claude Code CLI
#  3. extras/set-ime-shortcut-win-space.sh   — Super+Space chuyển input method
#  4. extras/install-chat-apps.sh            — Slack, Mattermost, Discord
# Lưu ý: các script con phải nằm đúng đường dẫn tương đối so với file này.
# Chạy: sudo ./setup-all-ubuntu-based   (dùng sudo, KHÔNG dùng su — cần SUDO_USER)

set -e

info() { printf '\033[1;36m[setup]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m     %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m   %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m  %s\n' "$*" >&2; exit 1; }

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

run_step "Chuỗi cài đặt cơ bản (de-snap, flatpak, apps, lotus)" setup-basic-ubuntu-based.sh
run_step "Claude Desktop + Claude Code CLI"                    extras/install-claude-deb.sh
run_step "Phím tắt Super+Space cho input method"               extras/set-ime-shortcut-win-space.sh
run_step "Slack, Mattermost, Discord"                           extras/install-chat-apps.sh

printf '\n\033[1;32mHoàn tất toàn bộ!\033[0m Khởi động lại máy để áp dụng mọi thứ.\n'
printf 'Sau khi khởi động lại:\n'
printf '  - Chạy \033[1mclaude\033[0m để đăng nhập Claude Code lần đầu\n'
printf '  - Bật bộ gõ Lotus trong fcitx5-config nếu chưa có\n'
