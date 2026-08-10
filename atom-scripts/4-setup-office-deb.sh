#!/bin/sh
# @setup-description: Cài Office
# @setup-when: always
# @setup-item: install_freeoffice|FreeOffice 2024
# @setup-item: install_libreoffice|LibreOffice
# 4-setup-office-deb.sh — Ubuntu/Debian: cài bộ Office tùy chọn
# Chạy: sudo ./4-setup-office-deb.sh [--all|-a|item-number ...]

set -e

[ "${DEBUG:-0}" = "1" ] && set -x

info() { printf '\033[1;34m[office]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m       %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m     %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m    %s\n' "$*" >&2; exit 1; }

CHILD_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CHILD_FILE="$CHILD_DIR/$(basename -- "$0")"
. "$CHILD_DIR/../lib/setup-contract.sh"
setup_child_prepare "$CHILD_FILE" "$@" || exit $?
if [ "$SETUP_SHOW_HELP" -eq 1 ]; then
    setup_print_help "$CHILD_FILE"
    exit 0
fi

ensure_curl() {
    command -v curl >/dev/null 2>&1 || apt-get install -y curl
}

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

prepare_apt() {
    wait_apt
    apt-get update
}

run_remote_script() {
    _url=$1
    _prefix=$2
    _script=$(mktemp "/tmp/${_prefix}.XXXXXX.sh") || return 1
    if ! curl -fsSL "$_url" -o "$_script"; then
        rm -f "$_script"
        return 1
    fi
    if bash "$_script"; then
        _code=0
    else
        _code=$?
    fi
    rm -f "$_script"
    return "$_code"
}

run_best_effort() {
    _label=$1
    _function=$2
    if "$_function"; then
        return 0
    else
        _code=$?
    fi
    warn "$_label thất bại (exit $_code) — tiếp tục"
    return 0
}

[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

purge_libreoffice() {
    info "Gỡ LibreOffice (nếu có)..."
    if dpkg -l 'libreoffice*' 2>/dev/null | grep -q '^ii'; then
        apt-get purge -y 'libreoffice*' || return $?
        apt-get autoremove -y --purge || return $?
        rm -rf /root/.config/libreoffice /root/.cache/libreoffice \
               /home/*/.config/libreoffice /home/*/.cache/libreoffice || return $?
        ok "Đã gỡ sạch LibreOffice"
    else
        ok "LibreOffice chưa được cài — bỏ qua"
    fi
}

purge_freeoffice() {
    info "Gỡ FreeOffice (nếu có)..."
    if ! dpkg -l 'softmaker-freeoffice*' 2>/dev/null | grep -q '^ii' && \
       [ ! -d /usr/share/freeoffice2024 ]; then
        ok "FreeOffice chưa được cài — bỏ qua"
        return 0
    fi
    ensure_curl || return $?
    run_remote_script https://softmaker.net/down/uninstall-softmaker-freeoffice-2024.sh uninstall-freeoffice || return $?
    ok "Đã gỡ FreeOffice 2024"
}

reconcile_office_selection() {
    _want_freeoffice=0
    _want_libreoffice=0
    setup_has_word "$SETUP_SELECTED" 1 && _want_freeoffice=1
    setup_has_word "$SETUP_SELECTED" 2 && _want_libreoffice=1

    if [ "$_want_freeoffice" -eq 1 ] && [ "$_want_libreoffice" -eq 0 ]; then
        run_best_effort "Gỡ LibreOffice" purge_libreoffice
    elif [ "$_want_freeoffice" -eq 0 ] && [ "$_want_libreoffice" -eq 1 ]; then
        run_best_effort "Gỡ FreeOffice" purge_freeoffice
    fi
}

install_freeoffice() {
    info "Cài FreeOffice 2024..."
    ensure_curl || return $?
    run_remote_script https://softmaker.net/down/install-softmaker-freeoffice-2024.sh install-freeoffice || return $?
    ok "Đã cài FreeOffice 2024"
}

install_libreoffice() {
    info "Cài LibreOffice từ repo mặc định của distro..."
    apt-get install -y libreoffice || return $?
    ok "Đã cài LibreOffice"
}

run_selected_best_effort() {
    _items=$(setup_items "$CHILD_FILE")
    _i=1
    while IFS='|' read -r _function _label; do
        [ -n "$_function" ] || continue
        if setup_has_word "$SETUP_SELECTED" "$_i"; then
            printf '\n\033[1;36m[item]\033[0m %d) %s\n' "$_i" "$_label"
            run_best_effort "$_label" "$_function"
        fi
        _i=$((_i + 1))
    done <<EOF
$_items
EOF
}

if [ -z "$SETUP_SELECTED" ]; then
    warn "Không chọn bộ Office nào — không thực hiện thay đổi"
    exit 0
fi

prepare_apt
reconcile_office_selection
run_selected_best_effort

printf '\n\033[1;32mHoàn tất!\033[0m Các lựa chọn Office đã chạy: %s\n' "$SETUP_SELECTED"
