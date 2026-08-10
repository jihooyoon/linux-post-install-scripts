#!/bin/sh
# @setup-description: Extra without core
# @setup-when: always
# @setup-item: first_extra|First extra item
# @setup-item: second_extra|Second extra item
printf '%s|%s\n' "$(basename -- "$0")" "$*" >> "$SETUP_TEST_LOG"
