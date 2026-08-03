#!/bin/sh
# de-snap.sh — Gỡ toàn bộ snap packages và snapd khỏi hệ thống
# Chạy: sudo ./de-snap.sh
# Lưu ý: trên Ubuntu 22.04+, việc purge snapd có thể kéo theo việc
# gỡ các gói transitional như firefox, gnome-software (cài lại bằng deb sau đó).

set -e

info() { printf '\033[1;34m[de-snap]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m     %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m   %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m  %s\n' "$*" >&2; exit 1; }

# --- Kiểm tra quyền root ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

# snap có thể chưa được cài — vẫn cho phép chạy các bước dọn dẹp còn lại
if command -v snap >/dev/null 2>&1; then
    SNAP_PRESENT=1
else
    SNAP_PRESENT=0
    warn "snap chưa được cài — bỏ qua bước remove snap, vẫn dọn dẹp phần còn lại"
fi

list_snaps() {
    snap list 2>/dev/null | awk 'NR>1 {print $1}'
}

# --- Bước 1: Remove các gói ứng dụng (lặp lại vì core phải remove sau) ---
if [ "$SNAP_PRESENT" -eq 1 ]; then
    info "Bước 1: Remove các gói ứng dụng..."
    i=0
    while [ "$i" -lt 20 ]; do
        APPS=$(list_snaps | grep -v -E '^(snapd|core|core1[0-9]|core2[0-9])$' || true)
        [ -z "$APPS" ] && break
        for s in $APPS; do
            if snap remove --purge "$s" >/dev/null 2>&1; then
                ok "Đã remove $s"
            else
                warn "Chưa remove được $s (còn phụ thuộc) — thử lại vòng sau"
            fi
        done
        i=$((i + 1))
    done
    if [ "$i" -ge 20 ]; then
        warn "Còn snap chưa remove được sau 20 vòng — bạn có thể chạy lại script"
    fi

    # --- Bước 2: Remove các core snap ---
    info "Bước 2: Remove core snap..."
    for c in core core18 core20 core22 core24; do
        if list_snaps | grep -qx "$c"; then
            snap remove --purge "$c" >/dev/null 2>&1 \
                && ok "Đã remove $c" || warn "Không remove được $c"
        fi
    done

    # --- Bước 3: Dừng, vô hiệu hóa và mask dịch vụ snapd ---
    info "Bước 3: Dừng và vô hiệu hóa dịch vụ snapd..."
    systemctl stop snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true
    systemctl disable snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true
    systemctl mask snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true
fi

# --- Bước 4: Purge snapd qua apt ---
info "Bước 4: Purge snapd..."
apt-get purge -y snapd

# --- Bước 5: Dọn các thư mục snap còn sót ---
info "Bước 5: Dọn thư mục snap..."
rm -rf /snap /var/snap /var/cache/snapd /var/lib/snapd /root/snap /home/*/snap

# --- Bước 6: Chặn apt cài lại snapd ---
info "Bước 6: Chặn cài lại snapd qua apt..."
if [ -d /etc/apt/preferences.d ]; then
    cat > /etc/apt/preferences.d/nosnap.pref <<'EOF'
# De-snap: ngăn apt tự động cài lại snapd
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF
    ok "Đã ghi /etc/apt/preferences.d/nosnap.pref"
fi

# --- Tổng kết ---
if command -v snap >/dev/null 2>&1; then
    warn "snap vẫn tồn tại trên hệ thống — kiểm tra lại thủ công"
else
    ok "Hoàn tất! snap đã bị gỡ hoàn toàn. Nên khởi động lại máy."
fi
