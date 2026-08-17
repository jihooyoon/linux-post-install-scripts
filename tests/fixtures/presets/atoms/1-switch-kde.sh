#!/bin/sh
# @setup-description: Preset switch KDE
# @setup-when: always
# @setup-core-description: switch KDE
printf '%s|%s\n' "$(basename "$0")" "$*" >> "$SETUP_TEST_LOG"
if [ "${SETUP_TEST_KDE_FAIL:-0}" = 1 ]; then
    exit 23
fi
