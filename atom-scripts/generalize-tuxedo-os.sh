#!/bin/sh
# generalize-tuxedo-os.sh — Gỡ các app + theme SDDM/Plasma + wallpaper + avatar Tuxedo khỏi Tuxedo OS
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
if ! dpkg -s sddm-theme-breeze >/dev/null 2>&1; then
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

# --- Bước 3b: Reset toàn bộ theme Plasma về mặc định KDE6 (global theme) ---
# Ưu tiên dùng lệnh chuẩn plasma-apply-lookandfeel -a org.kde.breeze.desktop
# (áp màu, plasma style, window decoration, splash + SDDM theme — SDDM cần
# quyền ghi /etc/sddm.conf.d, script chạy root nên OK).
# Icon/font/sound KHÔNG nằm trong LnF package → icon ghi lẻ bằng kwriteconfig6.
# Nếu lệnh chuẩn không có/fail → fallback ghi lẻ TOÀN BỘ từng key.
# Chạy SAU purge vì purge tuxedo-theme-plasma xóa luôn conffile kde_settings.conf.
# HOME/XDG_CONFIG_HOME trỏ vào user thật để config rơi vào ~/.config đúng người.
info "Bước 3b: Reset theme Plasma về mặc định KDE6 (global theme Breeze)..."
kcfg() { HOME="$TARGET_HOME" XDG_CONFIG_HOME="$TARGET_HOME/.config" kwriteconfig6 "$@"; }

if command -v plasma-apply-lookandfeel >/dev/null 2>&1; then
    if HOME="$TARGET_HOME" XDG_CONFIG_HOME="$TARGET_HOME/.config" \
        plasma-apply-lookandfeel -a org.kde.breeze.desktop; then
        ok "Đã áp global theme org.kde.breeze.desktop"
        # LnF package không gồm icon theme — ghi lẻ cho chắc
        kcfg --file kdeglobals --group Icons --key Theme breeze
        ok "Icon theme đã ghi breeze (kwriteconfig6)"
        applied=1
    else
        warn "plasma-apply-lookandfeel thất bại — sẽ ghi lẻ toàn bộ"
    fi
else
    warn "Không tìm thấy plasma-apply-lookandfeel — sẽ ghi lẻ toàn bộ"
fi

# Fallback: không có lệnh chuẩn (hoặc fail) → ghi lẻ toàn bộ từng key
if [ "${applied:-0}" -ne 1 ] && command -v kwriteconfig6 >/dev/null 2>&1; then
    info "Ghi lẻ toàn bộ theme key về mặc định KDE6..."
    kcfg --file kdeglobals --group KDE --key LookAndFeelPackage org.kde.breeze.desktop
    kcfg --file kdeglobals --group KDE --key widgetStyle Breeze
    kcfg --file kdeglobals --group KDE --key cursorTheme breeze_cursors
    kcfg --file kdeglobals --group General --key ColorScheme Breeze
    kcfg --file kdeglobals --group Icons --key Theme breeze
    kcfg --file plasmarc --group Theme --key name default
    kcfg --file kwinrc --group org.kde.kdecoration2 --key library org.kde.breeze
    kcfg --file kwinrc --group org.kde.kdecoration2 --key theme Breeze
    kcfg --file ksplashrc --group KSplash --key Theme org.kde.breeze
    kcfg --file kscreenlockerrc --group Greeter --key Theme org.kde.breeze.desktop
    ok "Đã ghi lẻ toàn bộ theme key (kwriteconfig6)"
elif [ "${applied:-0}" -ne 1 ]; then
    warn "Không tìm thấy kwriteconfig6 — bỏ qua bước reset theme"
fi

# --- Bước 4: Bỏ avatar mặc định Tuxedo (face.png), dùng icon người mặc định của KDE ---
# Tuxedo set avatar qua tuxedo-theme-plasma.postinst (copy /usr/share/tuxedo/face.png):
#   - /usr/share/plasma/avatars/face.png  → avatar dùng chung
#   - /etc/skel/.face                     → copy vào home user MỚI; accountsservice đọc
#                                           ~/.face lần đăng nhập đầu rồi ghi Icon=
#   - ~/.face trong home user đang có      → còn thừa lại, xóa luôn
# Bước 3 purge tuxedo-theme-plasma đã xóa 2 file đầu (theo postrm) — ở đây rm lại cho
# chắc và xóa Icon= trong accountsservice để KDE/SDDM fallback về icon người trắng
# trên nền xám mặc định, không còn dính logo Tuxedo.
info "Bước 4: Bỏ avatar mặc định Tuxedo (face.png), dùng icon KDE mặc định..."

# Xóa Icon= trong accountsservice (đang trỏ tới face.png)
for f in /var/lib/AccountsService/users/*; do
    [ -f "$f" ] || continue
    if grep -q '^Icon=' "$f"; then
        sed -i '/^Icon=/d' "$f"
        ok "Đã bỏ Icon= trong $(basename "$f")"
    fi
done

# Xóa avatar Tuxedo ở mọi nơi: file chung, /etc/skel (user mới), ~/.face (user đang có)
for f in /usr/share/plasma/avatars/face.png /etc/skel/.face /etc/skel/.face.icon; do
    if [ -f "$f" ]; then
        rm -f "$f"
        ok "Đã xóa $f"
    fi
done

getent passwd | awk -F: '$3>=1000 && $3<65534 {print $6}' | while read -r home; do
    [ -d "$home" ] || continue
    if [ -f "$home/.face" ] || [ -f "$home/.face.icon" ]; then
        rm -f "$home/.face" "$home/.face.icon"
        ok "Đã xóa $home/.face"
    fi
done

printf '\n\033[1;32mHoàn tất!\033[0m\n'
printf '  - Tuxedo apps: đã gỡ (Control Center, WebFAI Creator)\n'
printf '  - dGPU Guide: đã xóa khỏi application launcher\n'
printf '  - SDDM/Plasma theme: đã đổi sang Breeze, gỡ theme + wallpaper Tuxedo\n'
printf '  - Theme Plasma: đã reset global theme về mặc định KDE6 (Breeze)\n'
printf '  - Avatar mặc định: đã bỏ face.png, dùng icon người mặc định của KDE\n'
