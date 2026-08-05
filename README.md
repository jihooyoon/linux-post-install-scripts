# Linux Post-Installing Scripts

Scripts for configuring Linux distros after clean install

## Cơ chế scripts:

**Những việc scripts sẽ làm:**
- De-Bullshit Ubuntu: Mục tiêu gỡ hoàn toàn snap, tránh bloat
- Bật flatpak
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
command -v curl >/dev/null 2>&1 || sudo apt-get install -y -q curl; curl -fsSL https://raw.githubusercontent.com/jihooyoon/linux-post-install-scripts/main/install-remote.sh | sudo sh
```

Chỉ setup phần basic (không cài extras):

```bash
command -v curl >/dev/null 2>&1 || sudo apt-get install -y -q curl; curl -fsSL https://raw.githubusercontent.com/jihooyoon/linux-post-install-scripts/main/install-remote.sh | sudo sh -s -- --basic
```

*Cơ chế remote setup:*

> `install-remote.sh` tự tải repo về `/tmp`, cấp quyền execute (git không lưu quyền này), chạy `setup-all-ubuntu-based.sh` (thêm `--basic` để chỉ chạy `setup-basic-ubuntu-based.sh`), rồi tự xóa toàn bộ file tạm khi kết thúc — kể cả khi lỗi giữa chừng.

### Manual setup: Clone repo rồi chạy tay:
- Cần chmod để cấp quyền run cho các file script
- Chạy file `setup-basic-ubuntu-based.sh` để setup những thành phần cơ bản cho Ubuntu-based distro
- Chạy file `setup-all-ubuntu-based.sh` để setup những thành phần cơ bản kèm toàn bộ extras cho Ubuntu-based distro
- Các scripts con cũng có thể chạy độc lập, tuy nhiên đa phần scripts phục vụ nhu cầu chạy độc lập sẽ nằm trong `extras`, các scripts trong `atom-scripts` gần như luôn cần
 
### Additional: Nếu dùng GNOME (VD: Ubuntu)
**Cài thêm các extension cần thiết từ GNOME Extension Manager:**
- **KIMPanel (Hiển thị bộ gõ trên status bar)** - Highly recommend để bộ gõ tiếng Việt có trải nghiệm tốt:<br>
<https://extensions.gnome.org/extension/261/kimpanel>
- **Copyous (Clipboard Manager)** - Recommend, để có có thể paste những dữ liệu copy cũ hơn trong lịch sử mà không cần copy lại (Win + V):<br>
<https://extensions.gnome.org/extension/8834/copyous>
