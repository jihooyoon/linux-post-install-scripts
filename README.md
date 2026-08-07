# Linux Post-Installing Scripts

Scripts for configuring Linux distros after clean install

## Cơ chế scripts:

**Những việc scripts sẽ làm:**
- De-Bullshit Ubuntu: Mục tiêu gỡ hoàn toàn snap, tránh bloat
- Bật Flatpak
- Cài lại các app cơ bản (browser, email client, chuyển libreoffice thành freeoffice,...)
- Cài bộ gõ tiếng Việt dùng ổn nhất hiện tại (fcitx5-lotus)
- Setup các extras (chat apps, claude, shortcut chuyển bộ gõ (Alt + Space với Ubuntu/GNOME và Win + Space với các môi trường còn lại), nodejs,...)

**Hiện tại mới chỉ support các distro Ubuntu-based:** 
- Ubuntu và các flavors (VD Kubuntu)
- Tuxedo OS
- Các distro nền Ubuntu/Debian khác (Linux Mint, Pop!_OS, Zorin...) cũng có thể chạy, nhưng chưa được test kĩ.

## Cách sử dụng:

### Remote setup (recommended): một lệnh duy nhất (không cần clone tay): 

Full setup:

```bash
command -v curl >/dev/null 2>&1 || sudo apt-get install -y -q curl; curl -fsSL https://raw.githubusercontent.com/jihooyoon/linux-post-install-scripts/main/install-remote.sh | sh -s -- --silent
```

Basic setup:

```bash
command -v curl >/dev/null 2>&1 || sudo apt-get install -y -q curl; curl -fsSL https://raw.githubusercontent.com/jihooyoon/linux-post-install-scripts/main/install-remote.sh | sh -s -- --basic --silent
```

Setup with options (menu tương tác):

```bash
curl -fsSL https://raw.githubusercontent.com/jihooyoon/linux-post-install-scripts/main/install-remote.sh | sh
```

*Không cần `sudo` ở ngoài — `install-remote.sh` tự gọi `sudo` khi chạy phần cài đặt (chỉ hỏi mật khẩu sudo khi cần). Cách cũ (`curl ... | sudo sh`, `sudo sh install-remote.sh`) vẫn hoạt động.*

*Tham số `install-remote.sh`:*

| Tham số | Mô tả |
|---|---|
| *(không)* | Chạy `setup-all-ubuntu-based.sh` với menu tương tác |
| `--basic` | Chỉ chạy `setup-basic-ubuntu-based.sh` (bỏ qua extras) |
| `--silent` | Không hiện menu, tự chọn tất cả (truyền xuống script con) |
| `--help`, `-h` | In trợ giúp |

*Debug mode:* Thêm `DEBUG=1` trước `sh` để thấy tất cả lệnh đang chạy:

```bash
curl -fsSL https://raw.githubusercontent.com/jihooyoon/linux-post-install-scripts/main/install-remote.sh | DEBUG=1 sh
```

*Cơ chế remote setup:*

> `install-remote.sh` tự tải repo về `/tmp`, cấp quyền execute (git không lưu quyền này), rồi tự gọi `sudo` (nếu chưa root) để chạy `setup-all-ubuntu-based.sh` (thêm `--basic` để chỉ chạy `setup-basic-ubuntu-based.sh`), rồi tự xóa toàn bộ file tạm khi kết thúc — kể cả khi lỗi giữa chừng. Khi chạy qua pipe (`curl | sh`), script tự gán stdin của các script con từ terminal thật (`/dev/tty`) để menu tương tác nhận được input.

### Manual setup: Clone repo rồi chạy tay:
- Cần chmod để cấp quyền run cho các file script
- Chạy file `setup-basic-ubuntu-based.sh` để setup những thành phần cơ bản cho Ubuntu-based distro
- Chạy file `setup-all-ubuntu-based.sh` để setup những thành phần cơ bản kèm toàn bộ extras cho Ubuntu-based distro
- Các scripts con cũng có thể chạy độc lập, tuy nhiên đa phần scripts phục vụ nhu cầu chạy độc lập sẽ nằm trong `extras`, các scripts trong `atom-scripts` gần như luôn cần

**Các script chính đều hỗ trợ menu tương tác và tham số dòng lệnh:**

| Script | Tham số hỗ trợ |
|---|---|
| `setup-all-ubuntu-based.sh` | `--all`, `-a` (cài tất cả) / `--silent` (không tương tác + truyền xuống con) / `--help` |
| `setup-basic-ubuntu-based.sh` | `--silent` (truyền `--all` xuống script con) / `--help` |
| `install-basic-apps-deb.sh` | `--all`, `-a` (cài tất cả app) / `--help` |
| `install-ai-tools-deb.sh` | `--all`, `-a` / `--help` |
| `install-chat-apps-deb.sh` | `--all`, `-a` / `--help` |

> Mặc định (không tham số) các script sẽ hiện menu tương tác để chọn thành phần muốn cài.
> Chọn `q` để thoát — script sẽ exit 0, không làm đứt script cha.
 
### Additional: Nếu dùng GNOME (VD: Ubuntu)
**Cài thêm các extension cần thiết từ GNOME Extension Manager:**
- **KIMPanel (Hiển thị bộ gõ trên status bar)** - Highly recommend để bộ gõ tiếng Việt có trải nghiệm tốt:<br>
<https://extensions.gnome.org/extension/261/kimpanel>
- **Copyous (Clipboard Manager)** - Recommend, để có có thể paste những dữ liệu copy cũ hơn trong lịch sử mà không cần copy lại (Win + V):<br>
<https://extensions.gnome.org/extension/8834/copyous>
