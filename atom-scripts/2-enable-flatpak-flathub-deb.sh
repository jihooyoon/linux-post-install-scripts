#!/bin/sh
# @setup-description: Bật Flatpak & Flathub
# @setup-when: always
# @setup-core-description: Bật Flatpak & Flathub
# 2-enable-flatpak-flathub-deb.sh — Cài flatpak + bật kho Flathub trên Ubuntu/Debian
# Chạy: sudo ./2-enable-flatpak-flathub-deb.sh

set -e

# Debug mode: chạy với DEBUG=1 ./script.sh để thấy tất cả lệnh đang chạy
[ "${DEBUG:-0}" = "1" ] && set -x

info() { printf '\033[1;34m[flatpak]\033[0m %s\n' "$*"; }
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

detect_desktop() {
    DESKTOP=${XDG_CURRENT_DESKTOP:-}
    if [ -z "$DESKTOP" ] && [ -n "${SUDO_USER:-}" ] && command -v pgrep >/dev/null 2>&1; then
        if pgrep -u "$SUDO_USER" -x gnome-shell >/dev/null 2>&1; then
            DESKTOP=GNOME
        elif pgrep -u "$SUDO_USER" -x plasmashell >/dev/null 2>&1; then
            DESKTOP=KDE
        fi
    fi
}

install_gui_backend() {
    info "Bước 4: Cài plugin hiển thị flatpak trong App Center..."
    case "$DESKTOP" in
        *GNOME*)
            if apt-get install -y gnome-software-plugin-flatpak; then
                ok "Đã cài plugin cho GNOME Software"
            else
                warn "Không cài được plugin Flatpak cho GNOME Software — vẫn dùng Flatpak qua CLI được"
            fi
            ;;
        *KDE*|*Plasma*)
            if apt-get install -y plasma-discover-backend-flatpak; then
                ok "Đã cài backend cho KDE Discover"
            else
                warn "Không cài được backend Flatpak cho KDE Discover — vẫn dùng Flatpak qua CLI được"
            fi
            ;;
        *)
            warn "Không nhận diện được desktop (${DESKTOP:-trống}) — bỏ qua plugin GUI"
            ;;
    esac
}

# --- Kiểm tra quyền root ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

# --- Bước 1: Cập nhật danh sách gói ---
info "Bước 1: Cập nhật danh sách gói..."
wait_apt
apt-get update

# --- Bước 2: Cài flatpak ---
info "Bước 2: Cài flatpak..."
apt-get install -y flatpak
ok "Đã cài flatpak"

# --- Bước 3: Thêm kho Flathub ---
info "Bước 3: Thêm kho Flathub..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
ok "Đã thêm kho Flathub"

# --- Bước 4: Plugin tích hợp vào App Center theo desktop environment ---
detect_desktop
install_gui_backend

# --- Bước 5: Kiểm tra ---
info "Bước 5: Kiểm tra cấu hình..."
if flatpak remotes | grep -q flathub; then
    ok "Flathub đã sẵn sàng"
else
    die "Không thấy kho Flathub — kiểm tra lại kết nối mạng"
fi

printf '\n\033[1;32mHoàn tất!\033[0m Cài ứng dụng bằng lệnh:\n'
printf '    flatpak install flathub <app-id>\n'
printf 'Ví dụ:    flatpak install flathub org.videolan.VLC\n'
printf 'Gợi ý: đăng xuất/đăng nhập lại để App Center nhận plugin mới.\n'
