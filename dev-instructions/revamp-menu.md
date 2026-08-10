# Revamp Cơ chế Menu

## Mục tiêu

Xoá menu ở các script lẻ, sử dụng menu tổng, chọn một lượt rồi chạy tự động, tránh việc đợi từng stage lại hiện menu tiếp theo

## Xoá menu ở các script con

### Cơ chế chung 
Việc chọn thực hiện hạng mục nào ở các script con (trong `atom-scripts` và `extras`) sẽ dựa hoàn toàn vào argument, không có menu nữa

### Arguments
- Chỉ có `--all/-a`: sẽ thực hiện toàn bộ các mục
- Có nhiều argument tương ứng với các mục: Chỉ thực hiện những mục tương ứng có trong argument
- Có `--all/-a` kèm các argument chỉ định các mục khác: all exclude - thực hiện tất cả trừ các mục được chỉ định (mục này tạm thời chưa làm vội)
- Ngoài ra: báo lỗi argument, nhưng chỉ skip script lẻ, còn script cha vẫn chạy tiếp

### Cơ chế phục vụ việc quy hoạch động các mục (R.1)
- Tìm cơ chế để mỗi lần update hạng mục thì chỉ cần thêm/bớt hạng mục, không cần sửa định nghĩa argument, ví dụ:
  - phase đầu, có 4 hạng mục, có thể điền argument là 3 4, điền 5 6 sẽ lỗi
  - phase sau, thêm 2 hạng mục, nhưng chỉ cần thêm hạng mục chứ không cần thêm định nghĩa argument, có thể điền argument là 4 5 6, mục 5 6 sẽ tự động nhận
  - phase sau nữa, xoá hạng mục 4, hạng mục 5 6 tự được đổi thành 4 5, điền 4 sẽ không thực hiện hạng mục 4 cũ, mà thực hiện hạng mục 4 mới (chính là hạng mục 5 cũ)
- Liên kết với cơ chế build menu động ở script cha
  - Mỗi script con đều có phần description ngắn gọn, xúc tích, để biết script đó tên là gì, cài những hạng mục nào
  - Có cơ chế để script cha có thể quét xem script con gồm những hạng mục nào, đánh số argument nào

### Cơ chế migrate
- Trong scripts gốc khi mới tách nhánh dev (check xem trạng thái này ở commit nào, rồi điền luôn vào đây), có những hạng mục luôn thực hiện (được note sẵn là luôn thực hiện, hoặc chưa được đưa vào menu), thì cũng chưa tạo thành hạng mục có thể lựa chọn

### Cơ chế khác
- Khi script con báo error và thất bại, hoặc bị skip, thì script cha vẫn tiếp tục chạy


## Build menu ở script cha, sử dụng cơ chế build menu động

### Cấu trúc script và cơ chế menu chung
- Không còn chia 2 scripts `setup-all-ubuntu-based.sh` và `setup-basic-ubuntu-based.sh`, quy về 1 script chung `setup-ubuntu-based.sh`
- Trong script `setup-ubuntu-based.sh`, là hệ thống menu để định nghĩa các hạng mục sẽ thực hiện, sau khi kết thúc hệ thống chọn menu thì script cha này sẽ gọi các script con tương ứng với argument tương ứng, không cần thêm tương tác gì khác từ người dùng.
- Menu có nhiều stages (ví dụ: sau khi lựa chọn các extras, sẽ đến menu lựa chọn các hạng mục trong mỗi extra, lần lượt với từng extra). Có nút back để quay lại stage trước

### Cơ chế migrate filename của các script con (R.2)
- Quét các scripts cha trong scripts gốc khi mới tách nhánh dev (check xem trạng thái này ở commit nào, rồi điền luôn vào đây), xem script con nào được gọi trước, script con nào được gọi sau, đánh số thứ tự vào filename.
- Các scripts ở `atom-scripts` sẽ được đánh số riêng với các scripts ở `extras`. (VD `atom-scripts` bắt đầu từ `1-xxx.sh`, `2-xxx.sh`,... thì `extras` cũng bắt đầu từ `1-xxx.sh`, `2-xxx.sh`,... chứ không phải bắt đầu từ `3-xxx.sh`)

### Cơ chế build menu động (R.3)
Tự quét các scripts con trong `atom-scripts` và `extras` để xây dựng các hạng mục. Cụ thể:
- Với các scripts con trong `atom-scripts`:
  - Không có lựa chọn scripts nào để chạy, mà luôn chạy tất cả theo thứ tự filename được migrate ở (R.2)
  - Có menu lựa chọn các hạng mục trong từng atom script, show menu thành các stage theo thứ tự filename luôn. Ví dụ: `2_xxx.sh` có 3 hạng mục được lựa chọn, `5_yyy.sh` có 4 hạng mục được lựa chọn => menu sẽ show: stage 1 gồm 3 hạng mục ở `2_xxx.sh`, stage 2 sẽ gồm 4 hạng mục ở `5_yyy.sh`
- Với các scripts con trong `extras`
  - Có menu lựa chọn scripts nào để chạy. Ví dụ có 3 scripts `1_xxx.sh`, `2_yyy.sh`, `3_zzz.sh` thì sẽ có menu gồm 3 options: `1: <Description of extra script 1>`, `2: <Description of extra script 2>`, `3: <Description of extra script 3>`
  - Có menu lựa chọn các hạng mục trong từng extra script, show menu thành các stage tiếp sau menu chọn các extra.
- Cơ chế quét script con để lấy description và các hạng mục trong script sẽ được xây dựng trên cơ chế (R.1) ở các script con