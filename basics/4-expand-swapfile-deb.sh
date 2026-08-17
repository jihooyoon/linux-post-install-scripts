#!/bin/sh
# @setup-description: Mở rộng swap lên 16 GiB
# @setup-when: always
# @setup-core-description: Bảo đảm tổng swap active đạt tối thiểu 16 GiB
# 4-expand-swapfile-deb.sh — Ubuntu/Debian: tăng tổng swap một cách an toàn
# Chạy: sudo ./4-expand-swapfile-deb.sh

[ "${DEBUG:-0}" = "1" ] && set -x

LOG_CONTEXT=swap
info() { printf '\033[1;34m[%s]\033[0m %s\n' "$LOG_CONTEXT" "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m     %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m   %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m  %s\n' "$*" >&2; exit 1; }

CHILD_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CHILD_FILE="$CHILD_DIR/$(basename -- "$0")"
. "$CHILD_DIR/../lib/setup-contract.sh"
setup_child_prepare "$CHILD_FILE" "$@" || exit $?
if [ "$SETUP_SHOW_HELP" -eq 1 ]; then
    setup_print_help "$CHILD_FILE"
    exit 0
fi

[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

SWAP_SKIP_BYTES=$((12 * 1024 * 1024 * 1024))
TARGET_SWAP_BYTES=$((16 * 1024 * 1024 * 1024))
PAGE_SIZE_BYTES=$(getconf PAGESIZE 2>/dev/null || printf '4096')
NEW_SWAPFILE=/swapfile-extra
TEMP_SWAPFILE=""

total_swap_bytes() {
    LC_ALL=C swapon --show --noheadings --raw --bytes --output NAME,TYPE,SIZE 2>/dev/null \
        | awk '{ total += $3 } END { printf "%.0f\n", total + 0 }'
}

smallest_active_swapfile() {
    LC_ALL=C swapon --show --noheadings --raw --bytes --output NAME,TYPE,SIZE 2>/dev/null \
        | awk '$2 == "file" && (!found || $3 < smallest) { found=1; smallest=$3; path=$1 } END { if (found) print path }'
}

available_bytes() {
    df -PB1 "$1" 2>/dev/null | awk 'NR == 2 { print $4 + 0 }'
}

swap_is_active() {
    _swap_path=$1
    LC_ALL=C swapon --show --noheadings --raw --output NAME 2>/dev/null \
        | grep -Fx -- "$_swap_path" >/dev/null 2>&1
}

create_swapfile() {
    _swap_path=$1
    _swap_bytes=$2
    _swap_dir=$(dirname -- "$_swap_path")
    _swap_fs=$(findmnt -no FSTYPE -T "$_swap_dir" 2>/dev/null || true)

    [ ! -e "$_swap_path" ] || { warn "$_swap_path đã tồn tại, không ghi đè"; return 1; }
    case "$_swap_fs" in
        btrfs)
            command -v btrfs >/dev/null 2>&1 || {
                warn "Filesystem Btrfs cần lệnh btrfs để tạo swapfile an toàn"
                return 1
            }
            btrfs filesystem mkswapfile --size "$_swap_bytes" "$_swap_path" || return 1
            chmod 600 "$_swap_path" || return 1
            ;;
        *)
            _swap_mib=$((_swap_bytes / 1048576))
            _swap_remainder=$((_swap_bytes % 1048576))
            umask 077
            dd if=/dev/zero of="$_swap_path" bs=1M count="$_swap_mib" status=none || {
                rm -f "$_swap_path"
                return 1
            }
            if [ "$_swap_remainder" -gt 0 ]; then
                dd if=/dev/zero of="$_swap_path" bs=1 count="$_swap_remainder" \
                    oflag=append conv=notrunc,fsync status=none || {
                    rm -f "$_swap_path"
                    return 1
                }
            else
                sync -f "$_swap_path" 2>/dev/null || sync
            fi
            chmod 600 "$_swap_path" || { rm -f "$_swap_path"; return 1; }
            mkswap "$_swap_path" >/dev/null || { rm -f "$_swap_path"; return 1; }
            ;;
    esac
}

ensure_fstab_entry() {
    _swap_path=$1
    if awk -v path="$_swap_path" '$1 == path && $3 == "swap" { found=1 } END { exit !found }' /etc/fstab; then
        return 0
    fi
    if printf '%s none swap sw 0 0\n' "$_swap_path" >> /etc/fstab; then
        ok "Đã thêm $_swap_path vào /etc/fstab"
    else
        warn "Swap đã active nhưng không ghi được /etc/fstab; nó sẽ không tự bật sau reboot"
    fi
}

cleanup_temp_swapfile() {
    [ -n "$TEMP_SWAPFILE" ] || return 0
    if swap_is_active "$TEMP_SWAPFILE" && ! swapoff "$TEMP_SWAPFILE"; then
        warn "Không thể tắt swapfile tạm $TEMP_SWAPFILE — giữ lại để an toàn"
        return 1
    fi
    rm -f "$TEMP_SWAPFILE" || {
        warn "Không thể xóa swapfile tạm $TEMP_SWAPFILE"
        return 1
    }
    TEMP_SWAPFILE=""
}

trap 'cleanup_temp_swapfile || true' EXIT HUP INT TERM

restore_original_swapfile() {
    _swap_path=$1
    _old_file_bytes=$2
    warn "Đang cố khôi phục swapfile cũ tại $_swap_path..."
    rm -f "$_swap_path" || return 1
    create_swapfile "$_swap_path" "$_old_file_bytes" || return 1
    swapon "$_swap_path" || return 1
    ok "Đã khôi phục swapfile cũ"
}

expand_smallest_swapfile() {
    _swap_path=$1
    _old_file_bytes=$2
    _expand_bytes=$3
    _swap_dir=$(dirname -- "$_swap_path")
    _replacement_file_bytes=$((_old_file_bytes + _expand_bytes))
    _peak_extra_bytes=$((_old_file_bytes + _expand_bytes))
    _free_bytes=$(available_bytes "$_swap_dir")

    if [ -z "$_free_bytes" ] || [ "$_free_bytes" -lt "$_peak_extra_bytes" ]; then
        warn "Không đủ dung lượng trống để tạo swap tạm và file thay thế cho $_swap_path"
        return 0
    fi

    TEMP_SWAPFILE=$(mktemp "$_swap_dir/.${_swap_path##*/}.expand.XXXXXX") || {
        warn "Không tạo được tên swapfile tạm"
        return 0
    }
    rm -f "$TEMP_SWAPFILE" || { TEMP_SWAPFILE=""; return 0; }
    if ! create_swapfile "$TEMP_SWAPFILE" "$_old_file_bytes" || ! swapon "$TEMP_SWAPFILE"; then
        warn "Không bật được swapfile tạm — giữ nguyên $_swap_path"
        rm -f "$TEMP_SWAPFILE"
        TEMP_SWAPFILE=""
        return 0
    fi

    info "Đã bật swapfile tạm; chuyển dữ liệu ra khỏi $_swap_path..."
    if ! swapoff "$_swap_path"; then
        warn "swapoff thất bại; giữ nguyên swapfile cũ"
        cleanup_temp_swapfile || true
        return 0
    fi

    if ! rm -f "$_swap_path" || \
       ! create_swapfile "$_swap_path" "$_replacement_file_bytes" || \
       ! swapon "$_swap_path"; then
        warn "Không thể bật swapfile đã mở rộng; khôi phục kích thước cũ nếu có thể"
        if restore_original_swapfile "$_swap_path" "$_old_file_bytes"; then
            cleanup_temp_swapfile || true
        else
            warn "Khôi phục file cũ thất bại; giữ swapfile tạm active để tránh mất swap"
        fi
        return 0
    fi

    ensure_fstab_entry "$_swap_path"
    cleanup_temp_swapfile || true
}

create_additional_swapfile() {
    _expand_bytes=$1
    _new_file_bytes=$((_expand_bytes + PAGE_SIZE_BYTES))
    _free_bytes=$(available_bytes /)

    if [ -e "$NEW_SWAPFILE" ]; then
        warn "$NEW_SWAPFILE đã tồn tại nhưng không active; không ghi đè nên bỏ qua"
        return 0
    fi
    if [ -z "$_free_bytes" ] || [ "$_free_bytes" -lt "$_new_file_bytes" ]; then
        warn "Không đủ dung lượng trống để tạo $NEW_SWAPFILE"
        return 0
    fi
    if ! create_swapfile "$NEW_SWAPFILE" "$_new_file_bytes" || ! swapon "$NEW_SWAPFILE"; then
        warn "Không thể tạo hoặc bật $NEW_SWAPFILE"
        rm -f "$NEW_SWAPFILE"
        return 0
    fi
    ensure_fstab_entry "$NEW_SWAPFILE"
}

main() {
    CURRENT_SWAP_BYTES=$(total_swap_bytes)
    if [ "$CURRENT_SWAP_BYTES" -ge "$SWAP_SKIP_BYTES" ]; then
        info "SKIPPED: tổng swap đã đủ tốt ($(($CURRENT_SWAP_BYTES / 1024 / 1024)) MiB, từ 12 GiB trở lên)"
        return 0
    fi

    EXPAND_BYTES=$((TARGET_SWAP_BYTES - CURRENT_SWAP_BYTES))
    TARGET_SWAPFILE=$(smallest_active_swapfile)
    if [ -n "$TARGET_SWAPFILE" ]; then
        if [ ! -f "$TARGET_SWAPFILE" ]; then
            warn "$TARGET_SWAPFILE không còn là file thường; bỏ qua để an toàn"
            return 0
        fi
        OLD_FILE_BYTES=$(stat -c %s "$TARGET_SWAPFILE" 2>/dev/null || true)
        if [ -z "$OLD_FILE_BYTES" ] || [ "$OLD_FILE_BYTES" -le 0 ]; then
            warn "Không đọc được kích thước swapfile $TARGET_SWAPFILE"
            return 0
        fi
        info "Tổng swap hiện tại: $(($CURRENT_SWAP_BYTES / 1024 / 1024)) MiB; cần mở rộng thêm $(($EXPAND_BYTES / 1024 / 1024)) MiB"
        expand_smallest_swapfile "$TARGET_SWAPFILE" "$OLD_FILE_BYTES" "$EXPAND_BYTES"
    else
        info "Không có swapfile active; tạo $NEW_SWAPFILE để bổ sung $(($EXPAND_BYTES / 1024 / 1024)) MiB"
        create_additional_swapfile "$EXPAND_BYTES"
    fi

    FINAL_SWAP_BYTES=$(total_swap_bytes)
    if [ "$FINAL_SWAP_BYTES" -lt "$TARGET_SWAP_BYTES" ]; then
        warn "Tổng swap sau thao tác là $(($FINAL_SWAP_BYTES / 1024 / 1024)) MiB, chưa đạt 16 GiB"
    else
        ok "Tổng swap hiện tại: $(($FINAL_SWAP_BYTES / 1024 / 1024)) MiB"
    fi
}

main || warn "Mở rộng swap gặp lỗi không mong muốn — parent vẫn tiếp tục"
exit 0
