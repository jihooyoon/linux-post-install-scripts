# linux-post-install-scripts

Scripts for configuring Linux distros after clean install

# Những việc bộ scripts này làm:

- Debullshit: Mục tiêu gỡ hoàn toàn snap, tránh bloat
- Bật flatpak
- Cài một số thứ cơ bản sẵn cho người Việt

# Cách chạy:

**Một lệnh duy nhất (không cần clone tay):**

```bash
curl -fsSL https://raw.githubusercontent.com/jihooyoon/linux-post-install-scripts/main/bootstrap.sh | sudo bash
```

`bootstrap.sh` tự tải repo về `/tmp`, cấp quyền execute (git không lưu quyền này), chạy `setup-all-ubuntu-based.sh`, rồi tự xóa toàn bộ file tạm khi kết thúc — kể cả khi lỗi giữa chừng.

**Hoặc clone rồi chạy tay:**

- Chạy file `setup-basic-ubuntu-based.sh` để setup những thành phần cơ bản cho Ubuntu-based distro
- Chạy file `setup-all-ubuntu-based.sh` để setup những thành phần cơ bản kèm toàn bộ extras cho Ubuntu-based distro
- Các scripts con có thể chạy độc lập, tuy nhiên đa phần scripts phục vụ nhu cầu chạy độc lập sẽ nằm trong `extras`, các scripts trong `atom-scripts` gần như luôn cần
