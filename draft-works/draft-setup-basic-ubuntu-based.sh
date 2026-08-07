#!/bin/sh
# install-basic-ubuntu-based.sh — BẢN DRAFT: chỉ in lựa chọn, không cài đặt thật.
# Script thật: sudo ./setup-basic-ubuntu-based.sh
# Chạy chuỗi script cài đặt cơ bản cho Ubuntu-based
# Thứ tự: del-snap → flatpak → basic apps → lotus

set -e

info() { printf '\033[1;36m[master]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m      %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m    %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m   %s\n' "$*" >&2; exit 1; }

# --- Trợ giúp (không cần root) ---
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--silent] [--help|-h]  (draft — không cần sudo)"
        echo ""
        echo "  (không đối số)  Chạy toàn bộ chuỗi cơ bản"
        echo "  --silent        Không tương tác, truyền --all xuống các script con"
        echo "  --help, -h      In trợ giúp này"
        exit 0
        ;;
esac

# Bản draft: không kiểm tra root (script thật yêu cầu sudo).

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
    # Gán stdin của con từ /dev/tty: nếu chuỗi bị chạy qua pipe (vd: curl | sudo bash),
    # stdin của con là EOF → menu sẽ không nhận được input.
    "$SCRIPT_DIR/$file" $extra_args </dev/tty || die "$file thất bại — dừng chuỗi"
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
    run_step "Gỡ app Tuxedo (Control Center...)" atom-scripts/draft-generalize-tuxedo-os.sh $SILENT
else
    run_step "Gỡ snap, thay thế bằng các app deb" atom-scripts/draft-del-snap-n-replace-apps.sh $SILENT
fi
run_step "Flatpak + Flathub"                atom-scripts/draft-enable-flatpak-flathub-deb.sh $SILENT
run_step "Ứng dụng cơ bản"                  atom-scripts/draft-install-basic-apps-deb.sh $SILENT
run_step "Bộ gõ tiếng Việt Lotus"           atom-scripts/draft-install-lotus-ubuntu-based.sh $SILENT

printf '\n\033[1;32m[DRAFT] Hoàn tất toàn bộ chuỗi!\033[0m (không có gì thực sự được cài đặt)\n'
printf 'Script tùy chọn khác (chạy riêng nếu cần):\n'
printf '  - draft-set-ime-shortcut.sh         — Phím tắt chuyển input method (GNOME: Alt+Space / KDE: Super+Space)\n'
printf '  - draft-install-ai-tools-deb.sh       — Claude Desktop + Claude Code CLI + Codex CLI\n'
