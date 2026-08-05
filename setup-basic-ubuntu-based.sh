#!/bin/sh
# install-basic-ubuntu-based.sh — Chạy chuỗi script cài đặt cơ bản cho Ubuntu-based
# Thứ tự: del-snap → flatpak → basic apps → lotus
#   - del-snap trước: gỡ sạch snap/snapd + cài Firefox .deb, pin Thunderbird
#   - flatpak: Flatpak + Flathub
#   - basic apps: LibreOffice, fcitx5, FreeOffice, Chrome, Chromium, VS Code
#   - lotus: bộ gõ tiếng Việt Lotus cho fcitx5 + env
# Lưu ý: các script đơn vị nằm trong thư mục con atom-scripts/ cạnh file này.
# Chạy: sudo ./install-basic-ubuntu-based.sh            (chạy toàn bộ chuỗi)
#       sudo ./install-basic-ubuntu-based.sh --silent    (không tương tác, truyền --all xuống script con)
#       sudo ./install-basic-ubuntu-based.sh --help | -h (trợ giúp)

set -e

info() { printf '\033[1;36m[master]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m      %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m    %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m   %s\n' "$*" >&2; exit 1; }

# --- Trợ giúp (không cần root) ---
case "${1:-}" in
    --help|-h)
        echo "Usage: sudo $0 [--silent] [--help|-h]"
        echo ""
        echo "  (không đối số)  Chạy toàn bộ chuỗi cơ bản"
        echo "  --silent        Không tương tác, truyền --all xuống các script con"
        echo "  --help, -h      In trợ giúp này"
        exit 0
        ;;
esac

# --- Kiểm tra quyền root và user thật ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"
[ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ] \
    || die "Phải chạy bằng sudo (su sẽ mất SUDO_USER): sudo $0"

# Thư mục chứa script con (không phụ thuộc nơi gọi)
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Phát hiện Tuxedo OS (đã tắt snap mặc định, dùng Firefox, Thunderbird .deb sẵn)
is_tuxedo() {
    grep -qi 'tuxedo' /etc/os-release 2>/dev/null
}

run_step() {
    name=$1
    file=$2
    extra_args=${3:-}
    info "=== Bắt đầu: $name ($file) ==="
    # Không dùng sudo lồng nhau: master đã là root, gọi thẳng để giữ SUDO_USER
    "$SCRIPT_DIR/$file" $extra_args || die "$file thất bại — dừng chuỗi"
    ok "Hoàn tất: $name"
}

# --- Đọc tham số ---
SILENT=""
case "${1:-}" in
    --silent) SILENT="--all" ;;
    "")       ;;  # Mặc định: chạy bình thường
esac

if is_tuxedo; then
    info "Phát hiện Tuxedo OS — thay bước de-snap bằng generalize-tuxedo-os"
    run_step "Gỡ app Tuxedo (Control Center...)" atom-scripts/generalize-tuxedo-os.sh $SILENT
else
    run_step "Gỡ snap, thay thế bằng các app deb" atom-scripts/del-snap-n-replace-apps.sh $SILENT
fi
run_step "Flatpak + Flathub"                atom-scripts/enable-flatpak-flathub-deb.sh $SILENT
run_step "Ứng dụng cơ bản"                  atom-scripts/install-basic-apps-deb.sh $SILENT
run_step "Bộ gõ tiếng Việt Lotus"           atom-scripts/install-lotus-ubuntu-based.sh $SILENT

printf '\n\033[1;32mHoàn tất toàn bộ chuỗi!\033[0m Nên khởi động lại máy để áp dụng.\n'
printf 'Script tùy chọn khác (chạy riêng nếu cần):\n'
printf '  - set-ime-shortcut.sh         — Phím tắt chuyển input method (GNOME: Alt+Space / KDE: Super+Space)\n'
printf '  - install-ai-tools-deb.sh       — Claude Desktop + Claude Code CLI + Codex CLI\n'
