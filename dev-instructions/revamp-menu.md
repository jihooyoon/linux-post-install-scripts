# Revamp Cơ chế Menu

## Mục tiêu và mốc migrate

- Xoá menu ở các script con, gom toàn bộ lựa chọn vào một menu tổng, review một lần rồi chạy tự động không hỏi thêm.
- Mốc scripts gốc khi tách nhánh `dev`: commit `408cb0c5bbb7c693b4a9f3b25331a1b4b4caf956` (`add dev branch option`).
- Hợp nhất `setup-all-ubuntu-based.sh` và `setup-basic-ubuntu-based.sh` thành `setup-ubuntu-based.sh`; không giữ compatibility wrapper.

## Contract metadata của script con (R.1)

Mỗi file `<số>-*.sh` trong `basics` và `extras` khai báo metadata trong header để parent và child cùng đọc từ một nguồn:

- `description`: bắt buộc, mô tả ngắn gọn script.
- `when`: bắt buộc, luôn là `always`.
- `core-description`: không bắt buộc; mô tả phần luôn chạy dù không chọn item.
- `item`: zero hoặc nhiều dòng `function|label`; số argument được tính động theo thứ tự các dòng.

Metadata không hợp lệ làm script đó bị skip và được ghi nhận là failure; parent vẫn tiếp tục với các script khác. Thêm/xoá item chỉ cần thêm/xoá function và dòng metadata, không sửa parser hoặc bảng argument.

### Arguments của child

- `--all`/`-a`: chạy toàn bộ item.
- Một hoặc nhiều số, ví dụ `1 3`: chạy các item hợp lệ theo thứ tự metadata, tự loại duplicate.
- Không argument: chạy core nếu có; nếu không có core thì warning và no-op thành công.
- `--help`/`-h`: sinh help và danh sách item động từ metadata.
- Token sai, số ngoài range hoặc trộn `--all` với số: báo lỗi trước mọi side effect và exit `2`.
- `--all` kèm số để exclude được hoãn, chưa triển khai trong phase này.

Script con không còn menu và không đọc `/dev/tty`.

## Phân loại core/item tại mốc migrate

### Basic scripts

- De-snap, Tuxedo generalization, Flatpak/Flathub, IME (fcitx5) và Lotus: toàn bộ logic hiện tại là core.
- Office: FreeOffice và LibreOffice là item; khi chỉ chọn một bộ thì gỡ best-effort bộ còn lại.
- Basic Apps: Chrome, Chromium và VS Code là item; không có core.

### Extras

- AI Tools: không có core; Claude Desktop, Claude Code CLI và Codex CLI là item.
- Chat Apps: không có core; Slack, Mattermost và Discord là item.
- IME Shortcut và Dev Tools: toàn bộ logic hiện tại là core, chưa tách item.

AI Tools và Chat Apps không được cài dependency hoặc sửa hệ thống khi không chọn item. Nếu một extra không có core và không chọn item, parent loại nó khỏi execution plan và review ghi `Skipped: no items selected`.

### Dependency/PATH theo item

- AI Tools bỏ bước chuẩn bị toàn cục:
  - Claude Desktop tự bảo đảm `curl`, `gpg`, apt lock/update rồi cài package.
  - Claude Code và Codex tự bảo đảm `curl`, sau đó gọi helper thêm `~/.local/bin` vào `.bashrc`/`.zshrc` dưới user thật, idempotent và không tạo file root-owned.
  - Chỉ các CLI mới sửa PATH; chọn riêng Claude Desktop không sửa PATH.
- Chat Apps bỏ `apt-get update`, `curl`, `gpg` toàn cục:
  - Slack tự bảo đảm `curl` + `gpg`, đợi apt lock rồi update/install.
  - Mattermost và Discord tự bảo đảm `curl`, chỉ đợi apt lock trước khi cài `.deb`; không cài `gpg` và không chạy `apt-get update`.

## Quy hoạch filename và applicability (R.2)

Atom scripts dùng order slot:

1. De-snap (`when=non-tuxedo`) và Tuxedo generalization (`when=tuxedo`) cùng prefix `1-`.
2. Flatpak/Flathub.
3. IME (fcitx5).
4. Office.
5. Basic Apps.
6. Lotus.

Extras đánh số độc lập theo thứ tự hiện tại: `1` AI Tools, `2` IME Shortcut, `3` Chat Apps, `4` Dev Tools.

Parent chỉ scan `<số>-*.sh`, lọc `when` theo `/etc/os-release` trước khi build menu và execution plan. Slot `1` phải còn đúng một variant; duplicate active slot hoặc không chọn được variant là failure nhưng không chặn các slot khác.

## Menu động ở parent (R.3)

### CLI của `setup-ubuntu-based.sh`

- Không cờ: menu tương tác.
- `--all`: chọn toàn bộ atom items và extras, không hiện menu.
- `--pack-ms`: chọn OnlyOffice; các script và item khác chọn tất cả.
- `--pack-bs`: chọn OnlyOffice, Chrome, Mattermost, shortcut IME và Claude Desktop; skip Node.js Dev Tools.
- Ba preset loại trừ lẫn nhau; parent ghi lựa chọn vào cùng state với menu rồi execution đọc state đó.
- Unknown flag báo lỗi trước execution.

`remote-setup.sh` chỉ dùng `--dev` để chọn branch source và passthrough mọi argument còn lại sang entrypoint; `DEBUG=1` được preserve qua sudo.

### Flow và điều hướng

1. Các stage item của atom theo order slot.
2. Stage chọn extras.
3. Stage item của từng extra được chọn.
4. Review execution plan.

Mỗi stage bắt buộc nhập; Enter rỗng hoặc input sai sẽ reprompt:

- `a`: chọn tất cả.
- Danh sách số cách nhau bằng whitespace.
- `s`: không chọn item.
- `b`: quay lại stage trước, giữ state còn hợp lệ.
- `q`: thoát thành công trước execution.
- Review dùng `r` để chạy, `b` để sửa, `q` để thoát.

Atom luôn nằm trong execution plan; `s` chỉ chạy core. Extra có core nhưng không có item vẫn chạy core. Extra không có core và không chọn item bị loại khỏi plan. Sau `r`, parent chạy atom theo slot rồi extras theo order và không hỏi thêm.

### Kết quả execution

- Skip do user hoặc do `when` không áp dụng là success.
- Parse error, metadata error hoặc runtime error được ghi nhận; parent tiếp tục chạy các script còn lại.
- Cuối cùng in summary `success/skipped/failed`; nếu có failure thì parent exit `1`, nếu không thì exit `0`.

## Acceptance tests

- `sh -n` pass cho helper, parent, remote setup và toàn bộ child.
- Metadata thêm/xoá item tự đổi range; metadata/token/order sai bị reject.
- Tuxedo/non-Tuxedo chỉ chọn đúng một variant slot `1`.
- Menu xử lý input rỗng/sai, all, số, skip, Back, Review, Run và Quit.
- CLI matrix gồm interactive, `--all`, `--pack-ms`, `--pack-bs` và reject preset trộn/lặp.
- AI/Chat no-argument không gọi apt/curl/gpg/network và không sửa PATH.
- Claude Desktop không sửa PATH; Claude/Codex CLI không cài `gpg` và cập nhật PATH idempotent dưới đúng user.
- Mattermost/Discord không gọi `gpg` hoặc `apt-get update`; Slack có gọi.
- Dummy child xác nhận đúng order/argument, extra rỗng bị loại, tiếp tục sau lỗi và exit non-zero tổng hợp.
- Test không được gọi apt/network hoặc sửa hệ thống thật.
