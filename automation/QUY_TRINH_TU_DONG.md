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

`Release` sẽ bị từ chối nếu checkpoint của chương đang khóa chưa được `Complete`. Quy tắc này ngăn một lỗi tham số hoặc một lệnh chạy tiếp ngoài ý muốn mở khóa quá sớm.

## Biên soạn trước trong thời gian triển khai

Sau khi Chương N đã commit, push và khóa chuyển sang `DEPLOYING`, có thể tận dụng thời gian chờ GitHub Pages để chuẩn bị Chương N+1:

1. Chạy `DraftStart` bằng RunId đang sở hữu khóa.
2. Biên soạn Chương N+1 vào `draftPath` do lệnh trả về.
3. Xác minh tiêu đề, hai ranh giới, nguồn đối chiếu và HTML.
4. Chạy `DraftReady` để ghi manifest nháp.
5. Tiếp tục xác minh Chương N trên GitHub Pages, chạy `Complete` và `Release` như bình thường.

Nháp nằm trong `.automation/drafts/`, không được đưa vào `content/`, không sửa `library.json`, không commit và không push trong chu kỳ của Chương N. Khi lượt kế tiếp `Acquire`, bộ điều phối tự chuyển quyền sở hữu bản nháp `READY` đúng số chương sang RunId mới. Lượt mới phải đối chiếu lại repository và ranh giới trước khi sử dụng.

Sau khi bản nháp đã được kiểm tra và đưa nguyên vẹn vào tệp chương công khai, `DraftStart` của giai đoạn triển khai sẽ tự so sánh hai tệp. Chỉ khi nội dung khớp tuyệt đối, manifest cũ mới được coi là đã tiêu thụ và dọn đi để mở nháp cho chương tiếp theo. Nếu hai tệp khác nhau, quy trình dừng thay vì bỏ mất bản nháp. Mỗi lượt vẫn chỉ xuất bản tối đa một chương.

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

## Kiểm tra tên riêng và ngoại ngữ

Trước khi chuyển sang `COMMITTING`, bắt buộc:

1. Chạy `powershell -ExecutionPolicy Bypass -File automation\validate-names.ps1 -Path <tệp-chương>`.
2. Đối chiếu mọi tên viết bằng chữ Latin chưa từng xuất hiện với nguyên tác và các chương đã xuất bản.
3. Tên Trung Quốc phải dùng cách đọc Hán–Việt đã thống nhất; không để pinyin hoặc dạng tiếng Anh do ASR hay nguồn phụ chèn vào.
4. Tên phương Tây chỉ được giữ nguyên khi nguyên tác xác nhận đó là tên riêng; dùng một cách viết duy nhất trong toàn truyện.
5. Từ tiếng Anh thông thường phải dịch sang tiếng Việt. Chỉ giữ chữ viết tắt kỹ thuật khi không làm sai nghĩa.
6. Nếu chưa đủ dữ liệu xác minh tên, dừng ở `VALIDATING`; không tự đoán và không xuất bản.

## Thông báo

Chỉ thông báo khi:

- xuất bản thành công một chương;
- phát hiện blocker mới;
- dữ liệu không nhất quán;
- triển khai thất bại cần can thiệp.

Không thông báo trạng thái không đổi.
