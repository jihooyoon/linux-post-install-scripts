#!/bin/sh
# set-ime-shortcut.sh — Đặt phím tắt chuyển input method cho fcitx5
# - GNOME: TriggerKeys = Alt+Space (không đụng shortcut Super+Space mặc định của GNOME)
# - KDE/khác: TriggerKeys = Super+Space; KDE đổi KRunner sang Alt+Space
# - Xóa AltTriggerKeys (mặc định Shift_L: "giữ Shift trái tạm chuyển IM")
# Chạy: sudo ./set-ime-shortcut.sh

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

# --- Nhận diện desktop ---
# Chạy qua sudo nên XDG_CURRENT_DESKTOP thường bị reset (rỗng) — fallback đoán
# theo process của session đồ họa đang chạy của user
DESKTOP=$XDG_CURRENT_DESKTOP
if [ -z "$DESKTOP" ]; then
    pgrep -u "$SUDO_USER" -x gnome-shell >/dev/null 2>&1 && DESKTOP=GNOME
    pgrep -u "$SUDO_USER" -x plasmashell >/dev/null 2>&1 && DESKTOP=KDE
fi
[ -n "$DESKTOP" ] || warn "Không nhận diện được desktop — dùng mặc định Super+Space"

case "$DESKTOP" in
    *GNOME*)
        # GNOME mặc định chiếm Super+Space, còn Ctrl+Space thường bị app autocomplete
        # chiếm (IDE, browser) — dùng Alt+Space (GNOME không dùng mặc định), khỏi đụng gsettings
        TRIGGER="Alt+space"
        ;;
    *)
        TRIGGER="Super+space"
        ;;
esac

# --- Bước 1: Cấu hình phím tắt fcitx5 ---
# Định dạng fcitx5 (tham khảo ~/.config/fcitx5/config thật): option dạng list phải
# nằm trong sub-section riêng "[Hotkey/TriggerKeys]" với các dòng 0=, 1=, ...
# (dòng phẳng "TriggerKeys=..." kiểu fcitx4 là sai). List rỗng thì ghi phẳng
# dòng trống, ví dụ "AltTriggerKeys=". Option "EnumerateTriggerKeys" đã bị bỏ
# (thay bằng EnumerateWithTriggerKeys, mặc định True).
info "Bước 1: Cấu hình phím tắt fcitx5 (trigger: $TRIGGER)..."
FCONF="$HOME_USER/.config/fcitx5/config"
mkdir -p "$(dirname "$FCONF")"
if [ -f "$FCONF" ]; then
    # Patch config đã tồn tại (giữ nguyên các cài đặt khác):
    #  - bỏ dòng phẳng TriggerKeys= và EnumerateTriggerKeys= nếu có (format cũ)
    #  - đảm bảo AltTriggerKeys rỗng (tắt "giữ Shift trái tạm chuyển IM")
    #  - đặt trigger vào [Hotkey/TriggerKeys]; chưa có section thì thêm cuối file
    awk -v trig="$TRIGGER" '
        BEGIN { hotkey=0; trigsec=0; skip=0; done=0 }
        /^\[/ {
            hotkey  = ($0 == "[Hotkey]")
            trigsec = ($0 == "[Hotkey/TriggerKeys]")
            skip    = ($0 == "[Hotkey/AltTriggerKeys]")
            if (!skip) print
            next
        }
        skip { next }
        hotkey && /^TriggerKeys=/ { next }
        hotkey && /^EnumerateTriggerKeys=/ { next }
        hotkey && /^AltTriggerKeys=/ { print "AltTriggerKeys="; next }
        trigsec && /^0=/ && !done { print "0=" trig; done=1; next }
        { print }
        END { if (!done) printf "\n[Hotkey/TriggerKeys]\n0=%s\n", trig }
    ' "$FCONF" > "$FCONF.tmp" && mv "$FCONF.tmp" "$FCONF"
    # File chưa có dòng AltTriggerKeys trong [Hotkey] → thêm ngay sau header
    grep -q '^AltTriggerKeys=' "$FCONF" || sed -i '/^\[Hotkey\]$/a AltTriggerKeys=' "$FCONF"
else
    cat > "$FCONF" <<EOF
[Hotkey]
# Toggle Input Method
EnumerateWithTriggerKeys=True
# Temporarily Toggle Input Method
AltTriggerKeys=

[Hotkey/TriggerKeys]
0=$TRIGGER
EOF
fi
case "$DESKTOP" in
    *GNOME*) ok "Đã đặt Alt+Space = chuyển input method (giữ nguyên Super+Space của GNOME); đã bỏ 'giữ Shift trái tạm chuyển IM'" ;;
    *)       ok "Đã đặt Super+Space = chuyển input method; đã bỏ 'giữ Shift trái tạm chuyển IM'" ;;
esac

# --- Bước 2: Đè shortcut xung đột của KDE (KRunner) để Super+Space thuộc về fcitx5 ---
# GNOME không cần xử lý ở đây: đã dùng Alt+Space nên không đụng 'Switch input source'
case "$DESKTOP" in
    *KDE*|*Plasma*)
        info "Bước 2: Đè shortcut KRunner sang Alt+Space..."
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

printf '\n\033[1;32mHoàn tất!\033[0m Phím chuyển input method: \033[1mAlt+Space\033[0m (GNOME) / \033[1mSuper+Space\033[0m (KDE/khác). Đăng nhập lại để áp dụng.\n'
