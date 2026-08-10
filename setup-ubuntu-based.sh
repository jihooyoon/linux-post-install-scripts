#!/bin/sh
# setup-ubuntu-based.sh — Dynamic menu and runner for Ubuntu-based setup scripts.

[ "${DEBUG:-0}" = "1" ] && set -x

info() { printf '\033[1;36m[setup]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m    %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }
die()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

clear_menu_screen() {
    [ "${SETUP_TEST_MODE:-0}" = "1" ] && return
    [ -t 1 ] || return
    printf '\033[H\033[2J'
}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/lib/setup-contract.sh"

print_help() {
    cat <<EOF
Usage: sudo $0 [--all|-a] [--silent] [--basic] [--help|-h]

  (không đối số)  Mở menu động, review rồi chạy
  --all, -a       Chọn toàn bộ atom items và extras, không hiện menu
  --silent        Như --all và truyền --all xuống mọi child
  --basic         Chỉ chạy atom scripts, bỏ qua toàn bộ extras
  --help, -h      In trợ giúp này

Các cờ --basic, --all và --silent có thể kết hợp, không phụ thuộc thứ tự.
EOF
}

MODE_ALL=0
MODE_SILENT=0
MODE_BASIC=0
SHOW_HELP=0
for arg in "$@"; do
    case "$arg" in
        --all|-a) MODE_ALL=1 ;;
        --silent) MODE_ALL=1; MODE_SILENT=1 ;;
        --basic) MODE_BASIC=1 ;;
        --help|-h) SHOW_HELP=1 ;;
        *) die "Không rõ tuỳ chọn: $arg. Dùng --help để xem hướng dẫn." ;;
    esac
done
[ "$SHOW_HELP" -eq 0 ] || { print_help; exit 0; }

if [ "${SETUP_TEST_MODE:-0}" != "1" ]; then
    [ "$(id -u)" -eq 0 ] || die "Phải chạy với quyền root: sudo $0"
    [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ] \
        || die "Phải chạy bằng sudo để giữ user thật trong SUDO_USER: sudo $0"
fi

ATOM_DIR=${SETUP_ATOM_DIR:-"$SCRIPT_DIR/atom-scripts"}
EXTRA_DIR=${SETUP_EXTRA_DIR:-"$SCRIPT_DIR/extras"}
[ -d "$ATOM_DIR" ] || die "Không tìm thấy thư mục atom scripts: $ATOM_DIR"
[ "$MODE_BASIC" -eq 1 ] || [ -d "$EXTRA_DIR" ] \
    || die "Không tìm thấy thư mục extras: $EXTRA_DIR"

STATE_DIR=$(mktemp -d /tmp/setup-menu.XXXXXX) || die "Không tạo được thư mục state tạm"
cleanup_state() {
    [ -n "${STATE_DIR:-}" ] && [ -d "$STATE_DIR" ] && rm -rf "$STATE_DIR"
}
trap cleanup_state EXIT
trap 'cleanup_state; exit 130' INT
trap 'cleanup_state; exit 143' TERM

ATOM_MANIFEST="$STATE_DIR/atoms.manifest"
EXTRA_MANIFEST="$STATE_DIR/extras.manifest"
STATUS_FILE="$STATE_DIR/status"
STAGES_FILE="$STATE_DIR/stages"
EXTRA_SELECTED_FILE="$STATE_DIR/extras.selected"
: > "$ATOM_MANIFEST"
: > "$EXTRA_MANIFEST"
: > "$STATUS_FILE"
: > "$EXTRA_SELECTED_FILE"

FAIL_COUNT=0
record_status() {
    _status=$1
    _name=$2
    _detail=$3
    printf '%s|%s|%s\n' "$_status" "$_name" "$_detail" >> "$STATUS_FILE"
    [ "$_status" != "FAILED" ] || FAIL_COUNT=$((FAIL_COUNT + 1))
}

if [ -n "${SETUP_TEST_TUXEDO:-}" ]; then
    IS_TUXEDO=$SETUP_TEST_TUXEDO
elif grep -qi 'tuxedo' /etc/os-release 2>/dev/null; then
    IS_TUXEDO=1
else
    IS_TUXEDO=0
fi

remove_manifest_slot() {
    _manifest=$1
    _slot=$2
    awk -F'|' -v slot="$_slot" '$1 != slot' "$_manifest" > "$_manifest.tmp"
    mv -f "$_manifest.tmp" "$_manifest"
}

scan_directory() {
    _kind=$1
    _directory=$2
    _manifest=$3
    _invalid_slots=""
    : > "$_manifest"

    for _file in "$_directory"/[0-9]*-*.sh; do
        [ -f "$_file" ] || continue
        _base=$(basename -- "$_file")
        _slot=${_base%%-*}
        case "$_slot" in
            ''|*[!0-9]*|0|0*)
                record_status FAILED "$_kind:$_base" "invalid filename order"
                continue
                ;;
        esac

        if ! setup_validate_metadata "$_file"; then
            record_status FAILED "$_kind:$_base" "invalid metadata"
            continue
        fi

        _when=$(setup_when "$_file")
        if ! setup_when_applies "$_when" "$IS_TUXEDO"; then
            record_status SKIPPED "$_kind:$_base" "not applicable ($_when)"
            continue
        fi

        _description=$(setup_description "$_file")
        _core=$(setup_core_description "$_file")
        _count=$(setup_item_count "$_file")

        if setup_has_word "$_invalid_slots" "$_slot"; then
            record_status FAILED "$_kind:$_base" "slot $_slot đã bị vô hiệu do duplicate"
            continue
        fi

        if awk -F'|' -v slot="$_slot" '$1 == slot { found=1 } END { exit !found }' "$_manifest"; then
            remove_manifest_slot "$_manifest" "$_slot"
            _invalid_slots="${_invalid_slots}${_invalid_slots:+ }$_slot"
            record_status FAILED "$_kind:slot-$_slot" "multiple active scripts"
            continue
        fi

        printf '%s|%s|%s|%s|%s\n' \
            "$_slot" "$_file" "$_description" "$_core" "$_count" >> "$_manifest"
    done

    sort -t'|' -k1,1n -o "$_manifest" "$_manifest"
}

scan_directory atom "$ATOM_DIR" "$ATOM_MANIFEST"
if ! awk -F'|' '$1 == 1 { found=1 } END { exit !found }' "$ATOM_MANIFEST"; then
    record_status FAILED "atom:slot-1" "không có Tuxedo/non-Tuxedo variant phù hợp"
fi
if [ "$MODE_BASIC" -eq 0 ]; then
    scan_directory extra "$EXTRA_DIR" "$EXTRA_MANIFEST"
fi

selection_file() {
    printf '%s/%s-%s.selection\n' "$STATE_DIR" "$1" "$2"
}

get_selection() {
    _selection_path=$(selection_file "$1" "$2")
    [ -f "$_selection_path" ] && cat "$_selection_path"
}

set_selection() {
    _selection_path=$(selection_file "$1" "$2")
    printf '%s\n' "$3" > "$_selection_path"
}

build_stages() {
    : > "$STAGES_FILE"
    while IFS='|' read -r _slot _file _description _core _count; do
        [ -n "$_slot" ] || continue
        [ "$_count" -eq 0 ] || printf 'items|atom|%s|%s|%s\n' \
            "$_slot" "$_file" "$_description" >> "$STAGES_FILE"
    done < "$ATOM_MANIFEST"

    if [ "$MODE_BASIC" -eq 0 ] && [ -s "$EXTRA_MANIFEST" ]; then
        printf 'extras||||\n' >> "$STAGES_FILE"
        _enabled=$(cat "$EXTRA_SELECTED_FILE")
        while IFS='|' read -r _slot _file _description _core _count; do
            [ -n "$_slot" ] || continue
            if setup_has_word "$_enabled" "$_slot" && [ "$_count" -gt 0 ]; then
                printf 'items|extra|%s|%s|%s\n' \
                    "$_slot" "$_file" "$_description" >> "$STAGES_FILE"
            fi
        done < "$EXTRA_MANIFEST"
    fi
    printf 'review||||\n' >> "$STAGES_FILE"
}

read_menu_choice() {
    MENU_CHOICE=""
    if ! IFS= read -r MENU_CHOICE <&3; then
        die "Không đọc được input menu"
    fi
}

show_items() {
    _file=$1
    _items=$(setup_items "$_file")
    _i=1
    while IFS='|' read -r _function _label; do
        [ -n "$_function" ] || continue
        printf '  \033[1;33m%d)\033[0m %s\n' "$_i" "$_label"
        _i=$((_i + 1))
    done <<EOF
$_items
EOF
}

normalize_item_choice() {
    _file=$1
    _input=$2
    NORMALIZED_CHOICE=""
    NORMALIZED_ACTION=select
    case "$_input" in
        a) NORMALIZED_CHOICE=--all; return 0 ;;
        s) NORMALIZED_CHOICE=""; return 0 ;;
        b|q) NORMALIZED_ACTION=$_input; return 0 ;;
        '') warn "Bắt buộc nhập lựa chọn"; return 1 ;;
    esac

    _count=$(setup_item_count "$_file")
    _requested=""
    for _number in $_input; do
        case "$_number" in
            ''|*[!0-9]*|0|0*)
                warn "Item không hợp lệ: $_number"
                return 1
                ;;
        esac
        if [ "$_number" -gt "$_count" ]; then
            warn "Item $_number ngoài range 1..$_count"
            return 1
        fi
        _requested="${_requested}${_requested:+ }$_number"
    done
    [ -n "$_requested" ] || { warn "Bắt buộc nhập lựa chọn"; return 1; }

    _i=1
    while [ "$_i" -le "$_count" ]; do
        if setup_has_word "$_requested" "$_i"; then
            NORMALIZED_CHOICE="${NORMALIZED_CHOICE}${NORMALIZED_CHOICE:+ }$_i"
        fi
        _i=$((_i + 1))
    done
    return 0
}

show_item_stage() {
    _kind=$1
    _slot=$2
    _file=$3
    _description=$4
    _current=$(get_selection "$_kind" "$_slot")
    _core=$(setup_core_description "$_file")
    _count=$(setup_item_count "$_file")
    printf '\n\033[1;36m══════════════════════════════════════════\033[0m\n'
    printf '\033[1;36m  %s — chọn item\033[0m\n' "$_description"
    printf '\033[1;36m══════════════════════════════════════════\033[0m\n'
    show_items "$_file"
    [ "$_count" -eq 0 ] || printf '  -------\n'
    printf '  \033[1;33ma)\033[0m Tất cả item\n'
    if [ -n "$_core" ]; then
        printf '  \033[1;33ms)\033[0m Không chọn item (chỉ chạy core)\n'
    else
        printf '  \033[1;33ms)\033[0m Không chọn item (script sẽ bị skip)\n'
    fi
    printf '  \033[1;33mb)\033[0m Quay lại    \033[1;33mq)\033[0m Thoát\n'
    [ -z "$_current" ] || printf '  Lựa chọn hiện tại: %s\n' "$_current"
    printf '  -------\n'
    printf 'Nhập lựa chọn: '
}

normalize_extra_choice() {
    _input=$1
    NORMALIZED_CHOICE=""
    NORMALIZED_ACTION=select
    case "$_input" in
        a)
            while IFS='|' read -r _slot _rest; do
                [ -n "$_slot" ] || continue
                NORMALIZED_CHOICE="${NORMALIZED_CHOICE}${NORMALIZED_CHOICE:+ }$_slot"
            done < "$EXTRA_MANIFEST"
            return 0
            ;;
        s) return 0 ;;
        b|q) NORMALIZED_ACTION=$_input; return 0 ;;
        '') warn "Bắt buộc nhập lựa chọn"; return 1 ;;
    esac

    _requested=""
    for _number in $_input; do
        case "$_number" in
            ''|*[!0-9]*|0|0*) warn "Extra không hợp lệ: $_number"; return 1 ;;
        esac
        if ! awk -F'|' -v slot="$_number" '$1 == slot { found=1 } END { exit !found }' "$EXTRA_MANIFEST"; then
            warn "Không có extra số $_number"
            return 1
        fi
        _requested="${_requested}${_requested:+ }$_number"
    done

    while IFS='|' read -r _slot _rest; do
        [ -n "$_slot" ] || continue
        if setup_has_word "$_requested" "$_slot"; then
            NORMALIZED_CHOICE="${NORMALIZED_CHOICE}${NORMALIZED_CHOICE:+ }$_slot"
        fi
    done < "$EXTRA_MANIFEST"
    return 0
}

clear_deselected_extra_state() {
    _enabled=$1
    while IFS='|' read -r _slot _rest; do
        [ -n "$_slot" ] || continue
        if ! setup_has_word "$_enabled" "$_slot"; then
            _selection_path=$(selection_file extra "$_slot")
            [ ! -f "$_selection_path" ] || rm -f "$_selection_path"
        fi
    done < "$EXTRA_MANIFEST"
}

show_extra_stage() {
    _enabled=$(cat "$EXTRA_SELECTED_FILE")
    printf '\n\033[1;36m══════════════════════════════════════════\033[0m\n'
    printf '\033[1;36m  Chọn extra scripts\033[0m\n'
    printf '\033[1;36m══════════════════════════════════════════\033[0m\n'
    while IFS='|' read -r _slot _file _description _core _count; do
        [ -n "$_slot" ] || continue
        printf '  \033[1;33m%s)\033[0m %s\n' "$_slot" "$_description"
    done < "$EXTRA_MANIFEST"
    printf '  -------\n'
    printf '  \033[1;33ma)\033[0m Tất cả extras\n'
    printf '  \033[1;33ms)\033[0m Không chạy extras\n'
    printf '  \033[1;33mb)\033[0m Quay lại    \033[1;33mq)\033[0m Thoát\n'
    [ -z "$_enabled" ] || printf '  Lựa chọn hiện tại: %s\n' "$_enabled"
    printf '  -------\n'
    printf 'Nhập lựa chọn: '
}

selection_labels() {
    _file=$1
    _selection=$2
    _items=$(setup_items "$_file")
    _labels=""
    _i=1
    while IFS='|' read -r _function _label; do
        [ -n "$_function" ] || continue
        if [ "$_selection" = "--all" ] || setup_has_word "$_selection" "$_i"; then
            _labels="${_labels}${_labels:+, }$_label"
        fi
        _i=$((_i + 1))
    done <<EOF
$_items
EOF
    printf '%s\n' "$_labels"
}

print_script_review() {
    _kind=$1
    _slot=$2
    _file=$3
    _description=$4
    _core=$5
    _count=$6
    _selection=$(get_selection "$_kind" "$_slot")
    _labels=$(selection_labels "$_file" "$_selection")

    printf '  \033[97m%s. %s\033[0m\n' "$_slot" "$_description"
    [ -z "$_core" ] || printf '     \033[90mCore: %s\033[0m\n' "$_core"
    if [ "$_count" -gt 0 ]; then
        if [ -n "$_labels" ]; then
            printf '     \033[90mItems: %s\033[0m\n' "$_labels"
        elif [ -n "$_core" ]; then
            printf '     \033[90mItems: Skipped (core-only)\033[0m\n'
        else
            printf '     \033[90mSkipped: no items selected\033[0m\n'
        fi
    fi
}

show_review() {
    printf '\n\033[1;36m══════════════════════════════════════════\033[0m\n'
    printf '\033[1;36m  Review execution plan\033[0m\n'
    printf '\033[1;36m══════════════════════════════════════════\033[0m\n'
    printf '\nAtom scripts:\n'
    while IFS='|' read -r _slot _file _description _core _count; do
        [ -n "$_slot" ] || continue
        print_script_review atom "$_slot" "$_file" "$_description" "$_core" "$_count"
    done < "$ATOM_MANIFEST"

    if [ "$MODE_BASIC" -eq 1 ]; then
        printf '\n\033[90mExtras: Skipped (--basic)\033[0m\n'
    else
        printf '\nExtras:\n'
        _enabled=$(cat "$EXTRA_SELECTED_FILE")
        while IFS='|' read -r _slot _file _description _core _count; do
            [ -n "$_slot" ] || continue
            if setup_has_word "$_enabled" "$_slot"; then
                print_script_review extra "$_slot" "$_file" "$_description" "$_core" "$_count"
            else
                printf '  \033[97m%s. %s\033[0m\n' "$_slot" "$_description"
                printf '     \033[90mSkipped: not selected\033[0m\n'
            fi
        done < "$EXTRA_MANIFEST"
    fi
    printf '\n  \033[1;33mr)\033[0m Run    \033[1;33mb)\033[0m Back    \033[1;33mq)\033[0m Quit\n'
    printf 'Nhập lựa chọn: '
}

run_interactive_menu() {
    _input_source=${SETUP_MENU_INPUT:-/dev/tty}
    if [ "$_input_source" = "-" ]; then
        exec 3<&0
    else
        exec 3< "$_input_source" || die "Không mở được input menu: $_input_source"
    fi

    _stage_index=1
    while :; do
        build_stages
        _stage_count=$(wc -l < "$STAGES_FILE" | tr -d ' ')
        [ "$_stage_index" -le "$_stage_count" ] || _stage_index=$_stage_count
        _stage=$(sed -n "${_stage_index}p" "$STAGES_FILE")
        IFS='|' read -r _type _kind _slot _file _description <<EOF
$_stage
EOF

        case "$_type" in
            items)
                clear_menu_screen
                while :; do
                    show_item_stage "$_kind" "$_slot" "$_file" "$_description"
                    read_menu_choice
                    normalize_item_choice "$_file" "$MENU_CHOICE" && break
                done
                case "$NORMALIZED_ACTION" in
                    b)
                        if [ "$_stage_index" -gt 1 ]; then
                            _stage_index=$((_stage_index - 1))
                        else
                            warn "Đây là stage đầu tiên"
                        fi
                        ;;
                    q) exec 3<&-; return 10 ;;
                    *)
                        set_selection "$_kind" "$_slot" "$NORMALIZED_CHOICE"
                        _stage_index=$((_stage_index + 1))
                        ;;
                esac
                ;;
            extras)
                clear_menu_screen
                while :; do
                    show_extra_stage
                    read_menu_choice
                    normalize_extra_choice "$MENU_CHOICE" && break
                done
                case "$NORMALIZED_ACTION" in
                    b)
                        if [ "$_stage_index" -gt 1 ]; then
                            _stage_index=$((_stage_index - 1))
                        else
                            warn "Đây là stage đầu tiên"
                        fi
                        ;;
                    q) exec 3<&-; return 10 ;;
                    *)
                        printf '%s\n' "$NORMALIZED_CHOICE" > "$EXTRA_SELECTED_FILE"
                        clear_deselected_extra_state "$NORMALIZED_CHOICE"
                        _stage_index=$((_stage_index + 1))
                        ;;
                esac
                ;;
            review)
                clear_menu_screen
                show_review
                read_menu_choice
                case "$MENU_CHOICE" in
                    r) exec 3<&-; return 0 ;;
                    b)
                        if [ "$_stage_index" -gt 1 ]; then
                            _stage_index=$((_stage_index - 1))
                        else
                            warn "Không có stage trước"
                        fi
                        ;;
                    q) exec 3<&-; return 10 ;;
                    *) warn "Review chỉ nhận r, b hoặc q" ;;
                esac
                ;;
            *) die "Stage menu không hợp lệ: $_type" ;;
        esac
    done
}

run_child() {
    _kind=$1
    _slot=$2
    _file=$3
    _description=$4
    _args=$5
    _name="$_kind:$_slot:$(basename -- "$_file")"
    info "=== Bắt đầu: $_description ($(basename -- "$_file")) ==="
    if [ -n "$_args" ]; then
        sh "$_file" $_args
    else
        sh "$_file"
    fi
    _code=$?
    if [ "$_code" -eq 0 ]; then
        ok "Hoàn tất: $_description"
        record_status SUCCESS "$_name" "completed"
    else
        warn "$_description thất bại (exit $_code) — tiếp tục"
        record_status FAILED "$_name" "exit $_code"
    fi
}

execute_plan() {
    while IFS='|' read -r _slot _file _description _core _count; do
        [ -n "$_slot" ] || continue
        if [ "$MODE_ALL" -eq 1 ]; then
            _args=--all
        else
            _args=$(get_selection atom "$_slot")
        fi
        run_child atom "$_slot" "$_file" "$_description" "$_args"
    done < "$ATOM_MANIFEST"

    if [ "$MODE_BASIC" -eq 1 ]; then
        record_status SKIPPED extras "--basic"
        return
    fi

    if [ "$MODE_ALL" -eq 1 ]; then
        _enabled=""
        while IFS='|' read -r _slot _rest; do
            [ -n "$_slot" ] || continue
            _enabled="${_enabled}${_enabled:+ }$_slot"
        done < "$EXTRA_MANIFEST"
    else
        _enabled=$(cat "$EXTRA_SELECTED_FILE")
    fi

    while IFS='|' read -r _slot _file _description _core _count; do
        [ -n "$_slot" ] || continue
        if ! setup_has_word "$_enabled" "$_slot"; then
            record_status SKIPPED "extra:$_slot:$(basename -- "$_file")" "not selected"
            continue
        fi

        if [ "$MODE_ALL" -eq 1 ]; then
            _args=--all
        else
            _args=$(get_selection extra "$_slot")
        fi

        if [ "$_count" -gt 0 ] && [ -z "$_args" ] && [ -z "$_core" ]; then
            record_status SKIPPED "extra:$_slot:$(basename -- "$_file")" "no items selected"
            continue
        fi
        run_child extra "$_slot" "$_file" "$_description" "$_args"
    done < "$EXTRA_MANIFEST"
}

print_summary() {
    _success=$(awk -F'|' '$1 == "SUCCESS" { count++ } END { print count + 0 }' "$STATUS_FILE")
    _skipped=$(awk -F'|' '$1 == "SKIPPED" { count++ } END { print count + 0 }' "$STATUS_FILE")
    _failed=$(awk -F'|' '$1 == "FAILED" { count++ } END { print count + 0 }' "$STATUS_FILE")
    printf '\n\033[1;36m══════════════════════════════════════════\033[0m\n'
    printf '\033[1;36m  Execution summary\033[0m\n'
    printf '\033[1;36m══════════════════════════════════════════\033[0m\n'
    while IFS='|' read -r _status _name _detail; do
        [ -n "$_status" ] || continue
        case "$_status" in
            SUCCESS) _status_color=$(printf '\033[1;32m') ;;
            SKIPPED) _status_color=$(printf '\033[90m') ;;
            FAILED)  _status_color=$(printf '\033[1;31m') ;;
            *)       _status_color='' ;;
        esac
        printf '  %s%-7s\033[0m %s — %s\n' "$_status_color" "$_status" "$_name" "$_detail"
    done < "$STATUS_FILE"
    printf '\n  success=%s skipped=%s failed=%s\n' "$_success" "$_skipped" "$_failed"
}

if [ "$MODE_ALL" -eq 0 ]; then
    if run_interactive_menu; then
        :
    else
        _menu_code=$?
        if [ "$_menu_code" -eq 10 ]; then
            info "Đã thoát trước execution; không có thay đổi nào được thực hiện bởi parent"
            exit 0
        fi
        exit "$_menu_code"
    fi
else
    if [ "$MODE_BASIC" -eq 1 ]; then
        info "Chế độ không tương tác: chọn toàn bộ atom scripts, bỏ qua extras"
    else
        info "Chế độ không tương tác: chọn toàn bộ atom scripts và extras"
    fi
fi

execute_plan
print_summary

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi

printf '\n\033[1;32mHoàn tất toàn bộ!\033[0m Khởi động lại máy để áp dụng mọi thay đổi.\n'
exit 0
