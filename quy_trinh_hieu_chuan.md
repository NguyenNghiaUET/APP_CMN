# Quy trình Hiệu chuẩn và Tính toán Kết quả Đo

Tài liệu này giải thích chi tiết luồng hoạt động của hai chế độ hiệu chuẩn và cách hệ thống tính toán giá trị đo cuối cùng.

---

## 1. Chi tiết 2 Chế độ Hiệu chuẩn

### A. Chế độ: Điều chỉnh tham số hiệu chuẩn (`CalibrationDialog.qml`)
*   **Mục đích**: Hiệu chuẩn sai số hệ thống phát sinh từ bảng mạch relay và dây dẫn nội bộ bên trong thiết bị đo.
*   **Tệp tin lưu trữ**: `calibration.att`
*   **Các tham số chính**:
    *   **Điện trở chuẩn (Standard Resistance)**: Giá trị tham chiếu chính xác cao dùng để so sánh.
    *   **Điện trở cáp chuyển đổi (cableResistance)**: Điện trở của bộ dây nối nội bộ từ máy ra đầu chờ.
*   **Luồng thực hiện**:
    1.  Người dùng chọn cặp chân đo (ví dụ: `A_1 ↔ B_1`).
    2.  Máy đo giá trị thực tế qua hệ thống relay.
    3.  Tính toán sai số (Offset): `Offset = Giá trị đo thực tế - Điện trở chuẩn`.
    4.  Lưu `Offset` này vào danh sách tương ứng với cặp chân.

### B. Chế độ: Hiệu chuẩn theo cáp đo (`CableCalibrationDialog.qml`)
*   **Mục đích**: Hiệu chuẩn trực tiếp tại **tận đầu cáp đo** đang kết nối bên ngoài. Loại bỏ hoàn toàn ảnh hưởng của bộ cáp test riêng biệt.
*   **Tệp tin lưu trữ**: `cable_calibration.att`
*   **Luồng thực hiện**:
    1.  Danh sách điểm đo được lấy trực tiếp từ file Excel hoặc Script bài đo hiện tại.
    2.  Người dùng thực hiện đo trên từng cặp nhãn đầu/cuối của cáp thực tế.
    3.  Tính toán sai số hệ thống (SSHT): `SSHT = Giá trị đo thực tế - Điện trở chuẩn`.
    4.  **Lưu ý**: Chế độ này KHÔNG sử dụng tham số `cableResistance` vì việc đo tại đầu cáp đã bao gồm cả điện trở dây dẫn đó.

---

## 2. Luồng tính toán Kết quả đo cuối cùng

Khi thực hiện đo bài đo chính thức (`MainContent.qml`), hệ thống thực hiện các bước sau để đưa ra kết quả:

1.  **Lấy giá trị thô (Raw Value)**:
    *   Máy đo (Hioki) thực hiện đo và gửi giá trị điện trở thực tế về phần mềm.

2.  **Xác định Chế độ hiệu chuẩn đang dùng**:
    *   Hệ thống kiểm tra cài đặt hiện tại của người dùng là `Hiệu chuẩn theo cáp đo` hay `Điều chỉnh tham số hiệu chuẩn`.

3.  **Truy vấn Sai số (Offset)**:
    *   Tìm kiếm trong tệp cấu hình tương ứng (`.att`) để lấy giá trị sai số đã lưu cho cặp chân (PortPinA, PortPinB) đang đo.

4.  **Áp dụng công thức tính toán**:
    *   **Nếu dùng "Điều chỉnh tham số hiệu chuẩn"**:
        > `Giá trị cuối = Giá trị thô - Offset - Điện trở cáp nội bộ (cableResistance)`
    *   **Nếu dùng "Hiệu chuẩn theo cáp đo"**:
        > `Giá trị cuối = Giá trị thô - Offset (SSHT)`

5.  **Định dạng và Kết luận**:
    *   **So sánh ngưỡng**: Lấy `Giá trị cuối` so sánh với Cận trên / Cận dưới trong bài đo để xác định **PASS** hoặc **FAIL**.
    *   **Định dạng**: Chuyển đổi giá trị sang đơn vị phù hợp (mΩ, Ω, kΩ, MΩ...) để hiển thị trên bảng kết quả.
    *   **Ghi Log**: Lưu kết quả vào nhật ký hệ thống và xuất file Excel khi kết thúc bài đo.

---

### Lưu ý cho người vận hành:
*   Dùng **Điều chỉnh tham số** khi bạn muốn hiệu chuẩn định kỳ hệ thống máy đo cố định.
*   Dùng **Hiệu chuẩn theo cáp đo** khi bạn thay đổi bộ đồ gá (fixture) hoặc cáp test bên ngoài và cần độ chính xác tối ưu cho bài đo đó.
