#!/bin/sh
# @setup-description: Chuyển GNOME sang KDE Plasma
# @setup-when: always
# @setup-core-description: Cài KDE Plasma, chọn SDDM và gỡ GNOME
# 1-switch-to-kde-deb.sh — Ubuntu/Debian: chuyển desktop GNOME sang KDE Plasma
# Chạy: sudo ./1-switch-to-kde-deb.sh

[ "${DEBUG:-0}" = "1" ] && set -x

LOG_CONTEXT=switch-kde
info() { printf '\033[1;34m[%s]\033[0m %s\n' "$LOG_CONTEXT" "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m     %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m   %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m  %s\n' "$*" >&2; exit 1; }

CHILD_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CHILD_FILE="$CHILD_DIR/$(basename -- "$0")"
. "$CHILD_DIR/../lib/setup-contract.sh"
setup_child_prepare "$CHILD_FILE" "$@" || exit $?
if [ "$SETUP_SHOW_HELP" -eq 1 ]; then
    setup_print_help "$CHILD_FILE"
    exit 0
fi

[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

DEFAULT_DISPLAY_MANAGER_FILE=${SETUP_KDE_DEFAULT_DM_FILE:-/etc/X11/default-display-manager}
DISPLAY_MANAGER_SERVICE_LINK=${SETUP_KDE_DM_SERVICE_LINK:-/etc/systemd/system/display-manager.service}

detect_desktop() {
    DESKTOP=${XDG_CURRENT_DESKTOP:-}
    if [ -z "$DESKTOP" ] && [ -n "${SUDO_USER:-}" ] && command -v pgrep >/dev/null 2>&1; then
        if pgrep -u "$SUDO_USER" -x plasmashell >/dev/null 2>&1; then
            DESKTOP=KDE
        elif pgrep -u "$SUDO_USER" -x gnome-shell >/dev/null 2>&1; then
            DESKTOP=GNOME
        fi
    fi
}

wait_apt() {
    _wait_i=0
    while [ "$_wait_i" -lt 60 ]; do
        if ! fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/lib/dpkg/lock >/dev/null 2>&1; then
            return 0
        fi
        [ "$_wait_i" -ne 0 ] || info "apt/dpkg đang bị lock — đợi giải phóng (tối đa 60s)..."
        sleep 1
        _wait_i=$((_wait_i + 1))
    done
    warn "apt/dpkg vẫn bị lock sau 60s — bỏ qua chuyển KDE để tránh xung đột"
    return 1
}

preseed_sddm() {
    command -v debconf-set-selections >/dev/null 2>&1 || {
        warn "Không tìm thấy debconf-set-selections, không thể bảo đảm cài đặt silent"
        return 1
    }
    printf '%s\n' 'sddm shared/default-x-display-manager select sddm' | debconf-set-selections
}

install_and_configure_kde() {
    if ! wait_apt || ! preseed_sddm; then
        return 1
    fi

    info "Cài KDE Plasma và SDDM (noninteractive)..."
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y kde-plasma-desktop sddm; then
        warn "Cài KDE Plasma hoặc SDDM thất bại — giữ nguyên GNOME"
        return 1
    fi
    if ! dpkg -s kde-plasma-desktop >/dev/null 2>&1 || ! dpkg -s sddm >/dev/null 2>&1; then
        warn "KDE Plasma hoặc SDDM chưa được cài hoàn chỉnh — giữ nguyên GNOME"
        return 1
    fi

    if ! mkdir -p "$(dirname -- "$DEFAULT_DISPLAY_MANAGER_FILE")" || \
       ! printf '%s\n' /usr/bin/sddm > "$DEFAULT_DISPLAY_MANAGER_FILE" || \
       ! systemctl enable sddm.service || \
       ! ln -sfn /lib/systemd/system/sddm.service "$DISPLAY_MANAGER_SERVICE_LINK"; then
        warn "Không cấu hình được SDDM cho lần boot sau — giữ nguyên GNOME"
        return 1
    fi
}

mark_kde_switch_succeeded() {
    _marker=$(setup_kde_switch_marker)
    if ! mkdir -p "$(dirname -- "$_marker")" || \
       ! printf '%s\n' 'KDE Plasma and SDDM configured' > "$_marker" || \
       ! chmod 644 "$_marker"; then
        warn "Không ghi được marker KDE; dừng để tránh các script sau cấu hình nhầm GNOME"
        return 1
    fi
    ok "KDE Plasma đã sẵn sàng; SDDM sẽ là display manager sau reboot"
}

purge_gnome() {
    info "Gỡ GNOME và các gói Ubuntu Desktop..."
    if apt-get purge -y \
        'gnome*' 'gdm3' 'ubuntu-desktop*' 'ubuntu-session*' 'ubuntu-settings*' \
        nautilus evince eog gedit gnome-calculator gnome-calendar gnome-characters \
        gnome-clocks gnome-contacts gnome-font-viewer gnome-disk-utility \
        gnome-system-monitor gnome-screenshot; then
        ok "Đã purge các gói GNOME"
    else
        warn "Purge GNOME gặp lỗi — tiếp tục dọn dependency còn lại"
    fi
    if apt-get autoremove -y --purge; then
        ok "Đã dọn dependency không còn dùng"
    else
        warn "autoremove gặp lỗi"
    fi
}

main() {
    detect_desktop
    if setup_is_kde_desktop "$DESKTOP"; then
        setup_child_skip "desktop hiện tại đã là KDE/Plasma"
    fi

    info "Desktop hiện tại: ${DESKTOP:-không nhận diện được}; bắt đầu chuyển sang KDE Plasma"
    if ! install_and_configure_kde; then
        warn "Chưa chuyển sang KDE vì bước cài/cấu hình KDE hoặc SDDM chưa thành công"
        return 1
    fi
    if ! mark_kde_switch_succeeded; then
        return 1
    fi

    purge_gnome
    printf '\n\033[1;32mHoàn tất!\033[0m Hãy reboot để đăng nhập KDE Plasma qua SDDM.\n'
}

main
