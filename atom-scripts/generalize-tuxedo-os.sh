#!/bin/sh
# generalize-tuxedo-os.sh — Gỡ các app + theme SDDM/Plasma + wallpaper Tuxedo khỏi Tuxedo OS
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

# --- Bước 2: Xóa dGPU Guide khỏi application launcher ---
# Tuxedo OS first-boot (copy-guide.sh) copy dgpu.desktop ("dGPU Guide") vào
# ~/.local/share/applications + Desktop khi máy có 2 GPU. Autostart còn lại
# sẽ copy lại file mỗi lần đăng nhập nên phải xóa luôn.
info "Bước 2: Xóa dGPU Guide khỏi application launcher..."
TARGET_HOME=$(eval echo "~${SUDO_USER:-$USER}")

for f in \
    "$TARGET_HOME/.local/share/applications/dgpu.desktop" \
    "$TARGET_HOME/Desktop/dgpu.desktop" \
    "$TARGET_HOME/.config/autostart/copy-guide.desktop"; do
    if [ -f "$f" ]; then
        rm -f "$f"
        ok "Đã xóa $(basename "$f")"
    fi
done

# --- Bước 3: Đổi SDDM theme sang Breeze, gỡ theme + wallpaper Tuxedo ---
# kde_settings.conf là conffile của tuxedo-theme-plasma — purge sẽ xóa luôn file.
# Vì vậy: backup file trước, purge sau, rồi khôi phục lại đúng như cũ, chỉ đổi
# Current=tuxedo → Current=breeze (các cài đặt khác giữ nguyên).
info "Bước 3: Đổi SDDM theme sang Breeze, gỡ theme + wallpaper Tuxedo..."
if ! dpkg -l sddm-theme-breeze >/dev/null 2>&1; then
    info "Đang cài sddm-theme-breeze..."
    apt-get install -y sddm-theme-breeze
fi

if dpkg -l sddm-theme-breeze >/dev/null 2>&1; then
    SDDM_CONF=/etc/sddm.conf.d/kde_settings.conf
    SDDM_CONF_BAK=/tmp/kde_settings.conf.generalize-bak
    if [ -f "$SDDM_CONF" ]; then
        cp "$SDDM_CONF" "$SDDM_CONF_BAK"
    fi

    for pkg in sddm-theme-tuxedo tuxedo-theme-plasma tuxedo-wallpapers-2204 tuxedoos-desktop; do
        if dpkg -l "$pkg" >/dev/null 2>&1; then
            info "Đang gỡ $pkg..."
            apt-get purge -y "$pkg"
            ok "Đã gỡ $pkg"
        else
            ok "$pkg chưa được cài — bỏ qua"
        fi
    done

    # Khôi phục config như cũ, chỉ đổi Current=tuxedo → Current=breeze
    if [ -f "$SDDM_CONF_BAK" ]; then
        sed 's/^Current=tuxedo/Current=breeze/' "$SDDM_CONF_BAK" > "$SDDM_CONF"
        rm -f "$SDDM_CONF_BAK"
        ok "SDDM đã chuyển sang theme Breeze (Current=breeze)"
    elif [ ! -f "$SDDM_CONF" ]; then
        # Không có config gốc — tạo file tối thiểu chỉ để chọn Breeze
        mkdir -p /etc/sddm.conf.d
        printf '[Theme]\nCurrent=breeze\n' > "$SDDM_CONF"
        ok "SDDM đã chuyển sang theme Breeze (Current=breeze)"
    fi
else
    warn "Không cài được sddm-theme-breeze — giữ nguyên theme SDDM hiện tại"
fi

printf '\n\033[1;32mHoàn tất!\033[0m\n'
printf '  - Tuxedo apps: đã gỡ (Control Center, WebFAI Creator)\n'
printf '  - dGPU Guide: đã xóa khỏi application launcher\n'
printf '  - SDDM/Plasma theme: đã đổi sang Breeze, gỡ theme + wallpaper Tuxedo\n'
