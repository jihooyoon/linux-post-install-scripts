#!/bin/sh
# bootstrap.sh — Cài toàn bộ từ GitHub trên máy mới, tự dọn dẹp
#
# Cách dùng (một lệnh duy nhất trên máy cần cài):
#   curl -fsSL https://raw.githubusercontent.com/jihooyoon/linux-post-install-scripts/main/bootstrap.sh | sudo bash
#
# Cách hoạt động:
#   1. Tải tarball repo về /tmp (không cần clone tay, không cần git)
#   2. Git không lưu quyền execute → chmod +x toàn bộ script
#   3. Chạy setup-all-ubuntu-based.sh (SUDO_USER giữ nguyên — không sudo lồng nhau)
#   4. Tự xóa toàn bộ file tạm trong /tmp khi kết thúc (kể cả khi lỗi giữa chừng)

set -e

REPO="jihooyoon/linux-post-install-scripts"
BRANCH="main"
TARBALL="/tmp/linux-post-install-scripts.tar.gz"
DEST="/tmp/linux-post-install-scripts-$BRANCH"

info() { printf '\033[1;36m[bootstrap]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m      %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m   %s\n' "$*" >&2; exit 1; }

# Dọn file tạm khi kết thúc — kể cả khi script lỗi giữa chừng
trap 'rm -rf "$TARBALL" "$DEST"' EXIT INT TERM

# --- Kiểm tra quyền root và user thật ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với sudo: curl -fsSL <url>/bootstrap.sh | sudo bash"
[ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ] \
    || die "Không xác định được user thật — chạy bằng sudo (không dùng su)"
command -v curl >/dev/null 2>&1 || die "Thiếu curl — cài trước: sudo apt-get install -y curl"

# --- Bước 1: Tải repo về /tmp ---
info "Tải repo về /tmp (bản $BRANCH)..."
curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/$BRANCH" -o "$TARBALL"
tar -xzf "$TARBALL" -C /tmp
[ -f "$DEST/setup-all-ubuntu-based.sh" ] || die "Không tìm thấy setup-all-ubuntu-based.sh — sai repo/branch?"

# --- Bước 2: Cấp quyền execute (git không lưu quyền này) ---
chmod +x "$DEST"/*.sh "$DEST"/atom-scripts/*.sh "$DEST"/extras/*.sh
ok "Đã chmod +x toàn bộ script"

# --- Bước 3: Chạy setup-all (root; SUDO_USER giữ nguyên vì không sudo lồng nhau) ---
"$DEST/setup-all-ubuntu-based.sh" || die "setup-all thất bại — xem log phía trên"

ok "Xong! File tạm trong /tmp đã được tự động xóa. Khởi động lại máy để áp dụng."
