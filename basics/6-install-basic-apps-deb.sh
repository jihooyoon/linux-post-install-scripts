#!/bin/sh
# @setup-description: Cài các app cơ bản (Chrome, Chromium, VSCode, )
# @setup-when: always
# @setup-item: install_chrome|Google Chrome
# @setup-item: install_chromium|Chromium (.deb thật)
# @setup-item: install_vscode|Visual Studio Code
# 6-install-basic-apps-deb.sh — Ubuntu/Debian: cài các ứng dụng cơ bản tùy chọn
# Chạy: sudo ./6-install-basic-apps-deb.sh [--all|-a|item-number ...]

set -e

# Debug mode: chạy với DEBUG=1 ./script.sh để thấy tất cả lệnh đang chạy
[ "${DEBUG:-0}" = "1" ] && set -x

info() { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m      %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m    %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m   %s\n' "$*" >&2; exit 1; }

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

# --- Kiểm tra quyền root ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

# ============================================================
# Các hàm cài đặt (mỗi hàm = 1 mục trong menu)
# ============================================================

# --- Mục 1: Cài Google Chrome ---
install_chrome() {
    info "Cài Google Chrome..."
    CHROME_REPO_PATTERN='https?://dl\.google\.com/linux/chrome/deb/?([[:space:]]|$)'
    CHROME_REPO_FILES=$(grep -rslE "$CHROME_REPO_PATTERN" /etc/apt/sources.list.d/ /etc/apt/sources.list 2>/dev/null || true)
    if [ -n "$CHROME_REPO_FILES" ]; then
        warn "Đã có source Google Chrome; giữ nguyên và không thêm source mới: $(printf '%s' "$CHROME_REPO_FILES" | tr '\n' ' ')"
    else
        ensure_curl || return $?
        command -v gpg >/dev/null 2>&1 || apt-get install -y gpg || return $?
        mkdir -p /etc/apt/keyrings || return $?
        CHROME_KEY=$(mktemp /tmp/google-chrome-key.XXXXXX) || return 1
        if ! curl -fsSL https://dl.google.com/linux/linux_signing_key.pub -o "$CHROME_KEY"; then
            rm -f "$CHROME_KEY"
            return 1
        fi
        if ! gpg --yes --dearmor -o /etc/apt/keyrings/google-chrome.gpg "$CHROME_KEY"; then
            rm -f "$CHROME_KEY"
            return 1
        fi
        rm -f "$CHROME_KEY"
        printf '%s\n' \
            "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
            > /etc/apt/sources.list.d/google-chrome.list || return $?
    fi
    apt-get update || return $?
    apt-get install -y google-chrome-stable || return $?
    ok "Đã cài Google Chrome"
}

# --- Mục 2: Cài Chromium (.deb thật) ---
install_chromium() {
    info "Cài Chromium..."
    HAS_CHROMIUM=0
    for pkg in chromium chromium-browser; do
        # Lưu ý: gói purely virtual (vd: chromium trên Ubuntu 24.04) — apt-cache show
        # vẫn exit 0 nhưng stdout rỗng, nên phải kiểm tra record có nội dung thật
        if RECORD=$(apt-cache show "$pkg" 2>/dev/null) && [ -n "$RECORD" ] && \
           ! printf '%s\n' "$RECORD" | grep -qE '(Pre-?)?Depends:.*snapd'; then
            HAS_CHROMIUM=1
            CHROMIUM_PKG="$pkg"
            break
        fi
    done

    if [ "$HAS_CHROMIUM" -eq 1 ]; then
        info "Repo hiện tại có $CHROMIUM_PKG (.deb thật) — cài trực tiếp"
        apt-get install -y "$CHROMIUM_PKG" || return $?
    else
        # Fallback: thêm Linux Mint repo (chỉ lấy chromium)
        warn "Repo không có chromium .deb — thêm Linux Mint repo (chỉ chromium)"
        ensure_curl || return $?
        UBUNTU_CODENAME=$(grep -oP 'VERSION_CODENAME=\K.*' /etc/os-release 2>/dev/null || lsb_release -sc 2>/dev/null || true)
        case "$UBUNTU_CODENAME" in
            jammy)  MINT_SUITE="virginia"  ;;  # 22.04 → Mint 21.x
            noble)  MINT_SUITE="wilma"     ;;  # 24.04 → Mint 22.x
            *)      MINT_SUITE="zena"      ;;  # 26.04+ → Mint 23
        esac
        MINT_REPO_PATTERN='https?://packages\.linuxmint\.com/?([[:space:]]|$)'
        MINT_REPO_FILES=$(grep -rslE "$MINT_REPO_PATTERN" /etc/apt/sources.list.d/ /etc/apt/sources.list 2>/dev/null || true)
        if [ -n "$MINT_REPO_FILES" ]; then
            warn "Đã có source Linux Mint; giữ nguyên và không thêm source mới: $(printf '%s' "$MINT_REPO_FILES" | tr '\n' ' ')"
        else
            # Cài linuxmint-keyring
            MINT_KEYRING_URL="http://packages.linuxmint.com/pool/main/l/linuxmint-keyring"
            MINT_KEYRING_INDEX=$(curl -fsSL "$MINT_KEYRING_URL/" 2>/dev/null) || return $?
            KEYRING_DEB=$(printf '%s\n' "$MINT_KEYRING_INDEX" | \
                grep -oP 'linuxmint-keyring_[^"]+_all\.deb' | sort -V | tail -1)
            if [ -z "$KEYRING_DEB" ]; then
                warn "Không tìm thấy linuxmint-keyring — kiểm tra kết nối mạng"
                return 1
            fi
            TMP_DEB=$(mktemp /tmp/linuxmint-keyring.XXXXXX.deb) || return 1
            if ! curl -fsSL "$MINT_KEYRING_URL/$KEYRING_DEB" -o "$TMP_DEB"; then
                rm -f "$TMP_DEB"
                return 1
            fi
            if ! dpkg -i "$TMP_DEB"; then
                rm -f "$TMP_DEB"
                return 1
            fi
            rm -f "$TMP_DEB"
            mkdir -p /etc/apt/keyrings || return $?
            if [ -f /etc/apt/trusted.gpg.d/linuxmint-keyring.gpg ]; then
                mv /etc/apt/trusted.gpg.d/linuxmint-keyring.gpg /etc/apt/keyrings/ || return $?
            fi
            # Thêm repo Mint (Include: chromium — apt 26.04+ chỉ lấy chromium)
            if ! printf '%s\n' \
                '# Linux Mint repo — chỉ lấy chromium, không ảnh hưởng gì đến hệ thống' \
                'Types: deb' \
                'URIs: http://packages.linuxmint.com' \
                "Suites: $MINT_SUITE" \
                'Components: upstream' \
                'Include: chromium' \
                'Signed-By: /etc/apt/keyrings/linuxmint-keyring.gpg' \
                > /etc/apt/sources.list.d/linuxmint.sources; then
                return 1
            fi
        fi
        apt-get update || return $?
        apt-get install -y chromium || return $?
    fi
    ok "Đã cài Chromium"
}

# --- Mục 3: Cài Visual Studio Code ---
install_vscode() {
    info "Cài Visual Studio Code..."
    # /repos/code là source APT chính thức hiện tại. /repos/vscode là source legacy
    # khác endpoint, nên chỉ cảnh báo riêng thay vì coi là source trùng gây conflict.
    VSCODE_CODE_REPO_PATTERN='https?://packages\.microsoft\.com/repos/code/?([[:space:]]|$)'
    VSCODE_LEGACY_REPO_PATTERN='https?://packages\.microsoft\.com/repos/vscode/?([[:space:]]|$)'
    VSCODE_CODE_REPO_FILES=$(grep -rslE "$VSCODE_CODE_REPO_PATTERN" /etc/apt/sources.list.d/ /etc/apt/sources.list 2>/dev/null || true)
    VSCODE_LEGACY_REPO_FILES=$(grep -rslE "$VSCODE_LEGACY_REPO_PATTERN" /etc/apt/sources.list.d/ /etc/apt/sources.list 2>/dev/null || true)
    if [ -n "$VSCODE_CODE_REPO_FILES" ]; then
        warn "Đã có source VS Code chính thức (/repos/code); giữ nguyên và không thêm source mới: $(printf '%s' "$VSCODE_CODE_REPO_FILES" | tr '\n' ' ')"
    elif [ -n "$VSCODE_LEGACY_REPO_FILES" ]; then
        warn "Đã có source VS Code legacy (/repos/vscode); giữ nguyên và không thêm source /repos/code: $(printf '%s' "$VSCODE_LEGACY_REPO_FILES" | tr '\n' ' ')"
    else
        ensure_curl || return $?
        command -v gpg >/dev/null 2>&1 || apt-get install -y gpg || return $?
        mkdir -p /etc/apt/keyrings || return $?
        # Ghi key vào file tạm rồi mv để không để lại key cụt nếu gpg bị lỗi giữa chừng.
        VSCODE_KEY=$(mktemp /tmp/microsoft-key.XXXXXX) || return 1
        if ! curl -fsSL https://packages.microsoft.com/keys/microsoft.asc -o "$VSCODE_KEY"; then
            rm -f "$VSCODE_KEY"
            return 1
        fi
        if ! gpg --yes --dearmor -o /etc/apt/keyrings/microsoft.gpg.tmp "$VSCODE_KEY"; then
            rm -f "$VSCODE_KEY"
            return 1
        fi
        rm -f "$VSCODE_KEY"
        mv -f /etc/apt/keyrings/microsoft.gpg.tmp /etc/apt/keyrings/microsoft.gpg || return $?

        printf '%s\n' \
            "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
            > /etc/apt/sources.list.d/vscode.list || return $?
    fi

    apt-get update || return $?
    apt-get install -y code || return $?
    ok "Đã cài Visual Studio Code"
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
    warn "Không chọn ứng dụng tùy chọn — không thực hiện thay đổi"
else
    prepare_apt
    run_selected_best_effort
fi

printf '\n\033[1;32mHoàn tất!\033[0m Tóm tắt:\n'
[ -n "$SETUP_SELECTED" ] && printf '  - Các item đã chọn: %s\n' "$SETUP_SELECTED"
exit 0
