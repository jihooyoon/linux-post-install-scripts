#!/bin/sh
# @setup-description: De-bloat Ubuntu-based
# @setup-when: always
# @setup-core-description: Tự chọn de-snap Ubuntu hoặc de-brand Tuxedo

set -e
[ "${DEBUG:-0}" = "1" ] && set -x

LOG_CONTEXT=debloat
info() { printf '\033[1;34m[%s]\033[0m %s\n' "$LOG_CONTEXT" "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m     %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m   %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m  %s\n' "$*" >&2; exit 1; }

CHILD_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CHILD_FILE="$CHILD_DIR/$(basename -- "$0")"
. "$CHILD_DIR/../lib/setup-contract.sh"

KEEP_SNAP=0
PASSTHROUGH_ARGS=""
for arg in "$@"; do
    case "$arg" in
        --keep-snap)
            [ "$KEEP_SNAP" -eq 0 ] || die "--keep-snap chỉ được truyền một lần"
            KEEP_SNAP=1
            ;;
        *)
            PASSTHROUGH_ARGS="${PASSTHROUGH_ARGS}${PASSTHROUGH_ARGS:+ }$arg"
            ;;
    esac
done
setup_child_prepare "$CHILD_FILE" $PASSTHROUGH_ARGS || exit $?
if [ "$SETUP_SHOW_HELP" -eq 1 ]; then
    setup_print_help "$CHILD_FILE"
    printf '  --keep-snap     Giữ Snap, bỏ de-snap khi chạy trên máy non-Tuxedo\n'
    exit 0
fi

wait_apt() {
    _wait_i=0
    while [ "$_wait_i" -lt 60 ]; do
        if ! fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/lib/dpkg/lock >/dev/null 2>&1; then
            return 0
        fi
        if [ "$_wait_i" -eq 0 ]; then
            info "apt/dpkg đang bị lock — đợi giải phóng (tối đa 60s)..."
        fi
        sleep 1
        _wait_i=$((_wait_i + 1))
    done
    warn "apt/dpkg vẫn bị lock sau 60s — thử kill process giữ lock..."
    fuser -k /var/lib/dpkg/lock-frontend 2>/dev/null || true
    fuser -k /var/lib/apt/lists/lock 2>/dev/null || true
    fuser -k /var/lib/dpkg/lock 2>/dev/null || true
    sleep 2
}

desnap_ubuntu() {
    LOG_CONTEXT=desnap
    dpkg --configure -a 2>/dev/null || true

    if command -v snap >/dev/null 2>&1; then
        SNAP_PRESENT=1
    else
        SNAP_PRESENT=0
        warn "snap chưa được cài — bỏ qua bước remove snap, vẫn dọn dẹp phần còn lại"
    fi

    list_snaps() {
        snap list 2>/dev/null | awk 'NR>1 {print $1}'
    }

    if [ "$SNAP_PRESENT" -eq 1 ]; then
        info "Bước 1: Remove các gói ứng dụng..."
        desnap_attempt=0
        while [ "$desnap_attempt" -lt 20 ]; do
            APPS=$(list_snaps | grep -v -E '^(snapd|core|core1[0-9]|core2[0-9])$' || true)
            [ -z "$APPS" ] && break
            for s in $APPS; do
                if snap remove --purge "$s" >/dev/null 2>&1; then
                    ok "Đã remove $s"
                else
                    warn "Chưa remove được $s (còn phụ thuộc) — thử lại vòng sau"
                fi
            done
            desnap_attempt=$((desnap_attempt + 1))
        done
        if [ "$desnap_attempt" -ge 20 ]; then
            warn "Còn snap chưa remove được sau 20 vòng — bạn có thể chạy lại script"
        fi

        info "Bước 2: Remove core snap..."
        for c in core core18 core20 core22 core24; do
            if list_snaps | grep -qx "$c"; then
                snap remove --purge "$c" >/dev/null 2>&1 \
                    && ok "Đã remove $c" || warn "Không remove được $c"
            fi
        done

        info "Bước 3: Dừng và vô hiệu hóa dịch vụ snapd..."
        systemctl stop snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true
        systemctl disable snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true
        systemctl mask snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true
        systemctl kill snapd.service snapd.socket 2>/dev/null || true
    fi

    info "Bước 4: Purge snapd..."
    wait_apt
    apt-get purge -y snapd
    apt-get install -f -y 2>/dev/null || true
    dpkg --configure -a 2>/dev/null || true

    info "Bước 5: Dọn thư mục snap..."
    rm -rf /snap /var/snap /var/cache/snapd /var/lib/snapd /root/snap /home/*/snap

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

    if ! setup_is_kde_desktop "${XDG_CURRENT_DESKTOP:-}"; then
        case "$XDG_CURRENT_DESKTOP" in
            *GNOME*)
                info "Bước 7: Cài GNOME Software (App Center) bản .deb..."
                apt-get install -y --no-install-recommends gnome-software
                ok "Đã cài gnome-software"
                ;;
        esac
    fi

    info "Bước 8: Cài Firefox .deb và pin Thunderbird tránh snap..."
    command -v add-apt-repository >/dev/null 2>&1 || apt-get install -y software-properties-common
    add-apt-repository -y ppa:mozillateam/ppa
    apt-get update
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
    snap remove --purge firefox 2>/dev/null || true
    snap remove --purge thunderbird 2>/dev/null || true
    if apt-cache show firefox >/dev/null 2>&1; then
        FIREFOX_PKG=firefox
    else
        FIREFOX_PKG=firefox-esr
        warn "Repo không có gói firefox (rapid) — cài firefox-esr thay thế"
    fi
    apt-get install -y "$FIREFOX_PKG"
    ok "Đã cài $FIREFOX_PKG bản .deb (Thunderbird được pin sẵn, cài sau nếu cần)"

    if command -v snap >/dev/null 2>&1; then
        warn "snap vẫn tồn tại trên hệ thống — kiểm tra lại thủ công"
    else
        ok "Hoàn tất! snap đã bị gỡ hoàn toàn. Firefox đã được thay bằng bản .deb (Thunderbird đã pin sẵn)."
        printf 'Nên khởi động lại máy để hoàn tất.\n'
    fi
}

generalize_tuxedo() {
    LOG_CONTEXT=tuxedo-generalize
    info "Bước 1: Gỡ các app Tuxedo (Control Center, WebFAI Creator)..."
    TUXX_GUI="tuxedo-control-center"
    wait_apt
    for pkg in $TUXX_GUI; do
        if dpkg -l "$pkg" >/dev/null 2>&1; then
            info "Đang gỡ $pkg..."
            apt-get purge -y "$pkg"
            ok "Đã gỡ $pkg"
        else
            ok "$pkg chưa được cài — bỏ qua"
        fi
    done
    if dpkg -l tuxedo-webfai-creator >/dev/null 2>&1; then
        info "Đang gỡ tuxedo-webfai-creator..."
        apt-get purge -y tuxedo-webfai-creator
        ok "Đã gỡ tuxedo-webfai-creator"
    fi
    apt-get autoremove -y --purge || true

    info "Bước 2: Xóa dGPU Guide khỏi application launcher..."
    TARGET_HOME=$(eval echo "~${SUDO_USER:-$USER}")
    for f in \
        "$TARGET_HOME/.local/share/applications/dgpu.desktop" \
        "$TARGET_HOME/Desktop/dgpu.desktop" \
        "$TARGET_HOME/.config/autostart/copy-guide.desktop"; do
        if [ -f "$f" ]; then
            rm -f "$f"
            ok "Đã xóa $(basename "$f")"
        fi
    done

    info "Bước 3: Đổi SDDM theme sang Breeze, gỡ theme + wallpaper Tuxedo..."
    if ! dpkg -s sddm-theme-breeze >/dev/null 2>&1; then
        info "Đang cài sddm-theme-breeze..."
        apt-get install -y sddm-theme-breeze
    fi
    if dpkg -l sddm-theme-breeze >/dev/null 2>&1; then
        SDDM_CONF=/etc/sddm.conf.d/kde_settings.conf
        SDDM_CONF_BAK=/tmp/kde_settings.conf.generalize-bak
        if [ -f "$SDDM_CONF" ]; then
            cp "$SDDM_CONF" "$SDDM_CONF_BAK"
        fi
        for pkg in sddm-theme-tuxedo tuxedo-theme-plasma tuxedo-wallpapers-2204 tuxedoos-desktop; do
            if dpkg -l "$pkg" >/dev/null 2>&1; then
                info "Đang gỡ $pkg..."
                apt-get purge -y "$pkg"
                ok "Đã gỡ $pkg"
            else
                ok "$pkg chưa được cài — bỏ qua"
            fi
        done
        if [ -f "$SDDM_CONF_BAK" ]; then
            sed 's/^Current=tuxedo/Current=breeze/' "$SDDM_CONF_BAK" > "$SDDM_CONF"
            rm -f "$SDDM_CONF_BAK"
            ok "SDDM đã chuyển sang theme Breeze (Current=breeze)"
        elif [ ! -f "$SDDM_CONF" ]; then
            mkdir -p /etc/sddm.conf.d
            printf '[Theme]\nCurrent=breeze\n' > "$SDDM_CONF"
            ok "SDDM đã chuyển sang theme Breeze (Current=breeze)"
        fi
    else
        warn "Không cài được sddm-theme-breeze — giữ nguyên theme SDDM hiện tại"
    fi

    info "Bước 3b: Reset theme Plasma về mặc định KDE6 (global theme Breeze)..."
    kcfg() { HOME="$TARGET_HOME" XDG_CONFIG_HOME="$TARGET_HOME/.config" kwriteconfig6 "$@"; }
    if command -v plasma-apply-lookandfeel >/dev/null 2>&1; then
        if HOME="$TARGET_HOME" XDG_CONFIG_HOME="$TARGET_HOME/.config" \
            plasma-apply-lookandfeel -a org.kde.breezetwilight.desktop; then
            ok "Đã áp global theme org.kde.breezetwilight.desktop"
            kcfg --file kdeglobals --group Icons --key Theme breeze
            ok "Icon theme đã ghi breeze (kwriteconfig6)"
            applied=1
        else
            warn "plasma-apply-lookandfeel thất bại — sẽ ghi lẻ toàn bộ"
        fi
    else
        warn "Không tìm thấy plasma-apply-lookandfeel — sẽ ghi lẻ toàn bộ"
    fi
    if [ "${applied:-0}" -ne 1 ] && command -v kwriteconfig6 >/dev/null 2>&1; then
        info "Ghi lẻ toàn bộ theme key về mặc định KDE6..."
        kcfg --file kdeglobals --group KDE --key LookAndFeelPackage org.kde.breezetwilight.desktop
        kcfg --file kdeglobals --group KDE --key widgetStyle Breeze-Dark
        kcfg --file kdeglobals --group KDE --key cursorTheme breeze_cursors
        kcfg --file kdeglobals --group General --key ColorScheme Breeze
        kcfg --file kdeglobals --group Icons --key Theme breeze
        kcfg --file plasmarc --group Theme --key name default
        kcfg --file kwinrc --group org.kde.kdecoration2 --key library org.kde.breeze
        kcfg --file kwinrc --group org.kde.kdecoration2 --key theme Breeze
        kcfg --file ksplashrc --group KSplash --key Theme org.kde.breeze
        kcfg --file kscreenlockerrc --group Greeter --key Theme org.kde.breeze.desktop
        ok "Đã ghi lẻ toàn bộ theme key (kwriteconfig6)"
    elif [ "${applied:-0}" -ne 1 ]; then
        warn "Không tìm thấy kwriteconfig6 — bỏ qua bước reset theme"
    fi

    info "Bước 4: Bỏ avatar mặc định Tuxedo (face.png), dùng icon KDE mặc định..."
    for f in /var/lib/AccountsService/users/*; do
        [ -f "$f" ] || continue
        if grep -q '^Icon=' "$f"; then
            sed -i '/^Icon=/d' "$f"
            ok "Đã bỏ Icon= trong $(basename "$f")"
        fi
    done
    for f in /usr/share/plasma/avatars/face.png /etc/skel/.face /etc/skel/.face.icon; do
        if [ -f "$f" ]; then
            rm -f "$f"
            ok "Đã xóa $f"
        fi
    done
    getent passwd | awk -F: '$3>=1000 && $3<65534 {print $6}' | while read -r home; do
        [ -d "$home" ] || continue
        if [ -f "$home/.face" ] || [ -f "$home/.face.icon" ]; then
            rm -f "$home/.face" "$home/.face.icon"
            ok "Đã xóa $home/.face"
        fi
    done

    printf '\n\033[1;32mHoàn tất!\033[0m\n'
    printf '  - Tuxedo apps: đã gỡ (Control Center, WebFAI Creator)\n'
    printf '  - dGPU Guide: đã xóa khỏi application launcher\n'
    printf '  - SDDM/Plasma theme: đã đổi sang Breeze, gỡ theme + wallpaper Tuxedo\n'
    printf '  - Theme Plasma: đã reset global theme về mặc định KDE6 (Breeze)\n'
    printf '  - Avatar mặc định: đã bỏ face.png, dùng icon người mặc định của KDE\n'
}

is_tuxedo() {
    case "${SETUP_TEST_TUXEDO:-}" in
        1) return 0 ;;
        0) return 1 ;;
    esac
    grep -qi 'tuxedo' /etc/os-release 2>/dev/null
}

[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"
if is_tuxedo; then
    generalize_tuxedo
elif [ "$KEEP_SNAP" -eq 1 ]; then
    info "Máy non-Tuxedo và có --keep-snap — bỏ qua de-snap, không có thay đổi nào."
else
    desnap_ubuntu
fi
