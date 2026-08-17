#!/bin/sh
# @setup-description: Các mục nhỏ lẻ khác (Cài Flameshot, Cloudflare Warp)
# @setup-when: always
# @setup-item: install_flameshot|Flameshot (Better screenshot)
# @setup-item: install_cloudflare_warp|Cloudflare WARP
# Cài tiện ích desktop và mạng tùy chọn cho Ubuntu-based.

set -e
[ "${DEBUG:-0}" = "1" ] && set -x

info() { printf '\033[1;34m[misc]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m   %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2; }
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
    _wait_i=0
    while [ "$_wait_i" -lt 60 ]; do
        if ! fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/lib/dpkg/lock >/dev/null 2>&1; then
            return 0
        fi
        [ "$_wait_i" -ne 0 ] || info "apt/dpkg đang bị lock — đợi giải phóng (tối đa 60s)..."
        sleep 1
        _wait_i=$((_wait_i + 1))
    done
    warn "apt/dpkg vẫn bị lock sau 60s — thử kill process giữ lock..."
    fuser -k /var/lib/dpkg/lock-frontend 2>/dev/null || true
    fuser -k /var/lib/apt/lists/lock 2>/dev/null || true
    fuser -k /var/lib/dpkg/lock 2>/dev/null || true
    sleep 2
}

ensure_warp_prerequisite() {
    _command=$1
    _package=$2
    command -v "$_command" >/dev/null 2>&1 && return 0
    wait_apt || return $?
    apt-get install -y "$_package"
}

spectacle_is_installed() {
    command -v dpkg-query >/dev/null 2>&1 || return 1
    [ "$(dpkg-query -W -f='${db:Status-Status}' spectacle 2>/dev/null)" = installed ]
}

install_flameshot() {
    if setup_is_kde_desktop "$XDG_CURRENT_DESKTOP" && spectacle_is_installed; then
        printf '\033[1;33m[SKIPPED]\033[0m Không cần cài Flameshot: hãy dùng Spectacle được cài sẵn, nó đã đủ tốt.\n'
        return 0
    fi
    info "Cài Flameshot..."
    wait_apt || return $?
    apt-get install -y flameshot
    ok "Đã cài Flameshot"
}

install_cloudflare_warp() {
    ensure_warp_prerequisite curl curl || return $?
    ensure_warp_prerequisite gpg gnupg || return $?
    ensure_warp_prerequisite lsb_release lsb-release || return $?

    info "Thêm keyring Cloudflare WARP theo guide chính thức..."
    mkdir -p /usr/share/keyrings || return $?
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | \
        gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg || return $?

    info "Thêm apt repository Cloudflare WARP..."
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | \
        tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null || return $?

    info "Cập nhật apt và cài Cloudflare WARP..."
    wait_apt || return $?
    apt-get update || return $?
    apt-get install -y cloudflare-warp || return $?
    ok "Đã cài Cloudflare WARP. Dùng warp-cli để đăng ký và kết nối khi cần."
}

run_best_effort() {
    _label=$1
    _function=$2
    if "$_function"; then
        return 0
    fi
    _code=$?
    warn "$_label thất bại (exit $_code) — tiếp tục"
    return 0
}

run_selected_best_effort() {
    _items=$(setup_items "$CHILD_FILE")
    _item_index=1
    while IFS='|' read -r _function _label; do
        [ -n "$_function" ] || continue
        if setup_has_word "$SETUP_SELECTED" "$_item_index"; then
            printf '\n\033[1;36m[item]\033[0m %d) %s\n' "$_item_index" "$_label"
            run_best_effort "$_label" "$_function"
        fi
        _item_index=$((_item_index + 1))
    done <<EOF
$_items
EOF
}

if [ -z "$SETUP_SELECTED" ]; then
    warn "Không chọn mục miscellaneous nào — không thực hiện thay đổi"
    exit 0
fi
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"
run_selected_best_effort
printf '\n\033[1;32mHoàn tất!\033[0m Các mục miscellaneous đã chạy: %s\n' "$SETUP_SELECTED"
