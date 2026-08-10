#!/bin/sh
# @setup-description: Thiết lập bộ gõ cơ bản
# @setup-when: always
# @setup-core-description: Cài fcitx5 (kèm unikey, bamboo) thay ibus -- tránh tối đa lỗi trong các app hiện nay, cấu hình autostart
# 3-setup-ime-deb.sh — Ubuntu/Debian: thiết lập fcitx5 làm input method
# Chạy: sudo ./3-setup-ime-deb.sh

set -e

[ "${DEBUG:-0}" = "1" ] && set -x

info() { printf '\033[1;34m[ime]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m    %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

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

[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

info "Bước 1: Cập nhật danh sách gói..."
wait_apt
apt-get update

info "Bước 2: Cài fcitx5..."
PKGS="fcitx5 fcitx5-config-qt"
KIM=0
case "$XDG_CURRENT_DESKTOP" in
    *KDE*|*Plasma*)
        PKGS="$PKGS kde-config-fcitx5"
        info "Phát hiện KDE — thêm kde-config-fcitx5 (module cấu hình trong System Settings)"
        ;;
    *GNOME*)
        if apt-cache show gnome-shell-extension-manager >/dev/null 2>&1; then
            PKGS="$PKGS gnome-shell-extension-manager"
            info "Phát hiện GNOME — cài thêm Extension Manager (quản lý extension kimpanel)"
        else
            warn "GNOME: repo không có gnome-shell-extension-manager — nếu cần thì cài qua flatpak com.mattjakeman.ExtensionManager"
        fi
        if apt-cache show gnome-shell-extension-kimpanel >/dev/null 2>&1; then
            PKGS="$PKGS gnome-shell-extension-kimpanel"
            KIM=1
            info "Phát hiện GNOME — thêm kimpanel (hiển thị bộ gõ trên status bar)"
        else
            warn "GNOME: repo không có gnome-shell-extension-kimpanel — cài thủ công từ extensions.gnome.org/extension/261"
        fi
        ;;
esac

for eng in fcitx5-unikey fcitx5-bamboo; do
    if apt-cache show "$eng" >/dev/null 2>&1; then
        PKGS="$PKGS $eng"
        info "Có gói $eng — cài thêm bộ gõ tiếng Việt"
    else
        warn "Repo không có $eng — bỏ qua (fcitx5 vẫn gõ được tiếng khác)"
    fi
done
apt-get install -y $PKGS

if [ "$KIM" -eq 1 ]; then
    if [ -n "$SUDO_USER" ]; then
        sudo -u "$SUDO_USER" gnome-extensions enable kimpanel@wengxt 2>/dev/null || true
    fi
    ok "Đã cài kimpanel — đăng xuất/đăng nhập lại, bộ gõ sẽ hiện trên status bar"
    printf 'Nếu chưa thấy bộ gõ: mở app "Extensions" (gnome-extensions-app) và bật kimpanel.\n'
fi

info "Bước 3: Purge ibus và thêm fcitx5 vào autostart..."
if dpkg -l ibus 2>/dev/null | grep -q '^ii'; then
    apt-get purge -y ibus
    apt-get autoremove -y --purge
    rm -rf /root/.config/ibus /root/.cache/ibus \
           /home/*/.config/ibus /home/*/.cache/ibus
    ok "Đã purge sạch ibus"
else
    ok "ibus chưa được cài — bỏ qua"
fi

if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    HOME_USER=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    AUTOSTART="$HOME_USER/.config/autostart"
    sudo -u "$SUDO_USER" mkdir -p "$AUTOSTART"
    if [ -f /usr/share/applications/org.fcitx.Fcitx5.desktop ]; then
        sudo -u "$SUDO_USER" cp /usr/share/applications/org.fcitx.Fcitx5.desktop "$AUTOSTART/"
    else
        cat > "$AUTOSTART/org.fcitx.Fcitx5.desktop" <<'DESKTOP_EOF'
[Desktop Entry]
Type=Application
Name=fcitx5
Comment=Start fcitx5 input method framework
Exec=fcitx5
Icon=fcitx
Terminal=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Phase=Applications
DESKTOP_EOF
        chown "$SUDO_USER" "$AUTOSTART/org.fcitx.Fcitx5.desktop"
    fi
    ok "Đã thêm fcitx5 vào autostart của $SUDO_USER"
else
    warn "Không xác định được user — bỏ qua bước autostart"
fi

printf '\n\033[1;32mHoàn tất!\033[0m fcitx5 đã cài xong, ibus đã được purge và autostart đã sẵn sàng.\n'
printf 'Đăng xuất/đăng nhập lại để áp dụng.\n'
