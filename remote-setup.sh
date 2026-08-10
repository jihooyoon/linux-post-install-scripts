#!/bin/sh
# remote-setup.sh — Cài từ GitHub trên máy mới, tự dọn dẹp
#
# Cách dùng (một lệnh duy nhất trên máy cần cài) — KHÔNG cần sudo ở ngoài,
# script tự gọi sudo khi cần chạy phần cài đặt:
#   curl -fsSL https://raw.githubusercontent.com/jihooyoon/linux-post-install-scripts/main/remote-setup.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/jihooyoon/linux-post-install-scripts/main/remote-setup.sh | sh -s -- --all
#   curl -fsSL https://raw.githubusercontent.com/jihooyoon/linux-post-install-scripts/main/remote-setup.sh | sh -s -- --pack-bs
#   curl -fsSL https://raw.githubusercontent.com/jihooyoon/linux-post-install-scripts/main/remote-setup.sh | sh -s -- --dev
#
# (Cách cũ vẫn hoạt động: curl ... | sudo sh, hoặc sudo sh remote-setup.sh)
#
# Tham số được passthrough sang setup-ubuntu-based.sh. Riêng --dev chỉ chọn
# source branch cho remote, sau đó không được forward xuống parent.
#
# Cách hoạt động:
#   1. Tải tarball repo về /tmp (không cần clone tay, không cần git, không cần root)
#   2. Git không lưu quyền execute → chmod +x toàn bộ script
#   3. Tự gọi sudo (nếu chưa root) để chạy setup-ubuntu-based.sh với các cờ đã chọn
#   4. Tự xóa toàn bộ file tạm trong /tmp khi kết thúc (kể cả khi lỗi giữa chừng)

set -e

# Debug mode: chạy với DEBUG=1 curl ... | sh để thấy tất cả lệnh đang chạy
[ "${DEBUG:-0}" = "1" ] && set -x

REPO="jihooyoon/linux-post-install-scripts"
BRANCH="main"
TARBALL="/tmp/linux-post-install-scripts.tar.gz"

info() { printf '\033[1;36m[install]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m      %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m   %s\n' "$*" >&2; exit 1; }

# Dọn file tạm khi kết thúc — kể cả khi script lỗi giữa chừng.
# Lưu ý: setup chạy bằng sudo (hoặc DEST còn sót từ lần chạy bằng root trước) có thể
# để lại file root-owned trong DEST → rm bằng user bị "permission denied"; thử lại bằng sudo.
# "$1" = "noprompt" → dùng sudo -n (không hỏi mật khẩu) — áp dụng cho trap EXIT/INT/TERM
# để tránh prompt bất ngờ; lời gọi cleanup() ở đầu script (dọn DEST cũ) vẫn được phép hỏi.
cleanup() {
    _sudo_opt=""
    [ "${1:-}" = "noprompt" ] && _sudo_opt="-n"
    rm -rf "$TARBALL" "$DEST" 2>/dev/null \
        || { command -v sudo >/dev/null 2>&1 && sudo $_sudo_opt rm -rf "$TARBALL" "$DEST" 2>/dev/null; } \
        || true
}
trap 'cleanup noprompt' EXIT
trap 'cleanup noprompt; exit 130' INT
trap 'cleanup noprompt; exit 143' TERM

# --- Chỉ tách --dev để chọn branch; các argument khác passthrough nguyên vẹn ---
SETUP="setup-ubuntu-based.sh"
SETUP_ARGS=""
for arg in "$@"; do
    case "$arg" in
        --dev) BRANCH="dev" ;;
        *) SETUP_ARGS="${SETUP_ARGS}${SETUP_ARGS:+ }$arg" ;;
    esac
done

DEST="/tmp/linux-post-install-scripts-$BRANCH"

# --- Kiểm tra công cụ: curl để tải; sudo để chạy phần cài đặt nếu chưa root ---
command -v curl >/dev/null 2>&1 || die "Thiếu curl — cài trước: sudo apt-get install -y curl"
if [ "$(id -u)" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
    die "Thiếu sudo — chạy bằng root hoặc cài sudo trước"
fi

# --- Bước 0: Dọn DEST/TARBALL cũ còn sót (có thể chứa file root-owned từ lần chạy bằng root trước) ---
cleanup

# --- Bước 1: Tải repo về /tmp (chạy được cả khi chưa root) ---
info "Tải repo về /tmp (bản $BRANCH)..."
curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/$BRANCH" -o "$TARBALL"
tar -xzf "$TARBALL" -C /tmp
[ -f "$DEST/$SETUP" ] || die "Không tìm thấy $SETUP — sai repo/branch?"

# --- Bước 2: Cấp quyền execute (git không lưu quyền này) ---
chmod +x "$DEST"/*.sh "$DEST"/atom-scripts/*.sh "$DEST"/extras/*.sh
ok "Đã chmod +x toàn bộ script"

# --- Bước 3: Chạy setup (tự gọi sudo nếu chưa root) ---
# run_setup <cmd> [args...]:
#   - Nếu stdin đang là pipe (vd: curl | sh) mà có terminal thật (/dev/tty) thì gán
#     stdin từ /dev/tty cho lệnh — nếu không, menu sẽ không nhận được input
#     (stdin là EOF của pipe → read trả về ngay, script con chết im lặng).
#   - Giữ DEBUG=1 xuyên qua sudo khi đang chạy debug.
run_setup() {
    _cmd=$1
    shift
    if [ "${DEBUG:-0}" = "1" ] && [ "$_cmd" = "sudo" ]; then
        set -- --preserve-env=DEBUG "$@"
    fi
    if [ ! -t 0 ] && ( : </dev/tty ) 2>/dev/null; then
        "$_cmd" "$@" </dev/tty
    else
        "$_cmd" "$@"
    fi
}

info "Chạy $SETUP${SETUP_ARGS:+ với:$SETUP_ARGS}..."
if [ "$(id -u)" -eq 0 ]; then
    run_setup "$DEST/$SETUP" $SETUP_ARGS || die "$SETUP thất bại — xem log phía trên"
else
    info "Chưa phải root — tự gọi sudo (không cần 'curl | sudo sh')..."
    run_setup sudo "$DEST/$SETUP" $SETUP_ARGS || die "$SETUP thất bại — xem log phía trên"
fi

ok "Xong! File tạm trong /tmp đã được tự động xóa. Khởi động lại máy để áp dụng."
