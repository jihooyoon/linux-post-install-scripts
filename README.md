# Linux Post-Installing Scripts

Scripts for configuring Linux distros after clean install

## Cơ chế scripts:

**Những việc scripts sẽ làm:**

- De-Bullshit Ubuntu: Mục tiêu gỡ hoàn toàn snap, tránh bloat
- Bật Flatpak
- Cài bộ gõ fcitx5, Office tùy chọn (ONLYOFFICE, FreeOffice, LibreOffice) và app cơ bản (browser,...)
- Cài bộ gõ tiếng Việt Lotus cho fcitx5
- Setup các extras (chat apps, claude, shortcut chuyển bộ gõ (Alt + Space với Ubuntu/GNOME và Win + Space với các môi trường còn lại), nodejs,...)

**Hiện tại mới chỉ support các distro Ubuntu-based:**

- Ubuntu và các flavors (VD Kubuntu)
- Tuxedo OS
- Các distro nền Ubuntu/Debian khác (Linux Mint, Pop!_OS, Zorin...) cũng có thể chạy, nhưng chưa được test kĩ.

## Cách sử dụng:

### Remote setup (recommended): một lệnh duy nhất (không cần clone tay):

#### Pre-defined Packs (chọn sẵn, hoàn toàn auto):

*Pack MS:*
Đầy đủ cho MS, bao gồm OnlyOffice và các lựa chọn còn lại
```bash
command -v curl >/dev/null 2>&1 || (sudo apt-get update && sudo apt-get install -y -q curl); curl -fsSL https://raw.githubusercontent.com/jihooyoon/linux-post-install-scripts/main/remote-setup.sh | sh -s -- --pack-ms
```

*Pack BS:*
Cơ bản, phù hợp cho BS, chỉ bao gồm bộ gõ, OnlyOffice, Chrome, Mattermost, và Claude Desktop
```bash
command -v curl >/dev/null 2>&1 || (sudo apt-get update && sudo apt-get install -y -q curl); curl -fsSL https://raw.githubusercontent.com/jihooyoon/linux-post-install-scripts/main/remote-setup.sh | sh -s -- --pack-bs --keep-snap
```


#### Setup tuỳ chỉnh (có menu để bật/tắt từng hạng mục):

```bash
command -v curl >/dev/null 2>&1 || (sudo apt-get update && sudo apt-get install -y -q curl); curl -fsSL https://raw.githubusercontent.com/jihooyoon/linux-post-install-scripts/main/remote-setup.sh | sh
```

*Dev branch:*
```bash
command -v curl >/dev/null 2>&1 || (sudo apt-get update && sudo apt-get install -y -q curl); curl -fsSL https://raw.githubusercontent.com/jihooyoon/linux-post-install-scripts/dev/remote-setup.sh | sh -s -- --dev
```

#### Notes:

*Không cần `sudo` ở ngoài — `remote-setup.sh` tự gọi `sudo` khi chạy phần cài đặt (chỉ hỏi mật khẩu sudo khi cần). Cách cũ (`curl ... | sudo sh`, `sudo sh remote-setup.sh`) vẫn hoạt động.*

*Tham số `remote-setup.sh`:*

| Tham số           | Mô tả                                                                                     |
| ------------------ | ------------------------------------------------------------------------------------------- |
| *(không)*       | Chạy `setup-ubuntu-based.sh` với menu động và review trước execution                |
| `--dev`          | Tải và chạy source từ nhánh`dev` thay vì `main`                                   |
| `--all`, `-a`  | Không hiện menu, tự chọn tất cả                                                       |
| `--pack-ms`      | Chọn OnlyOffice; các script và item khác chọn tất cả                                 |
| `--pack-bs`      | Chọn OnlyOffice, Chrome, Mattermost, IME và Claude Desktop                                |
| `--keep-snap`    | Giữ Snap, bỏ bước De-snap (atom 1) trên Ubuntu và các flavors (VD Kubuntu, tạm check bằng non-Tuxedo); dùng được cùng các pack |
| `--help`, `-h` | In trợ giúp                                                                               |

*Debug mode:* Thêm `DEBUG=1` trước `sh` để thấy tất cả lệnh đang chạy:
```bash
curl -fsSL https://raw.githubusercontent.com/jihooyoon/linux-post-install-scripts/main/remote-setup.sh | DEBUG=1 sh
```

*Cơ chế remote setup:*
> `remote-setup.sh` tự tải repo về `/tmp`, cấp quyền execute, rồi tự gọi `sudo` để chạy entrypoint thống nhất `setup-ubuntu-based.sh`. Ngoài `--dev` (chỉ chọn branch source), mọi argument được passthrough sang entrypoint; `DEBUG=1` được giữ khi đi qua `sudo`. File tạm luôn được dọn khi kết thúc. Khi chạy qua pipe (`curl | sh`), stdin của parent được nối với terminal thật để menu nhận input.

### Manual setup: Clone repo rồi chạy tay:

- Cần chmod để cấp quyền run cho các file script
- Chạy `sudo ./setup-ubuntu-based.sh` để chọn atom items và extras qua menu động
- Dùng `sudo ./setup-ubuntu-based.sh --all`, `--pack-ms` hoặc `--pack-bs` để chạy không tương tác; thêm `--keep-snap` để giữ Snap và bỏ atom De-snap trên máy non-Tuxedo
- Các scripts con cũng có thể chạy độc lập, tuy nhiên đa phần scripts phục vụ nhu cầu chạy độc lập sẽ nằm trong `extras`, các scripts trong `atom-scripts` gần như luôn cần

**CLI của parent và script con:**

| Phạm vi                  | Tham số hỗ trợ                                                            |
| ------------------------- | ---------------------------------------------------------------------------- |
| `setup-ubuntu-based.sh` | `--all`, `-a`, `--pack-ms`, `--pack-bs`, `--keep-snap`, `--help` |
| Child có item            | `--all`, `-a`, một hoặc nhiều item number, `--help`                 |
| Child chỉ có core       | Không argument hoặc `--all`, `--help`                                   |

> Chỉ parent có menu. Child không argument sẽ chạy core nếu có; child không có core sẽ warning rồi no-op. Parent tiếp tục các script còn lại khi một child lỗi và trả non-zero tổng hợp ở cuối.

### Additional: Nếu dùng GNOME (VD: Ubuntu)

**Cài thêm extension cần thiết từ GNOME Extension Manager:**

- **KIMPanel (Hiển thị bộ gõ trên status bar)** - Highly recommend để bộ gõ tiếng Việt có trải nghiệm tốt:
  [https://extensions.gnome.org/extension/261/kimpanel](https://extensions.gnome.org/extension/261/kimpanel)
