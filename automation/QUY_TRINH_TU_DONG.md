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

## Biên soạn trước trong thời gian triển khai

Sau khi Chương N đã commit, push và khóa chuyển sang `DEPLOYING`, có thể tận dụng thời gian chờ GitHub Pages để chuẩn bị Chương N+1:

1. Chạy `DraftStart` bằng RunId đang sở hữu khóa.
2. Biên soạn Chương N+1 vào `draftPath` do lệnh trả về.
3. Xác minh tiêu đề, hai ranh giới, nguồn đối chiếu và HTML.
4. Chạy `DraftReady` để ghi manifest nháp.
5. Tiếp tục xác minh Chương N trên GitHub Pages, chạy `Complete` và `Release` như bình thường.

Nháp nằm trong `.automation/drafts/`, không được đưa vào `content/`, không sửa `library.json`, không commit và không push trong chu kỳ của Chương N. Khi lượt kế tiếp `Acquire`, bộ điều phối tự chuyển quyền sở hữu bản nháp `READY` đúng số chương sang RunId mới. Lượt mới phải đối chiếu lại repository và ranh giới trước khi sử dụng. Sau khi chương được checkpoint thành công, nháp đã dùng sẽ tự được dọn. Mỗi lượt vẫn chỉ xuất bản tối đa một chương.

Ví dụ:

```powershell
$runId = [Guid]::NewGuid().ToString('N')
.\automation\chapter-worker.ps1 Acquire -RunId $runId
.\automation\chapter-worker.ps1 Stage -RunId $runId -Stage EDITING
# Biên tập, kiểm định, commit, push, kiểm tra Pages và điện thoại.
.\automation\chapter-worker.ps1 DraftStart -RunId $runId
# Biên soạn chương kế tiếp vào draftPath được trả về.
.\automation\chapter-worker.ps1 DraftReady -RunId $runId -Title "Tên chương" -StartBoundary "00:00:00" -EndBoundary "00:08:00" -Source "transcript + nguồn đối chiếu"
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
