#!/bin/sh
# @setup-description: Preset IME Configs
# @setup-when: always
# @setup-item: ime_shortcut|IME Shortcut
# @setup-item: lotus_super_smooth|Lotus Super Smooth
printf '%s|%s\n' "$(basename "$0")" "$*" >> "$SETUP_TEST_LOG"
