#!/bin/sh
# generalize-tuxedo-os.sh — BẢN DRAFT: chỉ in thông báo, không làm gì thật.
# Script thật: sudo ./atom-scripts/generalize-tuxedo-os.sh
# Gỡ app Tuxedo (Control Center...) để biến Tuxedo OS thành KDE neon thuần

set -e

info() { printf '\033[1;34m[tuxedo-generalize]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m     %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m   %s\n' "$*"; }

# Bản draft: không kiểm tra root (script thật yêu cầu sudo).

info "draft-generalize-tuxedo-os.sh được gọi — args nhận được: '$*'"
info "Stub: sẽ gỡ app GUI Tuxedo (Control Center, Tomte...)"
ok "DRAFT: Hoàn tất draft-generalize-tuxedo-os.sh"
