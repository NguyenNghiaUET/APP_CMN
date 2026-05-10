# Luồng Import Excel và tạo Script – Các đoạn code link với nhau

Tài liệu giải thích cách dữ liệu đi từ file Excel/CSV → Danh sách cáp → Tạo bài đo tự động → danh sách script.

---

## 1. Tổng quan luồng dữ liệu

```
[File Excel/CSV]  →  CableListManager (C++)  →  CableListDialog (QML)
                                                      ↓
                                              tableDataModel (ListModel)
                                                      ↓
                                              Nút "Tạo bài đo" (copy rows)
                                                      ↓
                                              requestCreateAutoTestPlan(name, rows)
                                                      ↓
                                              Main.qml (Connections)
                                                      ↓
                                              AutoTestPlanDialog.openWithCable(name, tableRows)
                                                      ↓
                                              buildScriptListFromExcel(rows)
                                                      ↓
                                              scriptModel (ListModel) = danh sách script
```

---

## 2. Cấu trúc dữ liệu Excel / bảng (8 cột)

Cả **CSV** và **Excel (.xlsx)** đều được đọc thành các dòng, mỗi dòng là một object với **8 cột**:

| Cột   | Key   | Ý nghĩa (theo giao diện)     | Dùng khi tạo script        |
|-------|------|------------------------------|----------------------------|
| Cột 0 | col0 | Nhãn giắc đầu A              | labelA (tên connector A)   |
| Cột 1 | col1 | Tên chân đầu A               | pinA                       |
| Cột 2 | col2 | Chân đo cổng A               | (không dùng trong script) |
| Cột 3 | col3 | Nhãn giắc đầu B             | labelB (tên connector B)   |
| Cột 4 | col4 | Tên chân đầu B               | pinB                       |
| Cột 5 | col5 | Chân đo cổng B               | (không dùng trong script) |
| Cột 6 | col6 | Điện trở dẫn (Ω) ≤          | (không dùng trong script) |
| Cột 7 | col7 | Điện trở cách điện (MΩ) ≥    | (không dùng trong script) |

- **CableListManager** (C++) đọc file → trả về `QVariantList`: mỗi phần tử là `QVariantMap` với key `col0` … `col7`.
- **CableListDialog** nhận kết quả đó, chuẩn hóa sang chuỗi rồi đổ vào **tableDataModel** (cũng là các object `col0`…`col7`).

---

## 3. Từng bước chi tiết

### 3.1. Đọc file Excel/CSV (C++)

| Việc xảy ra | Hàm xử lý | Dòng | File |
|-------------|-----------|------|------|
| Nhận path file, chọn CSV hay XLSX, gọi parse và trả về mảng dòng | `loadTableData` | 216–255 | `CableListManager.cpp` |
| Đọc file CSV: từng dòng, tách ô bằng `,` / `;` / tab | `parseCsvFile` | 98–151 | `CableListManager.cpp` |
| Bỏ qua dòng tiêu đề (toàn chữ) | (trong parseCsvFile) | 128–141 | `CableListManager.cpp` |
| Tạo mỗi dòng thành object col0…col7 | (trong parseCsvFile) | 143–148 | `CableListManager.cpp` |
| Đọc file Excel: mở sheet, đọc ô, tạo col0…col7 | `parseXlsxFile` | 154–214 | `CableListManager.cpp` |
| Gán key col0…col7 cho mỗi dòng Excel | (trong parseXlsxFile) | 188–199 | `CableListManager.cpp` |

**Link:** QML gọi C++ tại **CableListDialog.qml dòng 79**: `cableListManager.loadTableData(path)`.

---

### 3.2. Hiển thị bảng trong Danh sách cáp (QML – CableListDialog)

**File:** `CableListDialog.qml`

- **cableListModel**: danh sách cáp (name, path) từ `cableListManager.cableNames()` / `cableListManager.cablePath(i)`.
- **tableDataModel**: danh sách dòng bảng của cáp đang chọn.

**loadTableForCurrentSelection():**

1. Lấy `path` của cáp đang chọn từ `cableListModel.get(selectedCableIndex).path`.
2. Gọi **cableListManager.loadTableData(path)** → nhận `rows` (mảng object col0…col7).
3. Duyệt `rows`, với mỗi `r` tạo object `{ col0, col1, …, col7 }` (chuỗi), **append** vào **tableDataModel**.

→ Bảng bên phải dialog “Danh sách cáp” chính là **tableDataModel** (cùng format col0…col7).

**Link:** Dữ liệu Excel/CSV đã nằm trong **tableDataModel** với format chuẩn col0–col7.

---

### 3.3. Nút “Tạo bài đo” – Chuẩn bị dữ liệu và mở dialog

**File:** `CableListDialog.qml` (khoảng dòng 318–339)

Khi bấm **“Tạo bài đo”**:

1. Lấy **tên cáp**: `name = cableListModel.get(selectedCableIndex).name`.
2. Copy toàn bộ bảng vào mảng **rows**:
   - Duyệt `tableDataModel` (đang hiển thị bảng của cáp đó).
   - Mỗi dòng `r` → push object `{ col0: r.col0, col1: r.col1, …, col7: r.col7 }` vào **rows**.
3. Gọi **cableListDialog.requestCreateAutoTestPlan(name, rows)**.

→ **rows** ở đây chính là bản sao của bảng Excel (cùng format col0…col7) để gửi sang dialog tạo bài đo.

**File:** `Main.qml` (Connections)

- **Connections** lắng nghe **cableListDialog**.
- Khi có **onRequestCreateAutoTestPlan(cableName, tableRows)**:
  - Gọi **autoTestPlanDialog.openWithCable(cableName, tableRows || [])**.

**Link:** CableListDialog không gọi trực tiếp AutoTestPlanDialog mà qua signal; Main.qml là nơi nối signal với **openWithCable**.

---

### 3.4. Mở dialog Tạo bài đo và chọn nguồn script

| Việc xảy ra | Hàm xử lý | Dòng | File |
|-------------|-----------|------|------|
| Nhận (name, tableRows), quyết định tạo từ Excel hay template | `openWithCable` | 70–79 | `AutoTestPlanDialog.qml` |
| Gán cableName | (trong openWithCable) | 71 | `AutoTestPlanDialog.qml` |
| Có dữ liệu → tạo script từ Excel | `buildScriptListFromExcel(tableRows)` | 73 | `AutoTestPlanDialog.qml` |
| Không có dữ liệu → tạo script mẫu | `buildScriptListFromTemplate()` | 75 | `AutoTestPlanDialog.qml` |
| Chọn script đầu, hiện dialog | (trong openWithCable) | 77–78 | `AutoTestPlanDialog.qml` |

**Link:** **tableRows** = mảng **rows** đã copy từ **tableDataModel** (CableListDialog.qml 329–336).

---

### 3.5. Tạo danh sách script từ Excel – buildScriptListFromExcel(rows)

Tất cả trong **AutoTestPlanDialog.qml**, hàm **buildScriptListFromExcel(rows)** bắt đầu **dòng 99**. Đầu vào: **rows** = mảng object col0…col7. Dùng cột: col0 = labelA, col1 = pinA, col3 = labelB, col4 = pinB.

| Việc xảy ra | Vị trí trong hàm | Dòng | File |
|-------------|------------------|------|------|
| Xóa scriptModel, thêm "Khởi tạo hệ thống" | Đầu hàm | 101–102 | `AutoTestPlanDialog.qml` |
| Duyệt rows, lấy col0,col1,col3,col4 (labelA, pinA, labelB, pinB) | Vòng while ngoài | 104–114 | `AutoTestPlanDialog.qml` |
| Bỏ qua dòng trống (không labelA và labelB) | (trong while) | 110–113 | `AutoTestPlanDialog.qml` |
| Gom nhóm: các dòng cùng (col0, col3) vào group | Vòng while trong | 116–131 | `AutoTestPlanDialog.qml` |
| Tạo script Thông báo (notification) | append + _defaultParams | 133–137 | `AutoTestPlanDialog.qml` |
| Tạo N script Kiểm tra điện trở dây dẫn (wire_resistance) | vòng for + append | 138–147 | `AutoTestPlanDialog.qml` |
| Tạo script Kiểm tra thông chập (continuity) | append | 149–152 | `AutoTestPlanDialog.qml` |
| Tạo script Kiểm tra điện trở cách điện (insulation) | append | 153–156 | `AutoTestPlanDialog.qml` |
| Tạo N script Kiểm tra cách điện vỏ GND (sheath_insulation) – phía A và B | vòng for + append | 157–174 | `AutoTestPlanDialog.qml` |

**Hàm phụ:** Mỗi script chuẩn hóa bởi **\_defaultParams(o)** – **dòng 81–97** – **AutoTestPlanDialog.qml** (gán displayText, scriptType, labelA, pinA, labelB, pinB, tham số đo).

**Link:** Kết quả = **scriptModel**. Khi "Lưu Lại" thì **serializeScriptModel()** – **dòng 47–68** – **AutoTestPlanDialog.qml** chuyển scriptModel thành JSON string rồi gọi TestPlanManager.

---

## 4. Tóm tắt link giữa các thành phần

| Thành phần            | Vai trò |
|-----------------------|--------|
| **CableListManager**  | Đọc file Excel/CSV → trả về mảng object col0…col7. |
| **CableListDialog**   | Gọi loadTableData → đổ vào tableDataModel; bấm “Tạo bài đo” → copy tableDataModel thành mảng **rows** → emit **requestCreateAutoTestPlan(name, rows)**. |
| **Main.qml**          | Nhận signal → gọi **autoTestPlanDialog.openWithCable(cableName, tableRows)**. |
| **AutoTestPlanDialog**| **openWithCable** nhận (name, tableRows); **buildScriptListFromExcel(tableRows)** đọc col0,col1,col3,col4, gom nhóm theo (labelA, labelB), tạo từng loại script và append vào **scriptModel**. |
| **scriptModel**       | ListModel chứa toàn bộ script (displayText, scriptType, labelA, pinA, labelB, pinB, và các tham số đo). Khi “Lưu Lại” thì **serializeScriptModel()** chuyển scriptModel thành JSON string và gửi cho **TestPlanManager.saveTestPlan(cableName, jsonStr)**. |

---

## 5. Sơ đồ nhanh (data flow)

```
Excel/CSV (file)
    ↓
CableListManager.loadTableData(path)  →  [ {col0..col7}, ... ]
    ↓
CableListDialog.loadTableForCurrentSelection()
    → tableDataModel = cùng format col0..col7
    ↓
User chọn cáp + bấm "Tạo bài đo"
    → rows = copy của tableDataModel (col0..col7)
    → requestCreateAutoTestPlan(cableName, rows)
    ↓
Main.qml: onRequestCreateAutoTestPlan
    → autoTestPlanDialog.openWithCable(cableName, tableRows)
    ↓
AutoTestPlanDialog.openWithCable(name, tableRows)
    → buildScriptListFromExcel(tableRows)
    ↓
buildScriptListFromExcel(rows)
    - Nhóm theo (col0, col3) = (labelA, labelB)
    - Mỗi nhóm: 1 notification + N wire_resistance + 1 continuity + 1 insulation + N sheath_insulation
    - Mỗi script append vào scriptModel
    ↓
scriptModel = danh sách script (hiển thị + cấu hình + Lưu lại)
```

Như vậy toàn bộ luồng “import Excel → tạo script” đi từ **CableListManager** → **CableListDialog** (tableDataModel) → signal + **Main.qml** → **AutoTestPlanDialog.openWithCable** → **buildScriptListFromExcel** → **scriptModel**, với format cột cố định col0 (labelA), col1 (pinA), col3 (labelB), col4 (pinB) xuyên suốt.

---

## 6. Bảng tra cứu: Hàm nào xử lý – Dòng nào – File nào

Mỗi việc trong luồng đều ghi rõ **hàm (hoặc chỗ) xử lý**, **dòng**, **file**.

### 6.1. C++ – Đọc Excel/CSV

| Việc xảy ra | Hàm | Dòng | File |
|-------------|-----|------|------|
| Nhận path, gọi parse CSV/XLSX, trả về mảng dòng | `loadTableData` | 216–255 | `CableListManager.cpp` |
| Đọc CSV: từng dòng, tách ô `,` `;` tab | `parseCsvFile` | 98–151 | `CableListManager.cpp` |
| Bỏ qua dòng tiêu đề (toàn chữ) | (trong parseCsvFile) | 128–141 | `CableListManager.cpp` |
| Tạo mỗi dòng thành object col0…col7 | (trong parseCsvFile) | 143–148 | `CableListManager.cpp` |
| Đọc Excel: sheet, ô, col0…col7 | `parseXlsxFile` | 154–214 | `CableListManager.cpp` |
| Gán col0…col7 cho từng dòng Excel | (trong parseXlsxFile) | 188–199 | `CableListManager.cpp` |

### 6.2. QML – CableListDialog (Danh sách cáp)

| Việc xảy ra | Hàm / chỗ | Dòng | File |
|-------------|-----------|------|------|
| Mở dialog Danh sách cáp | `open` | 22–24 | `CableListDialog.qml` |
| Chọn cáp khác → load bảng | `onSelectedCableIndexChanged` | 34–37 | `CableListDialog.qml` |
| Load danh sách cáp (name, path) | `refreshCableList` | 40–61 | `CableListDialog.qml` |
| cableListManager.cableNames() | (trong refreshCableList) | 46 | `CableListDialog.qml` |
| cableListManager.cablePath(i) | (trong refreshCableList) | 50 | `CableListDialog.qml` |
| Load bảng cho cáp đang chọn | `loadTableForCurrentSelection` | 63–126 | `CableListDialog.qml` |
| Lấy path cáp đang chọn | (trong loadTableForCurrentSelection) | 72 | `CableListDialog.qml` |
| Gọi C++ đọc file → nhận rows | (trong loadTableForCurrentSelection) | 79 | `CableListDialog.qml` |
| Append từng dòng vào tableDataModel (col0…col7) | (trong loadTableForCurrentSelection) | 95–119 | `CableListDialog.qml` |
| Khai báo signal (name, rows) | `requestCreateAutoTestPlan` | 20 | `CableListDialog.qml` |
| Bấm nút "Tạo bài đo" | `onClicked` (QC.Button) | 324–339 | `CableListDialog.qml` |
| Lấy tên cáp đang chọn | (trong onClicked) | 328 | `CableListDialog.qml` |
| Copy tableDataModel → mảng rows (col0…col7) | (trong onClicked) | 329–336 | `CableListDialog.qml` |
| Phát signal requestCreateAutoTestPlan(name, rows) | (trong onClicked) | 338 | `CableListDialog.qml` |

### 6.3. QML – Main.qml (nối signal → mở dialog bài đo)

| Việc xảy ra | Hàm / chỗ | Dòng | File |
|-------------|-----------|------|------|
| Lắng nghe cableListDialog | `Connections` | 105–110 | `Main.qml` |
| Nhận signal requestCreateAutoTestPlan | `onRequestCreateAutoTestPlan` | 107–109 | `Main.qml` |
| Gọi openWithCable(cableName, tableRows) | (trong onRequestCreateAutoTestPlan) | 108 | `Main.qml` |

### 6.4. QML – AutoTestPlanDialog (Tạo bài đo tự động)

| Việc xảy ra | Hàm / chỗ | Dòng | File |
|-------------|-----------|------|------|
| Nhận (name, tableRows), gọi build script hoặc template | `openWithCable` | 70–79 | `AutoTestPlanDialog.qml` |
| Gán cableName | (trong openWithCable) | 71 | `AutoTestPlanDialog.qml` |
| Tạo script từ Excel | `buildScriptListFromExcel(tableRows)` | 73 | `AutoTestPlanDialog.qml` |
| Tạo script mẫu (không có dữ liệu) | `buildScriptListFromTemplate()` | 75 | `AutoTestPlanDialog.qml` |
| Chọn script đầu, show dialog | (trong openWithCable) | 77–78 | `AutoTestPlanDialog.qml` |
| Chuẩn hóa tham số mỗi script | `_defaultParams` | 81–97 | `AutoTestPlanDialog.qml` |
| Chuyển scriptModel → JSON string (khi Lưu Lại) | `serializeScriptModel` | 47–68 | `AutoTestPlanDialog.qml` |

### 6.5. buildScriptListFromExcel(rows) – AutoTestPlanDialog.qml (dòng 99 trở đi)

| Việc xảy ra | Vị trí | Dòng | File |
|-------------|--------|------|------|
| Xóa scriptModel, thêm "Khởi tạo hệ thống" | Đầu hàm | 101–102 | `AutoTestPlanDialog.qml` |
| Duyệt rows, lấy col0,col1,col3,col4 (labelA, pinA, labelB, pinB) | Vòng while ngoài | 104–114 | `AutoTestPlanDialog.qml` |
| Bỏ qua dòng trống (không labelA và labelB) | (trong while) | 110–113 | `AutoTestPlanDialog.qml` |
| Gom nhóm: cùng (col0, col3) vào group | Vòng while trong | 116–131 | `AutoTestPlanDialog.qml` |
| Tạo script Thông báo (notification) | append + _defaultParams | 133–137 | `AutoTestPlanDialog.qml` |
| Tạo N script Kiểm tra điện trở dây dẫn (wire_resistance) | vòng for + append | 138–147 | `AutoTestPlanDialog.qml` |
| Tạo script Kiểm tra thông chập (continuity) | append | 149–152 | `AutoTestPlanDialog.qml` |
| Tạo script Kiểm tra điện trở cách điện (insulation) | append | 153–156 | `AutoTestPlanDialog.qml` |
| Tạo N script Kiểm tra cách điện vỏ GND (sheath_insulation) | vòng for + append | 157–174 | `AutoTestPlanDialog.qml` |
