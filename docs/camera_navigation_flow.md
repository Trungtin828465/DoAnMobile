# Quy trình camera chỉ đường

File này dùng để theo dõi logic hoạt động camera, STT, TTS, detect và layout khi test thực tế.

## 1. Chọn layout phòng

- Người dùng vào màn hình camera và chọn layout phòng đã lưu.
- Layout chỉ dùng để hỗ trợ suy luận hướng xoay khi detect thấy một vật khác trong phòng.
- Thông tin layout, tọa độ và độ tin cậy chỉ in ra terminal, không đọc dài bằng TTS.

## 2. Nói vật cần tìm

- Người dùng bấm mic và nói ví dụ: `tìm laptop`, `tìm cái giường`, `tìm cái bàn`.
- App dùng OpenRouter để phân loại câu nói thành một class trong danh sách detect.
- Nếu hiểu được vật cần tìm, app đọc ngắn gọn: `Tôi đã hiểu. Bạn đang muốn tìm ...`

## 3. Chụp ảnh detect đầu tiên

- App tự chụp ảnh sau khi đã hiểu vật cần tìm.
- Nếu detect thấy đúng vật cần tìm với độ tin cậy đủ dùng, app nói: `Đã phát hiện ... Hãy bật mic và nói: sẵn sàng.`
- App không bắt đầu chỉ đường ngay, để người dùng có thời gian chuẩn bị.

## 4. Detect thấy vật khác

- Nếu chưa thấy vật cần tìm nhưng detect thấy vật khác trong phòng, app lấy vật đó làm mốc.
- App so sánh tọa độ vật mốc và vật cần tìm trong layout để tính hướng xoay.
- TTS chỉ đọc hướng cần làm, ví dụ: `Tôi thấy có vật ..., dựa vào layout hãy quay người 180 độ thật chậm, rồi đứng yên 5 giây để tôi chụp lại.`
- Terminal sẽ in chi tiết vật mốc, độ tin cậy và góc lệch để debug.

## 5. Chụp lại sau khi xoay

- Sau khi hướng dẫn xoay, app đợi 5 giây rồi tự chụp ảnh mới.
- Nếu ảnh mới phát hiện đúng vật cần tìm, app dừng vòng quét và nói: `Đã phát hiện ... Hãy bật mic và nói: sẵn sàng.`
- Trạng thái này tránh lỗi lặp vô hạn cứ xoay 15 độ dù đã thấy vật.
- Trong một nhiệm vụ tìm vật, câu `sẵn sàng` chỉ được hỏi một lần.

## 6. Người dùng nói sẵn sàng

- Người dùng bấm mic và nói: `sẵn sàng`, `ok`, `oke`, `bắt đầu`.
- App chuyển sang bước chỉ đường từng chặng nhỏ đến vật.
- Từ bước này app không dùng câu xoay theo layout nữa; app chỉ dùng vị trí vật đã detect trong ảnh để hướng dẫn chặng di chuyển.
- Nếu chưa nghe rõ, app chỉ nhắc ngắn: `Tôi chưa nghe rõ. Nếu bạn đã sẵn sàng di chuyển, hãy bật mic và nói: sẵn sàng.`
- Khi người dùng bấm bật mic, app phát tiếng báo bật mic; khi bấm tắt mic, app phát tiếng báo tắt mic.

## 7. Chỉ đường từng chặng

- App dựa vào vị trí vật trên ảnh để gợi ý đi từng chặng nhỏ.
- Ví dụ: đi thẳng một, hai hoặc ba bước nhỏ; xoay nhẹ trái/phải nếu vật lệch khung hình; đưa tay dò phía trước.
- Sau mỗi chặng, app yêu cầu người dùng tự bấm mic và nói đã xong.

## 8. Xác nhận đã đi xong

- Người dùng bấm mic và nói: `đã xong`, `tôi đi xong rồi`, hoặc câu cùng nghĩa.
- App dùng OpenRouter để hiểu ý nghĩa xác nhận.
- Sau khi xác nhận, app chụp ảnh mới để kiểm tra lại khoảng cách và hướng.

## 9. Hoàn thành nhiệm vụ

- Khi vật đã gần và chiếm đủ vùng ảnh, app nói người dùng đưa tay lại gần để tìm vật.
- App thoát trạng thái tìm vật.
- Nếu muốn tìm vật khác, người dùng bấm mic để bắt đầu nhiệm vụ mới.

## 10. Debug terminal cần chú ý

- `OpenRouter`: kiểm tra app hiểu đúng vật cần tìm hay chưa.
- `Detect local`: kiểm tra model có phát hiện đúng vật không.
- `Layout`: kiểm tra vật mốc, vật cần tìm và góc xoay được tính ra.
- `STT`: kiểm tra mic có nghe được câu tìm vật, sẵn sàng hoặc đã xong không.
- `TTS`: kiểm tra app có đọc đúng bước ngắn gọn cho người dùng không.
