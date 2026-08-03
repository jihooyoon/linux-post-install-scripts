#!/bin/sh
# install-basic-apps-deb.sh — Ubuntu/Debian: gỡ sạch LibreOffice, cài fcitx5 + FreeOffice
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

ok "Đã cài fcitx5 (đăng xuất/đăng nhập lại để áp dụng)"

# --- Bước 3: Cài FreeOffice 2024 ---
info "Bước 3: Cài FreeOffice 2024..."
# Script chạy với quyền root sẵn rồi nên không cần su -c như tài liệu gốc
command -v curl >/dev/null 2>&1 || apt-get install -y curl
curl -fsSL https://softmaker.net/down/install-softmaker-freeoffice-2024.sh | bash
ok "Đã cài FreeOffice 2024"

# --- Bước 4: Cài Firefox + Thunderbird bản .deb từ PPA mozillateam ---
# (snap vốn là bản mặc định trên Ubuntu 22.04+ — dùng sau khi de-snap)
info "Bước 4: Cài Firefox và Thunderbird bản .deb từ PPA mozillateam..."
command -v add-apt-repository >/dev/null 2>&1 || apt-get install -y software-properties-common
add-apt-repository -y ppa:mozillateam/ppa
apt-get update

# Pin bản .deb từ PPA (1001) và chặn hẳn gói snap transitional của Ubuntu (-1)
cat > /etc/apt/preferences.d/mozillateam-ppa.pref <<'EOF'
# Ưu tiên bản .deb từ PPA mozillateam; chặn hoàn toàn gói snap transitional của Ubuntu
Package: firefox*
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001

Package: firefox*
Pin: release o=Ubuntu
Pin-Priority: -1

Package: thunderbird*
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001

Package: thunderbird*
Pin: release o=Ubuntu
Pin-Priority: -1
EOF

# Gỡ bản snap nếu còn sót
snap remove --purge firefox 2>/dev/null || true
snap remove --purge thunderbird 2>/dev/null || true

# Cài firefox (rapid); nếu repo không có thì fallback sang firefox-esr
if apt-cache show firefox >/dev/null 2>&1; then
    FIREFOX_PKG=firefox
else
    FIREFOX_PKG=firefox-esr
    warn "Repo không có gói firefox (rapid) — cài firefox-esr thay thế"
fi
apt-get install -y "$FIREFOX_PKG" thunderbird
ok "Đã cài $FIREFOX_PKG và Thunderbird bản .deb (cập nhật qua apt như bình thường)"

# --- Bước 5: Cài Google Chrome (repo chính thức của Google) ---
info "Bước 5: Cài Google Chrome..."
command -v gpg >/dev/null 2>&1 || apt-get install -y gpg
mkdir -p /etc/apt/keyrings
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
    > /etc/apt/sources.list.d/google-chrome.list
apt-get update
apt-get install -y google-chrome-stable
ok "Đã cài Google Chrome"

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
printf '  - fcitx5: cài xong (đăng xuất/đăng nhập lại để áp dụng)\n'
printf '  - FreeOffice 2024: đã cài\n'
printf '  - Firefox + Thunderbird: bản .deb từ PPA mozillateam\n'
printf '  - Google Chrome: repo chính thức của Google\n'
printf '  - Visual Studio Code: repo chính thức của Microsoft\n'
