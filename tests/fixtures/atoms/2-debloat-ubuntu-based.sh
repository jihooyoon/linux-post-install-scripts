#!/bin/sh
# @setup-description: Preset Debloat
# @setup-when: always
# @setup-core-description: core
case "${SETUP_TEST_TUXEDO:-0}:$*" in
    1:*) printf '%s|tuxedo|%s\n' "$(basename "$0")" "$*" ;;
    *:--keep-snap*|*:*\ --keep-snap*) printf '%s|keep-snap|%s\n' "$(basename "$0")" "$*" ;;
    *) printf '%s|desnap|%s\n' "$(basename "$0")" "$*" ;;
esac >> "$SETUP_TEST_LOG"
