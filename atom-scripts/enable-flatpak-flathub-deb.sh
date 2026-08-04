#!/bin/sh
# enable-flatpak-flathub-deb.sh — Cài flatpak + bật kho Flathub trên Ubuntu/Debian
# Chạy: sudo ./enable-flatpak-flathub-deb.sh

set -e

info() { printf '\033[1;34m[flatpak]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m      %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m    %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m   %s\n' "$*" >&2; exit 1; }

# --- Kiểm tra quyền root ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

# --- Bước 1: Cập nhật danh sách gói ---
info "Bước 1: Cập nhật danh sách gói..."
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
info "Bước 4: Cài plugin hiển thị flatpak trong App Center..."
case "$XDG_CURRENT_DESKTOP" in
    *GNOME*)
        apt-get install -y gnome-software-plugin-flatpak || true
        ok "Đã cài plugin cho GNOME Software"
        ;;
    *KDE*|*Plasma*)
        apt-get install -y plasma-discover-backend-flatpak || true
        ok "Đã cài backend cho KDE Discover"
        ;;
    *)
        warn "Không nhận diện được desktop ($XDG_CURRENT_DESKTOP) — bỏ qua plugin GUI"
        ;;
esac

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
