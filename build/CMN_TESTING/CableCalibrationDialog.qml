 import QtQuick
import QtQuick.Controls as QC
import QtQuick.Layouts
import QtQuick.Window
import Qt.labs.platform 1.1

// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║ CableCalibrationDialog.qml — Hiệu chuẩn theo cáp đo                       ║
// ║ ────────────────────────────────────────────────────────────────────────────  ║
// ║ Đo hiệu chuẩn ở TẬN CÁP NGOÀI CÙNG → KHÔNG có cableResistance             ║
// ║ Bảng tạo từ dữ liệu Excel (mỗi dòng Excel = 1 điểm hiệu chuẩn)           ║
// ║ SSHT = Hioki_hiệu_chuẩn - R_chuẩn                                          ║
// ║ Data cuối = Hioki_đọc - SSHT                                                ║
// ║ FILE: [appDir]/cable_calibration.att                                        ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
Window {
    id: cableCalibrationDialog
    title: qsTr("Hiệu chuẩn theo cáp đo")
    width: 1100
    height: 700
    visible: false
    modality: Qt.ApplicationModal
    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowMinMaxButtonsHint | Qt.WindowCloseButtonHint

    property Window mainWindow: null
    property var mainContent: null
    transientParent: mainWindow

    property double standardResistance: 0.01
    property int highlightedRowIndex: -1
    property bool _calibWaitingMcu: false

    // ── Dữ liệu Excel (nhận từ Main.qml) ──
    property var excelRows: []
    property var pinNumA: []
    property var pinNumB: []

    // ── ComboBox selection ──
    property var uniqueLabelsA: []
    property var uniqueLabelsB: []
    property string selectedLabelA: ""
    property string selectedLabelB: ""
    property var filteredPinsA: []
    property var filteredPinsB: []
    property int selectedPinIdxA: 0
    property int selectedPinIdxB: 0

    // ═══ Nhận dữ liệu Excel ═══
    function setCableData(tableRows) {
        excelRows = tableRows || []
        console.log("[CableCalib] setCableData received", excelRows.length, "rows")
        if (excelRows.length > 0) {
            console.log("[CableCalib] First row:", JSON.stringify(excelRows[0]))
            console.log("[CableCalib] col0:", _colVal(excelRows[0], 0), "col1:", _colVal(excelRows[0], 1), "col2:", _colVal(excelRows[0], 2),
                        "col3:", _colVal(excelRows[0], 3), "col4:", _colVal(excelRows[0], 4), "col5:", _colVal(excelRows[0], 5))
        }
        _buildPinArrays()
        initializeData()
    }

    function _colVal(row, idx) {
        if (row === null || row === undefined) return ""
        var key = "col" + idx
        if (row[key] !== undefined) return String(row[key])
        if (Array.isArray(row) && idx < row.length) return String(row[idx])
        return ""
    }

    function _getStartIdx() {
        if (excelRows.length > 0) {
            var fp = _colVal(excelRows[0], 2)
            if (fp !== "" && isNaN(Number(fp))) return 1
            fp = _colVal(excelRows[0], 5)
            if (fp !== "" && isNaN(Number(fp))) return 1
        }
        return 0
    }

    function _buildPinArrays() {
        var nA = [], nB = []
        var si = _getStartIdx()
        for (var i = si; i < excelRows.length; i++) {
            nA.push(_colVal(excelRows[i], 2))
            nB.push(_colVal(excelRows[i], 5))
        }
        pinNumA = nA
        pinNumB = nB
    }

    // ═══ Mở / Reload ═══
    function open() {
        initializeData()
        loadFromFile()
        show()
    }

    // Tự động reload khi dialog hiện lên (ví dụ khi quay lại từ chỉnh sửa bài đo)
    onVisibleChanged: {
        if (visible) {
            initializeData()
            loadFromFile()
        }
    }

    function reloadCalibrationTable() {
        initializeData()
        loadFromFile()
    }

    // ═══ Khởi tạo bảng: LUÔN lấy 100% từ Excel + Bổ sung dòng MỚI từ Test Plan ═══
    function initializeData() {
        cableCalibrationDataModel.clear()
        var labA = {}, labB = {}

        // 1. Dựng bảng 100% từ file Excel (giữ nguyên format Nhãn điểm đầu / Điểm đầu / Nhãn điểm cuối / Điểm cuối)
        var si = _getStartIdx()
        var count = 0
        // Dùng Set để track các dòng đã có trong Excel (labelA|nameA|labelB|nameB)
        var existingRows = {}
        for (var i = si; i < excelRows.length; i++) {
            var row = excelRows[i]
            var labelA_ex = _colVal(row, 0)
            var nameA_ex  = _colVal(row, 1)
            var pinA_ex   = _colVal(row, 2)
            var labelB_ex = _colVal(row, 3)
            var nameB_ex  = _colVal(row, 4)
            var pinB_ex   = _colVal(row, 5)

            if (labelA_ex) labA[labelA_ex] = true
            if (labelB_ex) labB[labelB_ex] = true

            cableCalibrationDataModel.append({
                "stt": count,
                "labelA": labelA_ex, "nameA": nameA_ex, "portPinA": Number(pinA_ex) || 0,
                "labelB": labelB_ex, "nameB": nameB_ex, "portPinB": Number(pinB_ex) || 0,
                "value": 0.0
            })
            existingRows[labelA_ex + "||" + nameA_ex + "||" + labelB_ex + "||" + nameB_ex] = true
            count++
        }

        // 2. Quét Test Plan: nếu có dòng wire_resistance nào mà CHƯA CÓ trong Excel → bổ sung thêm
        var planName = ""
        if (cableCalibrationDialog.mainContent && cableCalibrationDialog.mainContent.currentPlanName) {
            planName = cableCalibrationDialog.mainContent.currentPlanName
        }

        if (planName && typeof testPlanManager !== "undefined" && testPlanManager) {
            var scripts = testPlanManager.loadScripts(planName) || []
            for (var k = 0; k < scripts.length; k++) {
                var script = scripts[k]
                var st = String(script.scriptType || "")
                if (st === "wire_resistance") {
                    var slA = String(script.labelA !== undefined ? script.labelA : "")
                    var snA = String(script.pinA || "")
                    var spA = script.portPinA !== undefined ? Number(script.portPinA) : 0
                    var slB = String(script.labelB !== undefined ? script.labelB : "")
                    var snB = String(script.pinB || "")
                    var spB = script.portPinB !== undefined ? Number(script.portPinB) : 0

                    if (slA === "" && slB === "") continue

                    var rowKey = slA + "||" + snA + "||" + slB + "||" + snB
                    if (!existingRows[rowKey]) {
                        // Dòng MỚI từ test plan, chưa có trong Excel → thêm vào bảng hiệu chuẩn
                        if (slA) labA[slA] = true
                        if (slB) labB[slB] = true
                        cableCalibrationDataModel.append({
                            "stt": count,
                            "labelA": slA, "nameA": snA, "portPinA": spA,
                            "labelB": slB, "nameB": snB, "portPinB": spB,
                            "value": 0.0
                        })
                        existingRows[rowKey] = true
                        count++
                    }
                }
            }
        }

        uniqueLabelsA = Object.keys(labA).sort()
        uniqueLabelsB = Object.keys(labB).sort()
        if (uniqueLabelsA.length > 0 && !selectedLabelA) selectedLabelA = uniqueLabelsA[0]
        if (uniqueLabelsB.length > 0 && !selectedLabelB) selectedLabelB = uniqueLabelsB[0]
        _updateFilteredPins()
        console.log("[CableCalib] initializeData completed:", cableCalibrationDataModel.count, "rows (Excel:", (count - 0), "+ new from scripts)")
    }

    function _updateFilteredPins() {
        var pA = {}, pB = {}
        for (var i = 0; i < cableCalibrationDataModel.count; i++) {
            var it = cableCalibrationDataModel.get(i)
            if (it.labelA === selectedLabelA) pA[it.nameA] = true
            if (it.labelB === selectedLabelB) pB[it.nameB] = true
        }
        filteredPinsA = Object.keys(pA).sort(function(a,b){ return Number(a)-Number(b) })
        filteredPinsB = Object.keys(pB).sort(function(a,b){ return Number(a)-Number(b) })
        if (selectedPinIdxA >= filteredPinsA.length) selectedPinIdxA = 0
        if (selectedPinIdxB >= filteredPinsB.length) selectedPinIdxB = 0
    }

    function _findSelectedRow() {
        if (highlightedRowIndex >= 0 && highlightedRowIndex < cableCalibrationDataModel.count) {
            return { index: highlightedRowIndex, item: cableCalibrationDataModel.get(highlightedRowIndex) }
        }
        return null
    }

    function scrollToRow(idx) {
        if (idx >= 0 && idx < cableCalibrationDataModel.count) {
            highlightedRowIndex = idx
            cableCalibrationTableView.positionViewAtIndex(idx, ListView.Center)
        }
    }

    // ═══ Lưu / Load file cable_calibration.att ═══
    // Format: tab-separated. Dòng 1 = header (không có cableResistance)
    function saveToFile(filePath) {
        if (typeof window !== "undefined") window.addLog("Hiệu chuẩn", "Lưu file hiệu chuẩn cáp: " + filePath)
        var content = "0\t" + standardResistance.toFixed(6) + "\t0\t0\n"
        for (var i = 0; i < cableCalibrationDataModel.count; i++) {
            var it = cableCalibrationDataModel.get(i)
            content += (it.stt+1) + "\t" + it.labelA + "\t" + it.nameA + "\t" + it.portPinA +
                       "\t" + it.labelB + "\t" + it.nameB + "\t" + it.portPinB + "\t" + it.value.toFixed(6) + "\n"
        }
        return fileHelper.writeTextFile(filePath, content)
    }

    function loadFromFile() {
        var appDir = fileHelper.applicationDirPath()
        var filePath = appDir + "/cable_calibration.att"
        if (!fileHelper.fileExists(filePath)) return

        var content = fileHelper.readTextFile(filePath)
        if (!content || content.trim() === "") return
        var lines = content.split("\n")

        if (lines.length > 0) {
            var hp = lines[0].trim().split(/\t/)
            if (hp.length >= 2) {
                var sr = parseFloat(hp[1])
                if (!isNaN(sr) && sr > 0) standardResistance = sr
            }
        }

        var isEmpty = (cableCalibrationDataModel.count === 0)
        var labA = {}
        var labB = {}
        var vmap = {}

        for (var i = 1; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line === "") continue
            var p = line.split("\t")
            if (p.length >= 8) {
                var val = parseFloat(p[7])
                if (isEmpty) {
                    var labelA = p[1], nameA = p[2], pinA = p[3]
                    var labelB = p[4], nameB = p[5], pinB = p[6]
                    labA[labelA] = true
                    labB[labelB] = true
                    cableCalibrationDataModel.append({
                        "stt": i - 1,
                        "labelA": labelA, "nameA": nameA, "portPinA": Number(pinA) || 0,
                        "labelB": labelB, "nameB": nameB, "portPinB": Number(pinB) || 0,
                        "value": isNaN(val) ? 0.0 : val
                    })
                } else {
                    if (!isNaN(val) && val !== 0)
                        vmap[p[1] + "\t" + p[2] + "\t" + p[4] + "\t" + p[5]] = val
                }
            }
        }

        if (isEmpty) {
            uniqueLabelsA = Object.keys(labA).sort()
            uniqueLabelsB = Object.keys(labB).sort()
            if (uniqueLabelsA.length > 0 && !selectedLabelA) selectedLabelA = uniqueLabelsA[0]
            if (uniqueLabelsB.length > 0 && !selectedLabelB) selectedLabelB = uniqueLabelsB[0]
            _updateFilteredPins()
            console.log("[CableCalib] loadFromFile (fallback): Populated", cableCalibrationDataModel.count, "rows from file")
        } else {
            var cnt = 0
            for (var j = 0; j < cableCalibrationDataModel.count; j++) {
                var it = cableCalibrationDataModel.get(j)
                var key = it.labelA + "\t" + it.nameA + "\t" + it.labelB + "\t" + it.nameB
                if (vmap[key] !== undefined) {
                    cableCalibrationDataModel.setProperty(j, "value", vmap[key])
                    cnt++
                }
            }
            console.log("[CableCalib] loadFromFile:", cnt, "values loaded")
        }
    }

    // ═══ API tra cứu offset — cho MainContent ═══
    function getCalibrationOffset(portPinA, portPinB, scriptType) {
        // Tab này chỉ hiệu chuẩn wire_resistance/continuity
        if (scriptType !== "wire_resistance" && scriptType !== "continuity") {
            return { offset: 0, calibKey: "" }
        }
        
        var foundOffset = 0.0;
        var foundKey = "";

        for (var i = 0; i < cableCalibrationDataModel.count; i++) {
            var it = cableCalibrationDataModel.get(i)
            var a = parseInt(it.portPinA)
            var b = parseInt(it.portPinB)
            var val = parseFloat(it.value)
            
            // Tìm khớp cả 2 chiều: A=A & B=B HOẶC A=B & B=A (vì điện trở đo không phân biệt cực)
            if ((a === portPinA && b === portPinB) || (a === portPinB && b === portPinA)) {
                if (val !== 0) {
                    return { offset: val, calibKey: it.labelA + "_" + it.nameA + " ↔ " + it.labelB + "_" + it.nameB }
                } else {
                    // Nếu giá trị bù trừ bằng 0, vẫn ghi nhận tìm thấy nhưng offset = 0
                    foundOffset = 0;
                    foundKey = it.labelA + "_" + it.nameA + " ↔ " + it.labelB + "_" + it.nameB;
                }
            }
        }
        
        return { offset: foundOffset, calibKey: foundKey }
    }

    Component.onCompleted: {
        initializeData()
        loadFromFile()
    }

    // ═══ Nhận kết quả đo từ Hioki RM3544 ═══
    Connections {
        target: keithley2110
        function onResistanceRead(value) {
            // SSHT = Hioki - R_chuẩn (KHÔNG có cableResistance)
            var ssht = value - standardResistance
            var row = cableCalibrationDialog._findSelectedRow()
            if (row) {
                cableCalibrationDataModel.setProperty(row.index, "value", ssht)
                cableCalibrationDialog.scrollToRow(row.index)
                console.log("[CableCalib] SSHT =", value, "-", standardResistance, "=", ssht,
                            "→", row.item.labelA, row.item.nameA, "↔", row.item.labelB, row.item.nameB)
            }
        }
        function onErrorOccurred(error) { errorLabel.text = error; errorLabel.visible = true }
        function onOpenChanged() { if (keithley2110.isOpen) errorLabel.visible = false }
    }

    // ═══ Nhận tín hiệu MCU (relay bật xong → đọc máy đo) ═══
    Connections {
        target: typeof mcuSender !== "undefined" ? mcuSender : null
        enabled: cableCalibrationDialog._calibWaitingMcu
        function onMcuCalibrationReady() {
            if (cableCalibrationDialog._calibWaitingMcu) {
                cableCalibrationDialog._calibWaitingMcu = false
                console.log("[CableCalib] MCU sẵn sàng (0xBC) - đọc RM3544")
                keithley2110.readResistance()
            }
        }
    } 

    // ╔══════════════════════════════════════════════════════════════╗
    // ║ UI LAYOUT                                                    ║
    // ╚══════════════════════════════════════════════════════════════╝
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // Tiêu đề
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            QC.Label { text: qsTr("Hiệu chuẩn theo cáp đo"); font.bold: true; font.pixelSize: 18; Layout.fillWidth: true }
            QC.Button { text: qsTr("Reload"); font.pixelSize: 12; onClicked: cableCalibrationDialog.reloadCalibrationTable() }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // ── BẢNG DỮ LIỆU HIỆU CHỈNH (trái) ──
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#ffffff"; border.color: "#d0d0d0"; radius: 4

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    // === HEADER: TÊN BẢNG HIỆU CHỈNH ===
                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        color: "#f5f5f5"
                        border.color: "#ccc"
                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Dữ liệu hiệu chỉnh hiện tại")
                            font.pixelSize: 20
                            font.bold: true
                            color: "#333"
                        }
                    }

                    // Header bảng: Nhãn điểm đầu | Điểm đầu | Nhãn điểm cuối | Điểm cuối | Giá Trị
                    Row {
                        Layout.fillWidth: true
                        spacing: 0
                        property real cw: width / 5
                        Rectangle { width: parent.cw; height: 30; color: "#bbdefb"; border.color: "#c0c0c0"
                            Text { anchors.fill: parent; anchors.margins: 4; text: qsTr("Nhãn điểm đầu"); font.bold: true; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter } }
                        Rectangle { width: parent.cw; height: 30; color: "#f5f5f5"; border.color: "#c0c0c0"
                            Text { anchors.fill: parent; anchors.margins: 4; text: qsTr("Điểm đầu"); font.bold: true; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter } }
                        Rectangle { width: parent.cw; height: 30; color: "#f5f5f5"; border.color: "#c0c0c0"
                            Text { anchors.fill: parent; anchors.margins: 4; text: qsTr("Nhãn điểm cuối"); font.bold: true; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter } }
                        Rectangle { width: parent.cw; height: 30; color: "#f5f5f5"; border.color: "#c0c0c0"
                            Text { anchors.fill: parent; anchors.margins: 4; text: qsTr("Điểm cuối"); font.bold: true; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter } }
                        Rectangle { width: parent.cw; height: 30; color: "#f5f5f5"; border.color: "#c0c0c0"
                            Text { anchors.fill: parent; anchors.margins: 4; text: qsTr("Giá Trị"); font.bold: true; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter } }
                    }

                    QC.ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        QC.ScrollBar.vertical.policy: QC.ScrollBar.AsNeeded

                        ListView {
                            id: cableCalibrationTableView
                            width: Math.max(parent.width, 600)
                            model: cableCalibrationDataModel

                            delegate: Rectangle {
                                width: cableCalibrationTableView.width
                                height: 28
                                property color rowBg: {
                                    if (index === cableCalibrationDialog.highlightedRowIndex) return "#1976d2"
                                    return index % 2 === 0 ? "#ffffff" : "#f0f0f0"
                                }
                                color: rowBg
                                property color textColor: index === cableCalibrationDialog.highlightedRowIndex ? "white" : "black"

                                // Hàm helper: highlight dòng + cập nhật ComboBox selection + focus ô giá trị
                                function _selectThisRow() {
                                    selectedLabelA = model.labelA
                                    selectedLabelB = model.labelB
                                    _updateFilteredPins()
                                    var idxA = filteredPinsA.indexOf(model.nameA)
                                    if (idxA >= 0) selectedPinIdxA = idxA
                                    var idxB = filteredPinsB.indexOf(model.nameB)
                                    if (idxB >= 0) selectedPinIdxB = idxB
                                    cableCalibrationDialog.scrollToRow(index)
                                }

                                Row {
                                    width: parent.width
                                    spacing: 0
                                    property real cw: width / 5
                                    // Nhãn điểm đầu (labelA)
                                    Rectangle { width: parent.cw; height: 28; border.color: "#e0e0e0"; color: "transparent"
                                        Text { anchors.fill: parent; anchors.margins: 4; text: model.labelA; color: textColor
                                            verticalAlignment: Text.AlignVCenter; font.pixelSize: 12; font.bold: false; elide: Text.ElideRight }
                                        MouseArea { anchors.fill: parent; onClicked: { _selectThisRow(); cableValueField.forceActiveFocus(); cableValueField.selectAll() } }
                                    }
                                    // Điểm đầu (nameA)
                                    Rectangle { width: parent.cw; height: 28; border.color: "#e0e0e0"; color: "transparent"
                                        Text { anchors.fill: parent; anchors.margins: 4; text: model.nameA; color: textColor
                                            verticalAlignment: Text.AlignVCenter; font.pixelSize: 12; font.bold: true }
                                        MouseArea { anchors.fill: parent; onClicked: { _selectThisRow(); cableValueField.forceActiveFocus(); cableValueField.selectAll() } }
                                    }
                                    // Nhãn điểm cuối (labelB)
                                    Rectangle { width: parent.cw; height: 28; border.color: "#e0e0e0"; color: "transparent"
                                        Text { anchors.fill: parent; anchors.margins: 4; text: model.labelB; color: textColor
                                            verticalAlignment: Text.AlignVCenter; font.pixelSize: 12; font.bold: false; elide: Text.ElideRight }
                                        MouseArea { anchors.fill: parent; onClicked: { _selectThisRow(); cableValueField.forceActiveFocus(); cableValueField.selectAll() } }
                                    }
                                    // Điểm cuối (nameB)
                                    Rectangle { width: parent.cw; height: 28; border.color: "#e0e0e0"; color: "transparent"
                                        Text { anchors.fill: parent; anchors.margins: 4; text: model.nameB; color: textColor
                                            verticalAlignment: Text.AlignVCenter; font.pixelSize: 12; font.bold: true }
                                        MouseArea { anchors.fill: parent; onClicked: { _selectThisRow(); cableValueField.forceActiveFocus(); cableValueField.selectAll() } }
                                    }
                                    // Giá trị (sai số) — TextField để user có thể sửa trực tiếp
                                    Rectangle { width: parent.cw; height: 28; border.color: "#e0e0e0"; color: "transparent"
                                        QC.TextField {
                                            id: cableValueField
                                            anchors.fill: parent; anchors.margins: 1
                                            text: {
                                                if (model.value === undefined) return "0"
                                                if (model.value === 0.0 || model.value === 0) return ""
                                                var val = Number(model.value)
                                                if (val % 1 === 0) return val.toString()
                                                return val.toFixed(6).replace(/\.?0+$/, "")
                                            }
                                            selectByMouse: true
                                            font.pixelSize: 12; font.bold: true; padding: 3
                                            color: textColor
                                            background: Rectangle { color: "transparent" }
                                            validator: DoubleValidator { bottom: -1000000.0; top: 1000000.0 }
                                            // Khi click vào ô giá trị → cũng highlight dòng
                                            onActiveFocusChanged: {
                                                if (activeFocus) {
                                                    _selectThisRow()
                                                }
                                            }
                                            onEditingFinished: {
                                                var val = parseFloat(text)
                                                var newVal = !isNaN(val) ? val : 0.0
                                                if (model.value !== newVal) {
                                                    cableCalibrationDataModel.setProperty(index, "value", newVal)
                                                }
                                            }
                                            onFocusChanged: {
                                                if (!focus) {
                                                    var val = parseFloat(text)
                                                    var newVal = !isNaN(val) ? val : 0.0
                                                    if (model.value !== newVal) {
                                                        cableCalibrationDataModel.setProperty(index, "value", newVal)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── PANEL ĐIỀU KHIỂN (phải, 360px) ──
            Rectangle {
                Layout.preferredWidth: 360
                Layout.fillHeight: true
                color: "#f5f5f5"; border.color: "#d0d0d0"; radius: 4

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    // Panel hiệu chỉnh bằng máy đo
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "#e3f2fd"; border.color: "#90caf9"; radius: 4

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            QC.Label { text: qsTr("Hiệu chỉnh bằng máy đo"); font.bold: true; font.pixelSize: 14 }

                            // Cổng COM
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 3
                                QC.Label { text: qsTr("Cổng COM"); font.pixelSize: 13 }
                                QC.ComboBox {
                                    id: comPortCombo; Layout.fillWidth: true; font.pixelSize: 11; padding: 6
                                    model: (function() { var a=[]; for(var i=1;i<=64;i++) a.push("COM"+i); return a })()
                                    currentIndex: 2
                                    onCurrentIndexChanged: keithley2110.portName = model[currentIndex]
                                    Component.onCompleted: { if(model.length>0) keithley2110.portName = model[currentIndex] }
                                }
                            }

                            // Nút Connect
                            QC.Button {
                                Layout.fillWidth: true
                                text: keithley2110.isOpen ? qsTr("DISCONNECT") : qsTr("CONNECT")
                                background: Rectangle { color: keithley2110.isOpen ? "#4caf50" : "#f44336"; radius: 4 }
                                contentItem: Text { text: parent.text; color: "white"; font.bold: true; font.pixelSize: 13
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: {
                                    if (keithley2110.isOpen) { keithley2110.closePort(); errorLabel.visible = false }
                                    else { errorLabel.visible = false; if (!keithley2110.openPort()) { errorLabel.text = qsTr("Không thể mở cổng COM"); errorLabel.visible = true } }
                                }
                            }

                            // Hiển thị thông tin dòng đang chọn
                            Rectangle {
                                id: selectedInfoCard
                                Layout.fillWidth: true
                                height: 110
                                color: "#ffffff"
                                border.color: "#bbdefb"
                                border.width: 1
                                radius: 6
                                
                                property var currentRow: cableCalibrationDialog.highlightedRowIndex >= 0 ? cableCalibrationDataModel.get(cableCalibrationDialog.highlightedRowIndex) : null

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    QC.Label {
                                        text: selectedInfoCard.currentRow ? qsTr("Điểm đang chọn:") : qsTr("Chưa chọn điểm nào")
                                        font.bold: true
                                        font.pixelSize: 13
                                        color: "#424242"
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 12
                                        visible: selectedInfoCard.currentRow !== null
                                        
                                        // Điểm đầu
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            color: "#e3f2fd" // light blue
                                            radius: 4
                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 4
                                                QC.Label { text: selectedInfoCard.currentRow ? selectedInfoCard.currentRow.labelA : ""; font.bold: true; font.pixelSize: 14; color: "#1565c0"; Layout.alignment: Qt.AlignHCenter; elide: Text.ElideRight }
                                                QC.Label { text: selectedInfoCard.currentRow ? selectedInfoCard.currentRow.nameA : ""; font.pixelSize: 14; Layout.alignment: Qt.AlignHCenter }
                                            }
                                        }
                                        
                                        QC.Label { text: "↔"; font.bold: true; font.pixelSize: 22; color: "#9e9e9e" }
                                        
                                        // Điểm cuối
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            color: "#e8f5e9" // light green
                                            radius: 4
                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 4
                                                QC.Label { text: selectedInfoCard.currentRow ? selectedInfoCard.currentRow.labelB : ""; font.bold: true; font.pixelSize: 14; color: "#2e7d32"; Layout.alignment: Qt.AlignHCenter; elide: Text.ElideRight }
                                                QC.Label { text: selectedInfoCard.currentRow ? selectedInfoCard.currentRow.nameB : ""; font.pixelSize: 14; Layout.alignment: Qt.AlignHCenter }
                                            }
                                        }
                                    }
                                }
                            }

                            // Điện trở chuẩn
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 3
                                QC.Label { text: qsTr("Điện trở chuẩn"); font.pixelSize: 13 }
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 4
                                    QC.TextField {
                                        id: standardResistanceField; Layout.fillWidth: true; font.pixelSize: 13; padding: 8
                                        text: { var v=standardResistance; return v%1===0?v.toString():v.toFixed(6).replace(/\.?0+$/,"") }
                                        validator: DoubleValidator { bottom: 0; top: 1000000 }
                                        onTextChanged: { var v=parseFloat(text); if(!isNaN(v)) standardResistance=v }
                                    }
                                    QC.Label { text: "Ω"; font.pixelSize: 13; Layout.preferredWidth: 25 }
                                }
                            }

                            // Nút Hiệu chỉnh
                            QC.Button {
                                id: calibrateButton; Layout.fillWidth: true
                                text: cableCalibrationDialog._calibWaitingMcu ? qsTr("Chờ MCU...")
                                    : (keithley2110.isReading ? qsTr("Đang đọc...") : qsTr("Hiệu chỉnh"))
                                enabled: keithley2110.isOpen && !keithley2110.isReading && !cableCalibrationDialog._calibWaitingMcu
                                font.pixelSize: 13
                                onClicked: {
                                    errorLabel.visible = false
                                    if (!keithley2110.isOpen) { errorLabel.text = qsTr("Vui lòng mở cổng COM trước"); errorLabel.visible = true; return }

                                    var row = cableCalibrationDialog._findSelectedRow()
                                    if (!row) { errorLabel.text = qsTr("Không tìm thấy điểm đo phù hợp"); errorLabel.visible = true; return }

                                    var pinA = row.item.portPinA  // Chân đo cổng A (col2 Excel)
                                    var pinB = row.item.portPinB  // Chân đo cổng B (col5 Excel)

                                    console.log("═══ [CableCalib] ═══")
                                    console.log("  Nhãn:", row.item.labelA, "↔", row.item.labelB)
                                    console.log("  Chân:", row.item.nameA, "↔", row.item.nameB)
                                    console.log("  MCU pin:", pinA, "↔", pinB)

                                    if (typeof mcuSender !== "undefined" && mcuSender && mcuSender.isOpen && pinA > 0 && pinB > 0) {
                                        var startPt = "A_" + pinA
                                        var endPt = "B_" + pinB
                                        var scripts = [{ scriptType: "wire_resistance", portPinA: pinA, portPinB: pinB,
                                                         labelA: startPt, pinA: String(pinA), labelB: endPt, pinB: String(pinB) }]
                                        cableCalibrationDialog._calibWaitingMcu = true
                                        mcuSender.sendTestScripts(scripts, true)
                                    } else {
                                        console.log("  → MCU chưa kết nối - đọc RM3544 trực tiếp")
                                        keithley2110.readResistance()
                                    }
                                }
                            }

                            QC.Label { id: errorLabel; Layout.fillWidth: true; visible: false; color: "red"; font.pixelSize: 12; wrapMode: Text.WordWrap }
                        }
                    }

                    // Mode hiệu chuẩn
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 80
                        color: "#e8f5e9"; border.color: "#4caf50"; radius: 4
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 8; spacing: 6
                            QC.Label { text: qsTr("Chọn mode hiệu chuẩn:"); font.pixelSize: 13; font.bold: true }
                            QC.RadioButton { id: cableCalibrationModeRadio; checked: true; text: qsTr("Hiệu chuẩn theo cáp đo"); font.pixelSize: 12 }
                        }
                    }

                    // Đường dẫn file
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 60
                        color: "#fff9c4"; border.color: "#f9a825"; radius: 4
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 8; spacing: 4
                            QC.Label { text: qsTr("File sẽ lưu tại:"); font.pixelSize: 12; font.bold: true }
                            QC.Label { id: filePathLabel; Layout.fillWidth: true; font.pixelSize: 11; wrapMode: Text.WordWrap
                                text: fileHelper.applicationDirPath() + "/cable_calibration.att" }
                        }
                    }

                    // Nút Lưu
                    QC.Button {
                        Layout.fillWidth: true; text: qsTr("Chọn và Lưu Lại"); highlighted: true; font.pixelSize: 14; font.bold: true
                        onClicked: {
                            var filePath = fileHelper.applicationDirPath() + "/cable_calibration.att"
                            var mode = qsTr("Hiệu chuẩn theo cáp đo")
                            fileHelper.saveCalibrationMode(mode)
                            if (saveToFile(filePath)) {
                                saveSuccessDialog.text = qsTr("Đã lưu file thành công!\n\nMode: %1\nĐường dẫn:\n%2").arg(mode).arg(filePath)
                                saveSuccessDialog.open()
                                if (cableCalibrationDialog.mainContent && typeof cableCalibrationDialog.mainContent.updateCalibrationMode === "function")
                                    cableCalibrationDialog.mainContent.updateCalibrationMode()
                            } else {
                                saveErrorDialog.text = qsTr("Lỗi khi lưu file!\n\nĐường dẫn:\n%1").arg(filePath)
                                saveErrorDialog.open()
                            }
                        }
                    }
                }
            }
        }
    }

    ListModel { id: cableCalibrationDataModel }

    QC.Dialog {
        id: saveSuccessDialog; title: qsTr("Thành công"); modal: true; width: 500; standardButtons: QC.Dialog.Ok
        property string text: ""
        QC.Label { anchors.fill: parent; anchors.margins: 20; text: saveSuccessDialog.text; wrapMode: Text.WordWrap }
    }

    QC.Dialog {
        id: saveErrorDialog; title: qsTr("Lỗi"); modal: true; width: 500; standardButtons: QC.Dialog.Ok
        property string text: ""
        QC.Label { anchors.fill: parent; anchors.margins: 20; text: saveErrorDialog.text; wrapMode: Text.WordWrap; color: "red" }
    }
}
