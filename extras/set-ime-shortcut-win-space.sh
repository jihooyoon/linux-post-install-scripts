#!/bin/sh
# set-ime-shortcut-win-space.sh — Đặt phím tắt chuyển input method là Super+Space (fcitx5)
# - TriggerKeys = Super+space (chuyển/bật-tắt input method)
# - Xóa AltTriggerKeys (mặc định Shift_L: "giữ Shift trái tạm chuyển IM")
# - Đè shortcut xung đột: GNOME 'Switch input source' / KDE KRunner
# Chạy: sudo ./set-ime-shortcut-win-space.sh

set -e

info() { printf '\033[1;34m[ime]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m    %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

# --- Kiểm tra quyền root ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

# Config nằm trong home của user thật (không phải root) — bắt buộc chạy qua sudo
[ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ] \
    || die "Không xác định được user — chạy bằng sudo: sudo $0"
HOME_USER=$(getent passwd "$SUDO_USER" | cut -d: -f6)

# --- Bước 1: Cấu hình phím tắt fcitx5 ---
info "Bước 1: Cấu hình phím tắt fcitx5..."
FCONF="$HOME_USER/.config/fcitx5/config"
mkdir -p "$(dirname "$FCONF")"
if [ -f "$FCONF" ]; then
    # Patch config đã tồn tại (giữ nguyên các cài đặt khác)
    sed -i -e 's/^TriggerKeys=.*/TriggerKeys=Super+space/' \
           -e 's/^AltTriggerKeys=.*/AltTriggerKeys=/' "$FCONF"
    # Nếu config thiếu dòng (bản cũ), chèn sau [Hotkey]
    if ! grep -q '^TriggerKeys=' "$FCONF"; then
        sed -i 's/^\[Hotkey\]$/[Hotkey]\nTriggerKeys=Super+space\nAltTriggerKeys=/' "$FCONF"
    fi
else
    cat > "$FCONF" <<'EOF'
[Hotkey]
TriggerKeys=Super+space
AltTriggerKeys=
EnumerateTriggerKeys=Control+Shift+space
EOF
fi
ok "Đã đặt Super+Space = chuyển input method; đã bỏ 'giữ Shift trái tạm chuyển IM'"

# --- Bước 2: Đè shortcut xung đột của DE để Super+Space thuộc về fcitx5 ---
info "Bước 2: Đè shortcut xung đột của desktop environment..."
case "$XDG_CURRENT_DESKTOP" in
    *GNOME*)
        UID_USER=$(id -u "$SUDO_USER")
        BUS_ENV="env XDG_RUNTIME_DIR=/run/user/$UID_USER DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID_USER/bus"
        # GNOME vốn chiếm Super+Space làm 'Switch input source' → tắt hẳn
        if sudo -u "$SUDO_USER" $BUS_ENV gsettings set org.gnome.desktop.wm.keybindings switch-input-source "[]" 2>/dev/null; then
            sudo -u "$SUDO_USER" $BUS_ENV gsettings set org.gnome.desktop.wm.keybindings switch-input-source-backward "[]" 2>/dev/null || true
            ok "GNOME: đã tắt 'Switch input source' — Super+Space thuộc về fcitx5"
        else
            warn "GNOME: chưa đặt được (cần session đang chạy) — đổi tay trong GNOME Settings → Keyboard → Shortcuts"
        fi
        ;;
    *KDE*|*Plasma*)
        KSHORTCUT="$HOME_USER/.config/kglobalshortcutsrc"
        # KDE vốn chiếm Super+Space làm KRunner → đổi sang Alt+Space
        if [ -f "$KSHORTCUT" ]; then
            if grep -q '^\[org.kde.krunner\]$' "$KSHORTCUT"; then
                awk '
                    /^\[org\.kde\.krunner\]$/ { in_krunner=1 }
                    /^\[/ && !/^\[org\.kde\.krunner\]$/ { in_krunner=0 }
                    in_krunner && /^_launch=/ { sub(/^_launch=.*/, "_launch=Alt+Space,Meta+Space") }
                    { print }
                ' "$KSHORTCUT" > "$KSHORTCUT.tmp" && mv "$KSHORTCUT.tmp" "$KSHORTCUT"
            else
                printf '\n[org.kde.krunner]\n_launch=Alt+Space,Meta+Space\n' >> "$KSHORTCUT"
            fi
            ok "KDE: đã đổi KRunner từ Super+Space sang Alt+Space"
        else
            warn "KDE: chưa thấy kglobalshortcutsrc — sau khi đăng nhập KDE, đổi KRunner trong System Settings → Shortcuts"
        fi
        ;;
esac

printf '\n\033[1;32mHoàn tất!\033[0m Super+Space giờ là phím chuyển input method (đăng nhập lại để áp dụng).\n'
