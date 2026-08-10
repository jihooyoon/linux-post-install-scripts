#!/bin/sh
# @setup-description: Cài Office
# @setup-when: always
# @setup-item: install_onlyoffice|OnlyOffice (Tương thích tốt, hiệu năng ổn)
# @setup-item: install_freeoffice|FreeOffice 2024 (Tương thích ổn, hiệu năng tốt)
# @setup-item: install_libreoffice|LibreOffice (Tương thích kém, hiệu năng tốt)
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

ensure_gpg() {
    command -v gpg >/dev/null 2>&1 || apt-get install -y gpg
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

purge_onlyoffice() {
    info "Gỡ ONLYOFFICE (nếu có)..."
    if ! dpkg -l onlyoffice-desktopeditors 2>/dev/null | grep -q '^ii' && \
       [ ! -d /opt/onlyoffice ]; then
        ok "ONLYOFFICE chưa được cài — bỏ qua"
        return 0
    fi

    if dpkg -l onlyoffice-desktopeditors 2>/dev/null | grep -q '^ii'; then
        apt-get purge -y onlyoffice-desktopeditors || return $?
        apt-get autoremove -y --purge || return $?
    fi
    rm -rf /opt/onlyoffice \
           /root/.config/onlyoffice /root/.local/share/onlyoffice /root/.cache/onlyoffice \
           /home/*/.config/onlyoffice /home/*/.local/share/onlyoffice /home/*/.cache/onlyoffice || return $?
    rm -f /usr/share/applications/onlyoffice-desktopeditors.desktop \
          /usr/local/share/applications/onlyoffice-desktopeditors.desktop \
          /usr/bin/desktopeditors /usr/local/bin/desktopeditors || return $?
    ok "Đã gỡ sạch ONLYOFFICE"
}

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
    setup_has_word "$SETUP_SELECTED" 1 || run_best_effort "Gỡ ONLYOFFICE" purge_onlyoffice
    setup_has_word "$SETUP_SELECTED" 2 || run_best_effort "Gỡ FreeOffice" purge_freeoffice
    setup_has_word "$SETUP_SELECTED" 3 || run_best_effort "Gỡ LibreOffice" purge_libreoffice
}

install_onlyoffice() {
    if [ "$(getconf LONG_BIT 2>/dev/null || true)" != "64" ]; then
        warn "ONLYOFFICE Desktop Editors chỉ hỗ trợ hệ thống 64-bit"
        return 1
    fi

    info "Cài ONLYOFFICE Desktop Editors..."
    ONLYOFFICE_REPO_PATTERN='https?://download\.onlyoffice\.com/repo/debian/?([[:space:]]|$)'
    ONLYOFFICE_REPO_FILES=$(grep -rslE "$ONLYOFFICE_REPO_PATTERN" /etc/apt/sources.list.d/ /etc/apt/sources.list 2>/dev/null || true)
    if [ -n "$ONLYOFFICE_REPO_FILES" ]; then
        warn "Đã có source ONLYOFFICE; giữ nguyên source và keyring hiện có: $(printf '%s' "$ONLYOFFICE_REPO_FILES" | tr '\n' ' ')"
    else
        ensure_gpg || return $?
        mkdir -p -m 700 ~/.gnupg || return $?
        rm -f /tmp/onlyoffice.gpg
        if ! gpg --no-default-keyring --keyring gnupg-ring:/tmp/onlyoffice.gpg \
            --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys CB2DE8E5; then
            rm -f /tmp/onlyoffice.gpg
            return 1
        fi
        if ! chmod 644 /tmp/onlyoffice.gpg || ! chown root:root /tmp/onlyoffice.gpg; then
            rm -f /tmp/onlyoffice.gpg
            return 1
        fi
        mkdir -p /usr/share/keyrings || { rm -f /tmp/onlyoffice.gpg; return 1; }
        if ! mv -f /tmp/onlyoffice.gpg /usr/share/keyrings/onlyoffice.gpg; then
            rm -f /tmp/onlyoffice.gpg
            return 1
        fi
        if ! printf '%s\n' \
            'deb [signed-by=/usr/share/keyrings/onlyoffice.gpg] https://download.onlyoffice.com/repo/debian squeeze main' \
            > /etc/apt/sources.list.d/onlyoffice.list; then
            return 1
        fi
        ok "Đã thêm source ONLYOFFICE"
    fi

    apt-get update || return $?
    apt-get install -y onlyoffice-desktopeditors || return $?
    ok "Đã cài ONLYOFFICE Desktop Editors"
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
    _selected_items=$(setup_items "$CHILD_FILE")
    _selected_item_index=1
    while IFS='|' read -r _selected_function _selected_label; do
        [ -n "$_selected_function" ] || continue
        if setup_has_word "$SETUP_SELECTED" "$_selected_item_index"; then
            printf '\n\033[1;36m[item]\033[0m %d) %s\n' "$_selected_item_index" "$_selected_label"
            run_best_effort "$_selected_label" "$_selected_function"
        fi
        _selected_item_index=$((_selected_item_index + 1))
    done <<EOF
$_selected_items
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
