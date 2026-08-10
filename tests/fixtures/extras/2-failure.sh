#!/bin/sh
# @setup-description: Failing extra
# @setup-when: always
# @setup-core-description: fixture failure
printf '%s|%s\n' "$(basename -- "$0")" "$*" >> "$SETUP_TEST_LOG"
exit 7
