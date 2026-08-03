# Quy trình xuất bản chương tự động

## Nguồn sự thật

Mỗi lượt phải đọc trực tiếp:

- `data/library.json`;
- số tệp trong `content/ta-chi-muon-an-tinh-choi-game/`;
- trạng thái Git và commit hiện tại;
- transcript tương ứng với chương kế tiếp.

Không ghi số chương hiện tại vào lời nhắc lịch. Chương kế tiếp luôn bằng `chapterCount + 1`.

## Chuỗi trạng thái bắt buộc

1. Chạy `Inspect`.
2. Nếu nhận `READY`, chạy `Acquire` và giữ lại `runId`.
3. Biên tập đúng một chương.
4. Cập nhật giai đoạn bằng `Stage`: `EDITING`, `VALIDATING`, `COMMITTING`, `DEPLOYING`, `MOBILE_QA`.
5. Sau khi GitHub Pages trả HTTP 200 và kiểm tra điện thoại đạt yêu cầu, chạy `Complete`.
6. Chạy `Release`.

Ví dụ:

```powershell
$runId = [Guid]::NewGuid().ToString('N')
.\automation\chapter-worker.ps1 Acquire -RunId $runId
.\automation\chapter-worker.ps1 Stage -RunId $runId -Stage EDITING
# Biên tập, kiểm định, commit, push, kiểm tra Pages và điện thoại.
.\automation\chapter-worker.ps1 Complete -RunId $runId -Chapter 78 -Commit abc1234
.\automation\chapter-worker.ps1 Release -RunId $runId
```

## Quy tắc dừng

- `LOCKED`: một lượt khác đang xử lý; thoát yên lặng.
- `BLOCKED_INCONSISTENT_COUNT`: `chapterCount` không khớp số tệp HTML; không tự sửa.
- `BLOCKED_GIT_DIRTY`: có thay đổi tracked; không tự ghi đè.
- `VERIFY_EXISTING_TARGET`: chương đích đã tồn tại; xác minh, không tạo lại.
- Mất tín hiệu âm thanh thật: ghi blocker, không chạy ASR lặp lại.
- GitHub Pages chưa cập nhật: giữ khóa ở `DEPLOYING`, không tạo lại chương.

Khóa hết hạn sau 20 phút không có cập nhật giai đoạn. Mỗi lần chạy `Stage` sẽ gia hạn khóa. Khóa hết hạn chỉ được thay thế sau khi đã đọc lại repository và xác nhận không có chương đang được commit hoặc triển khai.

## Thông báo

Chỉ thông báo khi:

- xuất bản thành công một chương;
- phát hiện blocker mới;
- dữ liệu không nhất quán;
- triển khai thất bại cần can thiệp.

Không thông báo trạng thái không đổi.
