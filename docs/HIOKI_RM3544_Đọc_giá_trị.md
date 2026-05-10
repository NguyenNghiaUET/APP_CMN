# Đọc giá trị từ máy HIOKI RM3544 qua RS-232C

Tài liệu tham chiếu: **Communication Command Instruction Manual**  
`d:\QT_download\manual\English\RM3544e03.pdf`

---

## 1. Bạn cần đọc những thông số gì?

Theo giao diện phần mềm Cable_OPC (Thông số bài đo, Danh sách bài đo), các thông số **bắt buộc** cần lấy từ máy RM3544 là:

| Thông số | Mục đích trong phần mềm | Ví dụ |
|----------|-------------------------|--------|
| **Giá trị đo (resistance)** | So sánh với "Giá trị giới hạn đạt", quyết định Pass/Fail | 0.05, 0.8, 20 (Ω hoặc MΩ) |
| **Đơn vị đo** | Hiển thị và so sánh đúng thứ nguyên (Ω, kΩ, MΩ) | Ω, MΩ |

Giá trị máy trả về qua lệnh là **điện trở theo đơn vị Ω** (NR3). Đơn vị hiển thị (Ω / kΩ / MΩ) bạn có thể suy từ **dải đo hiện tại** (`:SENSe:RESistance:RANGe?`) nếu cần.

---

## 2. RS-232C – Cấu hình và lệnh đọc

### 2.1 Model và cổng

- **Model có RS-232C:** RM3544**-01** (có tích hợp RS-232C và USB).  
  Nếu máy con bạn là RM3544 (không có -01) thì không có cổng RS-232; khi đó cần dùng model -01 hoặc thiết bị chuyển đổi tương thích.
- Kết nối: cáp RS-232C từ máy RM3544-01 vào cổng COM trên máy tính (hoặc USB‑to‑Serial nếu máy tính không có COM).

### 2.2 Thông số cổng COM (theo manual)

| Thông số | Giá trị |
|----------|--------|
| **Baud rate** | **9600** (mặc định khi bật nguồn / *RST) |
| **Data bits** | 8 (theo mô tả truyền 10 bit/character: 1 start + 8 data + 1 stop) |
| **Parity** | None |
| **Stop bits** | 1 |

Trong Cable_OPC, dialog **Cấu hình thiết bị** → Thiết bị đo điện trở (HIOKI RM3544): chọn đúng **cổng COM** và **Baudrate 9600**.

### 2.3 Kết thúc lệnh (terminator)

- **Gửi từ PC → máy:** máy chấp nhận **CR** hoặc **CR+LF**.
- **Máy trả về → PC:** **CR+LF** (cố định cho RS-232C/USB, không đổi bằng lệnh).

Khi gửi lệnh từ phần mềm, nên kết thúc bằng `\r\n` (CR+LF).

### 2.4 Lệnh đọc giá trị (RM3544) – đối chiếu manual

Manual (RM3544e03.pdf) quy định lệnh **không phân biệt hoa/thường** và có thể **viết tắt** (short form). Dưới đây là **số trang** và cú pháp/phản hồi theo **Message Reference**, mục “(2) Reading Measured Values”.

**Trang trong manual (PDF, góc dưới ghi "X of 98"):**

| Nội dung | Trang |
|----------|-------|
| 2 Message List – danh sách lệnh (:FETCh?, :READ?, :MEASure:RESistance?) | **18–19** |
| Measurement Value Formats (NR3, Ω, dấu + trả về space) | **26–27** |
| :FETCh? – Read Most Recent Measurement | **32–33** |
| :FETCh:TEMPerature? (nhiệt độ) | **33** |
| :READ? – Measure (Await Triggers and Read Measurements) | **33–34** |
| :MEASure:RESistance? – Preset range và đo một lần | **35–36** |

| Lệnh (Syntax trong manual) | Trang | Mô tả | Phản hồi (RM3544) |
|----------------------------|-------|--------|--------------------|
| **`:FETCh?`** hoặc **`:FETC?`** | **32–33** | Đọc **giá trị đo mới nhất** (không phát trigger đo mới). Thời gian xử lý ≤ 5 ms. | `<Measurement value>` (NR3, đơn vị Ω). |
| **`:FETCh? LIMit`** hoặc **`:FETC? LIM`** | **32–33** | Như trên, kèm **kết quả comparator** (HI/IN/LO/OFF/ERR). | `<Measurement value>,<HI/IN/LO/OFF/ERR>`. |
| **`:READ?`** | **33–34** | Chuyển từ Idle sang Trigger Wait, thực hiện **một lần đo** rồi trả về giá trị. Thời gian = thời gian đo + khoảng 15 ms. | `<Measurement value>`. |
| **`:MEASure:RESistance?`** hoặc **`:MEAS:RES?`** | **35–36** | **Một lệnh** thực hiện: tắt continuous, trigger IMM, (tùy chọn) đặt range theo giá trị kỳ vọng, đo một lần, trả về giá trị. | `<Measurement value>`. |
| **`:MEASure:RESistance? <value>`** | **35–36** | Như trên, nhưng **đặt trước dải đo** phù hợp với `<value>` (0 đến 3.5E+06 cho RM3544). | `<Measurement value>`. |

**Ghi chú:**

- **:FETCh?** – Manual ghi đúng là **FETCh** (chữ “h” viết thường). Dạng viết tắt tối thiểu là **:FETC?** (ví dụ trong manual: `:FETC?`, `:FETC? LIM`).
- **:READ?** – RM3544 không có tham số; chỉ cần gửi `:READ?`.
- **:MEASure:RESistance?** – Nếu bỏ qua tham số thì máy dùng auto range; nếu gửi thêm giá trị (ví dụ `:MEAS:RES? 100E3`) thì máy chọn range phù hợp rồi đo và trả về.

**Ví dụ luồng dùng trong Cable_OPC:**

- Chỉ lấy giá trị hiện tại (máy đang đo liên tục): gửi **`:FETCh?`** hoặc **`:FETC?`** → đọc chuỗi trả về → parse số (Ω).
- Đo một lần theo trigger phần mềm: gửi **`:INIT:IMM`** (hoặc `:INIT`) rồi **`:READ?`** → đọc chuỗi trả về → parse số (Ω).
- Đo một lần và muốn máy tự chọn range: gửi **`:MEAS:RES?`** → đọc chuỗi trả về → parse số (Ω).

### 2.5 Định dạng giá trị trả về (data format)

(Xem **Measurement Value Formats** trong manual: **trang 26–27**.)

- **Định dạng:** NR3 (số thực dạng mũ), ví dụ: `+106.5710E+03`, `-1.2345E-02`.
- **Lưu ý:** Manual ghi "A '+' sign is returned as a **space** (ASCII 20H)" (trang 27) – tức chuỗi trả về có thể là ` 106.5710E+03` (dấu + thành space). Khi parse cần chấp nhận cả space và `+` ở đầu.
- **Đơn vị:** Giá trị luôn là **điện trở tính bằng Ω**. Ví dụ:
  - `106.5710E+03` → 106571 Ω ≈ 106.6 kΩ  
  - `20.0000E+06` → 20 MΩ  

Để hiển thị đơn vị (Ω / kΩ / MΩ) trong phần mềm, có thể:
- So sánh giá trị (Ω) với ngưỡng đã cấu hình (đã quy về cùng đơn vị), hoặc
- Gửi thêm `:SENSe:RESistance:RANGe?` để biết dải đo hiện tại và format đơn vị cho phù hợp.

### 2.6 Ví dụ chuỗi gửi/nhận (RS-232C)

**Gửi (PC → máy):**

```
:FETCh?
```
(kết thúc bằng CR hoặc CR+LF, ví dụ `\r\n`)

**Nhận (máy → PC):**

```
 106.5710E+03
```
(kết thúc CR+LF)

Parse: bỏ khoảng trắng đầu/cuối và ký tự CR/LF, chuyển chuỗi sang số (double). Giá trị = 106571.0 Ω.

---

## 3. Luồng xử lý trong phần mềm (đề xuất)

1. Mở cổng COM (QSerialPort) với **9600, 8N1**.
2. (Tùy chọn) Gửi `*IDN?` + đọc phản hồi để kiểm tra kết nối.
3. Khi cần đọc một giá trị cho bước đo:
   - **Cách A – Trigger bằng phần mềm:** Gửi `:INIT:IMM` (hoặc `:INIT`), sau đó gửi `:READ?`, đọc đến CR+LF → parse NR3.
   - **Cách B – Chỉ lấy giá trị hiện tại:** Gửi `:FETCh?`, đọc đến CR+LF → parse NR3.
4. Chuyển chuỗi NR3 thành số (Ω). So sánh với "Giá trị giới hạn đạt" và "Đơn vị đo" của bài đo → Đạt/Không đạt.
5. (Tùy chọn) Gửi `:SENSe:RESistance:RANGe?` nếu cần hiển thị hoặc kiểm tra dải đo (Ω).

Nếu bạn muốn, bước tiếp theo có thể là viết lớp C++ (Qt) đóng gói mở COM, gửi `:FETCh?` / `:READ?`, parse NR3 và trả về `double` (Ω) để tích hợp vào Cable_OPC.
