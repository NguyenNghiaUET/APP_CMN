# PROMPT – CMN_TESTING Auto Test Runner v2 (Qt 6 / QML + C++)

---

## 1. MÔ TẢ DỰ ÁN

Viết module **Auto Test Runner** cho ứng dụng **CMN_TESTING** (tab **CMN_Auto**).

Module này:
- Import file Excel (.xlsx) chứa danh sách bước test tuần tự
- Tự động thực thi từng bước theo LOẠI_BƯỚC
- Hiển thị tiến trình lên giao diện QML
- Ghi kết quả đo vào cột KẾT_QUẢ_ĐO và ĐÁNH_GIÁ trong file Excel
- Xuất báo cáo sau khi hoàn thành

---

## 2. SƠ ĐỒ PHẦN CỨNG VÀ NGUỒN DỮ LIỆU

```
┌─────────────────────────────────────────────────────────┐
│                    APP CMN_TESTING                       │
│                     (Qt/QML)                            │
└───┬──────────┬──────────┬────────────┬──────────────────┘
    │          │          │            │
    ▼          ▼          ▼            ▼
[MR3K160120] [MCU]   [MDL400/      [Keithley
 Nguồn DC    Relay   MDL4U001]      2210-220]
 BK Precision Board  Tải DC        Đồng hồ đo
 TCP/SCPI    Serial  TCP/SCPI      TCP/GPIB
```

### Nguồn dữ liệu từng loại đo:

| Dữ liệu cần đọc | Thiết bị | Giao tiếp |
|---|---|---|
| Điện áp đầu ra, Dòng điện, Công suất (phần Giám sát) | **BK MR3K160120** | TCP – SCPI |
| Trạng thái relay (đáp ứng) | **MCU relay board** | Serial/USB |
| Dòng đặt tải, Điện áp tải (V_Load), Dòng tải (I_Load) | **MDL400 / MDL4U001** | TCP – SCPI |
| Tín hiệu đo kiểm (Boost, FUZE_EN, Fire, Sig_GND, MLD, Tele, ERM, PM77, GEN1_1, SS1, PPA, PYRO, 27V_COMMAND, PYROFLARE_GND, VALVE_GND, RESERVE) | **Keithley 2210-220** | TCP/GPIB |
| Tín hiệu giám sát VCM (27V-VC1, BAT_OK, PUMP, KT-CCBH...) | **App VCM-01M** | RS422 – frame data |

---

## 3. CẤU TRÚC FILE EXCEL

File Excel có nhiều sheet, mỗi sheet = 1 bài test.
- Hàng 1: tiêu đề bài test
- Hàng 2: header cột
- Từ hàng 3: các bước test tuần tự

### Cột (A → J):

| Cột | Tên | Kiểu | Mô tả |
|---|---|---|---|
| A | STT | int | Số thứ tự bước |
| B | LOẠI_BƯỚC | string | Loại bước – app đọc để thực thi |
| C | MÔ_TẢ | string | Mô tả hiển thị lên UI |
| D | THAM_SỐ_1 | string | Tên relay / tên param / tên load |
| E | THAM_SỐ_2 | string | Giá trị ON/OFF / số / loại đo |
| F | THAM_SỐ_3 | string | Đơn vị / dòng đặt A / tham chiếu |
| G | YÊU_CẦU | string | Ngưỡng: "27±2.7 V", "0±0.3 V", "19÷31 V", "Dòng đặt ±10%" |
| H | KẾT_QUẢ_ĐO | double | **App ghi giá trị đo thực tế** |
| I | ĐÁNH_GIÁ | string | **App ghi "ĐẠT" / "KHÔNG ĐẠT"** |
| J | GHI_CHÚ | string | Ghi chú thêm |

---

## 4. LOẠI BƯỚC VÀ CÁCH XỬ LÝ

---

### 4.1 ACTION

App đọc MÔ_TẢ và xử lý theo keyword:

| Keyword trong MÔ_TẢ | Hành động |
|---|---|
| Chứa **"Kết nối"** | Hiện **popup** chờ công nhân thao tác xong bấm OK |
| Chứa **"SET RELAY"** | **Flush relay buffer** → gửi bản tin xuống MCU |
| Chứa **"Nhấn SET"** (không có "RELAY") | **Flush load buffer** → gửi ENABLE_LOAD xuống MDL |
| Chứa **"START MEASURE"** | Gọi `Keithley::startMeasureAll()` |
| Chứa **"Listen"** hoặc **"VCM"** | Gọi `VCMController::startListen()` |
| Chứa **"Auto Mode"** | Gọi `TestRunner::switchToAutoMode()` |
| Khác | Tự động bỏ qua, chuyển bước tiếp |

---

### 4.2 SET_SOURCE

```
P1 = "Voltage" | "Current_Max" | "Current_Protect" | "Output_Enable"
P2 = giá trị số hoặc "ON"/"OFF"
P3 = đơn vị (chỉ hiển thị)
```

Gửi lệnh SCPI tới **BK MR3K160120** qua TCP:

| P1 | Lệnh SCPI |
|---|---|
| Voltage | `VOLT <P2>` |
| Current_Max | `CURR <P2>` |
| Current_Protect | `CURR:PROT <P2>` |
| Output_Enable | `OUTP 1` (ON) hoặc `OUTP 0` (OFF) |

Ghi ĐÁNH_GIÁ = "ĐẠT" nếu ACK thành công, "KHÔNG ĐẠT" nếu timeout.

---

### 4.3 SET_RELAY

```
P1 = tên relay (xem bảng mapping mục 5)
P2 = "ON" hoặc "OFF"
```

**Cơ chế buffer:**
- Khi gặp SET_RELAY → chỉ ghi vào `relayBuffer[P1] = P2`, **chưa gửi**
- Khi gặp ACTION "SET RELAY" → flush toàn bộ `relayBuffer` xuống MCU

**Cách gửi xuống MCU (Serial):**
- Mỗi relay = 1 bản tin riêng biệt (không gộp)
- Bản tin chứa: số chân relay + trạng thái ON/OFF
- Tra bảng mapping (mục 5) để lấy số chân tương ứng tên relay
- Gửi tuần tự từng bản tin, đợi ACK trước khi gửi tiếp

**Xử lý đặc biệt:**
- `ALL_OTHERS` → set tất cả relay KHÔNG có trong relayBuffer hiện tại = OFF
- `ALL` → set tất cả relay = P2

---

### 4.4 SET_LOAD

```
P1 = "LOAD_1" đến "LOAD_6"
P2 = tên nguồn (PUMP, TELE, MLĐ, ERM, PPA, ĐTD, VRA, AP, FUZE, PYRO, IGNITER)
P3 = dòng đặt (A) – đây là giới hạn dòng tiêu thụ tối đa cho tải
```

- Lưu vào `loadConfig[P1] = {source: P2, current: P3}`
- Gửi ngay lệnh SCPI tới **MDL400/MDL4U001**: `CH<n>:CURR <P3>`
  (LOAD_1=CH1, LOAD_2=CH2, ..., LOAD_6=CH6)
- **Lưu ý**: P3 là dòng đặt giới hạn, không phải dòng thực tế.
  Dòng thực tế (I_Load) và điện áp thực tế (V_Load) đọc riêng từ MDL.

---

### 4.5 ENABLE_LOAD

```
P1 = "LOAD_1" đến "LOAD_6"
P2 = "ON" hoặc "OFF"
```

- Ghi vào `loadEnableBuffer[P1] = P2`, **chưa gửi**
- Khi gặp ACTION "Nhấn SET" → flush buffer: gửi `CH<n>:INP <1/0>` tới MDL

---

### 4.6 VERIFY

```
P1 = tên tín hiệu
P2 = nguồn đo: "VCM-01M" hoặc "Bảng đo"
YÊU_CẦU = ngưỡng so sánh
```

**Nguồn đọc theo P2:**

| P2 | Thiết bị | Hàm gọi |
|---|---|---|
| `VCM-01M` | App VCM-01M → RS422 → CMN app bóc tách frame | `VCMController::getSignalValue(P1)` |
| `Bảng đo` | **Keithley 2210-220** | `Keithley::readChannel(P1)` |

**Danh sách tín hiệu "Bảng đo" (Keithley 2210-220):**
```
Boost, FUZE_EN, Fire, Sig_GND, MLD, Tele, ERM, PM77,
GEN1_1, SS1, PPA, PYRO, 27V_COMMAND, PYROFLARE_GND, VALVE_GND, RESERVE
```

**Xử lý:**
1. Đọc giá trị từ nguồn tương ứng
2. Parse YÊU_CẦU → so sánh (xem mục 6)
3. Ghi KẾT_QUẢ_ĐO = giá trị đo (double)
4. Ghi ĐÁNH_GIÁ = "ĐẠT" / "KHÔNG ĐẠT"

---

### 4.7 RESULT_V / RESULT_I

```
P1 = "LOAD_1" đến "LOAD_6"
P2 = loại đo:
  V_Load → điện áp thực tế đọc từ MDL (MDLController::readVoltage(CH))
  I_Load → dòng thực tế đọc từ MDL (MDLController::readCurrent(CH))
  V_GS   → điện áp mạch giám sát đọc từ VCM-01M
  I_GS   → dòng mạch giám sát đọc từ VCM-01M
YÊU_CẦU = "27±2.7 V" hoặc "Dòng đặt ±10%"
```

- RESULT_V: đọc điện áp, so sánh ngưỡng cố định
- RESULT_I: đọc dòng, so sánh với dòng đặt (`loadConfig[P1].current`) ±10%
- Ghi KẾT_QUẢ_ĐO và ĐÁNH_GIÁ

---

### 4.8 SAISO_V / SAISO_I

```
P1 = tên nguồn (tra cache kết quả)
P2 = "V_GS" hoặc "I_GS"
P3 = "V_Load" / "I_Load" hoặc số tham chiếu cụ thể như "27"
YÊU_CẦU = "≤5%" hoặc "≤10%"
```

- Tra `resultCache[P1][P2]` và `resultCache[P1][P3]`
- Tính: `saiSo = |GS - ref| / ref * 100`
- Ghi KẾT_QUẢ_ĐO = saiSo (%), ĐÁNH_GIÁ theo ngưỡng

---

### 4.9 TEARDOWN

| P1 | Hành động |
|---|---|
| `DC_SOURCE` | Gửi `OUTP 0` tới MR3K → tắt nguồn |
| `ALL_LOADS` | Gửi `CH1..6:INP 0` tới MDL → tắt tất cả tải |
| `ALL_RELAY` | Set tất cả relay OFF → flush xuống MCU |
| `CHECK_HOUSING` / `CHECK_CONNECTOR` / `PACKAGING` | Hiện popup chờ xác nhận |

---

## 5. BẢNG MAPPING RELAY → SỐ CHÂN MCU

> **Lưu ý cho dev**: Bảng này define dưới dạng `QMap` hoặc `std::map` trong C++.
> Bạn (người dùng) sẽ cung cấp số chân thực tế sau – **tạm thời dùng số placeholder**.

```cpp
// relay_pin_map.h – sửa số chân theo thực tế phần cứng
static const QMap<QString, int> RELAY_PIN_MAP = {
    // Cột "Nút nhấn thao tác lệnh nguồn"
    {"VLS_ON",      1},   // TODO: sửa số chân thực tế
    {"Bat1_ON",     2},   // TODO
    {"Bat2_ON",     3},   // TODO
    {"Gen_ON",      4},   // TODO
    {"VLS_BatON",   5},   // TODO
    {"VLS_BatOFF",  6},   // TODO
    {"MPSS_TBKT",   7},   // TODO
    {"CMD_ERM",     8},   // TODO
    {"CMD_PUMP",    9},   // TODO
    {"CCBH_in",    10},   // TODO
    {"CMD_PPA",    11},   // TODO
    {"CMD_Pyro1",  12},   // TODO
    {"CMD_Pyro2",  13},   // TODO
    {"CMD_TJE",    14},   // TODO
    {"CMD_FUZE",   15},   // TODO
};
```

**Cách flush relay buffer xuống MCU:**
```cpp
void RelayController::flushRelayBuffer() {
    for (auto it = relayBuffer.begin(); it != relayBuffer.end(); ++it) {
        QString relayName = it.key();
        bool state        = (it.value() == "ON");
        int  pin          = RELAY_PIN_MAP.value(relayName, -1);

        if (pin < 0) continue;  // không tìm thấy trong map

        // Đóng gói bản tin gửi xuống MCU (1 relay = 1 bản tin)
        QByteArray frame = buildRelayFrame(pin, state);
        serialPort->write(frame);
        serialPort->waitForBytesWritten(100);
        waitForAck(200);  // chờ ACK từ MCU
    }
    relayBuffer.clear();
}
```

---

## 6. PARSE CHUỖI YÊU CẦU

```cpp
struct Requirement { double min, max; bool isPercentOfSetpoint; double tol; };

Requirement parseRequirement(const QString& req) {
    // "27±2.7 V"       → min=24.3,  max=29.7
    // "0±0.3 V"        → min=-0.3,  max=0.3
    // "19÷31 V"        → min=19.0,  max=31.0
    // "≤5%"            → min=-inf,  max=5.0
    // "≤10%"           → min=-inf,  max=10.0
    // "< 1%"           → min=-inf,  max=1.0
    // "Dòng đặt ±10%"  → isPercentOfSetpoint=true, tol=10.0
}
```

---

## 7. GIAO DIỆN QML (AutoTestPage.qml)

```qml
ColumnLayout {
    // Tiến trình
    ProgressBar { value: runner.currentStep / runner.totalSteps }
    Label { text: runner.currentStep + "/" + runner.totalSteps + " – " + runner.currentDesc }

    // Bước hiện tại – màu theo loại
    Rectangle {
        color: {
            "SET_SOURCE":    "#FFF2CC",
            "SET_RELAY":     "#E2EFDA",
            "SET_LOAD":      "#EAD1DC",
            "ENABLE_LOAD":   "#EAD1DC",
            "VERIFY":        "#FCE4D6",
            "RESULT_V":      "#F4CCCC",
            "RESULT_I":      "#F4CCCC",
            "ACTION":        "#FFE699",
            "TEARDOWN":      "#F2F2F2",
        }[runner.currentType] ?? "white"
        Label { text: "[" + runner.currentType + "] " + runner.currentDesc }
    }

    // Popup chờ xác nhận (chỉ khi ACTION có "Kết nối")
    Dialog {
        visible: runner.waitingConfirm
        title: "Yêu cầu thao tác"
        Label { text: runner.confirmMessage }
        Button { text: "ĐÃ THỰC HIỆN – TIẾP TỤC"; onClicked: runner.confirmStep() }
    }

    // Bảng kết quả rolling
    ListView {
        model: runner.stepResults
        delegate: RowLayout {
            Label { text: model.stt;   width: 40  }
            Label { text: model.desc;  width: 300 }
            Label { text: model.value !== undefined ? model.value.toFixed(3) : "–" }
            Label {
                text:  model.pass ? "ĐẠT" : "KHÔNG ĐẠT"
                color: model.pass ? "#27AE60" : "#E74C3C"
            }
        }
    }

    // Thống kê
    RowLayout {
        Label { text: "OK: "   + runner.okCount;  color: "green" }
        Label { text: "NG: "   + runner.ngCount;  color: "red"   }
        Label { text: "Fail: " + runner.failRate + "%" }
    }

    // Điều khiển
    RowLayout {
        Button { text: "IMPORT EXCEL"; onClicked: fileDialog.open() }
        Button { text: "CHẠY";        onClicked: runner.runAll();  enabled: !runner.running }
        Button { text: "TẠM DỪNG";    onClicked: runner.pause();   enabled: runner.running  }
        Button { text: "TIẾP TỤC";    onClicked: runner.resume();  enabled: runner.paused   }
        Button { text: "DỪNG";        onClicked: runner.stop()                               }
    }
}
```

---

## 8. KIẾN TRÚC C++

```
AutoTestRunner (QObject)
├── loadExcel(filePath, sheetName)
├── runAll()
├── pause() / resume() / stop()
├── confirmStep()                    ← slot: công nhân bấm OK popup
├── Q_PROPERTY currentStep int
├── Q_PROPERTY totalSteps  int
├── Q_PROPERTY currentDesc QString
├── Q_PROPERTY currentType QString
├── Q_PROPERTY waitingConfirm bool
├── Q_PROPERTY confirmMessage QString
├── Q_PROPERTY okCount  int
├── Q_PROPERTY ngCount  int
├── Q_PROPERTY failRate double
├── Q_PROPERTY running  bool
├── Q_PROPERTY paused   bool
├── signal stepStarted(int, QString type, QString desc)
├── signal stepCompleted(int, double value, bool pass)
├── signal allDone(int ok, int ng, double failRate)
└── slot  writeResultToExcel(int row, double value, bool pass)

PowerSupplyController  ← MR3K160120, TCP SCPI
RelayController        ← MCU board, QSerialPort
  ├── relayBuffer: QMap<QString, QString>
  ├── flushRelayBuffer()
  └── RELAY_PIN_MAP: QMap<QString, int>  (xem mục 5)
MDLController          ← MDL400+MDL4U001, TCP SCPI
  ├── setCurrent(channel, A)        → CH<n>:CURR <A>
  ├── setEnable(channel, bool)      → CH<n>:INP <1/0>
  ├── readVoltage(channel) → double → MEAS:VOLT? CH<n>
  └── readCurrent(channel) → double → MEAS:CURR? CH<n>
VCMController          ← App VCM-01M, RS422 Serial
  ├── startListen()
  └── getSignalValue(name) → double  (bóc tách frame RS422)
KeithleyController     ← Keithley 2210-220, TCP/GPIB
  ├── startMeasureAll()
  └── readChannel(signalName) → double
```

---

## 9. LUỒNG XỬ LÝ CHÍNH

```
loadExcel(file, sheet)
  → parse rows từ hàng 3 → List<TestStep>

runAll():
  for each step:
    emit stepStarted(i, type, desc)

    switch(type):

      ACTION:
        if desc.contains("Kết nối"):
          waitingConfirm = true
          confirmMessage = desc
          → dừng chờ confirmStep() signal từ UI

        elif desc.contains("SET RELAY"):
          RelayController::flushRelayBuffer()

        elif desc.contains("Nhấn SET"):  // không có "RELAY"
          MDLController::flushLoadBuffer()

        elif desc.contains("START MEASURE"):
          KeithleyController::startMeasureAll()

        elif desc.contains("VCM") or desc.contains("Listen"):
          VCMController::startListen()

        elif desc.contains("Auto Mode"):
          switchToAutoMode()

        // else: bỏ qua

      SET_SOURCE:
        PowerSupplyController::setParam(p1, p2)

      SET_RELAY:
        relayBuffer[p1] = p2
        // Nếu p1 == "ALL_OTHERS": mark để flush tất cả trừ hiện tại = OFF
        // Nếu p1 == "ALL": set toàn bộ map = p2

      SET_LOAD:
        loadConfig[p1] = {source: p2, current: p3.toDouble()}
        MDLController::setCurrent(channelOf(p1), p3.toDouble())

      ENABLE_LOAD:
        loadEnableBuffer[p1] = p2
        // Chờ ACTION "Nhấn SET" mới flush

      VERIFY:
        if p2 == "VCM-01M":
          value = VCMController::getSignalValue(p1)
        elif p2 == "Bảng đo":
          value = KeithleyController::readChannel(p1)
        pass = checkReq(value, req)
        writeResult(i, value, pass)

      RESULT_V:
        if p2 == "V_Load": value = MDLController::readVoltage(channelOf(p1))
        if p2 == "V_GS":   value = VCMController::getSignalValue(p1)
        pass = checkReq(value, req)
        writeResult(i, value, pass)

      RESULT_I:
        if p2 == "I_Load": value = MDLController::readCurrent(channelOf(p1))
        if p2 == "I_GS":   value = VCMController::getSignalValue(p1)
        setpoint = loadConfig[p1].current
        pass = checkPercentReq(value, setpoint, 10.0)
        writeResult(i, value, pass)

      SAISO_V / SAISO_I:
        gs  = resultCache[p1][p2]
        ref = isNumeric(p3) ? p3.toDouble() : resultCache[p1][p3]
        sai = |gs - ref| / ref * 100
        pass = sai <= parsePercentReq(req)
        writeResult(i, sai, pass)

      TEARDOWN:
        executeTeardown(p1)

  emit allDone(okCount, ngCount, failRate)
  saveExcel()   // ghi KẾT_QUẢ_ĐO + ĐÁNH_GIÁ vào file gốc
```

---

## 10. ĐỌC/GHI EXCEL – DÙNG QXlsx

```cpp
#include "xlsxdocument.h"

// Đọc
QXlsx::Document xlsx(filePath);
xlsx.selectSheet(sheetName);
for (int row = 3; row <= xlsx.dimension().lastRow(); ++row) {
    TestStep s;
    s.stt  = xlsx.read(row, 1).toInt();
    s.type = xlsx.read(row, 2).toString().trimmed();
    s.desc = xlsx.read(row, 3).toString().trimmed();
    s.p1   = xlsx.read(row, 4).toString().trimmed();
    s.p2   = xlsx.read(row, 5).toString().trimmed();
    s.p3   = xlsx.read(row, 6).toString().trimmed();
    s.req  = xlsx.read(row, 7).toString().trimmed();
    s.row  = row;  // lưu để ghi kết quả sau
    steps.append(s);
}

// Ghi kết quả
void writeResult(int row, double value, bool pass) {
    xlsx.write(row, 8, value);
    xlsx.write(row, 9, pass ? "ĐẠT" : "KHÔNG ĐẠT");
    xlsx.save();
    resultCache[currentStep.p1][currentStep.p2] = value;
}
```

---

## 11. LƯU Ý QUAN TRỌNG

1. **Relay buffer** chỉ flush khi ACTION desc chứa "SET RELAY" — không gửi sớm hơn
2. **Load buffer** chỉ flush khi ACTION desc chứa "Nhấn SET" (không có "RELAY")
3. **Mỗi relay = 1 bản tin riêng** gửi xuống MCU, gửi tuần tự chờ ACK
4. **Bảng RELAY_PIN_MAP** cần được cập nhật đúng số chân thực tế trước khi build
5. **Dòng đặt (SET_LOAD)** là giới hạn tiêu thụ, không phải dòng thực tế — dòng thực đọc từ MDL
6. **V_Load / I_Load** đọc từ MDL400/MDL4U001 qua SCPI
7. **Tín hiệu "Bảng đo"** đọc từ Keithley 2210-220
8. **Tín hiệu "VCM-01M"** bóc tách từ frame RS422 do App VCM-01M gửi sang
9. **Giám sát nguồn** (V, I, P trên UI phần Giám sát) đọc từ BK MR3K160120
10. **resultCache** lưu kết quả mọi bước để SAISO_V/I tra cứu sau
11. Nếu bất kỳ VERIFY/RESULT nào KHÔNG ĐẠT → có thể popup hỏi tiếp tục hay dừng
