#!/bin/sh
# install-ai-tools-deb.sh — Cài Claude Desktop (apt repo), Claude Code CLI, Codex CLI
# Chạy: sudo ./install-ai-tools-deb.sh            (hiện menu chọn app)
#       sudo ./install-ai-tools-deb.sh --all | -a (cài tất cả, không hỏi)
#       sudo ./install-ai-tools-deb.sh --help | -h (trợ giúp)
# Yêu cầu: Ubuntu 22.04+ / Debian 12+, kiến trúc amd64 hoặc arm64

set -e

info() { printf '\033[1;34m[ai-tools]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m     %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m   %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m  %s\n' "$*" >&2; exit 1; }

# --- Trợ giúp (không cần root) ---
case "${1:-}" in
    --help|-h)
        echo "Usage: sudo $0 [--all|-a] [--help|-h]"
        echo ""
        echo "  (không đối số)  Hiện menu tương tác để chọn app cài đặt"
        echo "  --all, -a       Cài tất cả, không hiện menu"
        echo "  --help, -h      In trợ giúp này"
        echo ""
        echo "  Các app có thể chọn trong menu:"
        echo "    1) Claude Desktop (apt repo chính thức)"
        echo "    2) Claude Code CLI (cài vào ~/.local/bin)"
        echo "    3) Codex CLI (cài vào ~/.local/bin)"
        exit 0
        ;;
esac

# --- Kiểm tra quyền root ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

# ============================================================
# Các hàm cài đặt (mỗi hàm = 1 mục trong menu)
# ============================================================

# --- Mục 1: Claude Desktop ---
install_claude_desktop() {
    info "Thêm apt repository của Claude Desktop..."
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

    info "Cài Claude Desktop..."
    apt-get update
    apt-get install -y claude-desktop
    ok "Đã cài claude-desktop (cập nhật qua apt như bình thường)"
}

# --- Mục 2: Claude Code CLI ---
install_claude_cli() {
    info "Cài Claude Code CLI..."
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        HOME_USER=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        curl -fsSL https://claude.ai/install.sh -o /tmp/claude-install.sh
        sudo -u "$SUDO_USER" -H bash /tmp/claude-install.sh
        rm -f /tmp/claude-install.sh
        if [ -x "$HOME_USER/.local/bin/claude" ]; then
            ok "Đã cài Claude Code CLI cho user $SUDO_USER (tự cập nhật trong nền)"
        else
            warn "Không thấy ~/.local/bin/claude — kiểm tra lại quá trình cài"
        fi
    else
        warn "Không xác định được user (chạy không qua sudo) — bỏ qua Claude Code CLI"
    fi
}

# --- Mục 3: Codex CLI ---
install_codex_cli() {
    info "Cài Codex CLI..."
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        HOME_USER=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        sudo -u "$SUDO_USER" -H bash -c 'curl -fsSL https://chatgpt.com/codex/install.sh | sh'
        if [ -x "$HOME_USER/.local/bin/codex" ]; then
            ok "Đã cài Codex CLI cho user $SUDO_USER"
        else
            warn "Không thấy ~/.local/bin/codex — kiểm tra lại quá trình cài"
        fi
    else
        warn "Không xác định được user (chạy không qua sudo) — bỏ qua Codex CLI"
    fi
}

# ============================================================
# Menu & chọn app
# ============================================================

# Định nghĩa các mục có thể chọn (label|hàm)
MENU_ITEMS="
Claude Desktop (apt repo chính thức)|install_claude_desktop
Claude Code CLI (cài vào ~/.local/bin)|install_claude_cli
Codex CLI (cài vào ~/.local/bin)|install_codex_cli
"

show_menu() {
    printf '\n'
    printf '\033[1;36m══════════════════════════════════════════\033[0m\n'
    printf '\033[1;36m  Chọn AI tool muốn cài đặt\033[0m\n'
    printf '\033[1;36m══════════════════════════════════════════\033[0m\n'
    i=1
    while IFS='|' read -r label func; do
        [ -z "$label" ] && continue
        printf '  \033[1;33m%d)\033[0m %s\n' "$i" "$label"
        i=$((i + 1))
    done <<EOF
$MENU_ITEMS
EOF
    printf '  \033[1;33ma)\033[0m Cài tất cả (mặc định)\n'
    printf '  \033[1;33mq)\033[0m Thoát (không cài gì thêm)\n'
    printf '\033[1;36m══════════════════════════════════════════\033[0m\n'
    printf 'Nhập số (vd: 1 3) hoặc Enter để cài tất cả: '
}

parse_menu_choice() {
    _input="$1"

    if [ -z "$_input" ] || [ "$_input" = "a" ]; then
        echo "1 2 3"
        return
    fi

    if [ "$_input" = "q" ]; then
        echo "quit"
        return
    fi

    echo "$_input"
}

# ============================================================
# Argument parsing
# ============================================================

ALL=0

case "${1:-}" in
    --all|-a) ALL=1 ;;
    "")       ;;  # Mặc định: hiện menu
    *)        die "Không rõ tuỳ chọn: $1. Dùng --help để xem hướng dẫn." ;;
esac

# ============================================================
# Luôn chạy (không cần chọn)
# ============================================================

# --- Bước 1: Chuẩn bị curl + gpg (Desktop và CLI đều cần) ---
info "Bước 1: Chuẩn bị curl và gpg..."
command -v curl >/dev/null 2>&1 || apt-get install -y curl
command -v gpg  >/dev/null 2>&1 || apt-get install -y gnupg

# --- Bước 2: Thêm ~/.local/bin vào PATH của user ---
info "Bước 2: Thêm ~/.local/bin vào PATH của user..."
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    HOME_USER=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    for rc in "$HOME_USER/.bashrc" "$HOME_USER/.zshrc"; do
        if grep -q 'HOME/.local/bin' "$rc" 2>/dev/null; then
            ok "$(basename "$rc") đã có ~/.local/bin trong PATH — bỏ qua"
        else
            printf '\n# Thêm ~/.local/bin vào PATH (do install-ai-tools-deb.sh)\n%s\n' \
                'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
            ok "Đã thêm ~/.local/bin vào PATH trong $(basename "$rc")"
        fi
    done
else
    warn "Không xác định được user — bỏ qua bước thêm PATH"
fi

# ============================================================
# Chọn app để cài
# ============================================================

if [ "$ALL" -eq 1 ]; then
    SELECTED="1 2 3"
    info "Chế độ --all: cài tất cả"
else
    show_menu
    info "TRƯỚC READ: chờ nhập lựa chọn..."
    read -r USER_CHOICE
    info "SAU READ: nhận được: '$USER_CHOICE'"

    SELECTED=$(parse_menu_choice "$USER_CHOICE")

    if [ "$SELECTED" = "quit" ]; then
        printf '\n\033[1;33mĐã thoát. Các bước đã chạy: curl + gpg + thêm PATH.\033[0m\n'
        exit 0
    fi
    info "Đã nhận input: '$USER_CHOICE' → chọn mục: $SELECTED"
fi

# Chạy các mục đã chọn
for num in $SELECTED; do
    i=1
    while IFS='|' read -r label func; do
        [ -z "$label" ] && continue
        if [ "$i" -eq "$num" ]; then
            printf '\n'
            info "PROCESSING mục $num ($label) — hàm: $func"
            $func
            break
        fi
        i=$((i + 1))
    done <<EOF
$MENU_ITEMS
EOF
done

printf '\n\033[1;32mHoàn tất!\033[0m Bước tiếp theo:\n'
for num in $SELECTED; do
    i=1
    while IFS='|' read -r label func; do
        [ -z "$label" ] && continue
        case "$i-$num" in
            1-1) printf '  - Claude Desktop: mở từ app launcher hoặc lệnh \033[1mclaude-desktop\033[0m, đăng nhập tài khoản Anthropic\n' ;;
            2-2) printf '  - Claude Code: mở terminal mới, chạy \033[1mclaude\033[0m để đăng nhập lần đầu\n' ;;
            3-3) printf '  - Codex CLI: mở terminal mới, chạy \033[1mcodex\033[0m để đăng nhập\n' ;;
        esac
        i=$((i + 1))
    done <<EOF
$MENU_ITEMS
EOF
done
