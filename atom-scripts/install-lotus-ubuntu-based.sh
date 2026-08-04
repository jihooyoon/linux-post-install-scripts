#!/bin/sh
# install-lotus-ubuntu-based.sh — Cài bộ gõ tiếng Việt Lotus (fcitx5-lotus) cho fcitx5
# Nguồn repo: https://fcitx5-lotus.pages.dev (hỗ trợ Ubuntu-based)
# Chạy: sudo ./install-lotus-ubuntu-based.sh

set -e

info() { printf '\033[1;34m[lotus]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m    %s\n' "$*"; }
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

# --- Bước 6: Biến môi trường fcitx5 trong /etc/environment.d/ ---
# /etc/environment.d/*.conf được systemd user manager áp dụng khi bắt đầu
# phiên đăng nhập — Ubuntu 20.04+ chạy phiên GNOME/KDE dưới systemd nên mọi
# app GUI khởi động từ desktop đều nhận được biến này. Tạo file riêng thay vì
# sửa /etc/environment: không đụng file dùng chung, dễ gỡ bỏ, chuẩn systemd.
# Lưu ý: file environment.d dùng KEY=VALUE, KHÔNG có "export".
info "Bước 6: Tạo /etc/environment.d/fcitx5.conf..."
if [ -f /etc/environment.d/fcitx5.conf ]; then
    ok "Đã có /etc/environment.d/fcitx5.conf — bỏ qua"
else
    mkdir -p /etc/environment.d
    cat > /etc/environment.d/fcitx5.conf <<'EOF'
XMODIFIERS=@im=fcitx
QT_IM_MODULE=fcitx
QT_IM_MODULES="wayland;fcitx"
GLFW_IM_MODULE=ibus
EOF
    ok "Đã tạo /etc/environment.d/fcitx5.conf (đăng nhập lại để áp dụng)"
fi

# --- Bước 7: Thêm Lotus vào fcitx5 profile của user ---
# fcitx5 lưu danh sách bộ gõ trong ~/.config/fcitx5/profile. Ghi sẵn Lotus vào
# group Default để sau đăng nhập gõ được luôn, không phải Add tay qua fcitx5-config.
info "Bước 7: Thêm Lotus vào fcitx5 profile..."
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    HOME_USER=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    PROFILE="$HOME_USER/.config/fcitx5/profile"

    if [ -f "$PROFILE" ] && grep -q '^Name=lotus$' "$PROFILE"; then
        ok "Lotus đã có trong fcitx5 profile — bỏ qua"
    else
        sudo -u "$SUDO_USER" mkdir -p "$HOME_USER/.config/fcitx5"
        if [ -f "$PROFILE" ]; then
            # Profile đã có — thêm Lotus với index tiếp theo trong group Default
            N=$(grep -c '^\[Groups/0/Items/' "$PROFILE")
            printf '\n[Groups/0/Items/%s]\nName=lotus\nLayout=\n' "$N" >> "$PROFILE"
        else
            # Chưa có profile (fcitx5 chưa từng chạy) — tạo mới: bàn phím us + Lotus
            cat > "$PROFILE" <<'EOF'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=lotus

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=lotus
Layout=
EOF
        fi
        chown "$SUDO_USER" "$PROFILE"
        ok "Đã thêm Lotus vào fcitx5 profile (đăng nhập lại để áp dụng)"
    fi
else
    warn "Không xác định được user (chạy không qua sudo) — bỏ qua bước profile"
fi

printf '\nCách gõ: \033[1mCtrl+Space\033[0m để chuyển giữa bàn phím tiếng Anh và \033[1mLotus\033[0m (đã thêm sẵn vào profile).\n'
printf 'Gợi ý: nên dùng cùng fcitx5 (install-basic-apps-deb.sh đã cài sẵn).\n'
printf 'Nếu app X11 GTK3 cũ không gõ được: thêm GTK_IM_MODULE=fcitx vào /etc/environment.d/fcitx5.conf.\n'
