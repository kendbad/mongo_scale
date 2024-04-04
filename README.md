# mongo_scale
example mongo scale using docker-compose replica set shard and shell

Hướng dẫn khởi tạo mongo scale.

1. Lệnh khởi tạo tự động

```bash
sudo ./up.sh
```

2. Lệnh dọn dẹp tự động

```bash
sudo ./down.sh
```

3. Có thể thêm shard-02 shard-03 dựa trên shard-01, chỉnh sửa lại up.sh để thêm shard-02 shard-03

4. Chỉnh sửa U và P trong .env để thay đổi xác thực đăng nhập

Hướng dẫn đẩy mã lên github bằng terminal của visual studio code.

```bash
sudo rm -r .git
git init
git add .
git commit -m "first commit" 
git branch -M main
git remote add origin https://github.com/kendbad/mongo_scale.git 
git push -u origin main
```
0. Gỡ bỏ thư mục .git nếu cần: sudo rm -r .git
1. Khởi tạo: git init
2. Thêm tất cả ở thư mục hiện tại: git add .
3. Ghi chú thay đổi: git commit -m "first commit" 
4. Đổi tên nhánh hiện tại sang main: git branch -M main
5. Kết nối với repo đã tạo trên github: git remote add origin </*liên kết đến repo*/>
6. Đẩy mã lên github: git push -u origin main
7. Lỗi khi push do tệp README.md không nên chọn tạo README khi khởi tạo repo trên github, hoặc xóa README.md trong thư mục local chứa mã nguồn.