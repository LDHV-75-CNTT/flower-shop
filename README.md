# 🌸 Flower Shop – website bán hoa thật

Website tĩnh chạy trên GitHub Pages, dùng **Supabase** (miễn phí) cho đăng nhập, dữ liệu, ảnh và phân quyền. Chưa cấu hình Supabase thì site chỉ hiện thông báo "chưa kết nối", không có dữ liệu giả.

Bạn cần làm 4 bước dưới đây (khoảng 15 phút). Các bước tạo tài khoản Supabase/GitHub phải do chính bạn thực hiện.

## Bước 1. Tạo Supabase
1. Vào supabase.com, đăng ký, tạo **New project** (đặt mật khẩu database, chọn vùng gần Việt Nam như Singapore).
2. Mở **SQL Editor > New query**, dán toàn bộ nội dung `supabase/schema.sql`, bấm **Run**. Phải báo thành công, không lỗi.
3. Vào **Project Settings > API**, ghi lại **Project URL** và **anon public key** (không dùng `service_role`).
4. Vào **Authentication > Providers > Email**: nếu muốn khách đăng ký xong dùng ngay, tắt **Confirm email**. Nếu giữ bật, nên cấu hình SMTP riêng (**Authentication > SMTP**), vì email mặc định của Supabase bị giới hạn rất ít thư mỗi giờ.

## Bước 2. Đưa mã lên GitHub
```
cd flower-shop
git init
git add .
git commit -m "Flower Shop"
git branch -M main
git remote add origin https://github.com/TEN-BAN/TEN-REPOSITORY.git
git push -u origin main
```
(Tạo repository trống tên TEN-REPOSITORY trên github.com trước.)

## Bước 3. Điền cấu hình và bật Pages
1. Repository > **Settings > Secrets and variables > Actions > tab Variables > New repository variable**. Tạo:
   - `SUPABASE_URL` và `SUPABASE_ANON_KEY` (bắt buộc)
   - `STORE_ADDRESS`, `STORE_PHONE`, `STORE_EMAIL`, `STORE_FACEBOOK` (thông tin cửa hàng hiện ở chân trang; link Facebook phải bắt đầu bằng https://)
2. **Settings > Pages > Source: GitHub Actions**.
3. Tab **Actions > Deploy Flower Shop > Run workflow** (hoặc push lại). Khi xanh, địa chỉ là `https://TEN-BAN.github.io/TEN-REPOSITORY/`.
4. Quay lại Supabase **Authentication > URL Configuration**: đặt **Site URL** là địa chỉ trên (để email xác nhận và đặt lại mật khẩu dẫn đúng về site).

Sau này đổi thông tin cửa hàng: sửa Variables rồi chạy lại workflow, không cần sửa mã.

## Bước 4. Tạo Admin và nhập hàng
1. Mở website, đăng ký tài khoản của bạn.
2. Trong Supabase SQL Editor chạy (thay email): `update profiles set role='admin' where id=(select id from auth.users where email='email-cua-ban@example.com');`
3. Đăng xuất, đăng nhập lại, vào **Quản trị > Sản phẩm & kho** để thêm sản phẩm thật, tải ảnh, đặt giá, tồn kho, mùa, ngày lễ.

## Vận hành hằng ngày
- Đơn mới nằm ở **Quản trị > Đơn hàng** (hệ thống chưa tự gửi email/thông báo, bạn cần mở trang này để xem đơn mới). Cập nhật trạng thái và thanh toán khi giao.
- Doanh thu chỉ tính đơn **Đã giao**, chưa hoàn tiền. Hủy đơn tự hoàn tồn kho. Khách tự hủy được đơn đang chờ xác nhận.
- Mã giảm giá, danh mục, ngày lễ, lịch sử kho đều quản lý trong khu Quản trị.

## Kiểm tra sau triển khai
Đăng ký khách thử (email khác) > thêm giỏ > đặt hàng COD > xem **Đơn của tôi** > đăng nhập admin xem đơn, đổi sang Đã giao + Đã thanh toán > xem **Doanh thu**. Thử vào `#/admin` bằng tài khoản khách: phải bị từ chối.

## Giới hạn hiện tại
Chỉ có thanh toán khi nhận hàng (COD), chưa có cổng thanh toán online. Chưa có phí vận chuyển. Chưa tự gửi email/thông báo đơn mới. Bốn nhóm mùa (theo quý) cố định.
