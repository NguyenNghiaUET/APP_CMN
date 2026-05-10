# Format packet PC → MCU (khớp CRC)

## Packet PC đang gửi (hiện tại)

| Byte      | Nội dung |
|-----------|----------|
| 0        | Header = `0xAA` |
| 1        | Length low byte  (length & 0xFF) |
| 2        | Length high byte (length >> 8)   |
| 3 .. N+2 | Data (JSON), N = length (2 byte little-endian) |
| N+3 .. N+6 | CRC32, 4 byte **big-endian** |

- **Length** = độ dài data (JSON), 2 byte little-endian: `length = Buffer[1] | (Buffer[2] << 8)`.
- **CRC** tính trên: `[Buffer[0], Buffer[1], ..., Buffer[N+2]]` (tức `[0xAA][len_lo][len_hi][data]`), tổng **3 + N** byte.

---

## Code MCU cũ (chưa khớp)

```c
uint8_t crc_pos = Buffer[1] + 2;   // 1 byte length → sai với packet 2 byte length
uint32_t crcChecksum = ...          // đọc CRC tại crc_pos
// CRC_Calculate(Buffer, length+2)  // length 1 byte
```

---

## Code MCU cần sửa để khớp

```c
// Đọc length 2 byte little-endian
uint16_t length = (uint16_t)Buffer[1] | ((uint16_t)Buffer[2] << 8);

// Vị trí CRC: ngay sau data (sau 3 + length byte)
uint16_t crc_pos = 3 + length;

// Đọc CRC nhận (4 byte big-endian)
uint32_t crcReceived = ((uint32_t)Buffer[crc_pos]   << 24) |
                       ((uint32_t)Buffer[crc_pos+1] << 16) |
                       ((uint32_t)Buffer[crc_pos+2] <<  8) |
                       ((uint32_t)Buffer[crc_pos+3]);

// Tính CRC trên payload: từ byte 0 đến (3 + length - 1) = (2 + length) byte
// Số byte cần tính = 3 + length (header + len_lo + len_hi + data)
uint32_t crcCalc = CRC_Calculate((volatile uint8_t*)Buffer, 3 + length);

if (crcCalc == crcReceived) {
    // CRC đúng → xử lý data từ Buffer[3] đến Buffer[2+length]
    // Data length = length byte
}
```

**Lưu ý:** PC dùng CRC **software** (bảng giống `sw_crc32_by_byte_table`). Nếu MCU dùng **CRC_Calculate (hardware)** mà kết quả khác, có thể dùng **software CRC** trên MCU cho cùng payload (3+length byte) để verify, hoặc chỉnh PC cho khớp hardware CRC STM32.

---

## Kiểm chứng CRC PC ↔ MCU

### 1. Self-test trên PC (tự động)

Khi gửi lần đầu, app chạy **CRC self-test**: tính CRC cho payload `[0xAA, 0x00, 0x00]` và so với giá trị cố định. Nếu **đúng** sẽ thấy trong log/console:

```text
CRC self-test OK (PC khớp thuật toán stm32_sw_crc32_by_byte)
```

Nếu **sai** sẽ có warning in ra CRC tính được và CRC mong đợi.

### 2. So sánh với MCU (kiểm chứng tay)

Trên MCU, gọi cùng thuật toán cho cùng payload 3 byte:

```c
uint8_t buf[] = { 0xAA, 0x00, 0x00 };
uint32_t crc = stm32_sw_crc32_by_byte(0xFFFFFFFFu, buf, 3);
// crc phải = 0xCEFB1644
```

Nếu `crc == 0xCEFB1644` thì PC và MCU dùng chung bảng và cùng cách tính → packet gửi từ PC có CRC đúng với MCU.

### 3. Ví dụ packet mẫu (để debug)

| Payload (hex)     | CRC (big-endian, 4 byte) |
|-------------------|---------------------------|
| `AA 00 00`        | `0xCEFB1644` → gửi `CE FB 16 44` |
| `AA 01 00 5B`     | *(tính bằng crc32_stm32 trên PC hoặc MCU)* |

Có thể in `CRC_Calculate(Buffer, NumOfByte)` hoặc `stm32_sw_crc32_by_byte(...)` trên MCU khi nhận packet và so với CRC trong packet để xác nhận khớp.
