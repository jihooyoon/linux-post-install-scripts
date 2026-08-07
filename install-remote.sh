#!/bin/sh
# install-remote.sh — Cài từ GitHub trên máy mới, tự dọn dẹp
#
# Cách dùng (một lệnh duy nhất trên máy cần cài):
#   curl -fsSL https://raw.githubusercontent.com/jihooyoon/linux-post-install-scripts/main/install-remote.sh | sudo bash
#   curl -fsSL https://raw.githubusercontent.com/jihooyoon/linux-post-install-scripts/main/install-remote.sh | sudo bash -s -- --basic
#   curl -fsSL https://raw.githubusercontent.com/jihooyoon/linux-post-install-scripts/main/install-remote.sh | sudo bash -s -- --basic --silent
#
# Tham số:
#   --basic   chỉ chạy setup-basic-ubuntu-based.sh, không chạy setup-all
#   --silent  không hiện menu tương tác, tự chọn tất cả (truyền xuống script con)
#
# Cách hoạt động:
#   1. Tải tarball repo về /tmp (không cần clone tay, không cần git)
#   2. Git không lưu quyền execute → chmod +x toàn bộ script
#   3. Chạy setup-all-ubuntu-based.sh (mặc định) hoặc setup-basic-ubuntu-based.sh
#      với arg --basic (SUDO_USER giữ nguyên — không sudo lồng nhau)
#   4. Tự xóa toàn bộ file tạm trong /tmp khi kết thúc (kể cả khi lỗi giữa chừng)

set -e

# Debug mode: chạy với DEBUG=1 để thấy tất cả lệnh đang chạy
[ "${DEBUG:-0}" = "1" ] && set -x

REPO="jihooyoon/linux-post-install-scripts"
BRANCH="main"
TARBALL="/tmp/linux-post-install-scripts.tar.gz"
DEST="/tmp/linux-post-install-scripts-$BRANCH"

info() { printf '\033[1;36m[install]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m      %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m   %s\n' "$*" >&2; exit 1; }

# Dọn file tạm khi kết thúc — kể cả khi script lỗi giữa chừng
trap 'rm -rf "$TARBALL" "$DEST"' EXIT INT TERM

# --- Đọc tham số: --basic → chỉ chạy setup-basic; --silent → không tương tác ---
SETUP="setup-all-ubuntu-based.sh"
SILENT=""
for arg in "$@"; do
    case "$arg" in
        --basic)  SETUP="setup-basic-ubuntu-based.sh" ;;
        --silent) SILENT="--silent" ;;
        --help|-h)
            echo "Usage: curl -fsSL <url>/install-remote.sh | sudo bash"
            echo "       curl -fsSL <url>/install-remote.sh | sudo bash -s -- [opts]"
            echo ""
            echo "  (không đối số)  Chạy setup-all-ubuntu-based.sh (tương tác)"
            echo "  --basic         Chỉ chạy setup-basic-ubuntu-based.sh"
            echo "  --silent        Không tương tác, truyền --silent xuống script con"
            echo "  --help, -h      In trợ giúp này"
            exit 0
            ;;
    esac
done

# --- Kiểm tra quyền root và user thật ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với sudo: curl -fsSL <url>/install-remote.sh | sudo bash"
[ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ] \
    || die "Không xác định được user thật — chạy bằng sudo (không dùng su)"
command -v curl >/dev/null 2>&1 || die "Thiếu curl — cài trước: sudo apt-get install -y curl"

# --- Bước 1: Tải repo về /tmp ---
info "Tải repo về /tmp (bản $BRANCH)..."
curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/$BRANCH" -o "$TARBALL"
tar -xzf "$TARBALL" -C /tmp
[ -f "$DEST/$SETUP" ] || die "Không tìm thấy $SETUP — sai repo/branch?"

# --- Bước 2: Cấp quyền execute (git không lưu quyền này) ---
chmod +x "$DEST"/*.sh "$DEST"/atom-scripts/*.sh "$DEST"/extras/*.sh
ok "Đã chmod +x toàn bộ script"

# --- Bước 3: Chạy setup (root; SUDO_USER giữ nguyên vì không sudo lồng nhau) ---
info "Chạy $SETUP${SILENT:+ (silent)}..."
"$DEST/$SETUP" $SILENT || die "$SETUP thất bại — xem log phía trên"

ok "Xong! File tạm trong /tmp đã được tự động xóa. Khởi động lại máy để áp dụng."
