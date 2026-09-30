#!/bin/sh
# purge-gnome.sh — gỡ GNOME sau khi đã chuyển sang KDE Plasma, chỉ khi đang ở phiên Plasma
# Basic 1 (chuyển KDE) cài bản copy của file này + timer systemd; purge ngay trong phiên
# GNOME đang chạy gần như chắc chắn làm chết session, nên phải chờ tới phiên Plasma.
#
#   purge-gnome.sh check      Timer gọi mỗi phút: phiên GNOME → nhắc chọn Plasma ở màn hình
#                             đăng nhập; phiên Plasma → mô phỏng rồi purge, xong thì tự gỡ timer
#   purge-gnome.sh now        Purge ngay (Basic 1 gọi khi chạy lại trong phiên Plasma)
#   purge-gnome.sh uninstall  Gỡ timer, service và script đã cài

INSTALL_DIR=${PURGE_GNOME_INSTALL_DIR:-/usr/local/lib/linux-post-install-scripts}
UNIT_DIR=${PURGE_GNOME_UNIT_DIR:-/etc/systemd/system}
LOG_FILE=${PURGE_GNOME_LOG:-/var/log/linux-post-install-scripts/purge-gnome.log}
STATE_DIR=${PURGE_GNOME_STATE_DIR:-/run/linux-post-install-scripts}
UNIT_NAME=linux-post-install-purge-gnome

GNOME_PACKAGES="gnome* gdm3 ubuntu-desktop* ubuntu-session* ubuntu-settings* \
nautilus evince eog gedit gnome-calculator gnome-calendar gnome-characters \
gnome-clocks gnome-contacts gnome-font-viewer gnome-disk-utility \
gnome-system-monitor gnome-screenshot"
# Gói không được phép bị gỡ kèm — có trong danh sách mô phỏng thì dừng
PROTECTED_PACKAGES='^(kde-plasma-desktop|sddm|plasma-.*|kwin-.*)$'

log() {
    mkdir -p "$(dirname -- "$LOG_FILE")" 2>/dev/null
    printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE"
}

# User đang chạy process $1 (plasmashell / gnome-shell); rỗng nếu không có
session_user() {
    _pid=$(pgrep -o -x "$1" 2>/dev/null) || return 1
    ps -o user= -p "$_pid" 2>/dev/null | tr -d ' '
}

notify_user() {
    _user=$1
    shift
    command -v notify-send >/dev/null 2>&1 || return 0
    _uid=$(id -u "$_user" 2>/dev/null) || return 0
    runuser -u "$_user" -- env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$_uid/bus" \
        notify-send -a "linux-post-install-scripts" "$@" >/dev/null 2>&1 || true
}

wait_apt_lock() {
    _wait_i=0
    while fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/lib/dpkg/lock >/dev/null 2>&1; do
        [ "$_wait_i" -lt "${1:-600}" ] || return 1
        sleep 5
        _wait_i=$((_wait_i + 5))
    done
}

gnome_installed() {
    dpkg-query -W -f='${Status}\n' gdm3 gnome-shell 2>/dev/null | grep -q 'install ok installed'
}

# Mô phỏng purge + autoremove; lỗi hoặc đụng gói KDE thì dừng, không gỡ gì
simulate_purge() {
    set -f
    # shellcheck disable=SC2086
    _sim=$(apt-get -s purge --autoremove $GNOME_PACKAGES 2>&1)
    _sim_code=$?
    set +f
    if [ "$_sim_code" -ne 0 ]; then
        log "Mô phỏng purge thất bại (exit $_sim_code) — không gỡ gì:"
        printf '%s\n' "$_sim" | tee -a "$LOG_FILE"
        return 1
    fi
    _hit=$(printf '%s\n' "$_sim" | awk '/^(Purg|Remv) /{print $2}' | grep -E "$PROTECTED_PACKAGES")
    if [ -n "$_hit" ]; then
        log "Mô phỏng cho thấy purge sẽ gỡ cả gói KDE — dừng, không gỡ gì:"
        printf '%s\n' "$_hit" | tee -a "$LOG_FILE"
        return 1
    fi
    log "Mô phỏng OK: sẽ gỡ $(printf '%s\n' "$_sim" | grep -c '^\(Purg\|Remv\) ') gói"
}

run_purge() {
    log "Gỡ GNOME và các gói Ubuntu Desktop..."
    set -f
    # shellcheck disable=SC2086
    DEBIAN_FRONTEND=noninteractive apt-get purge -y --autoremove $GNOME_PACKAGES >> "$LOG_FILE" 2>&1
    _purge_code=$?
    set +f
    if [ "$_purge_code" -ne 0 ]; then
        log "Purge GNOME thất bại (exit $_purge_code)"
        return "$_purge_code"
    fi
    log "Đã purge GNOME"
}

uninstall_self() {
    systemctl disable --now "$UNIT_NAME.timer" >/dev/null 2>&1
    rm -f "$UNIT_DIR/$UNIT_NAME.timer" "$UNIT_DIR/$UNIT_NAME.service"
    systemctl daemon-reload >/dev/null 2>&1
    rm -f "$INSTALL_DIR/purge-gnome.sh"
    rmdir "$INSTALL_DIR" 2>/dev/null
    log "Đã gỡ timer purge GNOME"
}

# Purge khi chắc chắn đang ở phiên Plasma và không còn phiên GNOME nào
purge_in_plasma() {
    _user=$1
    if ! gnome_installed; then
        log "GNOME đã được gỡ từ trước"
        return 0
    fi
    simulate_purge || return 1
    notify_user "$_user" "Đang gỡ GNOME" "Đừng tắt máy cho tới khi có thông báo hoàn tất."
    run_purge
}

cmd_check() {
    if pgrep -x gnome-shell >/dev/null 2>&1; then
        _user=$(session_user gnome-shell)
        _pid=$(pgrep -o -x gnome-shell)
        mkdir -p "$STATE_DIR"
        # Mỗi phiên GNOME chỉ nhắc một lần
        if [ ! -f "$STATE_DIR/gnome-notified-$_pid" ]; then
            : > "$STATE_DIR/gnome-notified-$_pid"
            log "Phát hiện phiên GNOME của $_user — chưa purge, nhắc chọn Plasma"
            notify_user "$_user" "Chưa hoàn tất chuyển sang KDE" \
                "Đang dùng GNOME. Đăng xuất và chọn Plasma ở màn hình đăng nhập để hoàn tất; GNOME sẽ tự được gỡ khi vào Plasma."
        fi
        return 0
    fi
    pgrep -x plasmashell >/dev/null 2>&1 || return 0
    _user=$(session_user plasmashell)
    # apt đang bận (vd unattended-upgrades): để lần kiểm tra sau
    if ! wait_apt_lock 120; then
        log "apt đang bị lock — thử lại ở lần kiểm tra sau"
        return 0
    fi
    if purge_in_plasma "$_user"; then
        notify_user "$_user" "Đã gỡ GNOME" "Chuyển sang KDE Plasma hoàn tất."
    else
        notify_user "$_user" "Gỡ GNOME thất bại" \
            "Xem log $LOG_FILE, rồi chạy lại Basic chuyển KDE (1-switch-to-kde-deb.sh) để thử lại."
    fi
    # Thành công hay thất bại đều gỡ timer — thử lại bằng cách chạy lại Basic chuyển KDE
    uninstall_self
}

cmd_now() {
    if pgrep -x gnome-shell >/dev/null 2>&1; then
        log "Đang có phiên GNOME — không purge. Đăng nhập phiên Plasma rồi chạy lại."
        return 1
    fi
    if ! pgrep -x plasmashell >/dev/null 2>&1; then
        log "Không thấy phiên Plasma đang chạy — không purge"
        return 1
    fi
    wait_apt_lock 600 || { log "apt vẫn bị lock sau 10 phút — không purge"; return 1; }
    purge_in_plasma "$(session_user plasmashell)" || return 1
    [ ! -f "$UNIT_DIR/$UNIT_NAME.timer" ] || uninstall_self
}

case "${1:-}" in
    check) cmd_check ;;
    now) cmd_now ;;
    uninstall) uninstall_self ;;
    *) printf 'Usage: %s check|now|uninstall\n' "$0" >&2; exit 2 ;;
esac
