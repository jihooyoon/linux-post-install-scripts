#!/bin/sh
# @setup-description: Cài các ứng dụng và CLI AI
# @setup-when: always
# @setup-item: install_claude_desktop|Claude Desktop (apt repo chính thức)
# @setup-item: install_claude_cli|Claude Code CLI (cài vào ~/.local/bin)
# @setup-item: install_codex_cli|Codex CLI (cài vào ~/.local/bin)
# 1-install-ai-tools-deb.sh — Cài Claude Desktop (apt repo), Claude Code CLI, Codex CLI
# Chạy: sudo ./1-install-ai-tools-deb.sh [--all|-a|item-number ...]
# Yêu cầu: Ubuntu 22.04+ / Debian 12+, kiến trúc amd64 hoặc arm64

set -e

# Debug mode: chạy với DEBUG=1 ./script.sh để thấy tất cả lệnh đang chạy
[ "${DEBUG:-0}" = "1" ] && set -x

info() { printf '\033[1;34m[ai-tools]\033[0m %s\n' "$*"; }
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

ensure_curl() {
    if ! command -v curl >/dev/null 2>&1; then
        wait_apt
        apt-get install -y curl
    fi
}

ensure_gpg() {
    if ! command -v gpg >/dev/null 2>&1; then
        wait_apt
        apt-get install -y gnupg
    fi
}

ensure_local_bin_path() {
    if [ -z "$SUDO_USER" ] || [ "$SUDO_USER" = "root" ]; then
        warn "Không xác định được user — bỏ qua bước thêm ~/.local/bin vào PATH"
        return 0
    fi

    HOME_USER=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    [ -n "$HOME_USER" ] || {
        warn "Không tìm thấy home của $SUDO_USER — bỏ qua bước thêm PATH"
        return 0
    }

    for rc in "$HOME_USER/.bashrc" "$HOME_USER/.zshrc"; do
        if grep -q 'HOME/.local/bin' "$rc" 2>/dev/null; then
            ok "$(basename "$rc") đã có ~/.local/bin trong PATH — bỏ qua"
        else
            sudo -u "$SUDO_USER" -H sh -c '
                rc=$1
                printf "\n# Thêm ~/.local/bin vào PATH (do AI tools setup)\n%s\n" \
                    '\''export PATH="$HOME/.local/bin:$PATH"'\'' >> "$rc"
            ' sh "$rc"
            ok "Đã thêm ~/.local/bin vào PATH trong $(basename "$rc")"
        fi
    done
}

# ============================================================
# Các hàm cài đặt (mỗi hàm = 1 mục trong menu)
# ============================================================

# --- Mục 1: Claude Desktop ---
install_claude_desktop() {
    ensure_curl
    ensure_gpg
    info "Thêm apt repository của Claude Desktop..."
    CLAUDE_DESKTOP_REPO_PATTERN='https?://downloads\.claude\.ai/claude-desktop/apt/stable/?([[:space:]]|$)'
    CLAUDE_DESKTOP_REPO_FILES=$(grep -rslE "$CLAUDE_DESKTOP_REPO_PATTERN" /etc/apt/sources.list.d/ /etc/apt/sources.list 2>/dev/null || true)
    if [ -n "$CLAUDE_DESKTOP_REPO_FILES" ]; then
        warn "Đã có source Claude Desktop; giữ nguyên và không thêm source mới: $(printf '%s' "$CLAUDE_DESKTOP_REPO_FILES" | tr '\n' ' ')"
    else
        curl -fsSLo /usr/share/keyrings/claude-desktop-archive-keyring.asc \
            https://downloads.claude.ai/claude-desktop/key.asc

        # Xác minh vân tay khóa theo guide (tránh khóa giả mạo)
        FPR=$(gpg --show-keys --with-colons /usr/share/keyrings/claude-desktop-archive-keyring.asc 2>/dev/null \
              | awk -F: '$1=="fpr"{print $10; exit}')
        [ "$FPR" = "31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE" ] \
            || die "Khóa tải về không khớp vân tay Anthropic (nhận: $FPR) — kiểm tra kết nối downloads.claude.ai"
        ok "Đã xác minh khóa Anthropic"

        echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main" \
            > /etc/apt/sources.list.d/claude-desktop.list
    fi

    info "Cài Claude Desktop..."
    wait_apt
    apt-get update
    apt-get install -y claude-desktop
    ok "Đã cài claude-desktop (cập nhật qua apt như bình thường)"
}

# --- Mục 2: Claude Code CLI ---
install_claude_cli() {
    info "Cài Claude Code CLI..."
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        ensure_curl
        HOME_USER=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        curl -fsSL https://claude.ai/install.sh -o /tmp/claude-install.sh
        sudo -u "$SUDO_USER" -H bash /tmp/claude-install.sh
        rm -f /tmp/claude-install.sh
        if [ -x "$HOME_USER/.local/bin/claude" ]; then
            ok "Đã cài Claude Code CLI cho user $SUDO_USER (tự cập nhật trong nền)"
        else
            warn "Không thấy ~/.local/bin/claude — kiểm tra lại quá trình cài"
        fi
        ensure_local_bin_path
    else
        warn "Không xác định được user (chạy không qua sudo) — bỏ qua Claude Code CLI"
    fi
}

# --- Mục 3: Codex CLI ---
install_codex_cli() {
    info "Cài Codex CLI..."
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        ensure_curl
        HOME_USER=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        sudo -u "$SUDO_USER" -H bash -c 'curl -fsSL https://chatgpt.com/codex/install.sh | sh'
        if [ -x "$HOME_USER/.local/bin/codex" ]; then
            ok "Đã cài Codex CLI cho user $SUDO_USER"
        else
            warn "Không thấy ~/.local/bin/codex — kiểm tra lại quá trình cài"
        fi
        ensure_local_bin_path
    else
        warn "Không xác định được user (chạy không qua sudo) — bỏ qua Codex CLI"
    fi
}

if [ -z "$SETUP_SELECTED" ]; then
    warn "Không chọn AI tool nào — không cài dependency, không sửa PATH"
    exit 0
fi

setup_run_selected "$CHILD_FILE" "$SETUP_SELECTED"

printf '\n\033[1;32mHoàn tất các AI tool đã chọn!\033[0m\n'
