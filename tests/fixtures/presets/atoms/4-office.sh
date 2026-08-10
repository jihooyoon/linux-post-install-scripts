#!/bin/sh
# @setup-description: Preset Office
# @setup-when: always
# @setup-item: onlyoffice|OnlyOffice
# @setup-item: freeoffice|FreeOffice
# @setup-item: libreoffice|LibreOffice
printf '%s|%s\n' "$(basename "$0")" "$*" >> "$SETUP_TEST_LOG"
