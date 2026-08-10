#!/bin/sh
# @setup-description: Extra core fixture
# @setup-when: always
# @setup-core-description: extra core
printf '%s|%s\n' "$(basename -- "$0")" "$*" >> "$SETUP_TEST_LOG"
