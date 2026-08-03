#!/bin/sh
# install-lotus-ubuntu-based.sh — Cài bộ gõ tiếng Việt Lotus (fcitx5-lotus) cho fcitx5
# Nguồn repo: https://fcitx5-lotus.pages.dev (hỗ trợ Ubuntu-based)
# Chạy: sudo ./install-lotus-ubuntu-based.sh

set -e

info() { printf '\033[1;34m[lotus]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m    %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

# --- Kiểm tra quyền root ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

# --- Bước 1: Xác định codename của hệ thống ---
info "Bước 1: Xác định Ubuntu codename..."
CODENAME=$(grep '^UBUNTU_CODENAME=' /etc/os-release | cut -d'=' -f2)
[ -n "$CODENAME" ] || die "Không tìm thấy UBUNTU_CODENAME — hệ thống không phải Ubuntu-based"
info "Codename: $CODENAME"

# --- Bước 2: Chuẩn bị công cụ cần thiết ---
info "Bước 2: Chuẩn bị curl và gpg (cài nếu thiếu)..."
command -v curl >/dev/null 2>&1 || apt-get install -y curl
command -v gpg  >/dev/null 2>&1 || apt-get install -y gpg
mkdir -p /etc/apt/keyrings

# --- Bước 3: Thêm khóa GPG và repo fcitx5-lotus ---
info "Bước 3: Thêm khóa GPG và repo fcitx5-lotus..."
curl -fsSL https://fcitx5-lotus.pages.dev/pubkey.gpg | gpg --dearmor -o /etc/apt/keyrings/fcitx5-lotus.gpg
echo "deb [signed-by=/etc/apt/keyrings/fcitx5-lotus.gpg] https://fcitx5-lotus.pages.dev/apt/$CODENAME $CODENAME main" \
    > /etc/apt/sources.list.d/fcitx5-lotus.list
ok "Đã thêm repo fcitx5-lotus cho $CODENAME"

# --- Bước 4: Cài fcitx5-lotus ---
info "Bước 4: Cập nhật và cài fcitx5-lotus..."
apt-get update
apt-get install -y fcitx5-lotus

# --- Bước 5: Kiểm tra và hướng dẫn ---
if dpkg -l fcitx5-lotus 2>/dev/null | grep -q '^ii'; then
    ok "Đã cài fcitx5-lotus"
else
    die "fcitx5-lotus cài chưa thành công — kiểm tra lại kết nối hoặc codename $CODENAME"
fi

# --- Bước 6: Biến môi trường fcitx5 trong ~/.bash_profile ---
# Đơn giản theo yêu cầu: ghi vào ~/.bash_profile của user đang chạy sudo.
# Lưu ý: ~/.bash_profile chỉ được đọc bởi bash login shell (SSH, tty) —
# app GUI và terminal mở từ desktop (non-login shell) không đọc file này.
info "Bước 6: Ghi biến môi trường fcitx5 vào ~/.bash_profile..."
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    HOME_USER=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    if grep -q '^export XMODIFIERS=@im=fcitx' "$HOME_USER/.bash_profile" 2>/dev/null; then
        ok "Biến fcitx5 đã có trong $HOME_USER/.bash_profile — bỏ qua"
    else
        cat >> "$HOME_USER/.bash_profile" <<'EOF'
export XMODIFIERS=@im=fcitx
export QT_IM_MODULE=fcitx
export QT_IM_MODULES="wayland;fcitx"
export GLFW_IM_MODULE=ibus
EOF
        ok "Đã ghi vào $HOME_USER/.bash_profile (đăng nhập lại để áp dụng)"
    fi
else
    warn "Không xác định được user (chạy không qua sudo) — bỏ qua bước env"
fi

printf '\nCách bật: mở \033[1mfcitx5-config\033[0m → tab \033[1mInput Method\033[0m → Add → tìm \033[1mLotus\033[0m.\n'
printf 'Gợi ý: nên dùng cùng fcitx5 (install-basic-apps-deb.sh đã cài sẵn).\n'
printf 'Nếu app X11 GTK3 cũ không gõ được: thêm GTK_IM_MODULE=fcitx vào /etc/environment.\n'
