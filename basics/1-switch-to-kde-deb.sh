#!/bin/sh
# @setup-description: Chuyển GNOME sang KDE Plasma
# @setup-when: always
# @setup-core-description: Cài KDE Plasma, chọn SDDM; gỡ GNOME sau khi vào phiên Plasma
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
PURGE_GNOME_SCRIPT="$CHILD_DIR/../lib/purge-gnome.sh"
PURGE_INSTALL_DIR=${PURGE_GNOME_INSTALL_DIR:-/usr/local/lib/linux-post-install-scripts}
PURGE_UNIT_DIR=${PURGE_GNOME_UNIT_DIR:-/etc/systemd/system}
PURGE_UNIT_NAME=linux-post-install-purge-gnome

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

    # display-manager.service đang trỏ DM cũ (vd gdm3) thì enable sddm sẽ lỗi "already exists".
    # disable chỉ gỡ symlink cho lần boot sau, không dừng GDM đang chạy phiên hiện tại.
    if [ -e /lib/systemd/system/gdm3.service ] || [ -e /usr/lib/systemd/system/gdm3.service ]; then
        systemctl disable gdm3.service || warn "Không disable được gdm3.service"
    fi
    if [ -L "$DISPLAY_MANAGER_SERVICE_LINK" ] && ! readlink "$DISPLAY_MANAGER_SERVICE_LINK" | grep -q '/sddm\.service$'; then
        rm -f "$DISPLAY_MANAGER_SERVICE_LINK"
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

# Plasma/GNOME theo process đang chạy thật — không dùng marker, vì marker có từ lúc
# còn ở phiên GNOME (trước reboot)
in_plasma_session() {
    pgrep -x plasmashell >/dev/null 2>&1 && ! pgrep -x gnome-shell >/dev/null 2>&1
}

gnome_installed() {
    dpkg-query -W -f='${Status}\n' gdm3 gnome-shell 2>/dev/null | grep -q 'install ok installed'
}

# Purge ngay trong phiên GNOME gần như chắc chắn làm chết session → cài timer, purge khi vào Plasma
install_deferred_purge() {
    if ! mkdir -p "$PURGE_INSTALL_DIR" "$PURGE_UNIT_DIR" || \
       ! cp "$PURGE_GNOME_SCRIPT" "$PURGE_INSTALL_DIR/purge-gnome.sh" || \
       ! chmod 755 "$PURGE_INSTALL_DIR/purge-gnome.sh"; then
        warn "Không cài được script purge GNOME — sau khi vào Plasma, chạy lại Basic chuyển KDE để gỡ GNOME"
        return 1
    fi
    cat > "$PURGE_UNIT_DIR/$PURGE_UNIT_NAME.service" <<EOF
[Unit]
Description=Gỡ GNOME sau khi chuyển sang KDE Plasma (linux-post-install-scripts)

[Service]
Type=oneshot
ExecStart=/bin/sh $PURGE_INSTALL_DIR/purge-gnome.sh check
EOF
    cat > "$PURGE_UNIT_DIR/$PURGE_UNIT_NAME.timer" <<EOF
[Unit]
Description=Kiểm tra phiên Plasma để gỡ GNOME (linux-post-install-scripts)

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
AccuracySec=10s

[Install]
WantedBy=timers.target
EOF
    # Chỉ enable, không start: timer chạy từ lần boot sau, không đụng phiên GNOME hiện tại
    if ! systemctl daemon-reload || ! systemctl enable "$PURGE_UNIT_NAME.timer"; then
        warn "Không bật được timer purge GNOME — sau khi vào Plasma, chạy lại Basic chuyển KDE để gỡ GNOME"
        return 1
    fi
    ok "Đã hẹn gỡ GNOME: tự chạy khi phát hiện phiên Plasma sau reboot"
}

main() {
    detect_desktop
    # Theo desktop đang chạy thật; marker không dùng ở đây vì nó có từ lúc còn ở phiên GNOME
    case "$DESKTOP" in
        *KDE*|*Plasma*)
            if gnome_installed && in_plasma_session; then
                info "Đang ở phiên Plasma nhưng GNOME vẫn còn — gỡ GNOME ngay"
                if sh "$PURGE_GNOME_SCRIPT" now; then
                    ok "Đã gỡ GNOME"
                else
                    warn "Gỡ GNOME chưa thành công — xem log /var/log/linux-post-install-scripts/purge-gnome.log; KDE vẫn dùng bình thường"
                fi
                return 0
            fi
            setup_child_skip "desktop hiện tại đã là KDE/Plasma"
            ;;
    esac
    # Đã chuyển KDE ở lần chạy trước (marker) nhưng vẫn đăng nhập GNOME: KDE/SDDM đã sẵn sàng,
    # timer purge đã hẹn — chỉ cần chọn Plasma ở màn hình đăng nhập
    if setup_kde_switch_succeeded; then
        warn "Đã chuyển sang KDE ở lần chạy trước nhưng đang dùng GNOME — đăng xuất/reboot và chọn Plasma ở màn hình đăng nhập SDDM"
        setup_child_skip "đã cấu hình KDE Plasma và SDDM từ lần chạy trước"
    fi

    info "Desktop hiện tại: ${DESKTOP:-không nhận diện được}; bắt đầu chuyển sang KDE Plasma"
    if ! install_and_configure_kde; then
        warn "Chưa chuyển sang KDE vì bước cài/cấu hình KDE hoặc SDDM chưa thành công"
        return 1
    fi
    if ! mark_kde_switch_succeeded; then
        return 1
    fi

    install_deferred_purge || true
    printf '\n\033[1;32mHoàn tất!\033[0m Hãy reboot, rồi \033[1mchọn Plasma ở màn hình đăng nhập SDDM\033[0m; GNOME sẽ tự được gỡ khi vào phiên Plasma.\n'
}

main
