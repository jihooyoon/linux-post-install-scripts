# linux-post-install-scripts

Scripts for configuring Linux distros after clean install

# Những việc bộ scripts này làm:

- Debullshit: Mục tiêu gỡ hoàn toàn snap, tránh bloat
- Bật flatpak
- Cài một số thứ cơ bản sẵn cho người Việt

# Cách chạy:

- Chạy file `setup-basic-ubuntu-based.sh` để setup những thành phần cơ bản cho Ubuntu-based distro
- Chạy file `setup-all-ubuntu-based.sh` để setup những thành phần cơ bản kèm toàn bộ extras cho Ubuntu-based distro
- Các scripts con có thể chạy độc lập, tuy nhiên đa phần scripts phục vụ nhu cầu chạy độc lập sẽ nằm trong `extras`, các scripts trong `atom-scripts` gần như luôn cần
