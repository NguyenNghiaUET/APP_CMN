import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    anchors.fill: parent

    property string currentPlanName: ""
    property string calibrationMode: ""
    property var mainContent: null
    property int _selectedIndex: -1
    property string _statusText: ""
    property string snValue: "DEFAULTSN0001"
    property string _lastManualExcelPath: ""
    
    property int _checkAllOverride: -1  // -1=theo model, 0=ép bỏ tick hết, 1=ép tick hết
    property bool _isTesting: false
    property var _testQueue: []
    property int _currentTestIndex: 0
    property int _manualTestState: 0 // 0: Idle, 1: Gửi lệnh, 2: Chờ đóng Relay, 3: Đọc máy đo
    property int _autoTestState: 0

    property string testStartTime: ""
    property string testEndTime: ""

    onCurrentPlanNameChanged: loadPlanIntoManualList(currentPlanName)

    function isMeasurable(scriptType) {
        var t = String(scriptType || "")
        return t === "continuity" || t === "sheath_insulation"
    }

    function isHeader(scriptType) {
        return String(scriptType || "").indexOf("_header") >= 0
    }

    function formatLimit(scriptType, value, upper) {
        var t = String(scriptType || "")
        if (t === "notification" || t === "system_init" || t.indexOf("_header") >= 0) return ""
        if (value === undefined || value === null || String(value) === "") return upper ? "NA" : "—"
        var n = Number(value)
        if (isNaN(n)) return "—"
        if (t === "continuity") {
            if (!upper) return "NA"
            if (n >= 999999) return "NA"
            if (n >= 1000) return "≤ " + (n / 1000).toFixed(3) + " kΩ"
            return "≤ " + (n % 1 === 0 ? String(n) : n.toFixed(3)) + " Ω"
        }
        if (t === "sheath_insulation") {
            if (upper) return "NA"
            if (n <= 0) return "NA"
            if (n >= 1000) return "≥ " + (n / 1000).toFixed(1) + " kΩ"
            return "≥ " + (n % 1 === 0 ? String(n) : n.toFixed(1)) + " Ω"
        }
        return String(n)
    }

    function formatMeasuredValue(scriptType, val) {
        var v = Number(val)
        if (isNaN(v) || val === "" || val === undefined) return ""
        var t = String(scriptType || "")
        return v.toFixed(4) + " Ω"
    }

    // === Xuất kết quả đo thủ công ra Excel ===
    function exportManualToExcel() {
        if (manualListModel.count === 0) return
        _syncCheckAllToModel()

        var realEndTime = root.testEndTime || ""
        if (!realEndTime) {
            for (var m = 0; m < manualListModel.count; m++) {
                var tm = manualListModel.get(m).measureTime;
                if (tm) realEndTime = tm; 
            }
        }
        if (!realEndTime) realEndTime = new Date().toLocaleString("en-US")

        var stationInfo = { 
            serialNumber: snValue, 
            startTime: root.testStartTime || new Date().toLocaleString("en-US"),
            endTime: realEndTime
        }
        if (typeof fileHelper !== "undefined" && fileHelper) {
            var cfgStr = fileHelper.loadStationConfig()
            if (cfgStr) {
                try {
                    var cfg = JSON.parse(cfgStr)
                    stationInfo.stationName = cfg.stationName || ""
                    stationInfo.companyName = cfg.companyName || ""
                } catch(e) {}
            }
        }

        var results = []
        var passCount = 0, failCount = 0
        for (var i = 0; i < manualListModel.count; i++) {
            var item = manualListModel.get(i)
            var t = String(item.scriptType || "")
            if (item.isHeader) continue
            var result = String(item.resultStatus || "")
            
            if (result === "PASS") passCount++
            else if (result === "FAIL") failCount++

            results.push({
                displayText: String(item.displayText || ""),
                scriptType: t,
                limitLower: formatLimit(t, item.limitLower, false),
                limitUpper: formatLimit(t, item.limitUpper, true),
                measuredValue: item.measuredValue !== undefined ? formatMeasuredValue(t, item.measuredValue) : "",
                measureTime: String(item.measureTime || ""),
                result: result
            })
        }

        var now = new Date()
        var dateStr = now.getFullYear() + "" +
            String(now.getMonth() + 1).padStart(2, "0") +
            String(now.getDate()).padStart(2, "0") + "_" +
            String(now.getHours()).padStart(2, "0") +
            String(now.getMinutes()).padStart(2, "0") +
            String(now.getSeconds()).padStart(2, "0")
        var sn = snValue || "NoSN"
        var defaultName = sn + "_Manual_" + (currentPlanName || "test") + "_" + dateStr + ".xlsx"

        var savePath = ""
        if (typeof fileHelper !== "undefined" && fileHelper) {
            var cfgStr2 = fileHelper.loadStationConfig()
            if (cfgStr2) {
                try { savePath = JSON.parse(cfgStr2).logPath || "" } catch(e2) {}
            }
            if (!savePath) savePath = fileHelper.applicationDirPath() + "/results"
        }
        var filePath = savePath + "/" + defaultName
        var stationJson = JSON.stringify(stationInfo)
        var resultsJson = JSON.stringify(results)

        if (typeof fileHelper !== "undefined" && fileHelper) {
            var ok = fileHelper.exportExcel(filePath, stationJson, resultsJson)
            if (ok) {
                root._lastManualExcelPath = filePath
                manualExcelDialog.excelFileName = defaultName
                manualExcelDialog.open()
            } else {
                manualExcelErrorDialog.open()
            }
        }
    }

    function selectedItem() {
        if (_selectedIndex < 0 || _selectedIndex >= manualListModel.count) return null
        return manualListModel.get(_selectedIndex)
    }

    function toggleExpand(index) {
        var hdr = manualListModel.get(index)
        if (!hdr || !hdr.isHeader) return
        var newExp = !hdr.expanded
        manualListModel.setProperty(index, "expanded", newExp)
        for (var i = index + 1; i < manualListModel.count; i++) {
            var item = manualListModel.get(i)
            if (item.isHeader) break
            manualListModel.setProperty(i, "hidden", !newExp)
            if (i < rightTableModel.count) rightTableModel.setProperty(i, "hidden", !newExp)
        }
    } 

    function loadPlanIntoManualList(planName) {
        manualListModel.clear()
        rightTableModel.clear()
        _selectedIndex = -1
        if (!planName || typeof testPlanManager === "undefined" || !testPlanManager) return
        var scripts = testPlanManager.loadScripts(planName) || []
        var currentExpanded = true
        for (var i = 0; i < scripts.length; i++) {
            var s = scripts[i]
            var t = String(s.scriptType || "")
            if (!t) continue
            var isHdr = isHeader(t)
            var exp = s.expanded !== undefined ? s.expanded : true
            if (isHdr) {
                if (t.indexOf("continuity") >= 0) {
                    exp = false
                }
                currentExpanded = exp
            }

            manualListModel.append({
                displayText: String(s.displayText || ""),
                scriptType: t,
                allowRun: s.allowRun !== false,
                checked: s.allowRun !== false,
                stopOnFail: s.stopOnFail !== false,
                measuredValue: String(s.measuredValue || ""),
                measureTime: String(s.measureTime || ""),
                resultStatus: String(s.resultStatus || ""),
                labelA: String(s.labelA || ""),
                labelB: String(s.labelB || ""),
                pinA: String(s.pinA || ""),
                pinB: String(s.pinB || ""),
                portPinA: s.portPinA !== undefined ? Number(s.portPinA) : -1,
                portPinB: s.portPinB !== undefined ? Number(s.portPinB) : -1,
                limitLower: (s.limitLower !== undefined && s.limitLower !== null && s.limitLower !== "") ? (parseFloat(s.limitLower) || 0) : 0,
                limitUpper: (s.limitUpper !== undefined && s.limitUpper !== null && s.limitUpper !== "") ? (parseFloat(s.limitUpper) || 999999) : 999999,
                deviceConfig: s.deviceConfig !== undefined ? s.deviceConfig : false,
                resistanceRange: String(s.resistanceRange || "RANGE_1KΩ"),
                deviceSpeed: String(s.deviceSpeed || "FAST"),
                measureVoltage: s.measureVoltage !== undefined ? Number(s.measureVoltage) : 250,
                currentLimit: String(s.currentLimit || "Auto"),
                trigDelay: s.trigDelay !== undefined ? Number(s.trigDelay) : 1,
                avgCount: s.avgCount !== undefined ? Number(s.avgCount) : 1,
                avgEnabled: s.avgEnabled !== undefined ? s.avgEnabled : false,
                numReadings: s.numReadings !== undefined ? Number(s.numReadings) : 3,
                delayBetween: s.delayBetween !== undefined ? Number(s.delayBetween) : 10,
                delayAfter: s.delayAfter !== undefined ? Number(s.delayAfter) : 100,
                dischargeDelay: s.dischargeDelay !== undefined ? Number(s.dischargeDelay) : 100,
                expanded: exp,
                isHeader: isHdr,
                isSpecial: t === "notification" || t === "system_init",
                hidden: !isHdr && !currentExpanded
            })
        }
        buildRightTable()
        syncEditorFromSelection()
    }



 function loadSripttoManulList() {
    manualListModel.clear()
     rightTableModel.clear()
     _selectedIndex = - 1 
     



     }
 

    function buildRightTable() {
        rightTableModel.clear()
        for (var i = 0; i < manualListModel.count; i++) {
            var s = manualListModel.get(i)
            rightTableModel.append({
                idx: i + 1,
                ticked: s.checked !== false,
                name: s.displayText,
                lower: formatLimit(s.scriptType, s.limitLower, false),
                value: s.measuredValue !== undefined && s.measuredValue !== "" ? String(s.measuredValue) : "",
                upper: formatLimit(s.scriptType, s.limitUpper, true),
                time: s.measureTime || "",
                status: s.resultStatus || "",
                hidden: s.hidden === true,
                isHdr: s.isHeader === true
            })
        }
        if (typeof rightTableView !== "undefined" && rightTableView) rightTableView.forceLayout()
    }

    // ⚠️ Tab thủ công: KHÔNG lưu xuống file — mọi thay đổi chỉ tồn tại trong bộ nhớ
    // Hàm này chỉ rebuild bảng hiển thị, KHÔNG ghi vào testPlanManager
    function savePlan() {
        // Cố ý để trống — không ghi ra disk để tránh ảnh hưởng bài đo chính
        buildRightTable()
    }

    function syncEditorFromSelection() {
        var item = selectedItem()
        if (!item) {
            editorName.text = ""
            editorType.text = ""
            editorA.text = ""
            editorB.text = ""
            editorPinA.text = ""
            editorPinB.text = ""
            editorPortA.text = ""
            editorPortB.text = ""
            editorLower.text = ""
            editorUpper.text = ""
            editorStatus.text = ""
            editorAllowRun.checked = true
            editorStopOnFail.checked = true
            return
        }
        editorName.text = item.displayText || ""
        editorType.text = item.scriptType || ""
        editorA.text = item.labelA || ""
        editorB.text = item.labelB || ""
        editorPinA.text = item.pinA || ""
        editorPinB.text = item.pinB || ""
        editorPortA.text = item.portPinA >= 0 ? String(item.portPinA) : ""
        editorPortB.text = item.portPinB >= 0 ? String(item.portPinB) : ""
        editorLower.text = String(item.limitLower !== undefined ? item.limitLower : "")
        editorUpper.text = String(item.limitUpper !== undefined ? item.limitUpper : "")
        editorStatus.text = item.resultStatus || ""
        editorAllowRun.checked = item.allowRun !== false
        editorStopOnFail.checked = item.stopOnFail !== false
        editorRange.text = item.resistanceRange || "RANGE_1KΩ"
        editorSpeed.text = item.deviceSpeed || "FAST"
        editorVoltage.text = String(item.measureVoltage !== undefined ? item.measureVoltage : 250)
        editorNumReadings.text = String(item.numReadings !== undefined ? item.numReadings : 3)
        editorDelayBetween.text = String(item.delayBetween !== undefined ? item.delayBetween : 10)
        editorDelayAfter.text = String(item.delayAfter !== undefined ? item.delayAfter : 100)
        editorDischargeDelay.text = String(item.dischargeDelay !== undefined ? item.dischargeDelay : 100)
    }

    function runManualTest() {
        if (_isTesting) return
        _syncCheckAllToModel() // Đồng bộ override vào model trước khi gom queue
        
        root.testStartTime = new Date().toLocaleString("en-US")
        root.testEndTime = ""

        var scriptsToRun = []
        for (var i = 0; i < manualListModel.count; i++) {
            var item = manualListModel.get(i)
            if (item.checked && isMeasurable(item.scriptType)) {
                var payload = {
                    modelIndex: i, // Lưu lại index thật trong bảng đẻ cập nhật KQ
                    scriptType: item.scriptType,
                    portPinA: item.portPinA,
                    portPinB: item.portPinB,
                    portLabelA: item.labelA,
                    portLabelB: item.labelB,
                    labelA: item.labelA,
                    pinA: item.pinA,
                    labelB: item.labelB,
                    pinB: item.pinB,
                    measureVoltage: item.measureVoltage || 250,
                    resistanceRange: item.resistanceRange || "AUTO",
                    deviceSpeed: item.deviceSpeed || "SLOW2",
                    limitLower: item.limitLower,
                    limitUpper: item.limitUpper,
                    delayBetween: item.delayBetween || 10,
                    delayAfter: item.delayAfter || 50,
                    trigDelay: item.trigDelay !== undefined ? item.trigDelay : 1,
                    avgCount: item.avgCount !== undefined ? item.avgCount : 1,
                    avgEnabled: item.avgEnabled,
                    dischargeDelay: item.dischargeDelay !== undefined ? item.dischargeDelay : 100
                }
                scriptsToRun.push(payload)
            }
        }

        if (scriptsToRun.length === 0) {
            _statusText = qsTr("Chưa tick chọn bài đo nào (hoặc không hỗ trợ đo)!")
            return
        }

        if (typeof mcuSender === "undefined" || !mcuSender || !mcuSender.isOpen) {
            _statusText = qsTr("Lỗi: Port MCU chưa kết nối")
            return
        }

        // --- ĐỒNG BỘ THUẬT TOÁN GOM NHÓM (GROUPING) NHƯ C++ ---
        // Do McuSender.cpp tự động nhóm các bài chung CMD lại với nhau, 
        // ta cũng phải nhóm _testQueue y hệt để MCU test đến đâu thì UI chốt kq đến đấy.
        var cmdOrder = []
        var scriptsByCmd = {}
        
        for (var k = 0; k < scriptsToRun.length; k++) {
            var sc = scriptsToRun[k]
            var st = sc.scriptType
            var cmd = 0x00
            if (st === "continuity") cmd = 0x8F
            else if (st === "sheath_insulation") cmd = 0x8D
            
            var cmdStr = String(cmd)
            if (cmdOrder.indexOf(cmdStr) === -1) {
                cmdOrder.push(cmdStr)
                scriptsByCmd[cmdStr] = []
            }
            scriptsByCmd[cmdStr].push(sc)
        }
        
        var sortedQueue = []
        for (var n = 0; n < cmdOrder.length; n++) {
            var cmdKey = cmdOrder[n]
            sortedQueue = sortedQueue.concat(scriptsByCmd[cmdKey])
        }

        _isTesting = true
        _testQueue = sortedQueue // Lưu mảng đã xào vị trí
        _currentTestIndex = 0
        _manualTestState = 1
        _statusText = qsTr("Đang nạp %1 lệnh xuống MCU...").arg(_testQueue.length)
        
        console.log("[Manual] Gửi chuỗi đo:", _testQueue.length, "bài")
        
        // Cú lừa: Gọi C++ bằng rổ dữ liệu nguyên thủy (để C++ tự làm việc của nó)
        mcuSender.sendTestScripts(scriptsToRun, false)
        
        mcuFailTimer.start()
    }

    function _advanceToNextManualTest() {
        _currentTestIndex++
        if (_currentTestIndex >= _testQueue.length) {
            _isTesting = false
            _manualTestState = 0
            _statusText = qsTr("✓ Đo hoàn tất %1 bài!").arg(_testQueue.length)
            root.testEndTime = new Date().toLocaleString("en-US")
            return
        }
        
        // Nghỉ một tí rồi bắn tiếp 0x04 cho bài kế
        var lastScript = _testQueue[_currentTestIndex - 1]
        var afterDelay = Number(lastScript.delayAfter || 50)
        
        advanceTimer.interval = afterDelay
        advanceTimer.start()
    }
    
    Timer {
        id: advanceTimer
        repeat: false
        onTriggered: {
            if (!_isTesting) return
            _manualTestState = 2
            _statusText = qsTr("Đo bài %1/%2. Đang đóng Relay...").arg(_currentTestIndex + 1).arg(_testQueue.length)
            mcuFailTimer.restart()
            mcuSender.sendSimpleCommand(0x04)
        }
    }

    function _saveMeasuredValue(rawValue) {
        if (_currentTestIndex >= 0 && _currentTestIndex < _testQueue.length) {
             var currentScript = _testQueue[_currentTestIndex]
             var rIndex = currentScript.modelIndex // Index thực của dòng trong List QML
             
             var script = manualListModel.get(rIndex)
             var scriptType = script.scriptType
             var adjustedValue = Number(rawValue)

             // --- ÁP DỤNG HIỆU CHUẨN ---
             if (mainContent !== null) {
                 var isCable = (calibrationMode === qsTr("Hiệu chuẩn theo cáp đo"))
                 var calibDialog = isCable ? mainContent.cableCalibrationDialog : mainContent.calibrationDialog
                 
                 if (calibDialog && isMeasurable(scriptType)) {
                     var portA = script.portPinA !== undefined ? Number(script.portPinA) : -1
                     var portB = script.portPinB !== undefined ? Number(script.portPinB) : -1
                     
                     if (portA >= 0 || portB >= 0) {
                         if (typeof calibDialog.getCalibrationOffset === "function") {
                             var calib = calibDialog.getCalibrationOffset(portA, portB, scriptType)
                             var cableRes = isCable ? 0 : (calibDialog.cableResistance || 0)
                             
                             if (calib.offset !== 0 || cableRes !== 0) {
                                 adjustedValue = adjustedValue - calib.offset - cableRes
                             }
                         }
                     }
                 }
             }

             manualListModel.setProperty(rIndex, "measuredValue", adjustedValue)
             
             // --- Tính toán PASS / FAIL ---
             var stat = "PASS"
             var lLow = Number(script.limitLower)
             var lUp = Number(script.limitUpper)
             if (!isNaN(lLow) && adjustedValue < lLow) stat = "FAIL"
             if (!isNaN(lUp) && lUp > 0 && adjustedValue > lUp) stat = "FAIL"
             
             manualListModel.setProperty(rIndex, "resultStatus", stat)
             // Lưu tạm text để hiển thị
             _statusText = qsTr("KQ: %1 %2").arg(adjustedValue.toFixed(4)).arg(stat)
             
             if (rIndex === _selectedIndex) syncEditorFromSelection()
             buildRightTable()
             
             // Chuyển sang bài kế tiếp
             _advanceToNextManualTest()
        }
    }

    Timer {
        id: mcuFailTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (_isTesting) {
                _isTesting = false
                _manualTestState = 0
                _statusText = qsTr("Lỗi: Xảy ra timeout báo chốt từ MCU!")
                root.testEndTime = new Date().toLocaleString("en-US")
            }
        }
    }

    Connections {
        target: typeof mcuSender !== "undefined" ? mcuSender : null
        
        function onMcuReadyForTest() {
            if (!_isTesting || _manualTestState !== 1) return
            
            console.log("[Manual] Nhận 0x06 MCU Ready. Bắt đầu đo bài 1...")
            _manualTestState = 2
            _statusText = qsTr("MCU đã nhận. Kích Relay bài 1/%1...").arg(_testQueue.length)
            
            mcuFailTimer.restart()
            mcuSender.sendSimpleCommand(0x04)
        }

        function onMcuStartTestResponse() {
            if (!_isTesting || _manualTestState !== 2) return
            
            var currentScript = _testQueue[_currentTestIndex]
            console.log("[Manual] Nhận 0x05 đóng Relay dòng", currentScript.modelIndex, "- Đọc KQ")
            mcuFailTimer.stop()
            _manualTestState = 3
            _statusText = qsTr("Đang lấy giá trị (%1/%2)...").arg(_currentTestIndex+1).arg(_testQueue.length)

            var type = String(currentScript.scriptType)
            if (type === "continuity" || type === "sheath_insulation") {
                if (typeof keithley2110 !== "undefined" && keithley2110.isOpen) {
                    keithley2110.readResistance()
                } else {
                    _statusText = qsTr("LỖI: RM3544 chưa mở/kết nối!")
                    _isTesting = false
                }
            }
        }
    }

    Connections {
        target: typeof keithley2110 !== "undefined" ? keithley2110 : null
        function onResistanceRead(val) {
            if (!_isTesting) return
            _statusText = qsTr("KQ: ") + val.toFixed(4) + " Ω"
            _saveMeasuredValue(val)
        }
        function onErrorOccurred(err) {
            if (!_isTesting) return
            _isTesting = false
            _statusText = qsTr("Lỗi RM3544: ") + err
        }
    }

    // Tự động tạo lại displayText từ tên gốc + label/pin hiện tại
    // VD: "Kiểm tra điện trở dây dẫn" + labelA="CS", pinA="6", labelB="HCX15-R", pinB="2"
    //   → "Kiểm tra điện trở dây dẫn [CS_6 <-> HCX15-R_2]"
    function rebuildDisplayText(baseName, labelA, pinA, labelB, pinB) {
        // Bỏ phần bracket cũ (nếu có) khỏi baseName
        var clean = String(baseName || "").replace(/\s*\[.*\]\s*$/, "").trim()
        // Xây lại bracket từ giá trị mới
        var partA = (labelA || "") + (pinA ? "_" + pinA : "")
        var partB = (labelB || "") + (pinB ? "_" + pinB : "")
        if (partA || partB)
            return clean + " [" + partA + " <-> " + partB + "]"
        return clean
    }

    function applyEditorToSelection() {
        var idx = _selectedIndex
        if (idx < 0 || idx >= manualListModel.count) return

        var old = manualListModel.get(idx)

        // ★ Tạo lại displayText từ tên gốc + label/pin hiện tại
        var newDisplayText = rebuildDisplayText(
            editorName.text, editorA.text, editorPinA.text, editorB.text, editorPinB.text
        )

        var updated = {
            displayText:     newDisplayText,
            scriptType:      old.scriptType,
            allowRun:        editorAllowRun.checked,
            checked:         editorAllowRun.checked,
            stopOnFail:      editorStopOnFail.checked,
            measuredValue:   old.measuredValue || "",
            measureTime:     old.measureTime || "",
            resultStatus:    editorStatus.text,
            labelA:          editorA.text,
            labelB:          editorB.text,
            pinA:            editorPinA.text,
            pinB:            editorPinB.text,
            portPinA:        editorPortA.text === "" ? -1 : Number(editorPortA.text),
            portPinB:        editorPortB.text === "" ? -1 : Number(editorPortB.text),
            limitLower:      editorLower.text === "" ? 0 : Number(editorLower.text),
            limitUpper:      editorUpper.text === "" ? 0 : Number(editorUpper.text),
            deviceConfig:    old.deviceConfig,
            resistanceRange: editorRange.text,
            deviceSpeed:     editorSpeed.text,
            measureVoltage:  editorVoltage.text === "" ? 250 : Number(editorVoltage.text),
            currentLimit:    old.currentLimit || "Auto",
            trigDelay:       old.trigDelay || 1,
            avgCount:        old.avgCount || 1,
            avgEnabled:      old.avgEnabled || false,
            numReadings:     editorNumReadings.text === "" ? 1 : Number(editorNumReadings.text),
            delayBetween:    editorDelayBetween.text === "" ? 10 : Number(editorDelayBetween.text),
            delayAfter:      editorDelayAfter.text === "" ? 100 : Number(editorDelayAfter.text),
            dischargeDelay:  editorDischargeDelay.text === "" ? 100 : Number(editorDischargeDelay.text),
            expanded:        old.expanded !== false,
            isHeader:        isHeader(old.scriptType),
            isSpecial:       old.scriptType === "notification" || old.scriptType === "system_init"
        }

        // Xóa rồi chèn lại — buộc ListView tạo lại delegate mới
        manualListModel.remove(idx)
        manualListModel.insert(idx, updated)
        _selectedIndex = idx

        // Rebuild bảng phải
        buildRightTable()

        // Cập nhật lại editor name hiển thị tên mới
        editorName.text = newDisplayText

        // Scroll + highlight
        Qt.callLater(function() {
            leftListView.currentIndex = idx
            rightTableView.currentIndex = idx
            leftListView.positionViewAtIndex(idx, ListView.Contain)
            rightTableView.positionViewAtIndex(idx, ListView.Contain)
        })
    }


    function checkAllStatus() {
        // Trả về: 2=tất cả tick, 1=một số tick, 0=không tick nào
        if (manualListModel.count === 0) return 0
        var countChecked = 0
        for (var i = 0; i < manualListModel.count; i++) {
            if (manualListModel.get(i).checked) countChecked++
        }
        if (countChecked === 0) return 0
        if (countChecked === manualListModel.count) return 2
        return 1
    }

    function setAllChecked(val) {
        _checkAllOverride = val ? 1 : 0
        _bulkSyncTimer.syncVal = val
        _bulkSyncTimer.currentIdx = 0
        _bulkSyncTimer.totalCount = manualListModel.count
        _statusText = val ? qsTr("Đang chọn tất cả... 0%") : qsTr("Đang bỏ chọn... 0%")
        _bulkSyncTimer.restart()
    }

    Timer {
        id: _bulkSyncTimer
        property bool syncVal: false
        property int currentIdx: 0
        property int totalCount: 0
        readonly property int batchSize: 30
        interval: 1
        repeat: true
        onTriggered: {
            var end = Math.min(currentIdx + batchSize, totalCount)
            for (var i = currentIdx; i < end; i++) {
                manualListModel.setProperty(i, "checked", syncVal)
                manualListModel.setProperty(i, "allowRun", syncVal)
                if (i < rightTableModel.count)
                    rightTableModel.setProperty(i, "ticked", syncVal)
            }
            currentIdx = end
            var pct = totalCount > 0 ? Math.round(currentIdx / totalCount * 100) : 100
            root._statusText = (syncVal ? qsTr("Đang chọn tất cả... ") : qsTr("Đang bỏ chọn... ")) + pct + "%"
            if (currentIdx >= totalCount) {
                stop()
                root._checkAllOverride = -1
                root._statusText = syncVal ? qsTr("✔ Đã chọn tất cả (%1 bài)").arg(totalCount) : qsTr("✔ Đã bỏ chọn tất cả")
            }
        }
    }

    // Đồng bộ ngay lập tức (dùng trước khi chạy test)
    function _syncCheckAllToModel() {
        if (_checkAllOverride < 0) return
        _bulkSyncTimer.stop()
        var val = (_checkAllOverride === 1)
        for (var i = 0; i < manualListModel.count; i++) {
            manualListModel.setProperty(i, "checked", val)
            manualListModel.setProperty(i, "allowRun", val)
        }
        for (var j = 0; j < rightTableModel.count; j++) {
            rightTableModel.setProperty(j, "ticked", val)
        }
        _checkAllOverride = -1
    }

    function insertTemplate(type) {
        var idx = _selectedIndex >= 0 ? _selectedIndex + 1 : manualListModel.count
        var item = {
            displayText: "",
            scriptType: type,
            allowRun: true,
            checked: true,
            stopOnFail: true,
            labelA: "",
            labelB: "",
            pinA: "",
            pinB: "",
            portPinA: -1,
            portPinB: -1,
            limitLower: 0,
            limitUpper: 999999,
            deviceConfig: false,
            resistanceRange: "RANGE_1KΩ",
            deviceSpeed: "FAST",
            measureVoltage: 250,
            currentLimit: "Auto",
            trigDelay: 1,
            avgCount: 1,
            avgEnabled: false,
            numReadings: 1,
            delayBetween: 10,
            delayAfter: 100,
            dischargeDelay: 100,
            expanded: true,
            resultStatus: "",
            measuredValue: "",
            measureTime: ""
        }
        if (type === "notification") item.displayText = qsTr("Thông báo kết nối cổng A/B")
        if (type === "continuity") item.displayText = qsTr("Kiểm tra thông chập giữa các chân")
        if (type === "sheath_insulation") item.displayText = qsTr("Kiểm tra điện trở cách điện với vỏ")
        manualListModel.insert(idx, item)
        _selectedIndex = idx
        buildRightTable()
        syncEditorFromSelection()
        savePlan()
    }

    function deleteSelected() {
        if (_selectedIndex < 0 || _selectedIndex >= manualListModel.count) return
        manualListModel.remove(_selectedIndex)
        if (_selectedIndex >= manualListModel.count) _selectedIndex = manualListModel.count - 1
        buildRightTable()
        syncEditorFromSelection()
        savePlan()
    }

    function moveSelected(step) {
        if (_selectedIndex < 0) return
        var to = _selectedIndex + step
        if (to < 0 || to >= manualListModel.count) return
        manualListModel.move(_selectedIndex, to, 1)
        _selectedIndex = to
        buildRightTable()
        syncEditorFromSelection()
        savePlan()
    }

    ListModel { id: manualListModel }
    ListModel { id: rightTableModel }

    Rectangle {
        anchors.fill: parent
        color: "#dfe8f1"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 6

            // ── Tiêu đề ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                color: "#1769aa"
                border.color: "#0d4f83"
                radius: 4
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Test Script - %1").arg(root.currentPlanName || qsTr("Chưa chọn bài đo"))
                    color: "white"
                    font.bold: true
                    font.pixelSize: 13
                }

                // Nút Đóng đưa lên góc phải
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 4
                    width: Math.max(26, height)
                    radius: 4
                    color: closeBtnMa.pressed ? "#e57373" : closeBtnMa.containsMouse ? "#ef9a9a" : "#FFFF00"
                    border.color: closeBtnMa.containsMouse ? "#c62828" : "#1769aa"
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text { 
                        anchors.centerIn: parent; 
                        text: "✕"; 
                        font.pixelSize: 14; 
                        color: closeBtnMa.containsMouse ? "#c62828" : "#1769aa";
                        font.bold: true 
                    }
                    MouseArea {
                        id: closeBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var w = root.Window.window
                            if (w) {
                                w.interfaceMode = "auto"
                                if (w.activeTabIndex !== undefined) w.activeTabIndex = 0
                            }
                        }
                    }
                }
            }
            // Rectangle {
            //               Layout.fillWidth: true
            //               Layout.preferredHeight: 32
            //               color: "#1769aa"
            //               border.color: "#1769aa"
            //               radius: 4
            //               Text {
            //                 anchors.centerIn: parent
            //                  text: qsTr("Test case %1").arg(root.currentPlanName || "chưa chọn bài đo")
            //                  color: "white"
            //                  font.bold:true
            //                  font.pixelSize: 15
            //               }
                // Rectangle {
                //     anchors.right: parent.right
                //     anchors.top:parent.top
                //     anchors.bottom:parent.bottom
                //     anchors.margins: 4
                //     width: Math.max(26,height)
                //     radius: 4
                //     color: btn.pressed ? "#e57373" : btn.containsMouse ? "#ef9a9a" : "#FFFF00"
                //     border.color: btn.containsMouse ? "#c62828" : "#1769aa"
                //      Behavior on color { ColorAnimation { duration: 80 } }
                     // Text {
                     //     anchors.centerIn: parent
                     //     text: "V";
                     //     font.pixelSize: 14;
                     //     color: closeBtnMa.containsMouse ? "#c62828" : "#1769aa";
                     //      font.bold: true
                     // }
                     // MouseArea {
                     //     id: btn
                     //     anchors.fill: parent
                     //     hoverEnabled: true
                     //     cursorShape: Qt.PointingHandCursor

                     //     onClicked: {
                     //         var w = root.Window.window
                     //         if (w) {
                     //             w.interfaceMode = "auto"
                     //             if (w.activeTabIndex !== undefined)
                     //                 w.activeTabIndex = 0
                     //         }
                     //     }
                     // }
               // }

            SplitView {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // ══════════════════════════════════════
                // CỘT 1: Danh sách bài đo
                // ══════════════════════════════════════
                Rectangle {
                    SplitView.preferredWidth: 360
                    SplitView.fillHeight: true
                    color: "#f6f9fc"
                    border.color: "#2f6ea8"
                    radius: 4

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        // Header "Danh sách bài đo" + nút Tick All / Bỏ All
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            color: "#1769aa"
                            radius: 3
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 4
                                Text {
                                    text: qsTr("Danh sách bài đo")
                                    color: "white"
                                    font.bold: true
                                    font.pixelSize: 11
                                    Layout.fillWidth: true
                                } 
                                // Nút Tick tất cả
                                Rectangle {
                                    width: 44; height: 18; radius: 3
                                    color: tickAllBtnMa.containsMouse ? "#4caf50" : "#2e7d32"
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text { anchors.centerIn: parent; text: "✓ All"; color: "white"; font.pixelSize: 9; font.bold: true }
                                    MouseArea {
                                        id: tickAllBtnMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.setAllChecked(true)
                                    }
                                }
                                // Nút Bỏ tick tất cả
                                Rectangle {
                                    width: 44; height: 18; radius: 3
                                    color: uncheckAllBtnMa.containsMouse ? "#ef9a9a" : "#c62828"
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text { anchors.centerIn: parent; text: "✗ All"; color: "white"; font.pixelSize: 9; font.bold: true }
                                    MouseArea {
                                        id: uncheckAllBtnMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.setAllChecked(false)
                                    }
                                }
                            }
                        }

                        // Danh sách
                        ListView {
                            id: leftListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: manualListModel
                            clip: true
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: model.hidden ? 0 : 26
                                visible: !model.hidden
                                radius: 2
                                color: index === root._selectedIndex ? "#bbdefb" : (index % 2 === 0 ? "#ffffff" : "#f4f8fd")
                                border.color: index === root._selectedIndex ? "#1769aa" : "#bdd3e5"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    spacing: 4

                                    CheckBox {
                                        opacity: model.isHeader ? 0 : 1
                                        enabled: !model.isHeader
                                        checked: root._checkAllOverride >= 0 ? (root._checkAllOverride === 1) : model.checked
                                        indicator.width: 15
                                        indicator.height: 15
                                        padding: 0
                                        onClicked: {
                                            if (root._checkAllOverride >= 0) {
                                                _bulkSyncTimer.stop()
                                                _bulkSyncTimer.triggered()
                                            }
                                            manualListModel.setProperty(index, "checked", checked)
                                            manualListModel.setProperty(index, "allowRun", checked)
                                            if (index < rightTableModel.count) rightTableModel.setProperty(index, "ticked", checked)
                                        }
                                    }

                                    // Số thứ tự
                                    Text {
                                        text: model.isHeader ? (model.expanded ? "▼" : "▶") : ((index + 1) + ".")
                                        font.pixelSize: model.isHeader ? 9 : 10
                                        color: model.isHeader ? "#1769aa" : "#7b8fa6"
                                        Layout.preferredWidth: model.isHeader ? 22 : 22
                                        horizontalAlignment: model.isHeader ? Text.AlignHCenter : Text.AlignLeft
                                    }

                                    Text {
                                        text: model.displayText
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        color: index === root._selectedIndex ? "#0d3a6b" : (model.isHeader ? "#1769aa" : "#1a3a5c")
                                        font.bold: model.isHeader || index === root._selectedIndex
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.leftMargin: 26
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: {
                                        if (model.isHeader) {
                                            root.toggleExpand(index)
                                        }
                                        root._selectedIndex = index
                                        syncEditorFromSelection()
                                    }
                                }
                            }
                        }

                        // Toolbar dưới danh sách
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            color: "#dbeeff"
                            radius: 3
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 9
                                spacing: 12

                                Repeater {
                                    model: [
                                        { lbl: "↑", tip: "Di chuyển lên" },
                                        { lbl: "↓", tip: "Di chuyển xuống" },
                                        { lbl: "🗑 Xóa", tip: "Xóa mục đang chọn" }
                                    ]
                                    delegate: Rectangle {
                                        height: 22
                                        width: modelData.lbl.length <= 2 ? 26 : txtLbl.contentWidth + 16
                                        radius: 4
                                        color: btnMa2.pressed ? "#90bce8" : btnMa2.containsMouse ? "#b3d4f5" : "#e8f3ff"
                                        border.color: "#2f6ea8"
                                        Behavior on color { ColorAnimation { duration: 80 } }
                                        Text {
                                            id: txtLbl
                                            anchors.centerIn: parent
                                            text: modelData.lbl
                                            font.pixelSize: 11
                                            color: "#1769aa"
                                            font.bold: true
                                        }
                                        MouseArea {
                                            id: btnMa2
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (modelData.lbl === "↑") root.moveSelected(-1)
                                                else if (modelData.lbl === "↓") root.moveSelected(1)
                                                else if (modelData.lbl === "🗑 Xóa") root.deleteSelected()
                                            }
                                        }
                                    }
                                }

                                // Nút "+ Thêm" với dropdown menu
                                Rectangle {
                                    height: 22
                                    width: addBtnText.contentWidth + 20
                                    radius: 4
                                    color: addBtnMa.pressed ? "#81c784" : addBtnMa.containsMouse ? "#a5d6a7" : "#c8e6c9"
                                    border.color: "#2e7d32"
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                    Text {
                                        id: addBtnText
                                        anchors.centerIn: parent
                                        text: "+ Thêm ▾"
                                        font.pixelSize: 11
                                        color: "#1b5e20"
                                        font.bold: true
                                    }
                                    MouseArea {
                                        id: addBtnMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: addTestMenu.open()
                                    }
                                    Menu {
                                        id: addTestMenu
                                        MenuItem {
                                            text: qsTr("🔗 Thông chập")
                                            onTriggered: root.insertTemplate("continuity")
                                        }
                                        MenuItem {
                                            text: qsTr("🛡 Cách điện vỏ")
                                            onTriggered: root.insertTemplate("sheath_insulation")
                                        }
                                        MenuSeparator {}
                                        MenuItem {
                                            text: qsTr("📢 Thông báo")
                                            onTriggered: root.insertTemplate("notification")
                                        }
                                    }
                                }
                                Item { Layout.fillWidth: true }
                            }
                        }
                    }
                }

                // ══════════════════════════════════════
                // CỘT 2: Thông số bài đo (Editor)
                // ══════════════════════════════════════
                Rectangle {
                    SplitView.preferredWidth: 340
                    SplitView.fillHeight: true
                    color: "#fcfdff"
                    border.color: "#2f6ea8"
                    radius: 4

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            color: "#1769aa"
                            radius: 3
                            Text { anchors.centerIn: parent; text: qsTr("Thông số bài đo"); color: "white"; font.bold: true; font.pixelSize: 12 }
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                            ColumnLayout {
                                width: parent.width
                                spacing: 0

                                // Thông tin cơ bản
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 20
                                    color: "#e3f0fb"
                                    Text { anchors.leftMargin: 6; anchors.fill: parent; text: qsTr("── Thông tin chung ──"); font.pixelSize: 10; color: "#1769aa"; font.bold: true; verticalAlignment: Text.AlignVCenter }
                                }
                                GridLayout {
                                    Layout.fillWidth: true
                                    Layout.margins: 4
                                    columns: 2
                                    rowSpacing: 3
                                    columnSpacing: 6

                                    Label { text: qsTr("Tên bài đo"); font.pixelSize: 11 }
                                    TextField { id: editorName; Layout.fillWidth: true; Layout.columnSpan: 1; font.pixelSize: 11; selectByMouse: true }

                                    Label { text: qsTr("Loại script"); font.pixelSize: 11 }
                                    TextField { id: editorType; readOnly: true; Layout.fillWidth: true; font.pixelSize: 11; color: "#888" }

                                    Label { text: qsTr("Giắc đầu A"); font.pixelSize: 11 }
                                    TextField { id: editorA; Layout.fillWidth: true; font.pixelSize: 11 }

                                    Label { text: qsTr("Giắc đầu B"); font.pixelSize: 11 }
                                    TextField { id: editorB; Layout.fillWidth: true; font.pixelSize: 11 }

                                    Label { text: qsTr("Chân A"); font.pixelSize: 11 }
                                    TextField { id: editorPinA; Layout.fillWidth: true; font.pixelSize: 11 }

                                    Label { text: qsTr("Chân B"); font.pixelSize: 11 }
                                    TextField { id: editorPinB; Layout.fillWidth: true; font.pixelSize: 11 }

                                    Label { text: qsTr("Port A (relay)"); font.pixelSize: 11 }
                                    TextField { id: editorPortA; Layout.fillWidth: true; font.pixelSize: 11; inputMethodHints: Qt.ImhDigitsOnly }

                                    Label { text: qsTr("Port B (relay)"); font.pixelSize: 11 }
                                    TextField { id: editorPortB; Layout.fillWidth: true; font.pixelSize: 11; inputMethodHints: Qt.ImhDigitsOnly }

                                    Label { text: qsTr("Cận dưới"); font.pixelSize: 11 }
                                    TextField { id: editorLower; Layout.fillWidth: true; font.pixelSize: 11; inputMethodHints: Qt.ImhFormattedNumbersOnly }

                                    Label { text: qsTr("Cận trên"); font.pixelSize: 11 }
                                    TextField { id: editorUpper; Layout.fillWidth: true; font.pixelSize: 11; inputMethodHints: Qt.ImhFormattedNumbersOnly }

                                    Label { text: qsTr("Kết quả"); font.pixelSize: 11 }
                                    TextField { id: editorStatus; readOnly: true; Layout.fillWidth: true; font.pixelSize: 11; color: "#888" }

                                    Label { text: qsTr("Cho phép chạy"); font.pixelSize: 11 }
                                    CheckBox { id: editorAllowRun; checked: true; indicator.width: 16; indicator.height: 16 }

                                    Label { text: qsTr("Dừng khi không đạt"); font.pixelSize: 11 }
                                    CheckBox { id: editorStopOnFail; checked: true; indicator.width: 16; indicator.height: 16 }
                                }

                                // Cấu hình máy đo
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 20
                                    color: "#e3f0fb"
                                    Text { anchors.leftMargin: 6; anchors.fill: parent; text: qsTr("── Cấu hình máy đo ──"); font.pixelSize: 10; color: "#1769aa"; font.bold: true; verticalAlignment: Text.AlignVCenter }
                                }
                                GridLayout {
                                    Layout.fillWidth: true
                                    Layout.margins: 4
                                    columns: 2
                                    rowSpacing: 3
                                    columnSpacing: 6

                                    Label { text: qsTr("Dải đo"); font.pixelSize: 11 }
                                    TextField { id: editorRange; text: "RANGE_1KΩ"; Layout.fillWidth: true; Layout.preferredWidth: 80; font.pixelSize: 11 }
                                    Label { text: qsTr("Tốc độ"); font.pixelSize: 11 }
                                    TextField { id: editorSpeed; text: "FAST"; Layout.fillWidth: true; font.pixelSize: 11 }

                                    Label { text: qsTr("Điện áp (V)"); font.pixelSize: 11 }
                                    TextField { id: editorVoltage; text: "250"; Layout.fillWidth: true; font.pixelSize: 11; inputMethodHints: Qt.ImhDigitsOnly }

                                    Label { text: qsTr("Số lần đọc"); font.pixelSize: 11 }
                                    TextField { id: editorNumReadings; text: "3"; Layout.fillWidth: true; font.pixelSize: 11; inputMethodHints: Qt.ImhDigitsOnly }

                                    Label { text: qsTr("Delay giữa (ms)"); font.pixelSize: 11 }
                                    TextField { id: editorDelayBetween; text: "10"; Layout.fillWidth: true; font.pixelSize: 11; inputMethodHints: Qt.ImhDigitsOnly }

                                    Label { text: qsTr("Delay sau (ms)"); font.pixelSize: 11 }
                                    TextField { id: editorDelayAfter; text: "100"; Layout.fillWidth: true; font.pixelSize: 11; inputMethodHints: Qt.ImhDigitsOnly }

                                    Label { text: qsTr("Xả điện (ms)"); font.pixelSize: 11 }
                                    TextField { id: editorDischargeDelay; text: "100"; Layout.fillWidth: true; font.pixelSize: 11; inputMethodHints: Qt.ImhDigitsOnly }
                                }
                            }
                        }

                        // ── Thanh nút phía dưới Editor ──
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            color: "#dbeeff"
                            radius: 3

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 6

                                // Nút Áp dụng (nổi bật nhất)
                                Rectangle {
                                    height: 26
                                    width: applyLbl.implicitWidth + 20
                                    radius: 5
                                    color: applyBtnMa.pressed ? "#1565c0" : applyBtnMa.containsMouse ? "#1e88e5" : "#1769aa"
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                    Text { id: applyLbl; anchors.centerIn: parent; text: qsTr("✔ Áp dụng"); color: "white"; font.pixelSize: 11; font.bold: true }
                                    MouseArea {
                                        id: applyBtnMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.applyEditorToSelection()
                                    }
                                }

                                // Divider
                                Rectangle { width: 1; height: 20; color: "#aac4de" }

                                // Nút Di chuyển
                                Repeater {
                                    model: [
                                        { lbl: "↑ Lên", action: "up" },
                                        { lbl: "↓ Xuống", action: "down" }
                                    ]
                                    delegate: Rectangle {
                                        height: 26
                                        width: moveLbl.implicitWidth + 14
                                        radius: 4
                                        color: moveBtnMa.pressed ? "#90bce8" : moveBtnMa.containsMouse ? "#b3d4f5" : "#e8f3ff"
                                        border.color: "#2f6ea8"
                                        Behavior on color { ColorAnimation { duration: 80 } }
                                        Text { id: moveLbl; anchors.centerIn: parent; text: modelData.lbl; font.pixelSize: 11; color: "#1769aa" }
                                        MouseArea {
                                            id: moveBtnMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (modelData.action === "up") root.moveSelected(-1)
                                                else root.moveSelected(1)
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }
                        }
                    }
                }

                // ══════════════════════════════════════
                // CỘT 3: Bảng script kết quả (phải)
                // ══════════════════════════════════════
                Rectangle {
                    SplitView.fillWidth: true
                    SplitView.fillHeight: true
                    color: "#ffffff"
                    border.color: "#2f6ea8"
                    radius: 4

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        // Header bảng bên phải với nút Tick All / Bỏ All
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            color: "#1769aa"
                            radius: 3
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 2
                                spacing: 2

                                // Ô Tick (header) — bấm để toggle tất cả
                                Rectangle {
                                    width: 40; height: 22; radius: 3
                                    color: headerTickMa.containsMouse ? "#42a5f5" : "transparent"
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                    // Biểu tượng trạng thái checkbox tất cả
                                    Text {
                                        anchors.centerIn: parent
                                        text: {
                                            var st = root.checkAllStatus()
                                            if (st === 2) return "☑"
                                            if (st === 1) return "⊟"
                                            return "☐"
                                        }
                                        color: "white"
                                        font.pixelSize: 14
                                    }
                                    MouseArea {
                                        id: headerTickMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            // Toggle: nếu tất cả đang tick thì bỏ tất cả, ngược lại tick tất cả
                                            root.setAllChecked(root.checkAllStatus() !== 2)
                                        }
                                    }
                                }

                                Label { text: qsTr("STT"); color: "white"; Layout.preferredWidth: 30; horizontalAlignment: Text.AlignHCenter; font.bold: true; font.pixelSize: 10 }
                                Label { text: qsTr("Bài đo"); color: "white"; Layout.fillWidth: true; font.bold: true; font.pixelSize: 10 }
                                Label { text: qsTr("Giá trị đo"); color: "white"; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignHCenter; font.bold: true; font.pixelSize: 10 }
                                Label { text: qsTr("Cận dưới"); color: "white"; Layout.preferredWidth: 65; horizontalAlignment: Text.AlignHCenter; font.bold: true; font.pixelSize: 10 }
                                Label { text: qsTr("Cận trên"); color: "white"; Layout.preferredWidth: 65; horizontalAlignment: Text.AlignHCenter; font.bold: true; font.pixelSize: 10 }
                                Label { text: qsTr("Thời gian"); color: "white"; Layout.preferredWidth: 66; horizontalAlignment: Text.AlignHCenter; font.bold: true; font.pixelSize: 10 }
                            }
                        }

                        // Bảng script bên phải
                        ListView {
                            id: rightTableView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: rightTableModel
                            clip: true
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: model.hidden ? 0 : 22
                                visible: !model.hidden
                                color: {
                                    if (model.status === "PASS") return "#e8f5e9"
                                    if (model.status === "FAIL") return "#ffebee"
                                    if (index === root._selectedIndex) return "#bbdefb"
                                    return index % 2 === 0 ? "#ffffff" : "#f4f8fd"
                                }
                                border.color: {
                                    if (model.status === "PASS") return "#4caf50"
                                    if (model.status === "FAIL") return "#e53935"
                                    return index === root._selectedIndex ? "#1769aa" : "#dce8f2"
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    spacing: 2

                                    CheckBox {
                                        opacity: model.isHdr ? 0 : 1
                                        enabled: !model.isHdr
                                        checked: root._checkAllOverride >= 0 ? (root._checkAllOverride === 1) : model.ticked
                                        indicator.width: 14
                                        indicator.height: 14
                                        padding: 0
                                        onClicked: {
                                            if (root._checkAllOverride >= 0) {
                                                _bulkSyncTimer.stop()
                                                _bulkSyncTimer.triggered()
                                            }
                                            manualListModel.setProperty(index, "checked", checked)
                                            manualListModel.setProperty(index, "allowRun", checked)
                                            rightTableModel.setProperty(index, "ticked", checked)
                                        }
                                    }

                                    Label {
                                        visible: !model.isHdr
                                        text: model.isHdr ? "" : model.idx
                                        Layout.preferredWidth: 30
                                        horizontalAlignment: Text.AlignHCenter
                                        font.pixelSize: 10
                                        color: "#556"
                                    }
                                    Label {
                                        text: model.name
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.pixelSize: 10
                                        font.bold: model.isHdr || index === root._selectedIndex
                                        color: index === root._selectedIndex ? "#0d3a6b" : (model.isHdr ? "#1769aa" : "#1a3a5c")
                                    }
                                    Label {
                                        text: model.value
                                        Layout.preferredWidth: 70
                                        horizontalAlignment: Text.AlignHCenter
                                        font.pixelSize: 10
                                        font.bold: model.status !== ""
                                        color: model.status === "PASS" ? "#2e7d32" : model.status === "FAIL" ? "#c62828" : "#1b5e20"
                                    }
                                    Label { text: model.lower; Layout.preferredWidth: 65; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 10; color: "#37474f" }
                                    Label { text: model.upper; Layout.preferredWidth: 65; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 10; color: "#37474f" }
                                    Label { text: model.time; Layout.preferredWidth: 66; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 10; color: "#546e7a" }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.leftMargin: 24
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: {
                                        root._selectedIndex = index
                                        syncEditorFromSelection()
                                    }
                                }
                            }
                        }

                        // Vùng SN + Bắt đầu
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 100
                            color: "#eef5fb"
                            border.color: "#d4e2ee"
                            radius: 4

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    Label { text: qsTr("SN:"); font.bold: true; font.pixelSize: 16 }
                                    TextField {
                                        text: root.snValue
                                        Layout.fillWidth: true
                                        font.pixelSize: 16
                                        horizontalAlignment: Text.AlignHCenter
                                        onTextChanged: root.snValue = text
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        Layout.preferredWidth: 120
                                        Layout.preferredHeight: 40
                                        radius: 6
                                        color: startBtnMa.pressed ? "#f9a825" : startBtnMa.containsMouse ? "#ffee58" : "#fdd835"
                                        border.color: "#f9a825"
                                        Behavior on color { ColorAnimation { duration: 80 } }
                                        Text { anchors.centerIn: parent; text: qsTr("▶ BẮT ĐẦU"); font.bold: true; font.pixelSize: 14; color: "#4e342e" }
                                        MouseArea { 
                                            id: startBtnMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor 
                                            onClicked: runManualTest()
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 130
                                        Layout.preferredHeight: 40
                                        radius: 6
                                        color: exportBtnMa.pressed ? "#1B5E20" : exportBtnMa.containsMouse ? "#388E3C" : "#2E7D32"
                                        border.color: "#1B5E20"
                                        Behavior on color { ColorAnimation { duration: 80 } }
                                        Text { anchors.centerIn: parent; text: qsTr("📊 Xuất Excel"); font.bold: true; font.pixelSize: 13; color: "white" }
                                        MouseArea {
                                            id: exportBtnMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: exportManualToExcel()
                                        }
                                    }

                                    Text {
                                        text: _statusText !== "" ? _statusText : "—"
                                        font.pixelSize: 20
                                        color: "#e53935"
                                        font.bold: true
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    // Dialog hỏi mở file Excel
    Dialog {
        id: manualExcelDialog
        property string excelFileName: ""
        title: qsTr("Xuất Excel thành công")
        modal: true
        anchors.centerIn: parent
        width: 420
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: {
            if (root._lastManualExcelPath) {
                Qt.openUrlExternally("file:///" + root._lastManualExcelPath.replace(/\\/g, "/"))
            }
        }
        Column {
            spacing: 12
            width: parent.width
            Text {
                text: qsTr("✔ Đã xuất thành công: %1").arg(manualExcelDialog.excelFileName)
                font.pixelSize: 14; font.bold: true; color: "#2E7D32"
                wrapMode: Text.WordWrap; width: parent.width
            }
            Text {
                text: qsTr("Bạn có muốn mở tệp Excel này lên ngay bây giờ không?")
                font.pixelSize: 13; color: "#333"
                wrapMode: Text.WordWrap; width: parent.width
            }
        }
    }

    // Dialog thông báo lỗi xuất Excel
    Dialog {
        id: manualExcelErrorDialog
        title: qsTr("Lỗi xuất Excel")
        modal: true
        anchors.centerIn: parent
        width: 380
        standardButtons: Dialog.Ok
        Column {
            spacing: 12
            width: parent.width
            Text {
                text: qsTr("✘ Đã xảy ra lỗi khi xuất file Excel. Vui lòng kiểm tra lại quyền truy cập thư mục hoặc file đang mở.")
                font.pixelSize: 14; color: "#c62828"
                wrapMode: Text.WordWrap; width: parent.width
            }
        }
    }
}
