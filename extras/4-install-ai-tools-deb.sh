#!/bin/sh
# @setup-description: Cài AI Tools
# @setup-when: always
# @setup-item: install_claude_desktop|Claude Desktop
# @setup-item: install_claude_cli|Claude Code CLI
# @setup-item: install_codex_cli|Codex CLI
# 4-install-ai-tools-deb.sh — Cài Claude Desktop (apt repo), Claude Code CLI, Codex CLI
# Chạy: sudo ./4-install-ai-tools-deb.sh [--all|-a|item-number ...]
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
        wait_apt || return $?
        apt-get install -y curl || return $?
    fi
}

ensure_gpg() {
    if ! command -v gpg >/dev/null 2>&1; then
        wait_apt || return $?
        apt-get install -y gnupg || return $?
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
            ' sh "$rc" || return $?
            ok "Đã thêm ~/.local/bin vào PATH trong $(basename "$rc")"
        fi
    done
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

# ============================================================
# Các hàm cài đặt (mỗi hàm = 1 mục trong menu)
# ============================================================

# --- Mục 1: Claude Desktop ---
install_claude_desktop() {
    ensure_curl || return $?
    ensure_gpg || return $?
    info "Thêm apt repository của Claude Desktop..."
    CLAUDE_DESKTOP_REPO_PATTERN='https?://downloads\.claude\.ai/claude-desktop/apt/stable/?([[:space:]]|$)'
    CLAUDE_DESKTOP_REPO_FILES=$(grep -rslE "$CLAUDE_DESKTOP_REPO_PATTERN" /etc/apt/sources.list.d/ /etc/apt/sources.list 2>/dev/null || true)
    if [ -n "$CLAUDE_DESKTOP_REPO_FILES" ]; then
        warn "Đã có source Claude Desktop; giữ nguyên và không thêm source mới: $(printf '%s' "$CLAUDE_DESKTOP_REPO_FILES" | tr '\n' ' ')"
    else
        mkdir -p /usr/share/keyrings || return $?
        if ! curl -fsSLo /usr/share/keyrings/claude-desktop-archive-keyring.asc \
            https://downloads.claude.ai/claude-desktop/key.asc; then
            return 1
        fi

        # Xác minh vân tay khóa theo guide (tránh khóa giả mạo)
        FPR=$(gpg --show-keys --with-colons /usr/share/keyrings/claude-desktop-archive-keyring.asc 2>/dev/null \
              | awk -F: '$1=="fpr"{print $10; exit}')
        if [ "$FPR" != "31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE" ]; then
            rm -f /usr/share/keyrings/claude-desktop-archive-keyring.asc
            warn "Khóa tải về không khớp vân tay Anthropic (nhận: $FPR) — bỏ qua Claude Desktop"
            return 1
        fi
        ok "Đã xác minh khóa Anthropic"

        if ! printf '%s\n' \
            "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main" \
            > /etc/apt/sources.list.d/claude-desktop.list; then
            return 1
        fi
    fi

    info "Cài Claude Desktop..."
    wait_apt || return $?
    apt-get update || return $?
    apt-get install -y claude-desktop || return $?
    ok "Đã cài claude-desktop (cập nhật qua apt như bình thường)"
}

# --- Mục 2: Claude Code CLI ---
install_claude_cli() {
    info "Cài Claude Code CLI..."
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        ensure_curl || return $?
        HOME_USER=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        [ -n "$HOME_USER" ] || { warn "Không tìm thấy home của $SUDO_USER"; return 1; }
        CLAUDE_INSTALL=$(mktemp /tmp/claude-install.XXXXXX.sh) || return 1
        if ! curl -fsSL https://claude.ai/install.sh -o "$CLAUDE_INSTALL"; then
            rm -f "$CLAUDE_INSTALL"
            return 1
        fi
        if ! chmod 644 "$CLAUDE_INSTALL"; then
            rm -f "$CLAUDE_INSTALL"
            return 1
        fi
        if ! sudo -u "$SUDO_USER" -H bash "$CLAUDE_INSTALL"; then
            rm -f "$CLAUDE_INSTALL"
            return 1
        fi
        rm -f "$CLAUDE_INSTALL"
        if [ -x "$HOME_USER/.local/bin/claude" ]; then
            ok "Đã cài Claude Code CLI cho user $SUDO_USER (tự cập nhật trong nền)"
        else
            warn "Không thấy ~/.local/bin/claude — kiểm tra lại quá trình cài"
            return 1
        fi
        ensure_local_bin_path || return $?
    else
        warn "Không xác định được user (chạy không qua sudo) — bỏ qua Claude Code CLI"
        return 1
    fi
}

# --- Mục 3: Codex CLI ---
install_codex_cli() {
    info "Cài Codex CLI..."
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        ensure_curl || return $?
        HOME_USER=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        [ -n "$HOME_USER" ] || { warn "Không tìm thấy home của $SUDO_USER"; return 1; }
        CODEX_INSTALL=$(mktemp /tmp/codex-install.XXXXXX.sh) || return 1
        if ! curl -fsSL https://chatgpt.com/codex/install.sh -o "$CODEX_INSTALL"; then
            rm -f "$CODEX_INSTALL"
            return 1
        fi
        if ! chmod 644 "$CODEX_INSTALL"; then
            rm -f "$CODEX_INSTALL"
            return 1
        fi
        if ! sudo -u "$SUDO_USER" -H env CODEX_NON_INTERACTIVE=1 sh "$CODEX_INSTALL"; then
            rm -f "$CODEX_INSTALL"
            return 1
        fi
        rm -f "$CODEX_INSTALL"
        if [ -x "$HOME_USER/.local/bin/codex" ]; then
            ok "Đã cài Codex CLI cho user $SUDO_USER"
        else
            warn "Không thấy ~/.local/bin/codex — kiểm tra lại quá trình cài"
            return 1
        fi
        ensure_local_bin_path || return $?
    else
        warn "Không xác định được user (chạy không qua sudo) — bỏ qua Codex CLI"
        return 1
    fi
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
    warn "Không chọn AI tool nào — không cài dependency, không sửa PATH"
    exit 0
fi

run_selected_best_effort

printf '\n\033[1;32mHoàn tất các AI tool đã chọn!\033[0m\n'
