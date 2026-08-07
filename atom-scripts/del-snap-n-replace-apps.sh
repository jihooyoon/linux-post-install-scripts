#!/bin/sh
# del-snap-n-replace-apps.sh — Gỡ toàn bộ snap packages và snapd, cài lại Firefox .deb + pin Thunderbird tránh snap
# Chạy: sudo ./del-snap-n-replace-apps.sh
# Lưu ý: trên Ubuntu 22.04+, việc purge snapd có thể kéo theo việc
# gỡ các gói transitional như firefox, gnome-software (cài lại bằng deb sau đó).
# Thunderbird được pin để sau này nếu cài sẽ lấy từ PPA, không phải snap.

set -e

# Debug mode: chạy với DEBUG=1 ./script.sh để thấy tất cả lệnh đang chạy
[ "${DEBUG:-0}" = "1" ] && set -x

info() { printf '\033[1;34m[del-snap]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m     %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m   %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m  %s\n' "$*" >&2; exit 1; }

wait_apt() {
    _i=0
    while [ "$_i" -lt 60 ]; do
        if ! fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/lib/dpkg/lock >/dev/null 2>&1; then
            return 0
        fi
        if [ "$_i" -eq 0 ]; then
            info "apt/dpkg đang bị lock — đợi giải phóng (tối đa 60s)..."
        fi
        sleep 1
        _i=$((_i + 1))
    done
    warn "apt/dpkg vẫn bị lock sau 60s — thử kill process giữ lock..."
    fuser -k /var/lib/dpkg/lock-frontend 2>/dev/null || true
    fuser -k /var/lib/apt/lists/lock 2>/dev/null || true
    fuser -k /var/lib/dpkg/lock 2>/dev/null || true
    sleep 2
}

# --- Kiểm tra quyền root ---
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"

# Sửa broken package state từ lần chạy trước (nếu có) — tránh cascade failure
dpkg --configure -a 2>/dev/null || true

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
    # Kill cứng: snapd có Restart=always, stop xong vẫn có thể restart trước khi mask kịp áp dụng
    systemctl kill snapd.service snapd.socket 2>/dev/null || true
fi

# --- Bước 4: Purge snapd qua apt ---
info "Bước 4: Purge snapd..."
wait_apt
apt-get purge -y snapd

# Sau purge snapd, sửa broken dependencies trước khi cài gì khác
apt-get install -f -y 2>/dev/null || true
dpkg --configure -a 2>/dev/null || true

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

# --- Bước 7: Cài lại GNOME Software (bản .deb thay cho snap transitional đã bị purge) ---
case "$XDG_CURRENT_DESKTOP" in
    *GNOME*)
        info "Bước 7: Cài GNOME Software (App Center) bản .deb..."
        apt-get install -y --no-install-recommends gnome-software
        ok "Đã cài gnome-software"
        ;;
esac

# --- Bước 8: Cài Firefox .deb + pin Thunderbird (tránh snap sau này) ---
info "Bước 8: Cài Firefox .deb và pin Thunderbird tránh snap..."
command -v add-apt-repository >/dev/null 2>&1 || apt-get install -y software-properties-common
add-apt-repository -y ppa:mozillateam/ppa
apt-get update

# Pin bản .deb từ PPA (1001) và chặn hẳn gói snap transitional của Ubuntu (-1)
# Thunderbird được pin để sau này nếu cài sẽ lấy từ PPA, không bị kéo snap
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
apt-get install -y "$FIREFOX_PKG"
ok "Đã cài $FIREFOX_PKG bản .deb (Thunderbird được pin sẵn, cài sau nếu cần)"

# --- Tổng kết ---
if command -v snap >/dev/null 2>&1; then
    warn "snap vẫn tồn tại trên hệ thống — kiểm tra lại thủ công"
else
    ok "Hoàn tất! snap đã bị gỡ hoàn toàn. Firefox đã được thay bằng bản .deb (Thunderbird đã pin sẵn)."
    printf 'Nên khởi động lại máy để hoàn tất.\n'
fi
