#!/bin/sh
# install-basic-apps-deb.sh — Ubuntu/Debian: gỡ sạch LibreOffice, cài fcitx5 (purge ibus, autostart) + FreeOffice
# Chạy: sudo ./install-basic-apps-deb.sh

set -e

info() { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m      %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m    %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m   %s\n' "$*" >&2; exit 1; }

# --- Kiểm tra quyền root ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

# --- Bước 0: Cập nhật danh sách gói ---
info "Bước 0: Cập nhật danh sách gói..."
apt-get update

# --- Bước 1: Gỡ sạch sẽ LibreOffice nếu có ---
info "Bước 1: Gỡ sạch LibreOffice (nếu có)..."
if dpkg -l 'libreoffice*' 2>/dev/null | grep -q '^ii'; then
    apt-get purge -y 'libreoffice*'
    apt-get autoremove -y --purge
    # Dọn cả cấu hình người dùng cho "thật sạch sẽ"
    rm -rf /root/.config/libreoffice /root/.cache/libreoffice \
           /home/*/.config/libreoffice /home/*/.cache/libreoffice
    ok "Đã gỡ sạch LibreOffice"
else
    ok "LibreOffice chưa được cài — bỏ qua"
fi

# --- Bước 2: Cài fcitx5 + config GUI (+ KCM module nếu KDE) ---
info "Bước 2: Cài fcitx5..."
# fcitx5-config-qt: GUI config; frontends được apt tự kéo theo (Recommends)
PKGS="fcitx5 fcitx5-config-qt"

KIM=0
case "$XDG_CURRENT_DESKTOP" in
    *KDE*|*Plasma*)
        PKGS="$PKGS kde-config-fcitx5"
        info "Phát hiện KDE — thêm kde-config-fcitx5 (module cấu hình trong System Settings)"
        ;;
    *GNOME*)
        # Extension Manager: cần để cài/bật extension kimpanel thủ công từ extensions.gnome.org
        if apt-cache show gnome-shell-extension-manager >/dev/null 2>&1; then
            PKGS="$PKGS gnome-shell-extension-manager"
            info "Phát hiện GNOME — cài thêm Extension Manager (quản lý extension kimpanel)"
        else
            warn "GNOME: repo không có gnome-shell-extension-manager — nếu cần thì cài qua flatpak com.mattjakeman.ExtensionManager"
        fi
        # kimpanel: hiển thị bộ gõ trên status bar + cửa sổ gợi ý (Wayland cần mới thấy được)
        if apt-cache show gnome-shell-extension-kimpanel >/dev/null 2>&1; then
            PKGS="$PKGS gnome-shell-extension-kimpanel"
            KIM=1
            info "Phát hiện GNOME — thêm kimpanel (hiển thị bộ gõ trên status bar)"
        else
            warn "GNOME: repo không có gnome-shell-extension-kimpanel — cài thủ công từ extensions.gnome.org/extension/261"
        fi
        ;;
esac

# Bộ gõ tiếng Việt — chỉ cài gói nào repo có (unikey, bamboo)
for eng in fcitx5-unikey fcitx5-bamboo; do
    if apt-cache show "$eng" >/dev/null 2>&1; then
        PKGS="$PKGS $eng"
        info "Có gói $eng — cài thêm bộ gõ tiếng Việt"
    else
        warn "Repo không có $eng — bỏ qua (fcitx5 vẫn gõ được tiếng khác)"
    fi
done

apt-get install -y $PKGS

# Bật extension kimpanel cho user (nếu chạy bằng sudo); không bật được thì hướng dẫn tay
if [ "$KIM" -eq 1 ]; then
    if [ -n "$SUDO_USER" ]; then
        sudo -u "$SUDO_USER" gnome-extensions enable kimpanel@wengxt 2>/dev/null || true
    fi
    ok "Đã cài kimpanel — đăng xuất/đăng nhập lại, bộ gõ sẽ hiện trên status bar"
    printf 'Nếu chưa thấy bộ gõ: mở app "Extensions" (gnome-extensions-app) và bật kimpanel.\n'
fi

# --- Bước 2b: Purge ibus + autostart fcitx5 ---
# ibus là IM framework mặc định của Ubuntu, khởi động qua gnome-shell/DBus (không có
# XDG autostart để tắt) → muốn tắt hẳn thì purge sạch. gnome-shell chỉ cần thư viện
# libibus nên vẫn hoạt động tốt sau khi purge.
info "Bước 2b: Purge ibus và thêm fcitx5 vào autostart..."
if dpkg -l ibus 2>/dev/null | grep -q '^ii'; then
    apt-get purge -y ibus
    apt-get autoremove -y --purge
    # Dọn config user còn sót (đồng phong cách bước gỡ LibreOffice)
    rm -rf /root/.config/ibus /root/.cache/ibus \
           /home/*/.config/ibus /home/*/.cache/ibus
    ok "Đã purge sạch ibus"
else
    ok "ibus chưa được cài — bỏ qua"
fi

# Autostart fcitx5 qua XDG (~/.config/autostart): hoạt động trên GNOME cả X11 lẫn
# Wayland (Wayland không đọc Xsession.d của im-config). Dùng desktop file của gói
# để giữ đúng Icon/Exec.
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    HOME_USER=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    AUTOSTART="$HOME_USER/.config/autostart"
    sudo -u "$SUDO_USER" mkdir -p "$AUTOSTART"
    if [ -f /usr/share/applications/org.fcitx.Fcitx5.desktop ]; then
        sudo -u "$SUDO_USER" cp /usr/share/applications/org.fcitx.Fcitx5.desktop "$AUTOSTART/"
    else
        # Fallback: tạo entry tối thiểu
        cat > "$AUTOSTART/org.fcitx.Fcitx5.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=fcitx5
Comment=Start fcitx5 input method framework
Exec=fcitx5
Icon=fcitx
Terminal=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Phase=Applications
EOF
        chown "$SUDO_USER" "$AUTOSTART/org.fcitx.Fcitx5.desktop"
    fi
    ok "Đã thêm fcitx5 vào autostart của $SUDO_USER"
else
    warn "Không xác định được user — bỏ qua bước autostart"
fi

ok "Đã cài fcitx5 (đăng xuất/đăng nhập lại để áp dụng)"

# --- Bước 3: Cài FreeOffice 2024 ---
info "Bước 3: Cài FreeOffice 2024..."
# Script chạy với quyền root sẵn rồi nên không cần su -c như tài liệu gốc
command -v curl >/dev/null 2>&1 || apt-get install -y curl
curl -fsSL https://softmaker.net/down/install-softmaker-freeoffice-2024.sh | bash
ok "Đã cài FreeOffice 2024"

# --- Bước 4: Cài Google Chrome (repo chính thức của Google) ---
info "Bước 4: Cài Google Chrome..."
command -v gpg >/dev/null 2>&1 || apt-get install -y gpg
mkdir -p /etc/apt/keyrings
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
    > /etc/apt/sources.list.d/google-chrome.list
apt-get update
apt-get install -y google-chrome-stable
ok "Đã cài Google Chrome"

# --- Bước 5: Cài Chromium (ưu tiên .deb từ repo có sẵn, fallback Linux Mint repo) ---
info "Bước 5: Cài Chromium..."
HAS_CHROMIUM=0
for pkg in chromium chromium-browser; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
        # Bỏ qua nếu là snap transitional (Depends: snapd)
        if ! apt-cache show "$pkg" 2>/dev/null | grep -q 'Depends:.*snapd'; then
            HAS_CHROMIUM=1
            CHROMIUM_PKG="$pkg"
            break
        fi
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

# --- Bước 6: Cài Visual Studio Code (repo chính thức của Microsoft) ---
info "Bước 6: Cài Visual Studio Code..."
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    > /etc/apt/sources.list.d/vscode.list
apt-get update
apt-get install -y code
ok "Đã cài Visual Studio Code"

printf '\n\033[1;32mHoàn tất!\033[0m Tóm tắt:\n'
printf '  - LibreOffice: đã gỡ sạch\n'
printf '  - fcitx5: cài xong, đã purge ibus, autostart sẵn (đăng xuất/đăng nhập lại)\n'
printf '  - FreeOffice 2024: đã cài\n'
printf '  - Google Chrome: repo chính thức của Google\n'
printf '  - Chromium: .deb (từ repo có sẵn hoặc Linux Mint)\n'
printf '  - Visual Studio Code: repo chính thức của Microsoft\n'
