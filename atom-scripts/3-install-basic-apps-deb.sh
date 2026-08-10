#!/bin/sh
# @setup-description: Cài nền bộ gõ và các app cơ bản
# @setup-when: always
# @setup-core-description: Dùng fcitx5 thay thế ibus (đã lỗi thời)
# @setup-item: install_freeoffice|FreeOffice 2024
# @setup-item: install_libreoffice|LibreOffice
# @setup-item: install_chrome|Google Chrome
# @setup-item: install_chromium|Chromium (.deb thật)
# @setup-item: install_vscode|Visual Studio Code
# 3-install-basic-apps-deb.sh — Ubuntu/Debian: cài fcitx5 và các ứng dụng cơ bản tùy chọn
# Chạy: sudo ./3-install-basic-apps-deb.sh [--all|-a|item-number ...]

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

ensure_curl() {
    command -v curl >/dev/null 2>&1 || apt-get install -y curl
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

# --- Kiểm tra quyền root ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

# ============================================================
# Các hàm cài đặt (mỗi hàm = 1 mục trong menu)
# ============================================================

# --- Reconcile hai bộ Office trước khi cài item ---
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
    run_remote_script \
        https://softmaker.net/down/uninstall-softmaker-freeoffice-2024.sh \
        uninstall-freeoffice || return $?
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

# --- Mục 1: Cài FreeOffice 2024 ---
install_freeoffice() {
    info "Cài FreeOffice 2024..."
    ensure_curl || return $?
    run_remote_script \
        https://softmaker.net/down/install-softmaker-freeoffice-2024.sh \
        install-freeoffice || return $?
    ok "Đã cài FreeOffice 2024"
}

# --- Mục 2: Cài LibreOffice từ repo mặc định ---
install_libreoffice() {
    info "Cài LibreOffice từ repo mặc định của distro..."
    apt-get install -y libreoffice || return $?
    ok "Đã cài LibreOffice"
}

# --- Mục 3: Cài Google Chrome ---
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

# --- Mục 4: Cài Chromium (.deb thật) ---
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

# --- Mục 5: Cài Visual Studio Code ---
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

# ============================================================
# Luôn chạy (không cần chọn)
# ============================================================

# --- Bước 0: Cập nhật danh sách gói ---
info "Bước 0: Cập nhật danh sách gói..."
wait_apt
apt-get update

# --- Bước 1: Cài fcitx5 + config GUI (+ KCM module nếu KDE) ---
info "Bước 1: Cài fcitx5..."
PKGS="fcitx5 fcitx5-config-qt"

KIM=0
case "$XDG_CURRENT_DESKTOP" in
    *KDE*|*Plasma*)
        PKGS="$PKGS kde-config-fcitx5"
        info "Phát hiện KDE — thêm kde-config-fcitx5 (module cấu hình trong System Settings)"
        ;;
    *GNOME*)
        if apt-cache show gnome-shell-extension-manager >/dev/null 2>&1; then
            PKGS="$PKGS gnome-shell-extension-manager"
            info "Phát hiện GNOME — cài thêm Extension Manager (quản lý extension kimpanel)"
        else
            warn "GNOME: repo không có gnome-shell-extension-manager — nếu cần thì cài qua flatpak com.mattjakeman.ExtensionManager"
        fi
        if apt-cache show gnome-shell-extension-kimpanel >/dev/null 2>&1; then
            PKGS="$PKGS gnome-shell-extension-kimpanel"
            KIM=1
            info "Phát hiện GNOME — thêm kimpanel (hiển thị bộ gõ trên status bar)"
        else
            warn "GNOME: repo không có gnome-shell-extension-kimpanel — cài thủ công từ extensions.gnome.org/extension/261"
        fi
        ;;
esac

for eng in fcitx5-unikey fcitx5-bamboo; do
    if apt-cache show "$eng" >/dev/null 2>&1; then
        PKGS="$PKGS $eng"
        info "Có gói $eng — cài thêm bộ gõ tiếng Việt"
    else
        warn "Repo không có $eng — bỏ qua (fcitx5 vẫn gõ được tiếng khác)"
    fi
done

apt-get install -y $PKGS

if [ "$KIM" -eq 1 ]; then
    if [ -n "$SUDO_USER" ]; then
        sudo -u "$SUDO_USER" gnome-extensions enable kimpanel@wengxt 2>/dev/null || true
    fi
    ok "Đã cài kimpanel — đăng xuất/đăng nhập lại, bộ gõ sẽ hiện trên status bar"
    printf 'Nếu chưa thấy bộ gõ: mở app "Extensions" (gnome-extensions-app) và bật kimpanel.\n'
fi

# --- Bước 1b: Purge ibus + autostart fcitx5 ---
info "Bước 1b: Purge ibus và thêm fcitx5 vào autostart..."
if dpkg -l ibus 2>/dev/null | grep -q '^ii'; then
    apt-get purge -y ibus
    apt-get autoremove -y --purge
    rm -rf /root/.config/ibus /root/.cache/ibus \
           /home/*/.config/ibus /home/*/.cache/ibus
    ok "Đã purge sạch ibus"
else
    ok "ibus chưa được cài — bỏ qua"
fi

if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    HOME_USER=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    AUTOSTART="$HOME_USER/.config/autostart"
    sudo -u "$SUDO_USER" mkdir -p "$AUTOSTART"
    if [ -f /usr/share/applications/org.fcitx.Fcitx5.desktop ]; then
        sudo -u "$SUDO_USER" cp /usr/share/applications/org.fcitx.Fcitx5.desktop "$AUTOSTART/"
    else
        cat > "$AUTOSTART/org.fcitx.Fcitx5.desktop" <<'DESKTOP_EOF'
[Desktop Entry]
Type=Application
Name=fcitx5
Comment=Start fcitx5 input method framework
Exec=fcitx5
Icon=fcitx
Terminal=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Phase=Applications
DESKTOP_EOF
        chown "$SUDO_USER" "$AUTOSTART/org.fcitx.Fcitx5.desktop"
    fi
    ok "Đã thêm fcitx5 vào autostart của $SUDO_USER"
else
    warn "Không xác định được user — bỏ qua bước autostart"
fi

ok "Đã cài fcitx5 (đăng xuất/đăng nhập lại để áp dụng)"

if [ -z "$SETUP_SELECTED" ]; then
    warn "Không chọn ứng dụng tùy chọn — chỉ chạy phần core"
else
    reconcile_office_selection
    run_selected_best_effort
fi

printf '\n\033[1;32mHoàn tất!\033[0m Tóm tắt:\n'
printf '  - fcitx5: cài xong, đã purge ibus, autostart sẵn (đăng xuất/đăng nhập lại)\n'
[ -n "$SETUP_SELECTED" ] && printf '  - Các item đã chọn: %s\n' "$SETUP_SELECTED"
