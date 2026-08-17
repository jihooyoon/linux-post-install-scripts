#!/bin/sh
# @setup-description: Thiết lập cơ bản (Gõ tiếng Việt, Flatpak & Flathub)
# @setup-when: always
# @setup-item: enable_flatpak_flathub|Bật Flatpak & Flathub
# @setup-item: setup_ime|Thiết lập bộ gõ fcitx5
# @setup-item: install_lotus|Cài & cấu hình bộ gõ tiếng Việt Lotus

# 3-setup-basics-ubuntu-based.sh — Flatpak, IME và Lotus

set -e
[ "$DEBUG" = 1 ] && set -x

LOG_CONTEXT=basics
info() { printf '\033[1;34m[%s]\033[0m %s\n' "$LOG_CONTEXT" "$*"; }
ok() { printf '\033[1;32m[OK]\033[0m     %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m   %s\n' "$*" >&2; }
die() { printf '\033[1;31m[ERROR]\033[0m  %s\n' "$*" >&2; exit 1; }

CHILD_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CHILD_FILE="$CHILD_DIR/$(basename -- "$0")"
. "$CHILD_DIR/../lib/setup-contract.sh"
setup_child_prepare "$CHILD_FILE" "$@" || exit $?
[ "$SETUP_SHOW_HELP" -eq 0 ] || { setup_print_help "$CHILD_FILE"; exit 0; }

wait_apt() {
    wait_i=0
    while [ "$wait_i" -lt 60 ]; do
        fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/lib/dpkg/lock >/dev/null 2>&1 || return 0
        [ "$wait_i" -ne 0 ] || info "apt/dpkg đang bị lock — đợi giải phóng (tối đa 60s)..."
        sleep 1
        wait_i=$((wait_i + 1))
    done
    warn "apt/dpkg vẫn bị lock sau 60s — thử kill process giữ lock..."
    fuser -k /var/lib/dpkg/lock-frontend 2>/dev/null || true
    fuser -k /var/lib/apt/lists/lock 2>/dev/null || true
    fuser -k /var/lib/dpkg/lock 2>/dev/null || true
    sleep 2
}

detect_desktop() {
    DESKTOP=${XDG_CURRENT_DESKTOP:-}
    if setup_is_kde_desktop "$DESKTOP"; then
        DESKTOP=KDE
    elif [ -z "$DESKTOP" ] && [ -n "$SUDO_USER" ] && command -v pgrep >/dev/null 2>&1; then
        if pgrep -u "$SUDO_USER" -x gnome-shell >/dev/null 2>&1; then DESKTOP=GNOME
        elif pgrep -u "$SUDO_USER" -x plasmashell >/dev/null 2>&1; then DESKTOP=KDE
        fi
    fi
}

install_gui_backend() {
    info "Bước 4: Cài plugin hiển thị flatpak trong App Center..."
    case "$DESKTOP" in
        *GNOME*) apt-get install -y gnome-software-plugin-flatpak && ok "Đã cài plugin cho GNOME Software" || warn "Không cài được plugin Flatpak cho GNOME Software — vẫn dùng Flatpak qua CLI được" ;;
        *KDE*|*Plasma*) apt-get install -y plasma-discover-backend-flatpak && ok "Đã cài backend cho KDE Discover" || warn "Không cài được backend Flatpak cho KDE Discover — vẫn dùng Flatpak qua CLI được" ;;
        *) warn "Không nhận diện được desktop (trống nếu chạy qua sudo) — bỏ qua plugin GUI" ;;
    esac
}

do_enable_flatpak_flathub() {
    LOG_CONTEXT=flatpak
    info "Bước 1: Cập nhật danh sách gói..."
    wait_apt
    apt-get update || return $?
    info "Bước 2: Cài flatpak..."
    apt-get install -y flatpak || return $?
    ok "Đã cài flatpak"
    info "Bước 3: Thêm kho Flathub..."
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || return $?
    ok "Đã thêm kho Flathub"
    detect_desktop
    install_gui_backend
    info "Bước 5: Kiểm tra cấu hình..."
    flatpak remotes | grep -q flathub || die "Không thấy kho Flathub — kiểm tra lại kết nối mạng"
    ok "Flathub đã sẵn sàng"
}

do_setup_ime() {
    LOG_CONTEXT=ime
    info "Bước 1: Cập nhật danh sách gói..."
    wait_apt
    apt-get update || return $?
    info "Bước 2: Cài fcitx5..."
    PKGS="fcitx5 fcitx5-config-qt"
    KIM=0
    detect_desktop
    case "$DESKTOP" in
        *KDE*|*Plasma*) PKGS="$PKGS kde-config-fcitx5"; info "Phát hiện KDE — thêm kde-config-fcitx5" ;;
        *GNOME*)
            if apt-cache show gnome-shell-extension-manager >/dev/null 2>&1; then PKGS="$PKGS gnome-shell-extension-manager"; fi
            if apt-cache show gnome-shell-extension-kimpanel >/dev/null 2>&1; then PKGS="$PKGS gnome-shell-extension-kimpanel"; KIM=1; fi
            ;;
    esac
    for eng in fcitx5-unikey fcitx5-bamboo; do
        if apt-cache show "$eng" >/dev/null 2>&1; then PKGS="$PKGS $eng"; else warn "Repo không có $eng — bỏ qua"; fi
    done
    apt-get install -y $PKGS || return $?
    if [ "$KIM" -eq 1 ]; then
        [ -z "$SUDO_USER" ] || sudo -u "$SUDO_USER" gnome-extensions enable kimpanel@wengxt 2>/dev/null || true
        ok "Đã cài kimpanel — đăng xuất/đăng nhập lại để hiển thị status bar"
    fi
    info "Bước 3: Purge ibus và thêm fcitx5 vào autostart..."
    if dpkg -l ibus 2>/dev/null | grep -q '^ii'; then
        apt-get purge -y ibus
        apt-get autoremove -y --purge
        rm -rf /root/.config/ibus /root/.cache/ibus /home/*/.config/ibus /home/*/.cache/ibus
        ok "Đã purge sạch ibus"
    else ok "ibus chưa được cài — bỏ qua"
    fi
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != root ]; then
        HOME_USER=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        AUTOSTART="$HOME_USER/.config/autostart"
        sudo -u "$SUDO_USER" mkdir -p "$AUTOSTART"
        if [ -f /usr/share/applications/org.fcitx.Fcitx5.desktop ]; then
            sudo -u "$SUDO_USER" cp /usr/share/applications/org.fcitx.Fcitx5.desktop "$AUTOSTART/"
        else
            cat > "$AUTOSTART/org.fcitx.Fcitx5.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=fcitx5
Exec=fcitx5
Icon=fcitx
Terminal=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Phase=Applications
EOF
            chown "$SUDO_USER" "$AUTOSTART/org.fcitx.Fcitx5.desktop"
        fi
        ok "Đã thêm fcitx5 vào autostart của $SUDO_USER"
    else warn "Không xác định được user — bỏ qua bước autostart"
    fi
}

do_install_lotus() {
    LOG_CONTEXT=lotus
    CODENAME=$(grep '^UBUNTU_CODENAME=' /etc/os-release | cut -d= -f2)
    [ -n "$CODENAME" ] || die "Không tìm thấy UBUNTU_CODENAME — hệ thống không phải Ubuntu-based"
    info "Bước 1: Chuẩn bị repo fcitx5-lotus cho $CODENAME..."
    wait_apt
    command -v curl >/dev/null 2>&1 || apt-get install -y curl
    command -v gpg >/dev/null 2>&1 || apt-get install -y gpg
    mkdir -p /etc/apt/keyrings
    LOTUS_REPO_FILES=$(grep -rsl "fcitx5-lotus.pages.dev/apt/$CODENAME" /etc/apt/sources.list.d/ /etc/apt/sources.list 2>/dev/null || true)
    if [ -z "$LOTUS_REPO_FILES" ]; then
        curl -fsSL https://fcitx5-lotus.pages.dev/pubkey.gpg | gpg --yes --dearmor -o /etc/apt/keyrings/fcitx5-lotus.gpg
        echo "deb [signed-by=/etc/apt/keyrings/fcitx5-lotus.gpg] https://fcitx5-lotus.pages.dev/apt/$CODENAME $CODENAME main" > /etc/apt/sources.list.d/fcitx5-lotus.list
    fi
    apt-get update || return $?
    apt-get install -y fcitx5-lotus || return $?
    dpkg -l fcitx5-lotus 2>/dev/null | grep -q '^ii' || die "fcitx5-lotus cài chưa thành công"
    detect_desktop
    mkdir -p /etc/environment.d
    if [ ! -f /etc/environment.d/fcitx5.conf ]; then
        printf 'XMODIFIERS=@im=fcitx\nGLFW_IM_MODULE=ibus\n' > /etc/environment.d/fcitx5.conf
        case "$DESKTOP" in *KDE*|*Plasma*) ;; *) printf 'QT_IM_MODULE=fcitx\nQT_IM_MODULES="wayland;fcitx"\n' >> /etc/environment.d/fcitx5.conf ;; esac
    fi
    case "$DESKTOP" in
        *KDE*|*Plasma*)
            if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != root ]; then
                HOME_USER=$(getent passwd "$SUDO_USER" | cut -d: -f6)
                KWINRC="$HOME_USER/.config/kwinrc"
                sudo -u "$SUDO_USER" mkdir -p "$HOME_USER/.config"
                if grep -q org.fcitx.Fcitx5.desktop "$KWINRC" 2>/dev/null; then
                    ok "kwinrc đã trỏ fcitx5 — bỏ qua"
                elif grep -q '^InputMethod' "$KWINRC" 2>/dev/null; then
                    warn "kwinrc InputMethod trỏ input method khác — giữ nguyên"
                else
                    printf '\n[Wayland]\nInputMethod[$e]=/usr/share/applications/org.fcitx.Fcitx5.desktop\n' >> "$KWINRC"
                    chown "$SUDO_USER" "$KWINRC"
                    ok "Đã ghi kwinrc InputMethod=fcitx5"
                fi
            fi
            ;;
    esac
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != root ]; then
        HOME_USER=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        PROFILE="$HOME_USER/.config/fcitx5/profile"
        sudo -u "$SUDO_USER" mkdir -p "$HOME_USER/.config/fcitx5/conf"
        if [ ! -f "$PROFILE" ]; then
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
        elif ! grep -q '^Name=lotus$' "$PROFILE"; then
            N=$(grep -c '^\[Groups/0/Items/' "$PROFILE")
            printf '\n[Groups/0/Items/%s]\nName=lotus\nLayout=\n' "$N" >> "$PROFILE"
        fi
        chown "$SUDO_USER" "$PROFILE"
        FCONF_DIR="$HOME_USER/.config/fcitx5/conf"
        if [ ! -f "$FCONF_DIR/lotus-app-rules.conf" ]; then
            printf 'slack=4\nplanmaker24free=4\ntextmaker24free=4\npresentations24free=4\n' > "$FCONF_DIR/lotus-app-rules.conf"
            chown "$SUDO_USER" "$FCONF_DIR/lotus-app-rules.conf"
        fi
        if [ ! -f "$FCONF_DIR/lotus.conf" ]; then
            cat > "$FCONF_DIR/lotus.conf" <<'EOF'
Mode="Uinput (Super Smooth)"
InputMethod=Telex
OutputCharset=Unicode
CycleModeKey=
W2U=Non-Start
BracketTransform=Disabled
SpellCheck=True
EnableMacro=True
CapitalizeMacro=True
AutoCapitalizeAfterPunctuation=False
DoubleSpaceToPeriod=False
DoubleHyphenToEmDash=False
AutoNonVnRestore=True
ModernStyle=True
FreeMarking=True
DdFreeStyle=True
FixUinputWithAck=False
UseLotusIcons=False
EnableDictionary=False
EnableCustomKeymap=False
ShowModeSmooth=True
ShortcutSmooth=1
ShowModeUinput=True
ShortcutUinput=2
ShowModeSuperSmooth=True
ShortcutSuperSmooth=a
ShowModeMinecraft=True
ShortcutMinecraft=3
ShowModeSurroundingText=True
ShortcutSurroundingText=4
ShowModePreedit=True
ShortcutPreedit=q
ShowModeEmoji=True
ShortcutEmoji=w
ShowModeOff=True
ShortcutOff=e
ShowModeDefault=True
ShortcutDefault=r
EnableMacroInOffMode=False
ModeOrder=Smooth,Uinput,Minecraft,SurroundingText,Preedit,Emoji,Off,SuperSmooth,Default
TimeFormat=%H:%M
DateFormat=%d/%m/%Y

[ModeMenuKey]
0=grave
EOF
            chown "$SUDO_USER" "$FCONF_DIR/lotus.conf"
        fi
    else warn "Không xác định được user — bỏ qua profile và config Lotus"
    fi
    ok "Lotus đã sẵn sàng; đăng xuất/đăng nhập lại để áp dụng"
}

BASICS_FAILURES=0
run_best_effort() {
    basics_label=$1
    basics_function=$2
    if ( "$basics_function" ); then return 0; fi
    basics_code=$?
    warn "$basics_label thất bại (exit $basics_code) — tiếp tục"
    BASICS_FAILURES=$((BASICS_FAILURES + 1))
}
enable_flatpak_flathub() { run_best_effort "Bật Flatpak & Flathub" do_enable_flatpak_flathub; }
setup_ime() { run_best_effort "Thiết lập bộ gõ fcitx5" do_setup_ime; }
install_lotus() { run_best_effort "Cài & cấu hình bộ gõ tiếng Việt Lotus" do_install_lotus; }

if [ -z "$SETUP_SELECTED" ]; then
    warn "Không chọn mục thiết lập cơ bản nào — không thực hiện thay đổi"
    exit 0
fi
[ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"
setup_run_selected "$CHILD_FILE" "$SETUP_SELECTED"
[ "$BASICS_FAILURES" -eq 0 ] || exit 1
