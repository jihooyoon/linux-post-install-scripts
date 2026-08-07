#!/bin/sh
# set-ime-shortcut.sh — BẢN DRAFT: chỉ in thông báo, không làm gì thật.
# Script thật: sudo ./extras/set-ime-shortcut.sh
# Phím tắt chuyển input method (GNOME: Alt+Space / KDE: Super+Space)

set -e

info() { printf '\033[1;34m[ime]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m     %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m   %s\n' "$*"; }

# Bản draft: không kiểm tra root / SUDO_USER (script thật yêu cầu sudo).

info "draft-set-ime-shortcut.sh được gọi — args nhận được: '$*'"
info "Stub: sẽ cài phím tắt chuyển input method (GNOME: Alt+Space / KDE: Super+Space)"
ok "DRAFT: Hoàn tất draft-set-ime-shortcut.sh"
