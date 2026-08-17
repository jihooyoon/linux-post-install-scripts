#!/bin/sh
# @setup-description: Preset Basics
# @setup-when: always
# @setup-item: flatpak|Flatpak
# @setup-item: ime|IME
# @setup-item: lotus|Lotus
printf '%s|%s\n' "$(basename "$0")" "$*" >> "$SETUP_TEST_LOG"
