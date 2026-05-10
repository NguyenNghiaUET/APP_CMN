import QtQuick
import QtQuick.Controls as QC
import QtQuick.Layouts
import QtQuick.Window
import Qt.labs.platform 1.1

// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║ CalibrationDialog.qml                                                       ║
// ║ ────────────────────────────────────────────────────────────────────────────  ║
// ║ Dialog hiệu chuẩn thiết bị đo.                                              ║
// ║                                                                              ║
// ║ MỤC ĐÍCH:                                                                    ║
// ║ - Lưu sai số (offset) giữa máy đo và điện trở chuẩn                         ║
// ║   • Hioki RM3544: đo điện trở dây (wire_resistance, continuity)              ║
// ║   • Hioki SM7110: đo điện trở cách điện (insulation, sheath_insulation)      ║
// ║ - Offset = giá_trị_đo - điện_trở_chuẩn                                      ║
// ║ - Khi đo thật, MainContent gọi getCalibrationOffset() để trừ offset          ║
// ║                                                                              ║
// ║ LUỒNG CHÍNH:                                                                 ║
// ║ 1. Nhận dữ liệu Excel từ CableListDialog (setCableData)                     ║
// ║ 2. Tạo tất cả tổ hợp điểm A↔A, B↔B, A↔B (initializeData)                   ║
// ║ 3. User chọn điểm đầu + cuối → bấm "Hiệu chỉnh" → đọc máy đo → tính offset║
// ║ 4. Lưu vào file calibration.att (saveToFile)                                 ║
// ║ 5. MainContent tra cứu offset qua getCalibrationOffset()                     ║
// ║                                                                              ║
// ║ FILE LƯU TRỮ: [appDir]/calibration.att                                      ║
// ║ FORMAT: "STT Điểm_đầu Điểm_cuối Offset" (mỗi dòng)                          ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
Window {
    id: calibrationDialog
    title: qsTr("Điều chỉnh tham số hiệu chỉnh")
    width: 1100
    height: 700
    visible: false
    modality: Qt.ApplicationModal // Chặn tương tác với cửa sổ chính khi đang mở
    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowMinMaxButtonsHint | Qt.WindowCloseButtonHint

    property Window mainWindow: null // Cửa sổ cha (Main.qml) — dùng để canh vị trí
    property var mainContent: null // Reference đến MainContent — để cập nhật calibration mode
    transientParent: mainWindow // Luôn hiện trên cửa sổ chính

    // ── Tham số hiệu chuẩn (user nhập) ──
    property double cableResistance: 0.1 // Điện trở cáp chuyển đổi (Ω) — dùng để trừ ra ở MainContent khi đo thật
    property double standardResistance: 0.01 // Điện trở chuẩn (Ω) — giá trị tham chiếu chính xác

    // ── Điểm đang chọn trên panel phải (ComboBox) ──
    property string selectedStartPoint: "A_1" // Điểm đầu đang chọn (VD: "A_1", "B_30")
    property string selectedEndPoint: "B_1" // Điểm cuối đang chọn (VD: "B_1", "A_50")
    property var availableStartPoints: [] // Danh sách điểm đầu hợp lệ (lấy từ scripts bài đo)
    property var availableEndPoints: [] // Danh sách điểm cuối hợp lệ (lấy từ scripts bài đo)

    // ── UI state ──
    property int highlightedRowIndex: -1 // Index dòng đang highlight vàng (-1 = không highlight)
    property bool _calibWaitingMcu: false // Đang chờ MCU bật relay cho hiệu chuẩn

    // ── Dữ liệu Excel — nhận từ CableListDialog qua Main.qml ──
    // Excel có 6 cột: col0=LabelA, col1=NameA, col2=PinA, col3=LabelB, col4=NameB, col5=PinB
    property var excelRows: [] // Mảng các row {col0, col1, ..., col7}
    property var pinLookupA: [] // Bảng tra: index i → "label/name (pin x) [Ry]" cho cổng A
    property var pinLookupB: [] // Bảng tra: index i → "label/name (pin x) [Ry]" cho cổng B
    property var pinNumA: [] // Mảng số pin cổng A: index i → giá trị pin từ col2
    property var pinNumB: [] // Mảng số pin cổng B: index i → giá trị pin từ col5

    // ═══════════════════════════════════════════════════════════════
    // ═══ HÀM NHẬN DỮ LIỆU EXCEL ═══
    // ═══════════════════════════════════════════════════════════════

    // Nhận dữ liệu Excel từ CableListDialog → build bảng tra pin → cập nhật thông tin Excel trong bảng
    function setCableData(tableRows) {
        excelRows = tableRows || []
        _buildPinLookup() // Parse Excel → tạo pinLookupA/B, pinNumA/B
        _refreshExcelInfo(
                    ) // Cập nhật cột "chanA", "chanB", "excelInfo" trong calibrationDataModel
    }

    // Helper: Lấy giá trị cột từ 1 row Excel
    // Row có thể là object {col0: "...", col1: "..."} hoặc array ["...", "..."]
    function _colVal(row, idx) {
        // lấy giá trị cột idx của row
        if (row === null || row === undefined)
            return "" // nếu row rỗng thì trả về ""
        var key = "col" + idx // key là "col0", "col1", "col2", ...
        if (row[key] !== undefined)
            return String(row[key]) // nếu row có key thì trả về giá trị của key
        if (Array.isArray(row) && idx < row.length)
            return String(
                        row[idx]) // nếu row là array thì trả về giá trị của idx
        return ""
    }

    // ═══════════════════════════════════════════════════════════════
    // ═══ HÀM BUILD BẢNG TRA PIN TỪ EXCEL ═══
    // ═══════════════════════════════════════════════════════════════

    // Parse từng dòng Excel → tạo mảng lookup cho cổng A và B
    // Kết quả: pinLookupA[i] = "label/name (pin x) [Ry]", pinNumA[i] = "x"
    function _buildPinLookup() {
        // build mảng lookup cho cổng A và B
        var lookA = [], lookB = [] // mảng lookup cho cổng A và B
        var numA = [], numB = [] // mảng số pin cho cổng A và B

        // Bỏ qua dòng header nếu col2/col5 không phải số
        var startIdx = 0 // index bắt đầu của mảng lookup
        if (excelRows.length > 0) {
            // nếu excelRows có phần tử
            var firstPinA = _colVal(excelRows[0],
                                    2) // lấy giá trị cột 2 của dòng đầu tiên
            var firstPinB = _colVal(excelRows[0],
                                    5) // lấy giá trị cột 5 của dòng đầu tiên
            if (firstPinA !== "" && isNaN(Number(firstPinA)))
                startIdx = 1 // nếu col2 không phải số thì startIdx = 1
            else if (firstPinB !== "" && isNaN(Number(firstPinB)))
                startIdx = 1 // nếu col5 không phải số thì startIdx = 1
        }

        for (var i = startIdx; i < excelRows.length; i++) {
            // lặp qua từng dòng Excel
            var row = excelRows[i] // row là 1 dòng Excel
            var labelA = _colVal(row, 0) // labelA là giá trị cột 0 của row
            var nameA = _colVal(row, 1) // nameA là giá trị cột 1 của row
            var pinA = _colVal(row, 2) // pinA là giá trị cột 2 của row
            var labelB = _colVal(row, 3) // labelB là giá trị cột 3 của row
            var nameB = _colVal(row, 4) // nameB là giá trị cột 4 của row
            var pinB = _colVal(row, 5) // pinB là giá trị cột 5 của row
            console.log("pinA", pinA, "pinB", pinB)

            var excelRow = i + 1 // +1 vì Excel đếm từ 1
            lookA.push(labelA + "/" + nameA + " (pin " + pinA + ") [R"
                       + excelRow + "]") // lookA là mảng lookup cho cổng A
            lookB.push(labelB + "/" + nameB + " (pin " + pinB + ") [R"
                       + excelRow + "]") // lookB là mảng lookup cho cổng B
            numA.push(pinA) // numA là mảng số pin cho cổng A
            numB.push(pinB) // numB là mảng số pin cho cổng B
        }

        pinLookupA = lookA
        pinLookupB = lookB
        pinNumA = numA
        pinNumB = numB
    }

    function _getLookupA(a) {
        return (a >= 1
                && a <= pinLookupA.length) ? pinLookupA[a - 1] : "" // nếu a nằm trong khoảng từ 1 đến độ dài của pinLookupA thì trả về giá trị của a - 1, ngược lại trả về ""
    }
    function _getLookupB(b) {
        return (b >= 1
                && b <= pinLookupB.length) ? pinLookupB[b - 1] : "" // nếu b nằm trong khoảng từ 1 đến độ dài của pinLookupB thì trả về giá trị của b - 1, ngược lại trả về ""
    }

    // Tra cứu thông tin Excel từ chuỗi điểm "A_x" hoặc "B_y"
    function _getPointExcelInfo(pointStr) {
        var parts = pointStr.split(
                    "_") // split chuỗi điểm "A_x" hoặc "B_y" thành 2 phần
        if (parts.length < 2)
            return "" // nếu parts có ít hơn 2 phần tử thì trả về ""
        var port = parts[0] // port là phần tử đầu tiên của parts
        var pin = parseInt(parts[1]) // pin là phần tử thứ hai của parts
        if (isNaN(pin))
            return "" // nếu pin không phải là số thì trả về ""
        if (port === "A")
            return _getLookupA(
                        pin) // nếu port là "A" thì trả về giá trị của pinLookupA[pin - 1]
        if (port === "B")
            return _getLookupB(
                        pin) // nếu port là "B" thì trả về giá trị của pinLookupB[pin - 1]
        return ""
    }

    // Tạo chuỗi tương đương Excel từ 2 điểm
    function _getExcelInfoFromPoints(startPt, endPt) {
        var infoStart = _getPointExcelInfo(startPt)
        var infoEnd = _getPointExcelInfo(endPt)
        if (infoStart && infoEnd)
            return infoStart + " ↔ " + infoEnd
        if (infoStart)
            return startPt.split("_")[0] + ": " + infoStart
        if (infoEnd)
            return endPt.split("_")[0] + ": " + infoEnd
        return ""
    }

    function _refreshExcelInfo() {
        for (var i = 0; i < calibrationDataModel.count; i++) {
            var item = calibrationDataModel.get(i)
            var startPt = item.startPoint
            var endPt = item.endPoint
            calibrationDataModel.setProperty(i, "chanA",
                                             _getPointExcelInfo(startPt))
            calibrationDataModel.setProperty(i, "chanB",
                                             _getPointExcelInfo(endPt))
            calibrationDataModel.setProperty(i, "excelInfo",
                                             _getExcelInfoFromPoints(startPt,
                                                                     endPt))
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // ═══ HÀM MỞ / RELOAD DIALOG ═══
    // ═══════════════════════════════════════════════════════════════

    // Mở dialog hiệu chuẩn — gọi từ menu "Công cụ → Điều chỉnh tham số hiệu chuẩn"
    function open() {
        loadAvailablePointsFromScripts(
                    ) // Bước 1: Quét bài đo → lấy danh sách pin hợp lệ
        initializeData() // Bước 2: Tạo 32K+ tổ hợp điểm (A↔A, B↔B, A↔B)
        loadFromFile() // Bước 3: Load offset đã lưu từ calibration.att
        show() // Bước 4: Hiện cửa sổ
    }

    // Reload lại bảng khi user chọn bài đo khác — không mở cửa sổ mới
    function reloadCalibrationTable() {
        loadAvailablePointsFromScripts()
        initializeData()
        loadFromFile()
    }

    // ═══════════════════════════════════════════════════════════════
    // ═══ HÀM QUÉT SCRIPTS → XÁC ĐỊNH CÁC ĐIỂM HỢP LỆ ═══
    // ═══════════════════════════════════════════════════════════════

    // Quét tất cả scripts trong bài đo hiện tại → xác định pin nào đang được dùng
    // Kết quả: availableStartPoints[] và availableEndPoints[] (VD: ["A_1", "A_4", "B_1", ...])
    // Nếu không có bài đo → mặc định A_1..A_128, B_1..B_128
    function loadAvailablePointsFromScripts() {
        // Lấy bài đo hiện tại từ MainContent
        var planName = ""
        if (mainContent && mainContent.currentPlanName) {
            planName = mainContent.currentPlanName
        }
        if (!planName || typeof testPlanManager === "undefined"
                || !testPlanManager) {
            // Nếu không có bài đo, hiển thị tất cả A_1 đến A_128 và B_1 đến B_128 cho cả điểm đầu và điểm cuối
            var allPoints = []
            for (var i = 1; i <= 128; i++) {
                allPoints.push("A_" + i)
                allPoints.push("B_" + i)
            }
            // Sắp xếp: A trước, sau đó B, mỗi loại sắp xếp theo số
            allPoints.sort(function (a, b) {
                var partsA = a.split("_")
                var partsB = b.split("_")
                var prefixA = partsA[0]
                var prefixB = partsB[0]
                var numA = parseInt(partsA[1])
                var numB = parseInt(partsB[1])
                if (prefixA !== prefixB) {
                    return prefixA < prefixB ? -1 : 1
                }
                return numA - numB
            })
            availableStartPoints = allPoints
            availableEndPoints = allPoints
            return
        }

        var scripts = testPlanManager.loadScripts(planName) || []
        var startPointsSet = new Set()
        var endPointsSet = new Set()
        var hasPortA = false // Có script từ cổng A (Col C2)
        var hasPortB = false // Có script từ cổng B (Col F)

        for (var i = 0; i < scripts.length; i++) {
            var script = scripts[i]
            var scriptType = String(script.scriptType || "")
            if (scriptType.indexOf("_header") >= 0)
                continue

            var portPinA = script.portPinA !== undefined
                    && script.portPinA !== null && !isNaN(
                        Number(script.portPinA)) ? Number(script.portPinA) : -1
            var portPinB = script.portPinB !== undefined
                    && script.portPinB !== null && !isNaN(
                        Number(script.portPinB)) ? Number(script.portPinB) : -1
            var portLabelA = String(script.portLabelA || "")
            var portLabelB = String(script.portLabelB || "")

            if (scriptType === "wire_resistance") {
                // wire_resistance: pinA từ cổng A (Col C2), pinB từ cổng B (Col F)
                // Thêm vào cả điểm đầu và điểm cuối để có thể chọn linh hoạt
                if (portPinA >= 0 && portPinA <= 128) {
                    startPointsSet.add("A_" + portPinA)
                    endPointsSet.add("A_" + portPinA) // Cũng thêm vào điểm cuối
                    hasPortA = true
                }
                if (portPinB >= 0 && portPinB <= 128) {
                    startPointsSet.add(
                                "B_" + portPinB) // Cũng thêm vào điểm đầu
                    endPointsSet.add("B_" + portPinB)
                    hasPortB = true
                }
            } else if (scriptType === "continuity"
                       || scriptType === "insulation") {
                // continuity/insulation: cả pinA và pinB đều từ cùng một cổng
                // Nếu từ cổng A (Col C2) → thêm tất cả A_1...A_128 vào cả điểm đầu và điểm cuối
                // Nếu từ cổng B (Col F) → thêm tất cả B_1...B_128 vào cả điểm đầu và điểm cuối
                var hasCol2 = portLabelA !== ""
                var hasCol5 = portLabelB !== ""

                if (hasCol2 && !hasCol5) {
                    // PIN từ cổng A (Col C2) → thêm tất cả A_1...A_128
                    hasPortA = true
                    // Thêm các điểm cụ thể từ script
                    if (portPinA >= 0 && portPinA <= 128) {
                        startPointsSet.add("A_" + portPinA)
                        endPointsSet.add("A_" + portPinA)
                    }
                    if (portPinB >= 0 && portPinB <= 128) {
                        startPointsSet.add("A_" + portPinB)
                        endPointsSet.add("A_" + portPinB)
                    }
                } else if (hasCol5 && !hasCol2) {
                    // PIN từ cổng B (Col F) → thêm tất cả B_1...B_128
                    hasPortB = true
                    // Thêm các điểm cụ thể từ script
                    if (portPinA >= 0 && portPinA <= 128) {
                        startPointsSet.add("B_" + portPinA)
                        endPointsSet.add("B_" + portPinA)
                    }
                    if (portPinB >= 0 && portPinB <= 128) {
                        startPointsSet.add("B_" + portPinB)
                        endPointsSet.add("B_" + portPinB)
                    }
                } else if (hasCol2) {
                    // Ưu tiên col2 (cổng A) → thêm tất cả A_1...A_128
                    hasPortA = true
                    if (portPinA >= 0 && portPinA <= 128) {
                        startPointsSet.add("A_" + portPinA)
                        endPointsSet.add("A_" + portPinA)
                    }
                    if (portPinB >= 0 && portPinB <= 128) {
                        startPointsSet.add("A_" + portPinB)
                        endPointsSet.add("A_" + portPinB)
                    }
                } else if (hasCol5) {
                    // Chỉ có col5 (cổng B) → thêm tất cả B_1...B_128
                    hasPortB = true
                    if (portPinA >= 0 && portPinA <= 128) {
                        startPointsSet.add("B_" + portPinA)
                        endPointsSet.add("B_" + portPinA)
                    }
                    if (portPinB >= 0 && portPinB <= 128) {
                        startPointsSet.add("B_" + portPinB)
                        endPointsSet.add("B_" + portPinB)
                    }
                }
            } else if (scriptType === "sheath_insulation") {
                // sheath_insulation: chỉ có một pin từ một cổng
                // Thêm vào cả điểm đầu và điểm cuối để có thể chọn linh hoạt
                if (portPinA >= 0 && portPinA <= 128) {
                    // pinA từ cổng A (Col C2)
                    startPointsSet.add("A_" + portPinA)
                    endPointsSet.add("A_" + portPinA) // Cũng thêm vào điểm cuối
                    hasPortA = true
                }
                if (portPinB >= 0 && portPinB <= 128) {
                    // pinB từ cổng B (Col F)
                    startPointsSet.add(
                                "B_" + portPinB) // Cũng thêm vào điểm đầu
                    endPointsSet.add("B_" + portPinB)
                    hasPortB = true
                }
            }
        }

        // Nếu có script từ cổng A (Col C2), thêm tất cả A_1...A_128 vào cả điểm đầu và điểm cuối
        if (hasPortA) {
            for (var j = 1; j <= 128; j++) {
                startPointsSet.add("A_" + j)
                endPointsSet.add("A_" + j)
            }
        }

        // Nếu có script từ cổng B (Col F), thêm tất cả B_1...B_128 vào cả điểm đầu và điểm cuối
        if (hasPortB) {
            for (var k = 1; k <= 128; k++) {
                startPointsSet.add("B_" + k)
                endPointsSet.add("B_" + k)
            }
        }

        // Chuyển Set thành Array và sắp xếp (sắp xếp theo prefix A/B trước, sau đó theo số)
        var startPointsArray = Array.from(startPointsSet).sort(function (a, b) {
            var partsA = a.split("_")
            var partsB = b.split("_")
            var prefixA = partsA[0]
            var prefixB = partsB[0]
            var numA = parseInt(partsA[1])
            var numB = parseInt(partsB[1])
            // So sánh prefix trước (A < B)
            if (prefixA !== prefixB) {
                return prefixA < prefixB ? -1 : 1
            }
            // Nếu cùng prefix, so sánh số
            return numA - numB
        })
        var endPointsArray = Array.from(endPointsSet).sort(function (a, b) {
            var partsA = a.split("_")
            var partsB = b.split("_")
            var prefixA = partsA[0]
            var prefixB = partsB[0]
            var numA = parseInt(partsA[1])
            var numB = parseInt(partsB[1])
            // So sánh prefix trước (A < B)
            if (prefixA !== prefixB) {
                return prefixA < prefixB ? -1 : 1
            }
            // Nếu cùng prefix, so sánh số
            return numA - numB
        })

        // Nếu không có điểm nào từ scripts, hiển thị tất cả A và B cho cả điểm đầu và điểm cuối
        if (startPointsArray.length === 0) {
            for (var j = 1; j <= 128; j++) {
                startPointsArray.push("A_" + j)
                startPointsArray.push("B_" + j)
            }
        }
        if (endPointsArray.length === 0) {
            for (var k = 1; k <= 128; k++) {
                endPointsArray.push("A_" + k)
                endPointsArray.push("B_" + k)
            }
        }

        availableStartPoints = startPointsArray
        availableEndPoints = endPointsArray

        console.log("[CalibrationDialog] Loaded", availableStartPoints.length,
                    "start points and", availableEndPoints.length,
                    "end points from scripts")
    }

    // ═══════════════════════════════════════════════════════════════
    // ═══ HÀM KHỞI TẠO BẢNG DỮ LIỆU HIỆU CHUẨN ═══
    // ═══════════════════════════════════════════════════════════════

    // Tạo tất cả tổ hợp điểm (128×128) và link với scripts từ bài đo
    // Bảng gồm 3 phần:
    //   Phần 1: A↔A (A_1↔A_2, A_1↔A_3, ...) — continuity cổng A — C(128,2) = 8128 dòng
    //   Phần 2: B↔B (B_1↔B_2, B_1↔B_3, ...) — continuity cổng B — C(128,2) = 8128 dòng
    //   Phần 3: A↔B (A_1↔B_1, A_1↔B_2, ...) — wire resistance  — 128×128 = 16384 dòng
    // Tổng: ~32,640 dòng (nhưng chỉ dòng có script → highlight xanh lá)
    function initializeData() {
        calibrationDataModel.clear()

        var planName = ""
        if (mainContent && mainContent.currentPlanName) {
            planName = mainContent.currentPlanName
        }

        // Các mapping để liên kết script → điểm trong bảng
        var scriptMapping = {} // Key: "A_X_B_Y" → Value: {labelA, pinA, labelB, pinB, scriptType, portPinA, portPinB}
        var pinAMapping = {} // Key: "A_X" → Value: portPinA (PIN mà MCU gửi, từ col2 Excel)
        var pinBMapping = {} // Key: "B_Y" → Value: portPinB (PIN mà MCU gửi, từ col5 Excel)
        var continuityAMapping = {} // Key: "A_X_A_Y" → Value: {portPinA, portPinB} (cùng cổng A)
        var continuityBMapping = {} // Key: "B_X_B_Y" → Value: {portPinA, portPinB} (cùng cổng B)

        if (planName && typeof testPlanManager !== "undefined"
                && testPlanManager) {
            var scripts = testPlanManager.loadScripts(planName) || []
            console.log("[CalibrationDialog] initializeData - Số lượng scripts:",
                        scripts.length)
            for (var i = 0; i < scripts.length; i++) {
                var script = scripts[i]
                var scriptType = String(script.scriptType || "")
                if (scriptType.indexOf("_header") >= 0)
                    continue

                var portPinA = script.portPinA !== undefined
                        && script.portPinA !== null && !isNaN(
                            Number(script.portPinA)) ? Number(
                                                           script.portPinA) : -1
                var portPinB = script.portPinB !== undefined
                        && script.portPinB !== null && !isNaN(
                            Number(script.portPinB)) ? Number(
                                                           script.portPinB) : -1

                // Debug: In ra thông tin script để kiểm tra mapping
                if (scriptType === "wire_resistance" && portPinA >= 0
                        && portPinB >= 0) {
                    console.log("[CalibrationDialog] Script:", script.labelA + "_" + script.pinA
                                + " <-> " + script.labelB + "_" + script.pinB,
                                "→ portPinA=" + portPinA + " (A_" + portPinA
                                + "), portPinB=" + portPinB + " (B_" + portPinB + ")")
                }

                if (scriptType === "wire_resistance" && portPinA >= 0
                        && portPinA <= 128 && portPinB >= 0
                        && portPinB <= 128) {
                    // wire_resistance: A_X <-> B_Y
                    // portPinA từ col2 (Chân đo cổng A) → A_portPinA (ví dụ: portPinA=4 → A_4)
                    // portPinB từ col5 (Chân đo cổng B) → B_portPinB (ví dụ: portPinB=1 → B_1)
                    // Bảng hiệu chuẩn bắt đầu từ 1, không phải 0
                    var key = "A_" + portPinA + "_B_" + portPinB
                    scriptMapping[key] = {
                        "labelA": String(script.labelA || ""),
                        "pinA": String(script.pinA || ""),
                        "labelB": String(script.labelB || ""),
                        "pinB": String(script.pinB || ""),
                        "scriptType": scriptType,
                        "portPinA": portPinA,
                        "portPinB"// Chân PIN mà MCU gửi đi (từ col2)
                        : portPinB // Chân PIN mà MCU gửi đi (từ col5)
                    }
                    // Lưu mapping PIN_A và PIN_B: portPinA từ col2 → A_portPinA
                    pinAMapping["A_" + portPinA] = portPinA
                    pinBMapping["B_" + portPinB] = portPinB
                } else if (scriptType === "continuity"
                           || scriptType === "insulation") {
                    // continuity/insulation: cùng cổng
                    var portLabelA = String(script.portLabelA || "")
                    var portLabelB = String(script.portLabelB || "")

                    if (portLabelA !== "" && portPinA >= 0 && portPinA <= 128
                            && portPinB >= 0 && portPinB <= 128) {
                        // Cổng A: A_X <-> A_Y
                        // portPinA và portPinB đều từ col2 (Chân đo cổng A)
                        // → A_portPinA và A_portPinB (ví dụ: portPinA=4, portPinB=5 → A_4 và A_5)
                        var keyA = "A_" + portPinA + "_A_" + portPinB
                        scriptMapping[keyA] = {
                            "labelA": String(script.labelA || ""),
                            "pinA": String(script.pinA || ""),
                            "labelB": String(script.labelA || ""),
                            "pinB": String(script.pinB || ""),
                            "scriptType": scriptType,
                            "portPinA": portPinA,
                            "portPinB"// Chân PIN mà MCU gửi đi (từ col2)
                            : portPinB // Chân PIN mà MCU gửi đi (từ col2)
                        }
                        // Lưu mapping A nối với A
                        continuityAMapping[keyA] = {
                            "portPinA": portPinA,
                            "portPinB": portPinB
                        }
                        pinAMapping["A_" + portPinA] = portPinA
                        pinAMapping["A_" + portPinB] = portPinB
                    }
                    if (portLabelB !== "" && portPinA >= 0 && portPinA <= 128
                            && portPinB >= 0 && portPinB <= 128) {
                        // Cổng B: B_X <-> B_Y
                        // portPinA và portPinB đều từ col5 (Chân đo cổng B)
                        // → B_portPinA và B_portPinB (ví dụ: portPinA=1, portPinB=2 → B_1 và B_2)
                        var keyB = "B_" + portPinA + "_B_" + portPinB
                        scriptMapping[keyB] = {
                            "labelA": String(script.labelA || ""),
                            "pinA": String(script.pinA || ""),
                            "labelB": String(script.labelA || ""),
                            "pinB": String(script.pinB || ""),
                            "scriptType": scriptType,
                            "portPinA": portPinA,
                            "portPinB"// Chân PIN mà MCU gửi đi (từ col5)
                            : portPinB // Chân PIN mà MCU gửi đi (từ col5)
                        }
                        // Lưu mapping B nối với B
                        continuityBMapping[keyB] = {
                            "portPinA": portPinA,
                            "portPinB": portPinB
                        }
                        pinBMapping["B_" + portPinA] = portPinA
                        pinBMapping["B_" + portPinB] = portPinB
                    }
                } else if (scriptType === "sheath_insulation") {
                    // sheath_insulation: chỉ có một pin
                    if (portPinA >= 0 && portPinA <= 128) {
                        pinAMapping["A_" + portPinA] = portPinA
                    }
                    if (portPinB >= 0 && portPinB <= 128) {
                        pinBMapping["B_" + portPinB] = portPinB
                    }
                }
            }
        }

        var stt = 0

        // ── Phần 1: A↔B – Chân cổng A nối với chân cổng B (A_x ↔ B_y) ──
        for (var a = 1; a <= 128; a++) {
            for (var b = 1; b <= 128; b++) {
                var key = "A_" + a + "_B_" + b
                var scriptInfo = scriptMapping[key]
                var pinAKey = "A_" + a
                var pinBKey = "B_" + b
                var continuityAKey = "A_" + a + "_A_" + b
                var continuityBKey = "B_" + a + "_B_" + b

                var startPtAB = "A_" + a
                var endPtAB = "B_" + b
                var item = {
                    "stt": stt,
                    "startPoint": startPtAB,
                    "endPoint": endPtAB,
                    "value": 0.0,
                    "chanA": _getPointExcelInfo(startPtAB),
                    "chanB": _getPointExcelInfo(endPtAB),
                    "excelInfo": _getExcelInfoFromPoints(startPtAB, endPtAB)
                }
                if (pinAMapping[pinAKey] !== undefined) {
                    item.pinA = pinAMapping[pinAKey]
                }
                if (pinBMapping[pinBKey] !== undefined) {
                    item.pinB = pinBMapping[pinBKey]
                }
                if (continuityAMapping[continuityAKey]) {
                    item.continuityA = continuityAMapping[continuityAKey]
                }
                if (continuityBMapping[continuityBKey]) {
                    item.continuityB = continuityBMapping[continuityBKey]
                }
                if (scriptInfo) {
                    item.scriptInfo = scriptInfo
                }
                calibrationDataModel.append(item)
                stt++
            }
        }

        // ── Phần 2: A↔A – Các chân cổng A nối với nhau (A_x ↔ A_y, x < y) ──
        for (var a1 = 1; a1 <= 128; a1++) {
            for (var a2 = a1 + 1; a2 <= 128; a2++) {
                var keyAA = "A_" + a1 + "_A_" + a2
                var scriptInfoAA = scriptMapping[keyAA]
                var pinAKey1 = "A_" + a1
                var pinAKey2 = "A_" + a2

                var startPtAA = "A_" + a1
                var endPtAA = "A_" + a2
                var itemAA = {
                    "stt": stt,
                    "startPoint": startPtAA,
                    "endPoint": endPtAA,
                    "value": 0.0,
                    "chanA": _getPointExcelInfo(startPtAA),
                    "chanB": _getPointExcelInfo(endPtAA),
                    "excelInfo": _getExcelInfoFromPoints(startPtAA, endPtAA)
                }
                if (pinAMapping[pinAKey1] !== undefined) {
                    itemAA.pinA = pinAMapping[pinAKey1]
                }
                if (pinAMapping[pinAKey2] !== undefined) {

                    // Chỉ hiển thị pinA của điểm đầu
                }
                if (continuityAMapping[keyAA]) {
                    itemAA.continuityA = continuityAMapping[keyAA]
                }
                if (scriptInfoAA) {
                    itemAA.scriptInfo = scriptInfoAA
                }
                calibrationDataModel.append(itemAA)
                stt++
            }
        }

        // ── Phần 3: B↔B – Các chân cổng B nối với nhau (B_x ↔ B_y, x < y) ──
        for (var b1 = 1; b1 <= 128; b1++) {
            for (var b2 = b1 + 1; b2 <= 128; b2++) {
                var keyBB = "B_" + b1 + "_B_" + b2
                var scriptInfoBB = scriptMapping[keyBB]
                var pinBKey1 = "B_" + b1
                var pinBKey2 = "B_" + b2

                var startPtBB = "B_" + b1
                var endPtBB = "B_" + b2
                var itemBB = {
                    "stt": stt,
                    "startPoint": startPtBB,
                    "endPoint": endPtBB,
                    "value": 0.0,
                    "chanA": _getPointExcelInfo(startPtBB),
                    "chanB": _getPointExcelInfo(endPtBB),
                    "excelInfo": _getExcelInfoFromPoints(startPtBB, endPtBB)
                }
                if (pinBMapping[pinBKey1] !== undefined) {
                    itemBB.pinB = pinBMapping[pinBKey1]
                }
                if (pinBMapping[pinBKey2] !== undefined) {

                    // Chỉ hiển thị pinB của điểm đầu
                }
                if (continuityBMapping[keyBB]) {
                    itemBB.continuityB = continuityBMapping[keyBB]
                }
                if (scriptInfoBB) {
                    itemBB.scriptInfo = scriptInfoBB
                }
                calibrationDataModel.append(itemBB)
                stt++
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // ═══ HÀM CẬP NHẬT & TRA CỨU GIÁ TRỊ OFFSET ═══
    // ═══════════════════════════════════════════════════════════════

    // Cập nhật 1 offset trong model + cache — gọi sau khi đo xong
    function updateValue(startPoint, endPoint, value) {
        // Tìm và cập nhật giá trị trong model
        for (var i = 0; i < calibrationDataModel.count; i++) {
            var item = calibrationDataModel.get(i)
            if (item.startPoint === startPoint && item.endPoint === endPoint) {
                calibrationDataModel.setProperty(i, "value", value)
                // Cập nhật cache
                if (value !== 0) {
                    _calibValueMap[startPoint + "_" + endPoint] = value
                } else {
                    delete _calibValueMap[startPoint + "_" + endPoint]
                }
                break
            }
        }
    }

    function scrollToPoint(startPoint, endPoint) {
        // Tìm index của dòng có startPoint và endPoint khớp
        for (var i = 0; i < calibrationDataModel.count; i++) {
            var item = calibrationDataModel.get(i)
            if (item.startPoint === startPoint && item.endPoint === endPoint) {
                // Highlight dòng này
                highlightedRowIndex = i
                // Scroll đến dòng đó
                calibrationTableView.positionViewAtIndex(i, ListView.Center)
                return
            }
        }
        // Nếu không tìm thấy, bỏ highlight
        highlightedRowIndex = -1
    }

    function findScriptByLabels(labelA, pinA, labelB, pinB) {
        // Tìm script trong bảng hiệu chỉnh dựa trên labelA, pinA, labelB, pinB
        // Trả về: {startPoint, endPoint, index} hoặc null nếu không tìm thấy
        for (var i = 0; i < calibrationDataModel.count; i++) {
            var item = calibrationDataModel.get(i)
            if (item.scriptInfo) {
                var info = item.scriptInfo
                if (info.labelA === labelA && info.pinA === pinA
                        && info.labelB === labelB && info.pinB === pinB) {
                    return {
                        "startPoint": item.startPoint,
                        "endPoint": item.endPoint,
                        "index": i,
                        "portPinA": info.portPinA,
                        "portPinB": info.portPinB
                    }
                }
            }
        }
        return null
    }

    // ═══════════════════════════════════════════════════════════════
    // ═══ HÀM LƯU / LOAD FILE calibration.att ═══
    // ═══════════════════════════════════════════════════════════════

    // Lưu toàn bộ bảng hiệu chuẩn ra file
    // Format dòng đầu: "0 [ĐT_chuẩn] [ĐT_cáp] 0"
    // Format các dòng sau: "STT Đ.đầu Đ.cuối Offset" (VD: "1 A_1 B_1 0.002345")
    function saveToFile(filePath) {
        if (typeof window !== "undefined")
            window.addLog(
                        "Hiệu chuẩn",
                        "Lưu file dữ liệu hiệu chuẩn thiết bị xuống mức hệ thống: " + filePath)
        var content = ""
        // Dòng đầu: 0 [điện trở chuẩn] [điện trở cáp chuyển đổi] 0 (STT=0, điện trở chuẩn, điện trở cáp chuyển đổi, giá trị=0)
        content += "0 " + standardResistance.toFixed(
                    6) + " " + cableResistance.toFixed(6) + " 0\n"

        // Các dòng tiếp theo: STT Điểm_đầu Điểm_cuối Giá_trị
        // Lưu tất cả các điểm (kể cả giá trị = 0)
        for (var i = 0; i < calibrationDataModel.count; i++) {
            var item = calibrationDataModel.get(i)
            content += (item.stt + 1) + " " + item.startPoint + " "
                    + item.endPoint + " " + item.value.toFixed(6) + "\n"
        }

        // Lưu file bằng fileHelper
        return fileHelper.writeTextFile(filePath, content)
    }

    function loadFromFile() {
        var appDir = fileHelper.applicationDirPath()
        var filePath = appDir + "/calibration.att"
        if (!fileHelper.fileExists(filePath)) {
            console.log("[CalibrationDialog] loadFromFile: file chưa tồn tại (lần đầu chạy)")
            return
        }
        var content = fileHelper.readTextFile(filePath)
        if (!content || content.trim() === "") {
            console.log("[CalibrationDialog] loadFromFile: file rỗng")
            return
        }

        var lines = content.split("\n")

        // Dòng đầu: 0 [standardResistance] [cableResistance] 0
        if (lines.length > 0) {
            var headerParts = lines[0].trim().split(/\s+/)
            if (headerParts.length >= 2) {
                var stdRes = parseFloat(headerParts[1])
                if (!isNaN(stdRes) && stdRes > 0) {
                    standardResistance = stdRes
                }
            }
            if (headerParts.length >= 3) {
                var cableRes = parseFloat(headerParts[2])
                if (!isNaN(cableRes) && cableRes > 0) {
                    cableResistance = cableRes
                }
            }
        }

        // Build map: "startPoint_endPoint" → value (chỉ lưu value != 0)
        var valueMap = {}
        var loadedCount = 0
        for (var i = 1; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line === "")
                continue
            var parts = line.split(/\s+/)
            if (parts.length >= 4) {
                var startPt = parts[1]
                var endPt = parts[2]
                var val = parseFloat(parts[3])
                if (!isNaN(val) && val !== 0) {
                    valueMap[startPt + "_" + endPt] = val
                    loadedCount++
                }
            }
        }

        // Cập nhật model với giá trị đã lưu
        var updatedCount = 0
        for (var j = 0; j < calibrationDataModel.count; j++) {
            var item = calibrationDataModel.get(j)
            var mapKey = item.startPoint + "_" + item.endPoint
            if (valueMap[mapKey] !== undefined) {
                calibrationDataModel.setProperty(j, "value", valueMap[mapKey])
                updatedCount++
            }
        }

        console.log("[CalibrationDialog] loadFromFile: loaded", updatedCount,
                    "values from", filePath, "(", loadedCount,
                    "non-zero in file)")
        _buildCalibValueMap()
    }

    // ── Cache HashMap để tra cứu offset nhanh ──
    // Key: "A_1_B_2" → Value: offset (double)
    // Rebuild mỗi khi load file hoặc cập nhật giá trị
    property var _calibValueMap: ({})

    function _buildCalibValueMap() {
        var map = {}
        for (var i = 0; i < calibrationDataModel.count; i++) {
            var item = calibrationDataModel.get(i)
            if (item.value !== 0) {
                map[item.startPoint + "_" + item.endPoint] = item.value
            }
        }
        _calibValueMap = map
        console.log("[CalibrationDialog] Built calibration map with",
                    Object.keys(map).length, "non-zero entries")
    }

    function _lookupCalibValue(startPoint, endPoint) {
        var key = startPoint + "_" + endPoint
        if (_calibValueMap[key] !== undefined)
            return _calibValueMap[key]
        for (var i = 0; i < calibrationDataModel.count; i++) {
            var item = calibrationDataModel.get(i)
            if (item.startPoint === startPoint && item.endPoint === endPoint) {
                return item.value
            }
        }
        return 0
    }

    // ═══════════════════════════════════════════════════════════════
    // ═══ API CHÍNH — ĐƯỢC GỌI TỪ MainContent KHI ĐO THỰC TẾ ═══
    // ═══════════════════════════════════════════════════════════════

    // Tra cứu offset hiệu chuẩn cho 1 cặp pin cụ thể
    // Input:  portPinA (số pin MCU cổng A), portPinB (số pin MCU cổng B), scriptType
    // Output: { offset: double, calibKey: string }
    // Key = "A_{portPin}" / "B_{portPin}" — dùng trực tiếp số chân đo cổng (MCU relay pin)
    // Ví dụ:  getCalibrationOffset(4, 1, "wire_resistance")
    //         → { offset: 0.002345, calibKey: "A_4 ↔ B_1" }
    // Cách dùng: adjustedValue = rawValue - result.offset
    function getCalibrationOffset(portPinA, portPinB, scriptType) {
        if (scriptType === "wire_resistance") {
            // wire_resistance: A_portPinA ↔ B_portPinB (dùng portPin trực tiếp)
            if (portPinA < 0 || portPinB < 0)
                return {
                    "offset": 0,
                    "calibKey": ""
                }
            var spWR = "A_" + portPinA
            var epWR = "B_" + portPinB
            return {
                "offset": _lookupCalibValue(spWR, epWR),
                "calibKey": spWR + " ↔ " + epWR
            }
        } else if (scriptType === "continuity" || scriptType === "insulation") {
            // continuity/insulation cùng cổng: A_x ↔ A_y hoặc B_x ↔ B_y
            if (portPinA > 0 && portPinB > 0) {
                // Thử cổng A trước
                var sA = Math.min(portPinA, portPinB)
                var eA = Math.max(portPinA, portPinB)
                var offsetA = _lookupCalibValue("A_" + sA, "A_" + eA)
                if (offsetA !== 0) {
                    return {
                        "offset": offsetA,
                        "calibKey": "A_" + sA + " ↔ A_" + eA
                    }
                }
                // Thử cổng B
                var sB = Math.min(portPinA, portPinB)
                var eB = Math.max(portPinA, portPinB)
                var offsetB = _lookupCalibValue("B_" + sB, "B_" + eB)
                if (offsetB !== 0) {
                    return {
                        "offset": offsetB,
                        "calibKey": "B_" + sB + " ↔ B_" + eB
                    }
                }
            }
            return {
                "offset": 0,
                "calibKey": ""
            }
        } else if (scriptType === "sheath_insulation") {
            // sheath_insulation: chỉ 1 pin
            if (portPinA > 0) {
                var offsetSA = _lookupCalibValue("A_" + portPinA, "")
                if (offsetSA !== 0)
                    return {
                        "offset": offsetSA,
                        "calibKey": "A_" + portPinA
                    }
            }
            if (portPinB > 0) {
                var offsetSB = _lookupCalibValue("B_" + portPinB, "")
                if (offsetSB !== 0)
                    return {
                        "offset": offsetSB,
                        "calibKey": "B_" + portPinB
                    }
            }
            return {
                "offset": 0,
                "calibKey": ""
            }
        }
        return {
            "offset": 0,
            "calibKey": ""
        }
    }

    // Khi component được tạo (lần đầu) → khởi tạo bảng + load file đã lưu
    Component.onCompleted: {
        initializeData()
        loadFromFile()
    }

    // ═══ Nhận kết quả đo từ máy Hioki RM3544 ═══
    // onResistanceRead: Khi đọc điện trở thành công → tính sai số → lưu vào bảng
    // onErrorOccurred: Khi đọc lỗi → hiện thông báo
    // onOpenChanged: Khi cổng COM mở/đóng → ẩn thông báo lỗi
    Connections {
        target: keithley2110
        function onResistanceRead(value) {
            // Tính sai số: ssht = Hioki_đọc - R_chuẩn - R_cáp
            // (Phần R_cáp này sẽ được MainContent cộng lại/trừ ra tùy theo mode hiệu chuẩn)
            var ssht = value - standardResistance - cableResistance
            // Lấy điểm từ selectedStartPoint và selectedEndPoint (đã là chuỗi đầy đủ như "B_30")
            var startPoint = selectedStartPoint
            var endPoint = selectedEndPoint
            // Đảm bảo lấy từ ComboBox nếu có
            if (startPointCombo.currentIndex >= 0
                    && startPointCombo.currentIndex < availableStartPoints.length) {
                startPoint = availableStartPoints[startPointCombo.currentIndex]
            }
            if (endPointCombo.currentIndex >= 0
                    && endPointCombo.currentIndex < availableEndPoints.length) {
                endPoint = availableEndPoints[endPointCombo.currentIndex]
            }
            updateValue(startPoint, endPoint, ssht)
        }

        function onErrorOccurred(error) {
            errorLabel.text = error
            errorLabel.visible = true
        }

        function onOpenChanged() {
            // Khi cổng COM được mở thành công, ẩn thông báo lỗi
            if (keithley2110.isOpen) {
                errorLabel.visible = false
            }
        }
    }

    // ═══ Nhận tín hiệu MCU khi hiệu chuẩn ═══
    // PC gửi packet CMD=0x7B → MCU nhận → bật relay → gửi 3A 53 BC [CRC] → PC đọc máy đo
    Connections {
        target: typeof mcuSender !== "undefined" ? mcuSender : null
        enabled: calibrationDialog._calibWaitingMcu
        function onMcuCalibrationReady() {
            // MCU relay đã bật (0xBC) → đọc máy đo
            if (calibrationDialog._calibWaitingMcu) {
                calibrationDialog._calibWaitingMcu = false
                console.log("[Calibration] MCU sẵn sàng (0xBC) - đọc RM3544")
                keithley2110.readResistance()
            }
        }
    }

    // ╔══════════════════════════════════════════════════════════════╗
    // ║ UI LAYOUT                                                    ║
    // ║ ColumnLayout (root)                                          ║
    // ║   ├── RowLayout (tiêu đề + nút Reload + nút Tìm Script)     ║
    // ║   └── RowLayout (nội dung chính)                             ║
    // ║       ├── Rectangle (BẢNG HIỆU CHUẨN — bên trái, co giãn)   ║
    // ║       │   ├── Checkboxes ẩn/hiện cột phụ                     ║
    // ║       │   ├── Header Row (STT | Đ.đầu | Đ.cuối | Giá trị)   ║
    // ║       │   └── ScrollView → ListView (32K+ dòng)              ║
    // ║       └── Rectangle (PANEL ĐIỀU KHIỂN — bên phải, 400px)     ║
    // ║           ├── TextField: Điện trở cáp chuyển đổi             ║
    // ║           ├── Panel "Hiệu chỉnh bằng máy đo"                ║
    // ║           │   ├── ComboBox: Cổng COM                         ║
    // ║           │   ├── Button: CONNECT/DISCONNECT                  ║
    // ║           │   ├── ComboBox: Điểm đầu (A_1, A_2, ...)         ║
    // ║           │   ├── ComboBox: Điểm cuối (B_1, B_2, ...)         ║
    // ║           │   ├── TextField: Điện trở chuẩn                   ║
    // ║           │   └── Button: Hiệu chỉnh (đọc máy đo)            ║
    // ║           ├── RadioButton: Chọn mode hiệu chuẩn               ║
    // ║           ├── Label: Đường dẫn file sẽ lưu                    ║
    // ║           └── Button: "Chọn và Lưu Lại"                       ║
    // ╚══════════════════════════════════════════════════════════════╝
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // Tiêu đề
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            QC.Label {
                text: qsTr("Điều chỉnh tham số hiệu chỉnh")
                font.bold: true
                font.pixelSize: 18
                Layout.fillWidth: true
            }
            // Nút reload bảng hiệu chuẩn
            QC.Button {
                text: qsTr("Reload")
                font.pixelSize: 12
                onClicked: {
                    calibrationDialog.reloadCalibrationTable()
                }
            }
            // Nút tìm script
            QC.Button {
                text: qsTr("Tìm Script")
                font.pixelSize: 12
                onClicked: {
                    findScriptDialog.open()
                }
            }
        }

        // ── Nội dung chính: Bảng (trái) + Panel điều khiển (phải) ──
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // Bảng dữ liệu hiệu chỉnh
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#ffffff"
                border.color: "#d0d0d0"
                radius: 4

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    QC.Label {
                        text: qsTr("Dữ liệu hiệu chỉnh  (A↔A: chân cổng A nối nhau  |  B↔B: chân cổng B nối nhau  |  A↔B: chân A nối chân B)")
                        font.bold: true
                        font.pixelSize: 11
                        Layout.fillWidth: true
                        color: "#555"
                    }

                    // Header của bảng
                    Row {
                        Layout.fillWidth: true
                        spacing: 0
                        Rectangle {
                            width: 45
                            height: 30
                            color: "#e0e0e0"
                            border.color: "#c0c0c0"
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("STT")
                                font.bold: true
                                font.pixelSize: 11
                            }
                        }
                        Rectangle {
                            width: 55
                            height: 30
                            color: "#e0e0e0"
                            border.color: "#c0c0c0"
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Điểm đầu")
                                font.bold: true
                                font.pixelSize: 11
                            }
                        }

                        Rectangle {
                            width: 55
                            height: 30
                            color: "#e0e0e0"
                            border.color: "#c0c0c0"
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Điểm cuối")
                                font.bold: true
                                font.pixelSize: 11
                            }
                        }

                        Rectangle {
                            width: 85
                            height: 30
                            color: "#e0e0e0"
                            border.color: "#c0c0c0"
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Giá trị")
                                font.bold: true
                                font.pixelSize: 11
                            }
                        }
                    }

                    QC.ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        QC.ScrollBar.vertical.policy: QC.ScrollBar.AsNeeded
                        QC.ScrollBar.horizontal.policy: QC.ScrollBar.AsNeeded

                        // ListView hiển thị ~32K dòng tổ hợp điểm
                        // Mỗi dòng = 1 delegate Row với các cột: STT, Đ.đầu, Đ.cuối, Giá trị
                        // Dòng được chọn → highlight vàng (highlightedRowIndex)
                        ListView {
                            id: calibrationTableView
                            width: Math.max(parent.width, 1200)
                            model: calibrationDataModel // ListModel chứa {stt, startPoint, endPoint, value}

                            delegate: Item {
                                width: delegateRow.width
                                height: delegateRow.height
                                property bool hasExcel: {
                                    if (model.scriptInfo !== undefined
                                            && model.scriptInfo !== null)
                                        return true
                                    //    if (model.excelInfo !== undefined && model.excelInfo !== null && model.excelInfo !== "") return true
                                    return false
                                }
                                property color rowBg: {
                                    if (index === calibrationDialog.highlightedRowIndex)
                                        return "#ffeb3b"
                                    if (hasExcel)
                                        return "#e8f5e9"
                                    return index % 2 === 0 ? "#f9f9f9" : "#ffffff"
                                }

                                Row {
                                    id: delegateRow
                                    spacing: 0

                                    // STT
                                    Rectangle {
                                        width: 45
                                        height: 28
                                        border.color: "#e0e0e0"
                                        color: rowBg
                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            text: model.stt + 1
                                            verticalAlignment: Text.AlignVCenter
                                            font.pixelSize: 11
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                calibrationDialog.highlightedRowIndex = index
                                                valueField.forceActiveFocus()
                                                valueField.selectAll()
                                            }
                                        }
                                    }
                                    // Điểm đầu
                                    Rectangle {
                                        width: 55
                                        height: 28
                                        border.color: "#e0e0e0"
                                        color: rowBg
                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            text: model.startPoint
                                            verticalAlignment: Text.AlignVCenter
                                            font.pixelSize: 11
                                            font.bold: hasExcel
                                            color: hasExcel ? "#2e7d32" : "#333"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                calibrationDialog.highlightedRowIndex = index
                                                valueField.forceActiveFocus()
                                                valueField.selectAll()
                                            }
                                        }
                                    }

                                    // Điểm cuối
                                    Rectangle {
                                        width: 55
                                        height: 28
                                        border.color: "#e0e0e0"
                                        color: rowBg
                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            text: model.endPoint
                                            verticalAlignment: Text.AlignVCenter
                                            font.pixelSize: 11
                                            font.bold: hasExcel
                                            color: hasExcel ? "#2e7d32" : "#333"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                calibrationDialog.highlightedRowIndex = index
                                                valueField.forceActiveFocus()
                                                valueField.selectAll()
                                            }
                                        }
                                    }

                                    // Giá trị
                                    Rectangle {
                                        width: 85
                                        height: 28
                                        border.color: "#e0e0e0"
                                        color: rowBg
                                        QC.TextField {
                                            id: valueField
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            text: {
                                                if (model.value === 0.0
                                                        || model.value === 0)
                                                    return ""
                                                var val = model.value
                                                if (val % 1 === 0)
                                                    return val.toString()
                                                return val.toFixed(6).replace(
                                                            /\.?0+$/, "")
                                            }
                                            selectByMouse: true
                                            font.pixelSize: 11
                                            padding: 3
                                            validator: DoubleValidator {
                                                bottom: -1000000.0
                                                top: 1000000.0
                                            }
                                            // Khi click vào ô giá trị → cũng highlight dòng
                                            onActiveFocusChanged: {
                                                if (activeFocus) {
                                                    calibrationDialog.highlightedRowIndex = index
                                                }
                                            }
                                            onEditingFinished: {
                                                var val = parseFloat(text)
                                                var oldVal = model.value
                                                var newVal = !isNaN(
                                                            val) ? val : 0.0
                                                if (oldVal !== newVal) {
                                                    if (typeof window !== "undefined")
                                                        window.addLog(
                                                                    "Hiệu chuẩn",
                                                                    "Sửa offset thiết bị: [" + model.startPoint + " ↔ " + model.endPoint + "] từ " + oldVal + " thành " + newVal)
                                                    calibrationDataModel.setProperty(
                                                                index, "value",
                                                                newVal)
                                                    _buildCalibValueMap(
                                                                ) // ✔ Cập nhật HashMap để Lookup ngay lập tức
                                                }
                                            }
                                            onFocusChanged: {
                                                if (!focus) {
                                                    var val = parseFloat(text)
                                                    var oldVal = model.value
                                                    var newVal = !isNaN(
                                                                val) ? val : 0.0
                                                    if (oldVal !== newVal) {
                                                        if (typeof window !== "undefined")
                                                            window.addLog(
                                                                        "Hiệu chuẩn",
                                                                        "Sửa offset thiết bị: [" + model.startPoint + " ↔ " + model.endPoint + "] từ " + oldVal + " thành " + newVal)
                                                        calibrationDataModel.setProperty(
                                                                    index,
                                                                    "value",
                                                                    newVal)
                                                        _buildCalibValueMap(
                                                                    ) // ✔ Cập nhật HashMap để Lookup ngay lập tức
                                                    }
                                                }
                                            }
                                        }
                                    }
                                } // end Row
                            }
                        }
                    }
                }
            }

            // ── Panel điều khiển bên phải (400px) ──
            // Chứa: nhập ĐT cáp, kết nối COM, chọn điểm, đo, lưu file
            Rectangle {
                Layout.preferredWidth: 400
                Layout.fillHeight: true
                color: "#f5f5f5"
                border.color: "#d0d0d0"
                radius: 4

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16

                    // Điện trở cáp chuyển đổi
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        QC.Label {
                            text: qsTr("Điện trở cáp chuyển đổi")
                            font.pixelSize: 13
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            QC.TextField {
                                id: cableResistanceField
                                Layout.fillWidth: true
                                text: {
                                    var val = cableResistance
                                    if (val % 1 === 0)
                                        return val.toString()
                                    return val.toFixed(6).replace(/\.?0+$/, "")
                                }
                                font.pixelSize: 13
                                padding: 8
                                validator: DoubleValidator {
                                    bottom: 0.0
                                    top: 1000000.0
                                }
                                onTextChanged: {
                                    var val = parseFloat(text)
                                    if (!isNaN(val)) {
                                        cableResistance = val
                                    }
                                }
                            }

                            QC.Label {
                                text: "Ω"
                                font.pixelSize: 13
                                Layout.preferredWidth: 25
                            }
                        }
                    }

                    // Hiệu chỉnh bằng máy đo
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 350
                        color: "#e3f2fd"
                        border.color: "#90caf9"
                        radius: 4

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            QC.Label {
                                text: qsTr("Hiệu chỉnh bằng máy đo")
                                font.bold: true
                                font.pixelSize: 14
                                Layout.fillWidth: true
                            }

                            // Cổng COM
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                QC.Label {
                                    text: qsTr("Cổng COM")
                                    font.pixelSize: 13
                                }

                                QC.ComboBox {
                                    id: comPortCombo
                                    Layout.fillWidth: true
                                    font.pixelSize: 11
                                    padding: 6
                                    model: (function () {
                                        var arr = []
                                        for (var i = 1; i <= 64; i++) {
                                            arr.push("COM" + i)
                                        }
                                        return arr
                                    })()
                                    currentIndex: 2 // COM3 mặc định
                                    onCurrentIndexChanged: {
                                        var portName = model[currentIndex]
                                        keithley2110.portName = portName
                                    }
                                    Component.onCompleted: {
                                        if (model.length > 0) {
                                            keithley2110.portName = model[currentIndex]
                                        }
                                    }
                                }
                            }

                            // Nút mở/đóng cổng COM
                            QC.Button {
                                Layout.fillWidth: true
                                text: keithley2110.isOpen ? qsTr("DISCONNECT") : qsTr(
                                                               "CONNECT")
                                background: Rectangle {
                                    color: keithley2110.isOpen ? "#4caf50" : "#f44336"
                                    radius: 4
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    font.bold: true
                                    font.pixelSize: 13
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: {
                                    if (keithley2110.isOpen) {
                                        keithley2110.closePort()
                                        errorLabel.visible = false
                                    } else {
                                        errorLabel.visible
                                                = false // Ẩn thông báo lỗi cũ trước khi thử mở
                                        if (!keithley2110.openPort()) {
                                            errorLabel.text = qsTr(
                                                        "Không thể mở cổng COM")
                                            errorLabel.visible = true
                                        }
                                        // Nếu mở thành công, errorLabel sẽ được ẩn qua signal onOpenChanged
                                    }
                                }
                            }

                            // Điểm đầu
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                QC.Label {
                                    text: qsTr("Điểm đầu")
                                    font.pixelSize: 13
                                }

                                QC.ComboBox {
                                    id: startPointCombo
                                    Layout.fillWidth: true
                                    font.pixelSize: 13
                                    padding: 8
                                    editable: true
                                    model: calibrationDialog.availableStartPoints.length
                                           > 0 ? calibrationDialog.availableStartPoints : (function () {
                                               var arr = []
                                               for (var i = 1; i <= 128; i++) {
                                                   arr.push("A_" + i)
                                               }
                                               return arr
                                           })()
                                    currentIndex: {
                                        var idx = calibrationDialog.availableStartPoints.indexOf(
                                                    selectedStartPoint)
                                        if (idx < 0
                                                && calibrationDialog.availableStartPoints.length
                                                > 0) {
                                            // Nếu không tìm thấy, thử tìm điểm đầu tiên có cùng số
                                            var match = selectedStartPoint.match(
                                                        /(\d+)/)
                                            if (match) {
                                                var num = parseInt(match[1])
                                                for (var i = 0; i < calibrationDialog.availableStartPoints.length; i++) {
                                                    var pointMatch = calibrationDialog.availableStartPoints[i].match(
                                                                /(\d+)/)
                                                    if (pointMatch && parseInt(
                                                                pointMatch[1]) === num) {
                                                        idx = i
                                                        break
                                                    }
                                                }
                                            }
                                        }
                                        return idx >= 0 ? idx : 0
                                    }
                                    onCurrentIndexChanged: {
                                        if (currentIndex >= 0 && currentIndex
                                                < calibrationDialog.availableStartPoints.length) {
                                            var pointStr = calibrationDialog.availableStartPoints[currentIndex]
                                            selectedStartPoint
                                                    = pointStr // Lưu toàn bộ chuỗi (ví dụ: "B_30")
                                            // Scroll đến dòng tương ứng trong bảng
                                            Qt.callLater(function () {
                                                calibrationDialog.scrollToPoint(
                                                            selectedStartPoint,
                                                            selectedEndPoint)
                                            })
                                        }
                                    }
                                    onAccepted: {
                                        // Khi người dùng nhập tay và nhấn Enter
                                        var text = displayText.trim()
                                        if (text !== "") {
                                            // Parse từ text (ví dụ: "A_50" hoặc "B_50")
                                            var match = text.match(
                                                        /(A|B)[_\s]*(\d+)/i)
                                            if (match && match.length > 2) {
                                                var num = parseInt(match[2])
                                                var pointStr = match[1].toUpperCase(
                                                            ) + "_" + num
                                                // Tìm trong availableStartPoints
                                                var idx = calibrationDialog.availableStartPoints.indexOf(
                                                            pointStr)
                                                if (idx >= 0 && num >= 1
                                                        && num <= 128) {
                                                    selectedStartPoint
                                                            = pointStr // Lưu toàn bộ chuỗi
                                                    currentIndex = idx
                                                    // Scroll đến dòng tương ứng trong bảng
                                                    Qt.callLater(function () {
                                                        calibrationDialog.scrollToPoint(
                                                                    selectedStartPoint,
                                                                    selectedEndPoint)
                                                    })
                                                } else {
                                                    // Giữ nguyên giá trị hiện tại nếu không hợp lệ
                                                    var currentIdx = calibrationDialog.availableStartPoints.indexOf(
                                                                selectedStartPoint)
                                                    currentIndex = currentIdx >= 0 ? currentIdx : 0
                                                }
                                            } else {
                                                // Giữ nguyên giá trị hiện tại nếu không parse được
                                                var currentIdx2 = calibrationDialog.availableStartPoints.indexOf(
                                                            selectedStartPoint)
                                                currentIndex = currentIdx2 >= 0 ? currentIdx2 : 0
                                            }
                                        }
                                    }
                                }
                            }

                            // Điểm cuối
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                QC.Label {
                                    text: qsTr("Điểm cuối")
                                    font.pixelSize: 13
                                }

                                QC.ComboBox {
                                    id: endPointCombo
                                    Layout.fillWidth: true
                                    font.pixelSize: 13
                                    padding: 8
                                    editable: true
                                    model: calibrationDialog.availableEndPoints.length
                                           > 0 ? calibrationDialog.availableEndPoints : (function () {
                                               var arr = []
                                               for (var i = 1; i <= 128; i++) {
                                                   arr.push("B_" + i)
                                               }
                                               return arr
                                           })()
                                    currentIndex: {
                                        var idx = calibrationDialog.availableEndPoints.indexOf(
                                                    selectedEndPoint)
                                        if (idx < 0
                                                && calibrationDialog.availableEndPoints.length
                                                > 0) {
                                            // Nếu không tìm thấy, thử tìm điểm đầu tiên có cùng số
                                            var match = selectedEndPoint.match(
                                                        /(\d+)/)
                                            if (match) {
                                                var num = parseInt(match[1])
                                                for (var i = 0; i < calibrationDialog.availableEndPoints.length; i++) {
                                                    var pointMatch = calibrationDialog.availableEndPoints[i].match(
                                                                /(\d+)/)
                                                    if (pointMatch && parseInt(
                                                                pointMatch[1]) === num) {
                                                        idx = i
                                                        break
                                                    }
                                                }
                                            }
                                        }
                                        return idx >= 0 ? idx : 0
                                    }
                                    onCurrentIndexChanged: {
                                        if (currentIndex >= 0 && currentIndex
                                                < calibrationDialog.availableEndPoints.length) {
                                            var pointStr = calibrationDialog.availableEndPoints[currentIndex]
                                            selectedEndPoint
                                                    = pointStr // Lưu toàn bộ chuỗi (ví dụ: "A_30")
                                            // Scroll đến dòng tương ứng trong bảng
                                            Qt.callLater(function () {
                                                calibrationDialog.scrollToPoint(
                                                            selectedStartPoint,
                                                            selectedEndPoint)
                                            })
                                        }
                                    }
                                    onAccepted: {
                                        // Khi người dùng nhập tay và nhấn Enter
                                        var text = displayText.trim()
                                        if (text !== "") {
                                            // Parse từ text (ví dụ: "A_50" hoặc "B_50")
                                            var match = text.match(
                                                        /(A|B)[_\s]*(\d+)/i)
                                            if (match && match.length > 2) {
                                                var num = parseInt(match[2])
                                                var pointStr = match[1].toUpperCase(
                                                            ) + "_" + num
                                                // Tìm trong availableEndPoints
                                                var idx = calibrationDialog.availableEndPoints.indexOf(
                                                            pointStr)
                                                if (idx >= 0 && num >= 1
                                                        && num <= 128) {
                                                    selectedEndPoint = pointStr // Lưu toàn bộ chuỗi
                                                    currentIndex = idx
                                                    // Scroll đến dòng tương ứng trong bảng
                                                    Qt.callLater(function () {
                                                        calibrationDialog.scrollToPoint(
                                                                    selectedStartPoint,
                                                                    selectedEndPoint)
                                                    })
                                                } else {
                                                    // Giữ nguyên giá trị hiện tại nếu không hợp lệ
                                                    var currentIdx = calibrationDialog.availableEndPoints.indexOf(
                                                                selectedEndPoint)
                                                    currentIndex = currentIdx >= 0 ? currentIdx : 0
                                                }
                                            } else {
                                                // Giữ nguyên giá trị hiện tại nếu không parse được
                                                var currentIdx2 = calibrationDialog.availableEndPoints.indexOf(
                                                            selectedEndPoint)
                                                currentIndex = currentIdx2 >= 0 ? currentIdx2 : 0
                                            }
                                        }
                                    }
                                }
                            }

                            // Điện trở chuẩn
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                QC.Label {
                                    text: qsTr("Điện trở chuẩn")
                                    font.pixelSize: 13
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    QC.TextField {
                                        id: standardResistanceField
                                        Layout.fillWidth: true
                                        text: {
                                            var val = standardResistance
                                            if (val % 1 === 0)
                                                return val.toString()
                                            return val.toFixed(6).replace(
                                                        /\.?0+$/, "")
                                        }
                                        font.pixelSize: 13
                                        padding: 8
                                        validator: DoubleValidator {
                                            bottom: 0.0
                                            top: 1000000.0
                                        }
                                        onTextChanged: {
                                            var val = parseFloat(text)
                                            if (!isNaN(val)) {
                                                standardResistance = val
                                            }
                                        }
                                    }

                                    QC.Label {
                                        text: "Ω"
                                        font.pixelSize: 13
                                        Layout.preferredWidth: 25
                                    }
                                }
                            }

                            // Nút Hiệu chỉnh (gửi MCU bật relay + đọc máy đo)
                            QC.Button {
                                id: calibrateButton
                                Layout.fillWidth: true
                                text: calibrationDialog._calibWaitingMcu ? qsTr("Chờ MCU...") : (keithley2110.isReading ? qsTr("Đang đọc...") : qsTr("Hiệu chỉnh"))
                                enabled: keithley2110.isOpen
                                         && !keithley2110.isReading
                                         && !calibrationDialog._calibWaitingMcu
                                font.pixelSize: 13
                                onClicked: {
                                    errorLabel.visible = false
                                    if (!keithley2110.isOpen) {
                                        errorLabel.text = qsTr(
                                                    "Vui lòng mở cổng COM trước")
                                        errorLabel.visible = true
                                        return
                                    }
                                    // Lấy pin từ điểm đang chọn (A_4 → pinA=4, B_1 → pinB=1)
                                    var startPt = selectedStartPoint // VD: "A_4"
                                    var endPt = selectedEndPoint // VD: "B_1"
                                    var pinA = parseInt(startPt.split(
                                                            "_")[1]) || -1
                                    var pinB = parseInt(endPt.split(
                                                            "_")[1]) || -1

                                    // Gửi bản tin xuống MCU để bật relay cho cặp pin (CMD=0x7B)
                                    console.log("═══ [Calibration] ═══")
                                    console.log("  Điểm:", startPt, "↔", endPt,
                                                "| pinA:", pinA, "pinB:", pinB)
                                    console.log("  → Packet sẽ gửi: 7A 01 01 7B 03 AB",
                                                pinA.toString(16).toUpperCase(
                                                    ).padStart(2, '0'),
                                                pinB.toString(16).toUpperCase(
                                                    ).padStart(2, '0'), "[CRC]")
                                    console.log("  MCU:",
                                                typeof mcuSender !== "undefined"
                                                && mcuSender ? "CÓ" : "NULL",
                                                "| isOpen:",
                                                (typeof mcuSender !== "undefined"
                                                 && mcuSender) ? mcuSender.isOpen : "N/A")

                                    if (typeof mcuSender !== "undefined"
                                            && mcuSender && mcuSender.isOpen
                                            && pinA > 0 && pinB > 0) {
                                        console.log("  → GỬI MCU thành công!")
                                        var scripts = [{
                                                           "scriptType": "wire_resistance",
                                                           "portPinA": pinA,
                                                           "portPinB": pinB,
                                                           "labelA": startPt,
                                                           "pinA": String(pinA),
                                                           "labelB": endPt,
                                                           "pinB": String(pinB)
                                                       }]
                                        calibrationDialog._calibWaitingMcu = true
                                        mcuSender.sendTestScripts(scripts, true)
                                        console.log("  → Đang chờ MCU response (3A 53 BC)...")
                                    } else {
                                        console.log("  → MCU chưa kết nối - đọc Hioki trực tiếp (không relay)")
                                        keithley2110.readResistance()
                                    }
                                    // Giá trị sẽ được nhận qua signal resistanceRead
                                }
                            }

                            QC.Label {
                                id: errorLabel
                                Layout.fillWidth: true
                                visible: false
                                color: "red"
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Chọn mode hiệu chuẩn
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 80
                        color: "#e8f5e9"
                        border.color: "#4caf50"
                        radius: 4

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            QC.Label {
                                text: qsTr("Chọn mode hiệu chuẩn:")
                                font.pixelSize: 13
                                font.bold: true
                                Layout.fillWidth: true
                            }

                            QC.RadioButton {
                                id: calibrationModeRadio
                                checked: true
                                text: qsTr("Điều chỉnh tham số hiệu chuẩn")
                                font.pixelSize: 12
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // Hiển thị đường dẫn file sẽ lưu
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        color: "#fff9c4"
                        border.color: "#f9a825"
                        radius: 4

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 4

                            QC.Label {
                                text: qsTr("File sẽ lưu tại:")
                                font.pixelSize: 12
                                font.bold: true
                                Layout.fillWidth: true
                            }

                            QC.Label {
                                id: filePathLabel
                                Layout.fillWidth: true
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                                text: {
                                    var appDir = fileHelper.applicationDirPath()
                                    return appDir + "/calibration.att"
                                }
                            }
                        }
                    }

                    // Nút Chọn và Lưu lại
                    QC.Button {
                        Layout.fillWidth: true
                        text: qsTr("Chọn và Lưu Lại")
                        highlighted: true
                        font.pixelSize: 14
                        font.bold: true
                        onClicked: {
                            var appDir = fileHelper.applicationDirPath()
                            var filePath = appDir + "/calibration.att"

                            // Lưu mode đã chọn
                            var mode = qsTr("Điều chỉnh tham số hiệu chuẩn")
                            fileHelper.saveCalibrationMode(mode)

                            if (saveToFile(filePath)) {
                                saveSuccessDialog.text = qsTr(
                                            "Đã lưu file thành công!\n\nMode: %1\nĐường dẫn:\n%2").arg(
                                            mode).arg(filePath)
                                saveSuccessDialog.open()
                                // Cập nhật mode ở MainContent
                                if (calibrationDialog.mainContent
                                        && typeof calibrationDialog.mainContent.updateCalibrationMode === "function") {
                                    calibrationDialog.mainContent.updateCalibrationMode()
                                }
                            } else {
                                saveErrorDialog.text = qsTr(
                                            "Lỗi khi lưu file!\n\nĐường dẫn:\n%1").arg(
                                            filePath)
                                saveErrorDialog.open()
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══ ListModel chứa toàn bộ dữ liệu bảng hiệu chuẩn ═══
    // Mỗi item: { stt, startPoint, endPoint, value, chanA, chanB, excelInfo, scriptInfo?, pinA?, pinB? }
    // - stt: số thứ tự (0-based)
    // - startPoint/endPoint: "A_1", "B_2", ... — định danh điểm
    // - value: offset hiệu chuẩn (double, 0 = chưa hiệu chuẩn)
    // - chanA/chanB: thông tin Excel ("J1/Wire1 (pin 3) [R3]")
    // - excelInfo: chuỗi kết hợp chanA + chanB
    // - scriptInfo: object script nếu có (labelA, pinA, labelB, pinB, scriptType)
    ListModel {
        id: calibrationDataModel
    }

    // Dialog thông báo lưu thành công
    QC.Dialog {
        id: saveSuccessDialog
        title: qsTr("Thành công")
        modal: true
        width: 500
        standardButtons: QC.Dialog.Ok

        property string text: ""

        QC.Label {
            anchors.fill: parent
            anchors.margins: 20
            text: saveSuccessDialog.text
            wrapMode: Text.WordWrap
        }
    }

    // Dialog thông báo lỗi
    QC.Dialog {
        id: saveErrorDialog
        title: qsTr("Lỗi")
        modal: true
        width: 500
        standardButtons: QC.Dialog.Ok

        property string text: ""

        QC.Label {
            anchors.fill: parent
            anchors.margins: 20
            text: saveErrorDialog.text
            wrapMode: Text.WordWrap
            color: "red"
        }
    }

    // ═══ Dialog tìm script ═══
    // User nhập labelA, pinA, labelB, pinB → tìm trong bảng → scroll tới dòng đó
    // Dùng hàm findScriptByLabels() để tìm
    QC.Dialog {
        id: findScriptDialog
        title: qsTr("Tìm Script trong Bảng Hiệu Chỉnh")
        modal: true
        width: 600
        standardButtons: QC.Dialog.Ok | QC.Dialog.Cancel

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            QC.Label {
                text: qsTr("Nhập thông tin script để tìm:")
                font.bold: true
                font.pixelSize: 13
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                QC.Label {
                    text: qsTr("Label A:")
                    Layout.preferredWidth: 80
                }
                QC.TextField {
                    id: findLabelAField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Ví dụ: cs")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                QC.Label {
                    text: qsTr("Pin A:")
                    Layout.preferredWidth: 80
                }
                QC.TextField {
                    id: findPinAField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Ví dụ: 4")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                QC.Label {
                    text: qsTr("Label B:")
                    Layout.preferredWidth: 80
                }
                QC.TextField {
                    id: findLabelBField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Ví dụ: HC.X15-R")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                QC.Label {
                    text: qsTr("Pin B:")
                    Layout.preferredWidth: 80
                }
                QC.TextField {
                    id: findPinBField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Ví dụ: R hoặc để trống")
                }
            }

            QC.Label {
                id: findResultLabel
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: "#0066cc"
                font.pixelSize: 12
                visible: false
            }
        }

        onAccepted: {
            var labelA = findLabelAField.text.trim()
            var pinA = findPinAField.text.trim()
            var labelB = findLabelBField.text.trim()
            var pinB = findPinBField.text.trim()

            if (labelA === "" || pinA === "" || labelB === "" || pinB === "") {
                findResultLabel.text = qsTr("Vui lòng nhập đầy đủ thông tin!")
                findResultLabel.color = "red"
                findResultLabel.visible = true
                return
            }

            var result = calibrationDialog.findScriptByLabels(labelA, pinA,
                                                              labelB, pinB)
            if (result) {
                findResultLabel.text = qsTr("Tìm thấy script!\n\n") + qsTr("Điểm đầu: %1\n").arg(
                            result.startPoint) + qsTr(
                            "Điểm cuối: %1\n").arg(result.endPoint) + qsTr("PIN_A: %1\n").arg(
                            result.portPinA) + qsTr(
                            "PIN_B: %1\n").arg(result.portPinB)
                        + qsTr("\nĐang scroll đến dòng này...")
                findResultLabel.color = "#0066cc"
                findResultLabel.visible = true

                // Scroll đến dòng tìm thấy
                Qt.callLater(function () {
                    calibrationDialog.scrollToPoint(result.startPoint,
                                                    result.endPoint)
                })
            } else {
                findResultLabel.text = qsTr(
                            "Không tìm thấy script với thông tin:\n") + qsTr(
                            "Label A: %1, Pin A: %2\n").arg(labelA).arg(
                            pinA) + qsTr("Label B: %1, Pin B: %2").arg(
                            labelB).arg(pinB)
                findResultLabel.color = "red"
                findResultLabel.visible = true
            }
        }

        onRejected: {
            findLabelAField.text = ""
            findPinAField.text = ""
            findLabelBField.text = ""
            findPinBField.text = ""
            findResultLabel.visible = false
        }
    }
}
