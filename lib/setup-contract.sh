#!/bin/sh
# Shared metadata and argument contract for setup parent/child scripts.

setup_contract_error() {
    printf '\033[1;31m[ERROR]\033[0m  %s\n' "$*" >&2
}

setup_meta_values() {
    _setup_file=$1
    _setup_key=$2
    awk -v prefix="# @setup-${_setup_key}: " '
        index($0, prefix) == 1 { print substr($0, length(prefix) + 1) }
    ' "$_setup_file"
}

setup_description() {
    setup_meta_values "$1" description
}

setup_when() {
    setup_meta_values "$1" when
}

setup_core_description() {
    setup_meta_values "$1" core-description
}

setup_items() {
    setup_meta_values "$1" item
}

setup_item_count() {
    setup_items "$1" | awk 'NF { count++ } END { print count + 0 }'
}

setup_has_word() {
    _setup_words=$1
    _setup_needle=$2
    case " $_setup_words " in
        *" $_setup_needle "*) return 0 ;;
        *) return 1 ;;
    esac
}

setup_validate_metadata() {
    _setup_file=$1

    [ -f "$_setup_file" ] || {
        setup_contract_error "Không tìm thấy script: $_setup_file"
        return 1
    }

    _setup_description_count=$(setup_meta_values "$_setup_file" description | awk 'END { print NR + 0 }')
    _setup_description=$(setup_description "$_setup_file")
    if [ "$_setup_description_count" -ne 1 ] || [ -z "$_setup_description" ]; then
        setup_contract_error "$_setup_file: metadata description phải có đúng một giá trị"
        return 1
    fi
    case "$_setup_description" in
        *'|'*)
            setup_contract_error "$_setup_file: description không được chứa ký tự |"
            return 1
            ;;
    esac

    _setup_when_count=$(setup_meta_values "$_setup_file" when | awk 'END { print NR + 0 }')
    _setup_when=$(setup_when "$_setup_file")
    if [ "$_setup_when_count" -ne 1 ]; then
        setup_contract_error "$_setup_file: metadata when phải có đúng một giá trị"
        return 1
    fi
    case "$_setup_when" in
        always|tuxedo|non-tuxedo) ;;
        *)
            setup_contract_error "$_setup_file: when không hợp lệ: $_setup_when"
            return 1
            ;;
    esac

    _setup_core_count=$(setup_meta_values "$_setup_file" core-description | awk 'END { print NR + 0 }')
    if [ "$_setup_core_count" -gt 1 ]; then
        setup_contract_error "$_setup_file: core-description chỉ được khai báo tối đa một lần"
        return 1
    fi
    _setup_core=$(setup_core_description "$_setup_file")
    case "$_setup_core" in
        *'|'*)
            setup_contract_error "$_setup_file: core-description không được chứa ký tự |"
            return 1
            ;;
    esac

    _setup_item_lines=$(setup_items "$_setup_file")
    _setup_seen_functions=""
    while IFS='|' read -r _setup_function _setup_label _setup_extra; do
        [ -n "$_setup_function$_setup_label$_setup_extra" ] || continue
        if [ -z "$_setup_function" ] || [ -z "$_setup_label" ] || [ -n "$_setup_extra" ]; then
            setup_contract_error "$_setup_file: item phải có dạng function|label"
            return 1
        fi
        case "$_setup_function" in
            [A-Za-z_]*[!A-Za-z0-9_]*|[!A-Za-z_]*|'')
                setup_contract_error "$_setup_file: function item không hợp lệ: $_setup_function"
                return 1
                ;;
        esac
        if setup_has_word "$_setup_seen_functions" "$_setup_function"; then
            setup_contract_error "$_setup_file: function item bị trùng: $_setup_function"
            return 1
        fi
        _setup_seen_functions="${_setup_seen_functions}${_setup_seen_functions:+ }$_setup_function"
    done <<EOF
$_setup_item_lines
EOF

    return 0
}

setup_print_help() {
    _setup_file=$1
    _setup_name=$(basename -- "$_setup_file")
    _setup_description=$(setup_description "$_setup_file")
    _setup_core=$(setup_core_description "$_setup_file")
    _setup_items_text=$(setup_items "$_setup_file")

    printf 'Usage: sudo %s [--all|-a] [item-number ...] [--help|-h]\n' "$_setup_name"
    printf '\n%s\n\n' "$_setup_description"
    if [ -n "$_setup_core" ]; then
        printf '  (không đối số)  Chỉ chạy core: %s\n' "$_setup_core"
    else
        printf '  (không đối số)  Không chạy item nào (warning rồi thoát thành công)\n'
    fi
    printf '  --all, -a       Chạy toàn bộ item\n'
    printf '  --help, -h      In trợ giúp này\n'

    _setup_i=1
    while IFS='|' read -r _setup_function _setup_label; do
        [ -n "$_setup_function" ] || continue
        [ "$_setup_i" -eq 1 ] && printf '\nCác item có thể chọn:\n'
        printf '  %d) %s\n' "$_setup_i" "$_setup_label"
        _setup_i=$((_setup_i + 1))
    done <<EOF
$_setup_items_text
EOF
}

setup_child_prepare() {
    _setup_file=$1
    shift

    setup_validate_metadata "$_setup_file" || return 2

    SETUP_SHOW_HELP=0
    SETUP_SELECTED=""
    SETUP_SELECTION_MODE=core

    if [ "$#" -eq 1 ]; then
        case "$1" in
            --help|-h)
                SETUP_SHOW_HELP=1
                SETUP_SELECTION_MODE=help
                return 0
                ;;
        esac
    fi

    _setup_all=0
    _setup_requested=""
    _setup_count=$(setup_item_count "$_setup_file")

    for _setup_arg in "$@"; do
        case "$_setup_arg" in
            --all|-a)
                _setup_all=$((_setup_all + 1))
                ;;
            --help|-h|--*)
                setup_contract_error "Không rõ tuỳ chọn: $_setup_arg"
                return 2
                ;;
            ''|*[!0-9]*|0|0*)
                setup_contract_error "Argument item không hợp lệ: $_setup_arg"
                return 2
                ;;
            *)
                if [ "$_setup_arg" -gt "$_setup_count" ]; then
                    setup_contract_error "Item $_setup_arg ngoài range 1..$_setup_count"
                    return 2
                fi
                _setup_requested="${_setup_requested}${_setup_requested:+ }$_setup_arg"
                ;;
        esac
    done

    if [ "$_setup_all" -gt 0 ] && [ -n "$_setup_requested" ]; then
        setup_contract_error "Chưa hỗ trợ trộn --all/-a với item number"
        return 2
    fi
    if [ "$_setup_all" -gt 1 ]; then
        setup_contract_error "--all/-a chỉ được truyền một lần"
        return 2
    fi

    if [ "$_setup_all" -eq 1 ]; then
        SETUP_SELECTION_MODE=all
        _setup_i=1
        while [ "$_setup_i" -le "$_setup_count" ]; do
            SETUP_SELECTED="${SETUP_SELECTED}${SETUP_SELECTED:+ }$_setup_i"
            _setup_i=$((_setup_i + 1))
        done
        return 0
    fi

    if [ -n "$_setup_requested" ]; then
        SETUP_SELECTION_MODE=items
        _setup_i=1
        while [ "$_setup_i" -le "$_setup_count" ]; do
            if setup_has_word "$_setup_requested" "$_setup_i"; then
                SETUP_SELECTED="${SETUP_SELECTED}${SETUP_SELECTED:+ }$_setup_i"
            fi
            _setup_i=$((_setup_i + 1))
        done
    fi

    return 0
}

setup_run_selected() {
    _setup_file=$1
    _setup_selected=$2
    _setup_items_text=$(setup_items "$_setup_file")
    _setup_i=1

    while IFS='|' read -r _setup_function _setup_label; do
        [ -n "$_setup_function" ] || continue
        if setup_has_word "$_setup_selected" "$_setup_i"; then
            printf '\n\033[1;36m[item]\033[0m %d) %s\n' "$_setup_i" "$_setup_label"
            "$_setup_function" || return $?
        fi
        _setup_i=$((_setup_i + 1))
    done <<EOF
$_setup_items_text
EOF
}

setup_when_applies() {
    _setup_condition=$1
    _setup_is_tuxedo=$2
    case "$_setup_condition" in
        always) return 0 ;;
        tuxedo) [ "$_setup_is_tuxedo" -eq 1 ] ;;
        non-tuxedo) [ "$_setup_is_tuxedo" -eq 0 ] ;;
        *) return 1 ;;
    esac
}
