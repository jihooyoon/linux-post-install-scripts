#!/bin/sh
# @setup-description: Cài bộ công cụ phát triển cơ bản
# @setup-when: always
# @setup-core-description: Cài Node.js LTS từ NodeSource
# 4-install-basic-dev-works.sh — Cài các công cụ dev cơ bản: Node.js (NodeSource LTS)
# Chạy: sudo ./4-install-basic-dev-works.sh

set -e

# Debug mode: chạy với DEBUG=1 ./script.sh để thấy tất cả lệnh đang chạy
[ "${DEBUG:-0}" = "1" ] && set -x

info() { printf '\033[1;34m[dev-tools]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m        %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m      %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m     %s\n' "$*" >&2; exit 1; }

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

# --- Kiểm tra quyền root ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

# --- Bước 1: Cài Node.js LTS từ NodeSource ---
info "Bước 1: Cài Node.js LTS từ NodeSource..."
wait_apt
command -v curl >/dev/null 2>&1 || apt-get install -y curl
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs
ok "Đã cài Node.js $(node --version)"

printf '\n\033[1;32mHoàn tất!\033[0m\n'
printf '  - Node.js: %s (LTS từ NodeSource)\n' "$(node --version)"
printf '  - npm:     %s (đi kèm Node.js)\n'    "$(npm --version)"
