#!/bin/sh
# install-basic-apps-deb.sh — Ubuntu/Debian: gỡ sạch LibreOffice, cài fcitx5 (purge ibus, autostart) + FreeOffice
# Chạy: sudo ./install-basic-apps-deb.sh            (hiện menu chọn app)
#       sudo ./install-basic-apps-deb.sh --all | -a (cài tất cả, không hỏi)
#       sudo ./install-basic-apps-deb.sh --help | -h (trợ giúp)

set -e

info() { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m      %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m    %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m   %s\n' "$*" >&2; exit 1; }

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
        echo "    1) LibreOffice → FreeOffice (gỡ LO, cài FreeOffice)"
        echo "    2) Google Chrome"
        echo "    3) Chromium (.deb thật)"
        echo "    4) Visual Studio Code"
        exit 0
        ;;
esac

# --- Kiểm tra quyền root ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

# ============================================================
# Các hàm cài đặt (mỗi hàm = 1 mục trong menu)
# ============================================================

# --- Mục 1: Gỡ LibreOffice + cài FreeOffice 2024 ---
install_freeoffice() {
    # Gỡ sạch LibreOffice nếu có
    info "Gỡ LibreOffice (nếu có)..."
    if dpkg -l 'libreoffice*' 2>/dev/null | grep -q '^ii'; then
        apt-get purge -y 'libreoffice*'
        apt-get autoremove -y --purge
        rm -rf /root/.config/libreoffice /root/.cache/libreoffice \
               /home/*/.config/libreoffice /home/*/.cache/libreoffice
        ok "Đã gỡ sạch LibreOffice"
    else
        ok "LibreOffice chưa được cài — bỏ qua"
    fi

    # Cài FreeOffice 2024
    info "Cài FreeOffice 2024..."
    command -v curl >/dev/null 2>&1 || apt-get install -y curl
    curl -fsSL https://softmaker.net/down/install-softmaker-freeoffice-2024.sh | bash
    ok "Đã cài FreeOffice 2024"
}

# --- Mục 2: Cài Google Chrome ---
install_chrome() {
    info "Cài Google Chrome..."
    command -v gpg >/dev/null 2>&1 || apt-get install -y gpg
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --yes --dearmor -o /etc/apt/keyrings/google-chrome.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
        > /etc/apt/sources.list.d/google-chrome.list
    apt-get update
    apt-get install -y google-chrome-stable
    ok "Đã cài Google Chrome"
}

# --- Mục 3: Cài Chromium (.deb thật) ---
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
        apt-get install -y "$CHROMIUM_PKG"
    else
        # Fallback: thêm Linux Mint repo (chỉ lấy chromium)
        warn "Repo không có chromium .deb — thêm Linux Mint repo (chỉ chromium)"
        command -v curl >/dev/null 2>&1 || apt-get install -y curl
        UBUNTU_CODENAME=$(grep -oP 'VERSION_CODENAME=\K.*' /etc/os-release 2>/dev/null || lsb_release -sc 2>/dev/null || true)
        case "$UBUNTU_CODENAME" in
            jammy)  MINT_SUITE="virginia"  ;;  # 22.04 → Mint 21.x
            noble)  MINT_SUITE="wilma"     ;;  # 24.04 → Mint 22.x
            *)      MINT_SUITE="zena"      ;;  # 26.04+ → Mint 23
        esac
        # Cài linuxmint-keyring
        MINT_KEYRING_URL="http://packages.linuxmint.com/pool/main/l/linuxmint-keyring"
        KEYRING_DEB=$(curl -fsSL "$MINT_KEYRING_URL/" 2>/dev/null | \
            grep -oP 'linuxmint-keyring_[^"]+_all\.deb' | sort -V | tail -1)
        [ -n "$KEYRING_DEB" ] || die "Không tìm thấy linuxmint-keyring — kiểm tra kết nối mạng"
        TMP_DEB=$(mktemp /tmp/linuxmint-keyring.XXXXXX.deb)
        curl -fsSL "$MINT_KEYRING_URL/$KEYRING_DEB" -o "$TMP_DEB"
        dpkg -i "$TMP_DEB"
        rm -f "$TMP_DEB"
        mkdir -p /etc/apt/keyrings
        [ -f /etc/apt/trusted.gpg.d/linuxmint-keyring.gpg ] && \
            mv /etc/apt/trusted.gpg.d/linuxmint-keyring.gpg /etc/apt/keyrings/
        # Thêm repo Mint (Include: chromium — apt 26.04+ chỉ lấy chromium)
        cat > /etc/apt/sources.list.d/linuxmint.sources <<EOF
# Linux Mint repo — chỉ lấy chromium, không ảnh hưởng gì đến hệ thống
Types: deb
URIs: http://packages.linuxmint.com
Suites: $MINT_SUITE
Components: upstream
Include: chromium
Signed-By: /etc/apt/keyrings/linuxmint-keyring.gpg
EOF
        apt-get update
        apt-get install -y chromium
    fi
    ok "Đã cài Chromium"
}

# --- Mục 4: Cài Visual Studio Code ---
install_vscode() {
    info "Cài Visual Studio Code..."
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --yes --dearmor -o /etc/apt/keyrings/microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        > /etc/apt/sources.list.d/vscode.list
    apt-get update
    apt-get install -y code
    ok "Đã cài Visual Studio Code"
}

# ============================================================
# Menu & chọn app
# ============================================================

# Định nghĩa các mục có thể chọn (label|hàm)
MENU_ITEMS="
LibreOffice → FreeOffice (gỡ LO, cài FreeOffice)|install_freeoffice
Google Chrome|install_chrome
Chromium (.deb thật)|install_chromium
Visual Studio Code|install_vscode
"

show_menu() {
    printf '\n'
    printf '\033[1;36m══════════════════════════════════════════\033[0m\n'
    printf '\033[1;36m  Chọn app muốn cài đặt\033[0m\n'
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
    printf 'Nhập số (vd: 1 3 4) hoặc Enter để cài tất cả: '
}

parse_menu_choice() {
    # $1 = raw input string from user
    _input="$1"

    # Mặc định (Enter rỗng) hoặc 'a' → tất cả
    if [ -z "$_input" ] || [ "$_input" = "a" ]; then
        echo "1 2 3 4"
        return
    fi

    # 'q' → thoát
    if [ "$_input" = "q" ]; then
        echo "quit"
        return
    fi

    # Trả về nguyên chuỗi số đã nhập
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

# --- Bước 0: Cập nhật danh sách gói ---
info "Bước 0: Cập nhật danh sách gói..."
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

# ============================================================
# Chọn app để cài
# ============================================================

if [ "$ALL" -eq 1 ]; then
    SELECTED="1 2 3 4"
    info "Chế độ --all: cài tất cả"
else
    show_menu
    info "TRƯỚC READ: chờ nhập lựa chọn..."
    read -r USER_CHOICE
    info "SAU READ: nhận được: '$USER_CHOICE'"

    SELECTED=$(parse_menu_choice "$USER_CHOICE")

    if [ "$SELECTED" = "quit" ]; then
        printf '\n\033[1;33mĐã thoát. Các bước đã chạy: cập nhật gói + fcitx5 + purge ibus.\033[0m\n'
        exit 0
    fi
    info "Đã nhận input: '$USER_CHOICE' → chọn mục: $SELECTED"
fi

# Chạy các mục đã chọn
FIRST=1
for num in $SELECTED; do
    i=1
    while IFS='|' read -r label func; do
        [ -z "$label" ] && continue
        if [ "$i" -eq "$num" ]; then
            printf '\n'
            if [ "$FIRST" -eq 1 ]; then
                FIRST=0
            fi
            info "PROCESSING mục $num ($label) — hàm: $func"
            $func
            break
        fi
        i=$((i + 1))
    done <<EOF
$MENU_ITEMS
EOF
done

printf '\n\033[1;32mHoàn tất!\033[0m Tóm tắt:\n'
printf '  - fcitx5: cài xong, đã purge ibus, autostart sẵn (đăng xuất/đăng nhập lại)\n'
for num in $SELECTED; do
    i=1
    while IFS='|' read -r label func; do
        [ -z "$label" ] && continue
        if [ "$i" -eq "$num" ]; then
            printf '  - %s: đã cài\n' "$label"
            break
        fi
        i=$((i + 1))
    done <<EOF
$MENU_ITEMS
EOF
done
