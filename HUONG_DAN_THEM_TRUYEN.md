# HƯỚNG DẪN THÊM TRUYỆN VÀ CHƯƠNG

## 1. Thêm truyện

Mở `data/library.json` và thêm một phần tử:

```json
{
  "id": "ten-truyen-khong-dau",
  "title": "TÊN TRUYỆN",
  "author": "TÊN TÁC GIẢ",
  "genre": "THỂ LOẠI",
  "status": "Đang cập nhật",
  "chapterCount": 100,
  "initials": "TT",
  "color": "linear-gradient(145deg, #684c3d, #2c1c17)",
  "description": "Mô tả ngắn về truyện.",
  "chapterTitles": {
    "1": "Tên riêng của chương 1"
  }
}
```

`id` phải viết thường, không dấu, dùng dấu gạch ngang và không trùng với truyện khác.

## 2. Thêm nội dung chương

Tạo thư mục:

`content/ten-truyen-khong-dau/`

Mỗi chương là một tệp HTML:

- Chương 1: `0001.html`
- Chương 2: `0002.html`
- Chương 125: `0125.html`

Ví dụ nội dung:

```html
<p>Nội dung đoạn thứ nhất.</p>
<p>TÊN RIÊNG sử dụng chữ in hoa. Tên “Kỹ Năng” đặt trong ngoặc kép.</p>
<div class="system">
  <div class="system-title">✦ HỆ THỐNG ✦</div>
  <p>Thông tin do HỆ THỐNG công bố.</p>
</div>
```

## 3. Cập nhật số chương

Sửa `chapterCount` trong `data/library.json` bằng tổng số chương hiện có.

Giao diện tự tạo thẻ truyện, mục lục, tìm kiếm, phân trang, lịch sử, đánh dấu và vị trí đọc riêng cho truyện đó.
