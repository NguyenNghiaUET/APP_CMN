import QtQuick
import QtQuick.Controls as QC
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Dialogs

Window {
    id: autoTestPlanDialog
    width: 960
    height: 620
    visible: false
    modality: Qt.ApplicationModal
    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowMinMaxButtonsHint | Qt.WindowCloseButtonHint

    property string cableName: ""  // luu ten cap dang kiem tra
    signal planSaved(string planName) // Signal khi lưu bài đo thành công
    property bool isEditMode: false  // true neu dang o che do chinh sua false neu dang ơ che do tao moi
    property var editPlanNames: []  // mang chua danh sach ten cac bai đo đã luu
    property int editPlanIndex: -1  // chi số bài đo đang dc chọn để edit
    property Window mainWindow: null //
    transientParent: mainWindow

    title: cableName
           ? (isEditMode ? qsTr("Chỉnh sửa bài đo - %1").arg(cableName) : qsTr("Tạo bài đo tự động (%1)").arg(cableName))
           : (isEditMode ? qsTr("Chỉnh sửa bài đo") : qsTr("Tạo bài đo tự động (Cable_TKC)"))

    property int selectedScriptIndex: -1 // chỉ số của script dang dc chon
    property var selectedIndices: [] // mảng các index được chọn (multi-select)
    property var selectedIndexMap: ({}) // map index → true cho O(1) lookup
    property int _selVersion: 0 // tăng mỗi khi selection thay đổi, giúp delegate chỉ re-evaluate khi cần
    property int dragFromIndex: -1 // index bắt đầu kéo
    property int dropTargetIndex: -1 // index đích khi kéo thả

    // lấy loại script đang đc chọn
    readonly property string selectedScriptType: selectedScriptIndex >= 0 && selectedScriptIndex < scriptModel.count
                                                 ? scriptModel.get(selectedScriptIndex).scriptType
                                                 : ""
    //
    readonly property var selectedScript: selectedScriptIndex >= 0 && selectedScriptIndex < scriptModel.count
                                          ? scriptModel.get(selectedScriptIndex) : null

    property int scriptListRefresh: 0  // tăng khi bấm ▼/▸ để cập nhật hiển thị thu gọn

    // === Cache visibility: map childIndex → bool (expanded) ===
    // Rebuilt khi scriptListRefresh thay đổi, giúp _isSectionChildVisible O(1) thay vì O(K)
    property var _visCache: ({})

    function _rebuildVisCache() {
        var cache = {}
        var curChildType = ""
        var curExpanded = true
        for (var i = 0; i < scriptModel.count; i++) {
            var t = String(scriptModel.get(i).scriptType || "")
            if (t.indexOf("_header") >= 0) {
                curChildType = t.replace("_header", "")
                curExpanded = scriptModel.get(i).expanded !== false
            } else if (t === curChildType) {
                cache[i] = curExpanded
            } else {
                curChildType = ""
                curExpanded = true
            }
        }
        _visCache = cache
    }
    onScriptListRefreshChanged: _rebuildVisCache()    // signal handler khi property ScriptListRefreshChange ,nó tự động gọ _rebuildVisCache() để cập nhật cache

    function _isSectionChildVisible(scriptType, itemIndex) {
        // O(1) cache lookup thay vì backward scan
        var v = _visCache[itemIndex]
        return v !== false
    }

    // Helper: set cả selectedIndices và selectedIndexMap cùng lúc
    function setSelection(indicesArray) {
        var map = {}
        for (var i = 0; i < indicesArray.length; i++) map[indicesArray[i]] = true
        selectedIndices = indicesArray
        selectedIndexMap = map
        _selVersion++  // thông báo cho delegates re-evaluate isSelected

    }

    function setScriptParam(key, value) {
        if (selectedScriptIndex >= 0 && selectedScriptIndex < scriptModel.count) {
            var item = scriptModel.get(selectedScriptIndex)
            var oldVal = item[key]
            if (oldVal !== value) {
                if (typeof window !== "undefined" && window.addLog) {
                    var scriptName = item.displayText || "Script"
                    var propNames = {
                        "displayText": "Tên hiển thị", "pinA": "Chân A", "pinB": "Chân B",
                        "portPinA": "Chân trạm A", "portPinB": "Chân trạm B",
                        "labelA": "Nhãn cổng A", "labelB": "Nhãn cổng B",
                        "limitLower": "Cận dưới", "limitUpper": "Cận trên",
                        "numReadings": "Số lần đọc", "delayBetween": "Trễ đọc",
                        "delayAfter": "Trễ chuyển mạch", "sysMsg": "TB hệ thống",
                        "userMsg": "TB người dùng", "unitIndex": "Đơn vị"
                    }
                    var pName = propNames[key] || key
                    window.addLog("Sửa bài đo", "Đổi '" + pName + "' của [" + scriptName + "] từ '" + (oldVal === undefined ? "N/A" : oldVal) + "' thành '" + value + "'")
                }
                scriptModel.setProperty(selectedScriptIndex, key, value)
            }
        }
    }

    // Áp dụng cấu hình thông số máy đo từ script hiện tại cho TẤT CẢ scripts cùng loại
    // + gửi lệnh cấu hình tới máy đo luôn (nếu đã kết nối)
    function applyDeviceConfigToAll() {
        if (!selectedScript) return
        var st = String(selectedScript.scriptType || "")
        if (!st) return

        // Xác định loại scripts cần áp dụng
        var targetTypes = []
        if (st === "continuity" || st === "sheath_insulation") {
            targetTypes = ["continuity", "sheath_insulation"]
        } else {
            return
        }

        // Lấy thông số từ script hiện tại
        var params = {}
        params.deviceConfig = selectedScript.deviceConfig !== undefined ? selectedScript.deviceConfig : false
        params.deviceSpeed = String(selectedScript.deviceSpeed || "FAST")
        params.numReadings = selectedScript.numReadings !== undefined ? Number(selectedScript.numReadings) : 3
        params.delayBetween = selectedScript.delayBetween !== undefined ? Number(selectedScript.delayBetween) : 10
        params.delayAfter = selectedScript.delayAfter !== undefined ? Number(selectedScript.delayAfter) : 100
        params.resistanceRange = String(selectedScript.resistanceRange || "RANGE_1KΩ")

        // Áp dụng cho tất cả scripts cùng loại
        var count = 0
        for (var i = 0; i < scriptModel.count; i++) {
            var t = String(scriptModel.get(i).scriptType || "")
            if (targetTypes.indexOf(t) >= 0) {
                for (var key in params) {
                    scriptModel.setProperty(i, key, params[key])
                }
                count++
            }
        }

        // Gửi lệnh cấu hình tới máy đo luôn (nếu đã kết nối)
        if (typeof keithley2110 !== "undefined" && keithley2110 && keithley2110.isOpen) {
            var range = params.resistanceRange
            var speed = params.deviceSpeed
            keithley2110.configureRM3544(range, speed)
            console.log("[CONFIG] ✅ Đã gửi cấu hình tới RM3544 - range:", range, "speed:", speed)
        } else {
            console.log("[CONFIG] ⚠ RM3544 chưa kết nối - chỉ lưu cấu hình vào scripts")
        }

        console.log("[CONFIG] Đã áp dụng cấu hình cho", count, "scripts loại:", targetTypes.join(", "))
        return count
    }

    // Tự động lưu bài đo sau khi áp dụng cấu hình máy đo
    function _autoSaveAfterConfig() {
        var name = cableName
        if (!name || typeof testPlanManager === "undefined" || !testPlanManager) return
        var jsonStr = serializeScriptModel()
        if (testPlanManager.saveTestPlan(name, jsonStr)) {
            console.log("[CONFIG] Tự động lưu bài đo:", name)
            planSaved(name)
        }
    }

    // Toggle allowRun cho tất cả scripts
    function toggleAllScripts(checked) {
        for (var i = 0; i < scriptModel.count; i++) {
            scriptModel.setProperty(i, "allowRun", checked)
        }
        scriptListRefresh++
    }

    // Toggle allowRun cho tất cả children của 1 header
    function toggleSectionScripts(headerIndex, checked) {
        var headerType = String(scriptModel.get(headerIndex).scriptType || "")
        var childType = headerType.replace("_header", "")
        // Set cho header
        scriptModel.setProperty(headerIndex, "allowRun", checked)
        // Set cho tất cả children liền sau header
        for (var i = headerIndex + 1; i < scriptModel.count; i++) {
            var t = String(scriptModel.get(i).scriptType || "")
            if (t === childType) {
                scriptModel.setProperty(i, "allowRun", checked)
            } else {
                break
            }
        }
        scriptListRefresh++
    }

    // Kiểm tra tất cả scripts có được tick không
    function isAllChecked() {
        for (var i = 0; i < scriptModel.count; i++) {
            var item = scriptModel.get(i)
            if (item.allowRun === false) return false
        }
        return scriptModel.count > 0
    }

    // Kiểm tra tất cả children của 1 header có được tick không
    function isSectionAllChecked(headerIndex) {
        if (headerIndex < 0 || headerIndex >= scriptModel.count) return true
        var item = scriptModel.get(headerIndex)
        if (!item) return true
        var headerType = String(item.scriptType || "")
        var childType = headerType.replace("_header", "")
        for (var i = headerIndex + 1; i < scriptModel.count; i++) {
            var t = String(scriptModel.get(i).scriptType || "")
            if (t === childType) {
                if (scriptModel.get(i).allowRun === false) return false
            } else {
                break
            }
        }
        return true
    }


    function updateDisplayText() {
        if (selectedScriptIndex < 0 || selectedScriptIndex >= scriptModel.count) return
        var item = scriptModel.get(selectedScriptIndex)
        var t = item.scriptType
        if (t === "notification")
            scriptModel.setProperty(selectedScriptIndex, "displayText", qsTr("Thông báo Kết nối cổng A với %1; cổng B với %2").arg(item.labelA || "").arg(item.labelB || ""))
        else if (t === "continuity")
            scriptModel.setProperty(selectedScriptIndex, "displayText", (item.pinA !== undefined && item.pinA !== "" && item.pinB !== undefined && item.pinB !== "")
                ? qsTr("Kiểm tra thông chập giữa các chân (%1_%2–%1_%3)").arg(item.labelA || "").arg(item.pinA || "").arg(item.pinB || "")
                : qsTr("Kiểm tra thông chập giữa các chân (%1 <-> %2)").arg(item.labelA || "").arg(item.labelB || ""))
        else if (t === "sheath_insulation")
            scriptModel.setProperty(selectedScriptIndex, "displayText", qsTr("Kiểm tra điện trở cách điện với vỏ [%1_%2 <-> Cable cover]").arg(item.labelA || "").arg(item.pinA || ""))
    }
     function update() {
         if(selectedScriptIndex < 0 || selectedScriptIndex >= scriptModel.count) return
         var item = scriptModel.get(selectedScriptIndex)
     }

    function serializeScriptModel() {
        var list = []
        for (var i = 0; i < scriptModel.count; i++) {
            var item = scriptModel.get(i)
            var ob = {
                displayText: String(item.displayText || ""),
                scriptType: String(item.scriptType || ""),
                labelA: String(item.labelA || ""), pinA: String(item.pinA || ""),
                labelB: String(item.labelB || ""), pinB: String(item.pinB || ""),
                portLabelA: String(item.portLabelA || ""), portLabelB: String(item.portLabelB || ""),
                allowRun: item.allowRun !== undefined ? Boolean(item.allowRun) : true,
                stopOnFail: item.stopOnFail !== undefined ? Boolean(item.stopOnFail) : true,
                unitIndex: item.unitIndex !== undefined ? Number(item.unitIndex) : 0,
                limitLower: item.limitLower !== undefined ? Number(item.limitLower) : 0,
                limitUpper: item.limitUpper !== undefined ? Number(item.limitUpper) : ((item.scriptType === "continuity" || item.scriptType === "sheath_insulation") ? 999999 : 0),
                numReadings: item.numReadings !== undefined ? Number(item.numReadings) : 3,
                delayBetween: item.delayBetween !== undefined ? Number(item.delayBetween) : 10,
                delayAfter: item.delayAfter !== undefined ? Number(item.delayAfter) : 100,
                dischargeDelay: item.dischargeDelay !== undefined ? Number(item.dischargeDelay) : 0,
                sysMsg: String(item.sysMsg || ""), userMsg: String(item.userMsg || ""),
                deviceConfig: item.deviceConfig !== undefined ? Boolean(item.deviceConfig) : false,
                resistanceRange: String(item.resistanceRange || "RANGE_1KΩ"),
                deviceSpeed: String(item.deviceSpeed || "FAST"),
                measureVoltage: item.measureVoltage !== undefined ? Number(item.measureVoltage) : 250,
                currentLimit: String(item.currentLimit || "Auto"),
                trigDelay: item.trigDelay !== undefined ? Number(item.trigDelay) : 1,
                avgCount: item.avgCount !== undefined ? Number(item.avgCount) : 1,
                avgEnabled: item.avgEnabled !== undefined ? Boolean(item.avgEnabled) : false
            }
            _addPortPinsIfValid(ob, item)
            if (ob.scriptType === "continuity_header" || ob.scriptType === "sheath_insulation_header")
                ob.expanded = item.expanded !== false
            list.push(ob)
        }
        return JSON.stringify(list)
    }

    function _addPortPinsIfValid(ob, item) {
        // Chỉ lưu portPinA/portPinB nếu giá trị >= 0 (không lưu -1)
        if (item.portPinA !== undefined && item.portPinA !== null && !isNaN(Number(item.portPinA))) {
            var portA = Number(item.portPinA)  // chuyển đổi portPinA thành số nguyên 
            if (portA >= 0) {
                ob.portPinA = portA   // gán portPinA cho ob 
            }
        }
        if (item.portPinB !== undefined && item.portPinB !== null && !isNaN(Number(item.portPinB))) {
            var portB = Number(item.portPinB)  // chuyển đổi portPinB thành số nguyên 
            if (portB >= 0) {
                ob.portPinB = portB   // gán portPinB cho ob 
            }
        }
    }

    function openWithCable(name, tableRows) {   // mở cửa sổ tạo bài đo tự động
        isEditMode = false
        cableName = name || ""    // CableName tên cáp
        show()                    // mở cửa sổ
        Qt.callLater(function() {    // Đợi 1 chút để cửa sổ hiện lên rồi mới build script
            if (tableRows && tableRows.length > 0) {
               buildScriptListFromExcel(tableRows)     // build script từ excel
            } else {
                buildScriptListFromTemplate()     // build script từ template
            }
            selectedScriptIndex = scriptModel.count > 0 ? 0 : -1      // chọn script đầu tiên
        })
    }

    function openWithSavedPlan(planName) {
        if (!planName || typeof testPlanManager === "undefined" || !testPlanManager)
            return
        isEditMode = true
        editPlanNames = testPlanManager.planNames() || []
        var idx = editPlanNames.indexOf(planName)
        editPlanIndex = idx >= 0 ? idx : 0
        show()
        Qt.callLater(function() {
            loadPlanIntoModel(planName)
            selectedScriptIndex = scriptModel.count > 0 ? 0 : -1
        })
    }

    function openEditTab(preferredPlanName) {
        isEditMode = true
        if (typeof testPlanManager === "undefined" || !testPlanManager) {
            cableName = ""
            scriptModel.clear()
            show()
            return
        }
        var names = testPlanManager.planNames()
        editPlanNames = names || []

        // Show cửa sổ ngay lập tức
        show()

        // Load data sau 50ms để window hiện trước
        var pName = preferredPlanName
        Qt.callLater(function() {
            if (editPlanNames.length > 0) {
                var idx = pName ? editPlanNames.indexOf(pName) : -1
                if (idx >= 0) {
                    loadPlanIntoModel(editPlanNames[idx])
                    editPlanIndex = idx
                } else {
                    loadPlanIntoModel(editPlanNames[0])
                    editPlanIndex = 0
                }
            } else {
                cableName = ""
                scriptModel.clear()
                editPlanIndex = -1
            }
            selectedScriptIndex = scriptModel.count > 0 ? 0 : -1
        })
    }

    // === Batch loading system ===
    property var _pendingScripts: []
    property int _batchIndex: 0
    property bool _isLoading: false

    // Đếm tổng số cặp điểm đo (measurable scripts) cho full bài
    function countMeasurablePairs() {
        var total = 0, wr = 0, cont = 0, ins = 0, sheath = 0
        for (var i = 0; i < scriptModel.count; i++) {
            var t = String(scriptModel.get(i).scriptType || "")
            if (t === "continuity") { cont++; total++ }
            else if (t === "sheath_insulation") { sheath++; total++ }
        }
        return { total: total, cont: cont, sheath: sheath }
    }

    Timer {
        id: batchLoadTimer
        interval: 1  // yield to event loop mỗi batch
        repeat: true
        onTriggered: {
            var batchSize = 80
            var end = Math.min(autoTestPlanDialog._batchIndex + batchSize, autoTestPlanDialog._pendingScripts.length)
            for (var i = autoTestPlanDialog._batchIndex; i < end; i++)
                scriptModel.append(autoTestPlanDialog._pendingScripts[i])
            autoTestPlanDialog._batchIndex = end
            if (autoTestPlanDialog._batchIndex >= autoTestPlanDialog._pendingScripts.length) {
                stop()
                autoTestPlanDialog._isLoading = false
                autoTestPlanDialog._pendingScripts = []
                autoTestPlanDialog._rebuildVisCache()
                autoTestPlanDialog.selectedScriptIndex = scriptModel.count > 0 ? 0 : -1
            }
        }
    }

    function loadPlanIntoModel(planName) {
        if (!planName)
            return
        cableName = planName
        batchLoadTimer.stop()
        _isLoading = false

        // Ngắt model khỏi ListView
        if (typeof scriptListView !== "undefined" && scriptListView)
            scriptListView.model = null

        scriptModel.clear()
        if (typeof testPlanManager === "undefined" || !testPlanManager) {
            if (typeof scriptListView !== "undefined" && scriptListView)
                scriptListView.model = scriptModel
            return
        }
        var scripts = testPlanManager.loadScripts(planName)
        if (!scripts || scripts.length === 0) {
            if (typeof scriptListView !== "undefined" && scriptListView)
                scriptListView.model = scriptModel
            return
        }

        // Pre-process tất cả items trước
        var prepared = []
        for (var i = 0; i < scripts.length; i++)
            prepared.push(_defaultParams(scripts[i]))

        // Gắn model lại trước khi batch load
        if (typeof scriptListView !== "undefined" && scriptListView)
            scriptListView.model = scriptModel

        // Batch load
        _pendingScripts = prepared
        _batchIndex = 0
        _isLoading = true
        batchLoadTimer.start()
    }

    function _defaultParams(o) {
        var d = {
            displayText: o.displayText || "", scriptType: o.scriptType || "",
            labelA: o.labelA || "", pinA: o.pinA || "",
            // Thông chập cùng giắc: nếu labelB rỗng thì lấy labelA
            labelB: (o.labelB || "") !== "" ? (o.labelB || "")
                : (o.scriptType === "continuity" ? (o.labelA || "") : ""),
            pinB: o.pinB || "",
            portLabelA: o.portLabelA || "", portLabelB: o.portLabelB || "",
            allowRun: o.allowRun !== undefined ? o.allowRun : true,
            stopOnFail: o.stopOnFail !== undefined ? o.stopOnFail : true,
            unitIndex: o.unitIndex !== undefined ? o.unitIndex : 0,
            limitLower: o.limitLower !== undefined ? o.limitLower : 0,
            limitUpper: (function() {
                var def = (o.scriptType === "continuity" || o.scriptType === "sheath_insulation") ? 999999 : 0
                var v = o.limitUpper !== undefined ? Number(o.limitUpper) : def
                return v
            })(),
            numReadings: o.numReadings !== undefined ? o.numReadings : 3,
            delayBetween: o.delayBetween !== undefined ? o.delayBetween : 10,
            delayAfter: o.delayAfter !== undefined ? o.delayAfter : 100,
            dischargeDelay: o.dischargeDelay !== undefined ? o.dischargeDelay : 0,
            sysMsg: o.sysMsg || "", userMsg: o.userMsg || "",
            deviceConfig: o.deviceConfig !== undefined ? o.deviceConfig : false,
            resistanceRange: o.resistanceRange || "RANGE_1KΩ",
            deviceSpeed: o.deviceSpeed || "FAST",
            measureVoltage: o.measureVoltage !== undefined ? o.measureVoltage : 250,
            currentLimit: o.currentLimit || "Auto",
            trigDelay: o.trigDelay !== undefined ? o.trigDelay : 1,
            avgCount: o.avgCount !== undefined ? o.avgCount : 1,
            avgEnabled: o.avgEnabled !== undefined ? o.avgEnabled : false
        }
        // Chỉ đọc portPinA/portPinB từ file nếu giá trị >= 0 (không parse từ pinA/pinB)
        if (o.portPinA !== undefined && o.portPinA !== null && !isNaN(Number(o.portPinA))) {
            var portA = Number(o.portPinA)
            if (portA >= 0) {
                d.portPinA = portA
            }
        }
        if (o.portPinB !== undefined && o.portPinB !== null && !isNaN(Number(o.portPinB))) {
            var portB = Number(o.portPinB)
            if (portB >= 0) {
                d.portPinB = portB
            }
        }
        return d
    }

    function _parseLimitValue(str) {
        if (!str) return NaN
        var s = String(str).trim().replace(/^[≤≥<>=\s]+/, "").replace(",", ".")
        return parseFloat(s)
    }

    function _isHeaderRow(row) {
        if (!row) return false
        var c0 = String(row.col0 || "").trim()
        var c1 = String(row.col1 || "").trim()
        var c3 = String(row.col3 || "").trim()
        // Hàng tiêu đề Excel có "Nhãn giắc đầu A", "Tên chân đầu A", "Nhãn giắc đầu B" → bỏ qua, dùng dữ liệu thật (CS, HC.X15-R, 4, 5...)
        return (c0 === qsTr("Nhãn giắc đầu A") && c3 === qsTr("Nhãn giắc đầu B")) || c1 === qsTr("Tên chân đầu A")
    }

    function buildScriptListFromExcel(rows) {
        if (typeof scriptListView !== "undefined" && scriptListView)
            scriptListView.model = null
        scriptModel.clear()
        scriptModel.append({ displayText: qsTr("Khởi tạo hệ thống"), scriptType: "system_init" })
        var a = buildScriptArrayFromExcel(rows)
        for (var j = 0; j < a.length; j++) scriptModel.append(a[j])
        _rebuildVisCache()
        Qt.callLater(function() {
            if (typeof scriptListView !== "undefined" && scriptListView) {
                scriptListView.model = scriptModel
                scriptListView.currentIndex = autoTestPlanDialog.selectedScriptIndex
            }
        })
    }

    function _buildScriptListFromExcelLegacy(rows) {
        var i = 0
        while (i < rows.length) {
            var r = rows[i]
            if (_isHeaderRow(r)) { i++; continue }
            var labelA = String(r.col0 || "").trim()
            var labelB = String(r.col3 || "").trim()
            if (!labelA && !labelB) { i++; continue }
            var group = []
            while (i < rows.length) {
                var row = rows[i]
                if (_isHeaderRow(row)) {
                    i++
                    continue
                }
                var la = String(row.col0 || "").trim()
                var lb = String(row.col3 || "").trim()
                if (!la && !lb) {
                    i++
                    continue
                }
                if (group.length > 0 && (la !== labelA || lb !== labelB))
                    break
                labelA = la
                labelB = lb
                group.push(row)
                i++
            }
            // Bỏ qua nhóm có Cable cover (chỉ dùng cho cách điện vỏ, không thêm thông báo/dây dẫn)
            var cableCover = "Cable cover"
            if (labelA === cableCover || labelB === cableCover)
                continue

            // Mỗi lần đổi cổng B (nhóm mới): thông báo kết nối cổng A với labelA, cổng B với labelB
            var notMsg = qsTr("Thông báo Kết nối cổng A với %1; cổng B với %2").arg(labelA).arg(labelB)
            scriptModel.append(_defaultParams({
                displayText: notMsg, scriptType: "notification",
                labelA: labelA, labelB: labelB, sysMsg: notMsg, userMsg: notMsg
            }))
            // Danh sách chân từng đầu giắc (để thông chập / cách điện vỏ trong cùng connector)
            var pinsA = []
            var pinsB = []
            for (var gx = 0; gx < group.length; gx++) {
                var gr = group[gx]
                var pa = String(gr.col1 || "").trim()
                var portA = parseInt(String(gr.col2 || "").trim(), 10)
                if (isNaN(portA)) portA = parseInt(pa, 10)
                if (pa !== "" && pinsA.findIndex(function(x) { return x.pin === pa }) < 0)
                    pinsA.push({ pin: pa, port: portA })
                var pb = String(gr.col4 || "").trim()
                var portB = parseInt(String(gr.col5 || "").trim(), 10)
                if (isNaN(portB)) portB = parseInt(pb, 10)
                if (pb !== "" && pinsB.findIndex(function(x) { return x.pin === pb }) < 0)
                    pinsB.push({ pin: pb, port: portB })
            }
            // 4. Thông chập: header sổ ra (▼/▸) + các cặp trong cùng nhãn giắc
            scriptModel.append(_defaultParams({
                displayText: qsTr("Kiểm tra thông chập giữa các chân"),
                scriptType: "continuity_header",
                expanded: true
            }))
            for (var ia = 0; ia < pinsA.length; ia++) {
                for (var ja = ia + 1; ja < pinsA.length; ja++) {
                    var contA = {
                        displayText: qsTr("Kiểm tra thông chập giữa các chân (%1_%2–%1_%3)").arg(labelA).arg(pinsA[ia].pin).arg(pinsA[ja].pin),
                        scriptType: "continuity", labelA: labelA, labelB: labelA, pinA: pinsA[ia].pin, pinB: pinsA[ja].pin,
                        portPinA: pinsA[ia].port, portPinB: pinsA[ja].port
                    }
                    scriptModel.append(_defaultParams(contA))
                }
            }
            for (var ib = 0; ib < pinsB.length; ib++) {
                for (var jb = ib + 1; jb < pinsB.length; jb++) {
                    var contB = {
                        displayText: qsTr("Kiểm tra thông chập giữa các chân (%1_%2–%1_%3)").arg(labelB).arg(pinsB[ib].pin).arg(pinsB[jb].pin),
                        scriptType: "continuity", labelA: labelB, labelB: labelB, pinA: pinsB[ib].pin, pinB: pinsB[jb].pin,
                        portPinA: pinsB[ib].port, portPinB: pinsB[jb].port
                    }
                    scriptModel.append(_defaultParams(contB))
                }
            }
            // 5. Cách điện vỏ (Cable cover): header sổ ra (−/+) + mỗi chân đo với Cable cover
            scriptModel.append(_defaultParams({
                displayText: qsTr("Kiểm tra điện trở cách điện với vỏ"),
                scriptType: "sheath_insulation_header",
                expanded: true
            }))


            for (var s = 0; s < pinsA.length; s++) {
                scriptModel.append(_defaultParams({
                    displayText: qsTr("Kiểm tra điện trở cách điện với vỏ [%1_%2 <-> Cable cover]").arg(labelA).arg(pinsA[s].pin),
                    scriptType: "sheath_insulation", labelA: labelA, pinA: pinsA[s].pin, labelB: "Cable cover", pinB: "",
                    portPinA: pinsA[s].port
                }))
            }
            for (var s2 = 0; s2 < pinsB.length; s2++) {
                scriptModel.append(_defaultParams({
                    displayText: qsTr("Kiểm tra điện trở cách điện với vỏ [%1_%2 <-> Cable cover]").arg(labelB).arg(pinsB[s2].pin),
                    scriptType: "sheath_insulation", labelA: labelB, pinA: pinsB[s2].pin, labelB: "Cable cover", pinB: "",
                    portPinA: pinsB[s2].port
                }))
            }
        }
    }

    function buildScriptArrayFromExcel(rows) {
        var arr = []
        var inSheathSection = false
        var firstDataRow = true

        for (var i = 0; i < rows.length; i++) {
            var r = rows[i]
            if (_isHeaderRow(r)) continue

            var c0 = String(r.col0 || "").trim()
            var c1 = String(r.col1 || "").trim()
            var c2 = String(r.col2 || "").trim()
            var c3 = String(r.col3 || "").trim()
            var c4 = String(r.col4 || "").trim()
            var c5 = String(r.col5 || "").trim()
            var c6 = String(r.col6 || "").trim()

            if (!c0 && !c1) continue  // dòng trống

            // Phát hiện dòng phân cách section: "Đo điện trở các chân connector với vỏ"
            if (!inSheathSection && c0.indexOf("đo điện trở") >= 0 || c0.indexOf("Đo điện trở") >= 0) {
                if (c1 === "" && c2 === "") {  // xác nhận là dòng header, không phải data
                    arr.push(_defaultParams({
                        displayText: qsTr("Kiểm tra điện trở cách điện với vỏ"),
                        scriptType: "sheath_insulation_header", expanded: true
                    }))
                    inSheathSection = true
                    continue
                }
            }

            if (!inSheathSection) {
                // === Section 1: Thông chập ===
                if (firstDataRow) {
                    var notMsg = qsTr("Thông báo Kết nối cổng A với %1; cổng B với %2").arg(c0).arg(c3)
                    arr.push(_defaultParams({ displayText: notMsg, scriptType: "notification",
                        labelA: c0, labelB: c3, sysMsg: notMsg, userMsg: notMsg }))
                    arr.push(_defaultParams({ displayText: qsTr("Kiểm tra thông chập giữa các chân"),
                        scriptType: "continuity_header", expanded: true }))
                    firstDataRow = false
                }

                var portA = parseInt(c2, 10)
                var portB = parseInt(c5, 10)
                var limitUp = _parseLimitValue(c6)
                if (isNaN(limitUp) || limitUp <= 0) limitUp = 0.8

                arr.push(_defaultParams({
                    displayText: qsTr("Thông chập [%1_%2 → %3_%4]").arg(c0).arg(c1).arg(c3).arg(c4),
                    scriptType: "continuity",
                    labelA: c0, pinA: c1, labelB: c3, pinB: c4,
                    portPinA: isNaN(portA) ? -1 : portA,
                    portPinB: isNaN(portB) ? -1 : portB,
                    portLabelA: isNaN(portA) ? "" : "A",
                    portLabelB: isNaN(portB) ? "" : "B",
                    limitLower: 0, limitUpper: limitUp
                }))
            } else {
                // === Section 2: Cách điện với vỏ ===
                var portA2 = parseInt(c2, 10)
                var limitLow = _parseLimitValue(c6)
                if (isNaN(limitLow) || limitLow <= 0) limitLow = 100

                arr.push(_defaultParams({
                    displayText: qsTr("Cách điện vỏ [%1_%2 → Ground]").arg(c0).arg(c1),
                    scriptType: "sheath_insulation",
                    labelA: c0, pinA: c1,
                    labelB: "Ground plane", pinB: "Ground",
                    portPinA: isNaN(portA2) ? -1 : portA2,
                    portLabelA: isNaN(portA2) ? "" : "A",
                    limitLower: limitLow, limitUpper: 999999
                }))
            }
        }
        return arr
    }


    function appendScriptsFromExcel(rows, insertIndex) {
        if (!rows || rows.length === 0) return
        var a = buildScriptArrayFromExcel(rows)
        var idx = insertIndex >= 0 ? insertIndex : scriptModel.count
        for (var j = 0; j < a.length; j++) scriptModel.insert(idx + j, a[j])
        selectedScriptIndex = idx
        scriptListRefresh++
    }

    function buildScriptListFromTemplate() {
        scriptModel.clear()
        scriptModel.append(_defaultParams({ displayText: qsTr("Khởi tạo hệ thống"), scriptType: "system_init" }))
        var notT = cableName ? qsTr("Thông báo Kết nối cổng A với %1; cổng B với ...").arg(cableName) : qsTr("Thông báo Kết nối cổng A với ...; cổng B với ...")
        scriptModel.append(_defaultParams({ displayText: notT, scriptType: "notification", labelA: cableName || "", labelB: "", sysMsg: notT, userMsg: notT }))
        scriptModel.append(_defaultParams({ displayText: qsTr("Kiểm tra thông chập giữa các chân [Connector_pin1 <-> Connector_pin2]"), scriptType: "continuity", labelA: "", pinA: "", pinB: "", labelB: "" }))
        scriptModel.append(_defaultParams({ displayText: qsTr("Kiểm tra điện trở cách điện với vỏ [X <-> Cable cover]"), scriptType: "sheath_insulation", labelA: "", pinA: "", labelB: "Cable cover", pinB: "" }))
    }

    ListModel {
        id: scriptModel
    }

    // Danh sách bài đo mẫu (thêm vào bảng từ đây hoặc từ menu)
    ListModel {
        id: templateListModel
        ListElement { displayText: qsTr("Khởi tạo hệ thống"); scriptType: "system_init" }
        ListElement { displayText: qsTr("Hiện thông báo"); scriptType: "notification" }
        ListElement { displayText: qsTr("Thiết lập rơ le"); scriptType: "relay" }
        ListElement { displayText: qsTr("Lưu kết quả đo"); scriptType: "save_result" }
        ListElement { displayText: qsTr("Kiểm tra thông chập giữa các chân"); scriptType: "continuity" }
        ListElement { displayText: qsTr("Kiểm tra điện trở cách điện với vỏ"); scriptType: "sheath_insulation" }
        ListElement { displayText: qsTr("➕ Thêm cặp cổng mới"); scriptType: "add_connector_pair" }
    }

    property var copiedScript: null  // Sao chép bài đo (Ctrl+C / Dán)
    property int scriptContextMenuIndex: -1  // Dòng đang mở menu chuột phải

    function insertTemplateScript(scriptType, atIndex, templateDisplayText) {
        if (typeof window !== "undefined" && window.addLog) {
            window.addLog("Sửa bài đo", "Chèn script mới: " + (templateDisplayText || scriptType) + " tại vị trí " + (atIndex + 1))
        }
        var idx = atIndex >= 0 ? atIndex : scriptModel.count
        var t = String(scriptType || "")
        var displayText = templateDisplayText || ""
        var params = {}

        // ── Thêm cặp cổng mới → mở dialog ──
        if (t === "add_connector_pair") {
            addConnectorPairDialog._insertAtIndex = -1  // Luôn chèn xuống cuối script list
            addConnectorPairDialog.open()
            return
        }

        if (t === "system_init") {
            displayText = displayText || qsTr("Khởi tạo hệ thống")
            params = { displayText: displayText, scriptType: "system_init" }
        } else if (t === "notification") {
            displayText = displayText || (cableName ? qsTr("Thông báo Kết nối cổng A với %1; cổng B với ...").arg(cableName) : qsTr("Thông báo Kết nối cổng A với ...; cổng B với ..."))
            params = _defaultParams({ displayText: displayText, scriptType: "notification", labelA: cableName || "", labelB: "", sysMsg: displayText, userMsg: displayText })
        } else if (t === "continuity") {
            params = _defaultParams({ displayText: displayText || qsTr("Kiểm tra thông chập giữa các chân [Connector_pin1 <-> Connector_pin2]"), scriptType: "continuity", labelA: "", pinA: "", pinB: "", labelB: "" })
        } else if (t === "sheath_insulation") {
            params = _defaultParams({ displayText: displayText || qsTr("Kiểm tra điện trở cách điện với vỏ [X <-> Cable cover]"), scriptType: "sheath_insulation", labelA: "", pinA: "", labelB: "Cable cover", pinB: "" })
        } else {
            params = _defaultParams({ displayText: displayText || qsTr("Bài đo"), scriptType: t })
        }
        scriptModel.insert(idx, params)
        selectedScriptIndex = idx
        scriptListRefresh++
    }

    // ═══ Sinh scripts cho 1 cặp cổng mới ═══
    // Mỗi cặp chân tạo: continuity + sheath_insulation
    // pinsA = [{pin: "4", port: 4}, ...], pinsB = [{pin: "4", port: 4}, ...]
    function buildScriptsForConnectorPair(labelA, labelB, pinsA, pinsB, insertIndex) {
        var arr = []
        // 1. Notification
        var notMsg = qsTr("Thông báo Kết nối cổng A với %1; cổng B với %2").arg(labelA).arg(labelB)
        arr.push(_defaultParams({ displayText: notMsg, scriptType: "notification", labelA: labelA, labelB: labelB, sysMsg: notMsg, userMsg: notMsg }))
        var maxLen = Math.max(pinsA.length, pinsB.length)

        // 2. Continuity header + scripts (mỗi cặp chân A↔B tạo 1 bài)
        arr.push(_defaultParams({ displayText: qsTr("Kiểm tra thông chập giữa các chân"), scriptType: "continuity_header", expanded: true }))
        for (var c = 0; c < maxLen; c++) {
            var cPinA = c < pinsA.length ? pinsA[c] : pinsA[pinsA.length - 1]
            var cPinB = c < pinsB.length ? pinsB[c] : pinsB[pinsB.length - 1]
            arr.push(_defaultParams({ displayText: qsTr("Kiểm tra thông chập giữa các chân (%1_%2–%3_%4)").arg(labelA).arg(cPinA.pin).arg(labelB).arg(cPinB.pin),
                scriptType: "continuity", labelA: labelA, labelB: labelB, pinA: cPinA.pin, pinB: cPinB.pin,
                portPinA: cPinA.port, portPinB: cPinB.port }))
        }

        // 3. Sheath insulation header + scripts (mỗi chân tạo 1 bài đo với vỏ)
        arr.push(_defaultParams({ displayText: qsTr("Kiểm tra điện trở cách điện với vỏ"), scriptType: "sheath_insulation_header", expanded: true }))
        for (var sa = 0; sa < pinsA.length; sa++)
            arr.push(_defaultParams({ displayText: qsTr("Kiểm tra điện trở cách điện với vỏ [%1_%2 <-> Cable cover]").arg(labelA).arg(pinsA[sa].pin),
                scriptType: "sheath_insulation", labelA: labelA, pinA: pinsA[sa].pin, labelB: "Cable cover", pinB: "", portPinA: pinsA[sa].port }))
        for (var sb = 0; sb < pinsB.length; sb++)
            arr.push(_defaultParams({ displayText: qsTr("Kiểm tra điện trở cách điện với vỏ [%1_%2 <-> Cable cover]").arg(labelB).arg(pinsB[sb].pin),
                scriptType: "sheath_insulation", labelA: labelB, pinA: pinsB[sb].pin, labelB: "Cable cover", pinB: "", portPinA: pinsB[sb].port }))

        // Insert tất cả vào scriptModel
        var idx = insertIndex >= 0 ? insertIndex : scriptModel.count
        for (var k = 0; k < arr.length; k++) scriptModel.insert(idx + k, arr[k])
        selectedScriptIndex = idx
        scriptListRefresh++
        _rebuildVisCache()
        if (typeof window !== "undefined" && window.addLog)
            window.addLog("Sửa bài đo", "Đã thêm cặp cổng " + labelA + " ↔ " + labelB + " (" + arr.length + " scripts)")
        return arr.length
    }

    function deleteScriptAt(index) {
        if (index < 0 || index >= scriptModel.count) return
        if (typeof window !== "undefined" && window.addLog) {
            window.addLog("Sửa bài đo", "Xóa script: " + (scriptModel.get(index).displayText || "Script") + " tại vị trí " + (index + 1))
        }
        scriptModel.remove(index)
        if (selectedScriptIndex >= scriptModel.count) selectedScriptIndex = scriptModel.count - 1
        else if (selectedScriptIndex >= index && selectedScriptIndex > 0) selectedScriptIndex--
        scriptListRefresh++
    }

    function copyScriptAt(index) {
        if (index < 0 || index >= scriptModel.count) return
        var item = scriptModel.get(index)
        if (typeof window !== "undefined" && window.addLog) {
            window.addLog("Sửa bài đo", "Copy script: " + (item.displayText || "Script"))
        }
        copiedScript = {}
        for (var k in item) copiedScript[k] = item[k]
    }

    function pasteScriptAt(index) {
        if (!copiedScript) return
        if (typeof window !== "undefined" && window.addLog) {
            window.addLog("Sửa bài đo", "Paste script: " + (copiedScript.displayText || "Script") + " vào vị trí " + (index + 2))
        }
        var idx = index >= 0 ? index : scriptModel.count
        scriptModel.insert(idx, copiedScript)
        selectedScriptIndex = idx
        scriptListRefresh++
    }

    function moveScriptAt(fromIndex, direction) {
        if (fromIndex < 0 || fromIndex >= scriptModel.count) return
        var toIndex = direction === "up" ? fromIndex - 1 : fromIndex + 1
        if (toIndex < 0 || toIndex >= scriptModel.count) return

        if (typeof window !== "undefined" && window.addLog) {
            window.addLog("Sửa bài đo", "Di chuyển script: '" + (scriptModel.get(fromIndex).displayText || "Script") + "' từ " + (fromIndex + 1) + " đến " + (toIndex + 1))
        }

        scriptModel.move(fromIndex, toIndex, 1)
        selectedScriptIndex = toIndex
        // Cập nhật selectedIndices
        setSelection([toIndex])
        scriptListRefresh++
    }

    // Di chuyển nhiều script đã chọn đến vị trí targetIndex
    // Tối ưu: contiguous block dùng 1 lệnh move(), non-contiguous dùng rebuild
    function moveSelectedScriptsTo(targetIdx) {
        if (selectedIndices.length === 0) return
        if (typeof window !== "undefined" && window.addLog) {
            window.addLog("Sửa bài đo", "Di chuyển " + selectedIndices.length + " script đến vị trí " + (targetIdx + 1))
        }
        var sorted = selectedIndices.slice().sort(function(a, b) { return a - b })
        var blockSize = sorted.length

        // Tính vị trí đích đã điều chỉnh (loại bỏ ảnh hưởng của selected items)
        var adjustedTarget = targetIdx
        for (var m = 0; m < sorted.length; m++) {
            if (sorted[m] < targetIdx) adjustedTarget--
        }
        if (adjustedTarget < 0) adjustedTarget = 0
        var maxPos = scriptModel.count - blockSize
        if (adjustedTarget > maxPos) adjustedTarget = maxPos

        // Kiểm tra nếu vị trí đích trùng vị trí hiện tại → không cần di chuyển
        var alreadyInPlace = true
        for (var c = 0; c < sorted.length; c++) {
            if (sorted[c] !== adjustedTarget + c) {
                alreadyInPlace = false
                break
            }
        }
        if (alreadyInPlace) return

        // Kiểm tra selection có liền nhau không (contiguous block)
        var isContiguous = true
        for (var k = 1; k < sorted.length; k++) {
            if (sorted[k] !== sorted[k - 1] + 1) {
                isContiguous = false
                break
            }
        }

        if (isContiguous) {
            // === FAST PATH: contiguous block → 1 lệnh move() duy nhất ===
            var fromStart = sorted[0]
            scriptModel.move(fromStart, adjustedTarget, blockSize)
        } else {
            // === SLOW PATH: non-contiguous → rebuild bằng JS array ===
            var allItems = []
            for (var i = 0; i < scriptModel.count; i++) {
                var item = scriptModel.get(i)
                var ob = {}
                for (var key in item) ob[key] = item[key]
                allItems.push(ob)
            }
            var selSet = {}
            for (var s = 0; s < sorted.length; s++) selSet[sorted[s]] = true
            var selectedItems = []
            var remainingItems = []
            for (var j = 0; j < allItems.length; j++) {
                if (selSet[j]) selectedItems.push(allItems[j])
                else remainingItems.push(allItems[j])
            }
            var at = adjustedTarget
            if (at > remainingItems.length) at = remainingItems.length
            var newOrder = remainingItems.slice(0, at)
                .concat(selectedItems)
                .concat(remainingItems.slice(at))
            scriptModel.clear()
            for (var n = 0; n < newOrder.length; n++) {
                scriptModel.append(newOrder[n])
            }
        }

        // Cập nhật selection
        var newIndices = []
        var newMap = {}
        for (var p = 0; p < blockSize; p++) {
            newIndices.push(adjustedTarget + p)
            newMap[adjustedTarget + p] = true
        }
        selectedIndices = newIndices
        selectedIndexMap = newMap
        selectedScriptIndex = newIndices.length > 0 ? newIndices[0] : -1
        _selVersion++
        _rebuildVisCache()
    }

    // Xóa nhiều script đã chọn
    function deleteSelectedScripts() {
        if (selectedIndices.length === 0) return
        var sorted = selectedIndices.slice().sort(function(a, b) { return b - a }) // Giảm dần
        for (var i = 0; i < sorted.length; i++) {
            scriptModel.remove(sorted[i])
        }
        setSelection([])
        if (scriptModel.count > 0) {
            selectedScriptIndex = Math.min(sorted[sorted.length - 1], scriptModel.count - 1)
            setSelection([selectedScriptIndex])
        } else {
            selectedScriptIndex = -1
        }
        scriptListRefresh++
    }

    function openScriptContextMenu(idx) {
        scriptContextMenuIndex = idx
        scriptContextMenu.popup()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        QC.SplitView {
            orientation: Qt.Horizontal
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Danh sách bài đo (mẫu) — chọn để thêm vào bảng Scripts
            Rectangle {
                id: templatePanel
                QC.SplitView.minimumWidth: 180
                QC.SplitView.preferredWidth: 220
                QC.SplitView.maximumWidth: 320
                color: "#f5f5f5"
                border.color: "#d0d0d0"
                radius: 4
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4
                    QC.Label {
                        text: qsTr("Danh sách bài đo")
                        font.bold: true
                        font.pixelSize: 14
                        color: "#1976D2"
                        Layout.fillWidth: true
                    }
                    QC.ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        QC.ScrollBar.vertical.policy: QC.ScrollBar.AlwaysOn
                        ListView {
                            id: templateListView
                            width: templatePanel.width - 24
                            model: templateListModel
                            delegate: QC.ItemDelegate {
                                width: templateListView.width - 4
                                height: 32
                                contentItem: RowLayout {
                                    spacing: 6
                                    Item { Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
                                    QC.Label {
                                        Layout.fillWidth: true
                                        text: model.displayText
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }
                                }
                                onClicked: insertTemplateScript(model.scriptType, autoTestPlanDialog.selectedScriptIndex >= 0 ? autoTestPlanDialog.selectedScriptIndex + 1 : scriptModel.count, model.displayText)
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: scriptsPanel
                QC.SplitView.minimumWidth: 200
                QC.SplitView.preferredWidth: 340
                QC.SplitView.maximumWidth: 700
                color: "#fafafa"
                border.color: "#d0d0d0"
                radius: 4
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        visible: isEditMode && editPlanNames.length > 0
                        QC.Label { text: qsTr("Bài đo:"); font.pixelSize: 12; Layout.preferredWidth: 50 }
                        QC.ComboBox {
                            id: editPlanCombo
                            Layout.fillWidth: true
                            model: editPlanNames
                            currentIndex: editPlanIndex
                            onCurrentIndexChanged: {
                                if (currentIndex >= 0 && currentIndex < editPlanNames.length && currentIndex !== editPlanIndex) {
                                    editPlanIndex = currentIndex
                                    loadPlanIntoModel(editPlanNames[currentIndex])
                                    selectedScriptIndex = scriptModel.count > 0 ? 0 : -1
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        QC.CheckBox {
                            id: checkAllScriptsBox
                            checked: {
                                var _ = autoTestPlanDialog.scriptListRefresh
                                return autoTestPlanDialog.isAllChecked()
                            }
                            onToggled: autoTestPlanDialog.toggleAllScripts(checked)
                            padding: 0
                            indicator.width: 16
                            indicator.height: 16
                        }
                        QC.Label {
                            text: autoTestPlanDialog._isLoading
                                ? qsTr("Scripts (%1/%2)").arg(scriptModel.count).arg(autoTestPlanDialog._pendingScripts.length)
                                : qsTr("Scripts (%1)").arg(scriptModel.count)
                            font.bold: true
                            font.pixelSize: 14
                            color: autoTestPlanDialog._isLoading ? "#FF9800" : "#1976D2"
                            Layout.fillWidth: true
                        }

                        // Tổng số cặp điểm gửi MCU
                        Rectangle {
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: pairCountLabel.implicitWidth + 12
                            color: "#E3F2FD"
                            border.color: "#90CAF9"
                            radius: 3
                            visible: !autoTestPlanDialog._isLoading && scriptModel.count > 0
                            QC.Label {
                                id: pairCountLabel
                                anchors.centerIn: parent
                                property var pairInfo: {
                                    var _ = autoTestPlanDialog.scriptListRefresh
                                    return autoTestPlanDialog.countMeasurablePairs()
                                }
                                text: qsTr("MCU: %1 cặp").arg(pairInfo.total)
                                font.pixelSize: 11
                                font.bold: true
                                color: "#1565C0"

                                QC.ToolTip.visible: pairCountMa.containsMouse
                                QC.ToolTip.text: qsTr("Điện trở dây: %1\nThông chập: %2\nCách điện: %3\nCách điện vỏ: %4")
                                    .arg(pairInfo.wr).arg(pairInfo.cont).arg(pairInfo.ins).arg(pairInfo.sheath)
                            }
                            MouseArea {
                                id: pairCountMa
                                anchors.fill: parent
                                hoverEnabled: true
                            }
                        }
                    }
                    QC.ScrollView {
                        id: scriptScrollView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ListView {
                            id: scriptListView
                            width: scriptScrollView.availableWidth
                            height: scriptScrollView.availableHeight
                            clip: true
                            cacheBuffer: 2000
                            reuseItems: true
                            model: scriptModel
                            currentIndex: autoTestPlanDialog.selectedScriptIndex
                            delegate: Item {
                                id: scriptDelegate
                                width: scriptListView.width - 4
                                height: {
                                    var _ = autoTestPlanDialog.scriptListRefresh
                                    var t = model.scriptType
                                    // Headers và types không collapsible: luôn hiển thị
                                    if (t === "notification" || t === "system_init" || t === "relay" || t === "save_result"
                                        || t === "continuity_header" || t === "sheath_insulation_header")
                                        return 32
                                    // Children: kiểm tra header cha có expanded không
                                    if (t === "continuity" || t === "sheath_insulation") {
                                        if (!autoTestPlanDialog._isSectionChildVisible(t, index)) return 0
                                    }
                                    return 32
                                }
                                visible: height > 0

                                // Drop indicator line
                                Rectangle {
                                    width: parent.width
                                    height: 3
                                    color: "#2196F3"
                                    visible: autoTestPlanDialog.dropTargetIndex === index
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    z: 10
                                }

                                property bool isSelected: {
                                    var _ = autoTestPlanDialog._selVersion  // depend on version counter
                                    return autoTestPlanDialog.selectedIndexMap[index] === true
                                }

                                property bool isHeader: String(model.scriptType || "").indexOf("_header") >= 0

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 2
                                    color: scriptDelegate.isHeader ? (scriptDelegate.isSelected ? "#BBDEFB" : "#E8EAF6")
                                         : (scriptDelegate.isSelected ? "#BBDEFB" : (scriptListView.currentIndex === index ? "#E3F2FD" : "transparent"))
                                    border.color: scriptDelegate.isSelected ? "#2196F3" : (scriptDelegate.isHeader ? "#9FA8DA" : "transparent")
                                    border.width: scriptDelegate.isSelected ? 1.5 : (scriptDelegate.isHeader ? 1 : 0)
                                    opacity: (model.allowRun !== false) ? 1.0 : 0.45

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 4
                                        anchors.rightMargin: 6
                                        spacing: 2
                                        // CheckBox cho phép chạy
                                        QC.CheckBox {
                                            checked: {
                                                if (scriptDelegate.isHeader) {
                                                    var _ = autoTestPlanDialog.scriptListRefresh
                                                    return autoTestPlanDialog.isSectionAllChecked(index)
                                                }
                                                return model.allowRun !== false
                                            }
                                            padding: 0
                                            indicator.width: 14
                                            indicator.height: 14
                                            onToggled: {
                                                if (scriptDelegate.isHeader) {
                                                    autoTestPlanDialog.toggleSectionScripts(index, checked)
                                                } else {
                                                    scriptModel.setProperty(index, "allowRun", checked)
                                                }
                                            }
                                        }
                                        // Icon: ▼/▶ cho header, space cho children
                                        Item {
                                            Layout.preferredWidth: scriptDelegate.isHeader ? 18 : 0
                                            Layout.preferredHeight: 18
                                            visible: scriptDelegate.isHeader
                                            QC.Label {
                                                anchors.centerIn: parent
                                                text: model.expanded !== false ? "▼" : "▶"
                                                font.pixelSize: 10
                                                color: "#3949AB"
                                            }
                                        }
                                        // Indent cho children
                                        Item {
                                            Layout.preferredWidth: scriptDelegate.isHeader ? 0 : 24
                                            visible: !scriptDelegate.isHeader
                                        }
                                        QC.Label {
                                            Layout.fillWidth: true
                                            text: model.displayText
                                            font.pixelSize: scriptDelegate.isHeader ? 12 : 11
                                            font.bold: scriptDelegate.isHeader
                                            color: scriptDelegate.isHeader ? "#283593" : (scriptDelegate.isSelected ? "#0D47A1" : "#333")
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.leftMargin: 28 // Tránh vùng CheckBox
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        drag.target: dragHandle
                                        drag.axis: Drag.YAxis

                                        property bool dragging: false

                                        onClicked: function(mouse) {
                                            if (mouse.button === Qt.RightButton) {
                                                // Nếu click phải vào item chưa chọn → chọn nó
                                                if (!(autoTestPlanDialog.selectedIndexMap[index] === true)) {
                                                    autoTestPlanDialog.selectedScriptIndex = index
                                                    autoTestPlanDialog.setSelection([index])
                                                }
                                                autoTestPlanDialog.openScriptContextMenu(index)
                                                return
                                            }

                                            // Header toggle
                                            if (model.scriptType === "continuity_header" || model.scriptType === "sheath_insulation_header") {
                                                var exp = scriptModel.get(index).expanded !== false
                                                scriptModel.setProperty(index, "expanded", !exp)
                                                autoTestPlanDialog.scriptListRefresh++
                                                return
                                            }

                                            if (mouse.modifiers & Qt.ControlModifier) {
                                                // Ctrl+Click: toggle selection
                                                var arr = autoTestPlanDialog.selectedIndices.slice()
                                                var idx = arr.indexOf(index)
                                                if (idx >= 0) {
                                                    arr.splice(idx, 1)
                                                } else {
                                                    arr.push(index)
                                                }
                                                autoTestPlanDialog.setSelection(arr)
                                                autoTestPlanDialog.selectedScriptIndex = arr.length > 0 ? arr[arr.length - 1] : -1
                                            } else if (mouse.modifiers & Qt.ShiftModifier) {
                                                // Shift+Click: range selection
                                                var from = autoTestPlanDialog.selectedScriptIndex
                                                if (from < 0) from = 0
                                                var to = index
                                                var minI = Math.min(from, to)
                                                var maxI = Math.max(from, to)
                                                var rangeArr = []
                                                for (var ri = minI; ri <= maxI; ri++) rangeArr.push(ri)
                                                autoTestPlanDialog.setSelection(rangeArr)
                                                autoTestPlanDialog.selectedScriptIndex = index
                                            } else {
                                                // Click thường: chọn 1 item
                                                autoTestPlanDialog.selectedScriptIndex = index
                                                autoTestPlanDialog.setSelection([index])
                                            }
                                        }

                                        onPressed: function(mouse) {
                                            if (mouse.button === Qt.LeftButton) {
                                                dragging = false
                                                autoTestPlanDialog.dragFromIndex = index
                                            }
                                        }

                                        onPositionChanged: function(mouse) {
                                            if (pressed && Math.abs(mouse.y) > 10) {
                                                dragging = true
                                                // Tính drop target index
                                                var mappedY = scriptDelegate.mapToItem(scriptListView, mouse.x, mouse.y).y
                                                var targetI = scriptListView.indexAt(0, mappedY + scriptListView.contentY)
                                                if (targetI < 0) targetI = scriptModel.count
                                                autoTestPlanDialog.dropTargetIndex = targetI
                                            }
                                        }



                                        onReleased: function(mouse) {
                                            if (dragging && autoTestPlanDialog.dropTargetIndex >= 0) {
                                                var fromIdx = autoTestPlanDialog.dragFromIndex
                                                if (fromIdx < 0 || fromIdx >= scriptModel.count) {
                                                    dragging = false
                                                    autoTestPlanDialog.dragFromIndex = -1
                                                    autoTestPlanDialog.dropTargetIndex = -1
                                                    return
                                                }
                                                var fromType = String(scriptModel.get(fromIdx).scriptType || "")
                                                var dropTarget = autoTestPlanDialog.dropTargetIndex

                                                if (fromType.indexOf("_header") >= 0) {
                                                    // === Kéo header → gom header + tất cả children thành 1 block ===
                                                    var childType = fromType.replace("_header", "")
                                                    var groupStart = fromIdx
                                                    var groupEnd = fromIdx  // inclusive
                                                    for (var ci = fromIdx + 1; ci < scriptModel.count; ci++) {
                                                        if (String(scriptModel.get(ci).scriptType || "") === childType) {
                                                            groupEnd = ci
                                                        } else {
                                                            break
                                                        }
                                                    }
                                                    var groupSize = groupEnd - groupStart + 1

                                                    // Nếu drop target nằm trong group → bỏ qua (không tự drop vào chính mình)
                                                    if (dropTarget >= groupStart && dropTarget <= groupEnd + 1) {
                                                        dragging = false
                                                        autoTestPlanDialog.dragFromIndex = -1
                                                        autoTestPlanDialog.dropTargetIndex = -1
                                                        return
                                                    }

                                                    // Set selection = toàn bộ group
                                                    var groupIndices = []
                                                    for (var gi = groupStart; gi <= groupEnd; gi++) groupIndices.push(gi)
                                                    autoTestPlanDialog.setSelection(groupIndices)
                                                    autoTestPlanDialog.selectedScriptIndex = groupStart

                                                    // Di chuyển block
                                                    autoTestPlanDialog.moveSelectedScriptsTo(dropTarget)
                                                } else {
                                                    // === Kéo item thường ===
                                                    if (!(autoTestPlanDialog.selectedIndexMap[fromIdx] === true)) {
                                                        autoTestPlanDialog.setSelection([fromIdx])
                                                        autoTestPlanDialog.selectedScriptIndex = fromIdx
                                                    }
                                                    autoTestPlanDialog.moveSelectedScriptsTo(dropTarget)
                                                }
                                            }
                                            dragging = false
                                            autoTestPlanDialog.dragFromIndex = -1
                                            autoTestPlanDialog.dropTargetIndex = -1
                                        }
                                    }

                                    // Invisible drag handle
                                    Item {
                                        id: dragHandle
                                        width: 1; height: 1
                                        visible: false
                                    }
                                }
                            }
                        }
                    }
                }
            }

            QC.ScrollView {
                id: configScrollView
                QC.SplitView.fillWidth: true
                QC.SplitView.minimumWidth: 280
                clip: true
                ColumnLayout {
                    width: configScrollView.availableWidth
                    spacing: 8
                    QC.GroupBox {
                        title: qsTr("Cấu hình chung")
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        GridLayout {
                            columns: 2
                            rowSpacing: 6
                            columnSpacing: 12
                            width: parent.width - 40
                            QC.Label { text: qsTr("Cho phép chạy") }
                            QC.CheckBox {
                                id: allowRunCheck
                                checked: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.allowRun : true
                                Layout.leftMargin: 4
                                onToggled: autoTestPlanDialog.setScriptParam("allowRun", checked)
                            }
                            QC.Label { text: qsTr("Dừng khi Không đạt") }
                            QC.CheckBox {
                                id: stopOnFailCheck
                                checked: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.stopOnFail : true
                                Layout.leftMargin: 4
                                onToggled: autoTestPlanDialog.setScriptParam("stopOnFail", checked)
                            }
                            QC.Label { text: qsTr("Tên bài đo") }
                            QC.TextField {
                                id: testNameField
                                Layout.fillWidth: true
                                placeholderText: qsTr("Tên bài đo")
                                text: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.displayText : ""
                                onTextChanged: autoTestPlanDialog.setScriptParam("displayText", text)
                            }
                        }
                    }
                    QC.GroupBox {
                        title: selectedScriptType === "notification" ? qsTr("Test Parameter") : qsTr("Thông số bài đo")
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        visible: selectedScriptType !== "" && selectedScriptType !== "system_init"
                        ColumnLayout {
                            width: parent.width - 40
                            Loader {
                                id: paramLoader
                                Layout.fillWidth: true
                                sourceComponent: selectedScriptType === "notification" ? notificationParams
                                                  : selectedScriptType === "continuity" ? measurementParams
                                                  : selectedScriptType === "sheath_insulation" ? sheathParams
                                                  : emptyParams
                            }
                        }
                    }
                    QC.GroupBox {
                        title: qsTr("Thông số máy đo")
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        visible: selectedScriptType === "continuity" || selectedScriptType === "sheath_insulation"
                        ColumnLayout {
                            width: parent.width - 40
                            Loader {
                                id: deviceParamLoader
                                Layout.fillWidth: true
                                sourceComponent: (selectedScriptType === "continuity" || selectedScriptType === "sheath_insulation")
                                    ? deviceParamsResistance : emptyParams
                            }

                            // Nút áp dụng cấu hình
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.topMargin: 8
                                height: applyAllBtn.implicitHeight + 8
                                color: "transparent"
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 8

                                    // Nút áp dụng cho script hiện tại
                                    QC.Button {
                                        id: applyThisBtn
                                        text: qsTr("📌 Áp dụng cho script này")
                                        Layout.fillWidth: true
                                        onClicked: {
                                            if (!autoTestPlanDialog.selectedScript) return
                                            var st = String(autoTestPlanDialog.selectedScript.scriptType || "")
                                            if (st === "continuity" || st === "sheath_insulation") {
                                                if (typeof keithley2110 !== "undefined" && keithley2110 && keithley2110.isOpen) {
                                                    var range = String(autoTestPlanDialog.selectedScript.resistanceRange || "RANGE_1KΩ")
                                                    var speed = String(autoTestPlanDialog.selectedScript.deviceSpeed || "FAST")
                                                    keithley2110.configureRM3544(range, speed)
                                                    applyAllResult.text = qsTr("✅ Đã cấu hình RM3544 - range: %1, speed: %2").arg(range).arg(speed)
                                                    applyAllResult.color = "#2E7D32"
                                                } else {
                                                    applyAllResult.text = qsTr("⚠ RM3544 chưa kết nối")
                                                    applyAllResult.color = "#E65100"
                                                }
                                            }
                                            // Tự động lưu bài đo sau khi gửi cấu hình
                                            _autoSaveAfterConfig()
                                            applyAllResultTimer.restart()
                                        }
                                        background: Rectangle {
                                            color: applyThisBtn.pressed ? "#1565C0" : applyThisBtn.hovered ? "#42A5F5" : "#2196F3"
                                            radius: 4
                                        }
                                        contentItem: Text {
                                            text: applyThisBtn.text
                                            color: "white"
                                            font.bold: true
                                            font.pixelSize: 12
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        QC.ToolTip.visible: hovered
                                        QC.ToolTip.text: qsTr("Gửi cấu hình máy đo từ script đang chọn\nmà KHÔNG thay đổi các scripts khác.")
                                    }

                                    // Nút áp dụng cho tất cả scripts cùng loại
                                    QC.Button {
                                        id: applyAllBtn
                                        text: qsTr("📋 Áp dụng cho tất cả Thông chập + Cách điện vỏ")
                                        Layout.fillWidth: true
                                        onClicked: {
                                            var count = autoTestPlanDialog.applyDeviceConfigToAll()
                                            if (count > 0) {
                                                var st = selectedScriptType
                                                var deviceConnected = false
                                                deviceConnected = (typeof keithley2110 !== "undefined" && keithley2110 && keithley2110.isOpen)
                                                if (deviceConnected) {
                                                    applyAllResult.text = qsTr("✅ Đã áp dụng cho %1 scripts + cấu hình máy đo").arg(count)
                                                    applyAllResult.color = "#2E7D32"
                                                } else {
                                                    applyAllResult.text = qsTr("✅ Đã áp dụng cho %1 scripts (máy đo chưa kết nối)").arg(count)
                                                    applyAllResult.color = "#E65100"
                                                }
                                                // Tự động lưu bài đo sau khi áp dụng
                                                _autoSaveAfterConfig()
                                                applyAllResultTimer.restart()
                                            }
                                        }
                                        background: Rectangle {
                                            color: applyAllBtn.pressed ? "#E65100" : applyAllBtn.hovered ? "#FF9800" : "#FFA726"
                                            radius: 4
                                        }
                                        contentItem: Text {
                                            text: applyAllBtn.text
                                            color: "white"
                                            font.bold: true
                                            font.pixelSize: 12
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        QC.ToolTip.visible: hovered
                                        QC.ToolTip.text: qsTr("Lấy thông số máy đo từ script đang chọn\nvà áp dụng cho TẤT CẢ scripts cùng loại.\n(Bao gồm: tốc độ, dải đo, số lần đọc, delay,...)")
                                    }
                                }
                            }
                            QC.Label {
                                id: applyAllResult
                                text: ""
                                font.pixelSize: 11
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                Timer {
                                    id: applyAllResultTimer
                                    interval: 3000
                                    onTriggered: applyAllResult.text = ""
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight
            spacing: 8

            QC.Label {
                id: saveMessageLabel
                text: ""
                color: "#2e7d32"
                font.pixelSize: 12
                visible: text !== ""
            }
            QC.Button {
                id: saveButton
                text: qsTr("Lưu Lại")
                font.pixelSize: 12
                onClicked: {
                    autoTestPlanDialog.updateDisplayText()
                    var name = cableName
                    var jsonStr = autoTestPlanDialog.serializeScriptModel()

                    if (name && typeof testPlanManager !== "undefined" && testPlanManager) {
                        if (testPlanManager.saveTestPlan(name, jsonStr)) {
                            saveMessageLabel.text = qsTr("Đã lưu")
                            if (typeof window !== "undefined") window.addLog("Sửa bài đo", "Đã lưu tất cả thay đổi vào bài đo: " + name)
                            autoTestPlanDialog.planSaved(name)
                        }
                    } else if (!name) {
                        saveMessageLabel.text = qsTr("Đã lưu")
                    }
                    saveMessageTimer.start()
                }
            }
            Timer {
                id: saveMessageTimer
                interval: 2000
                repeat: false
                onTriggered: saveMessageLabel.text = ""
            }
        }
    }

    Component {
        id: emptyParams
        Item { height: 1; width: 1 }
    }

    Component {
        id: notificationParams
        GridLayout {
            columns: 2
            rowSpacing: 6
            columnSpacing: 12
            QC.Label { text: qsTr("Thông báo hệ thống") }
            QC.TextField {
                Layout.fillWidth: true
                text: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.sysMsg : ""
                onTextChanged: autoTestPlanDialog.setScriptParam("sysMsg", text)
            }
            QC.Label { text: qsTr("Thông báo người dùng") }
            QC.TextField {
                Layout.fillWidth: true
                text: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.userMsg : ""
                onTextChanged: autoTestPlanDialog.setScriptParam("userMsg", text)
            }
            QC.Label { text: qsTr("Nhãn giắc cổng A") }
            QC.TextField {
                Layout.fillWidth: true
                text: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.labelA : ""
                onTextChanged: { autoTestPlanDialog.setScriptParam("labelA", text); autoTestPlanDialog.updateDisplayText() }
            }
            QC.Label { text: qsTr("Nhãn giắc cổng B") }
            QC.TextField {
                Layout.fillWidth: true
                text: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.labelB : ""
                onTextChanged: { autoTestPlanDialog.setScriptParam("labelB", text); autoTestPlanDialog.updateDisplayText() }
            }
        }
    }

    Component {
        id: measurementParams
        GridLayout {
            columns: 2
            rowSpacing: 6
            columnSpacing: 12
            QC.Label { text: qsTr("Đơn vị đo") }
            QC.ComboBox {
                id: unitCombo
                model: ["Ω", "kΩ", "MΩ"]
                currentIndex: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.unitIndex : 0
                Layout.fillWidth: true
                onCurrentIndexChanged: autoTestPlanDialog.setScriptParam("unitIndex", currentIndex)
            }
            QC.Label { text: qsTr("Giá trị giới hạn đạt dưới (Ω)") }
            QC.TextField {
                id: limitLowerField
                Layout.fillWidth: true
                text: {
                    if (autoTestPlanDialog.selectedScriptType === "continuity") return "1000"
                    if (autoTestPlanDialog.selectedScript) return String(autoTestPlanDialog.selectedScript.limitLower)
                    return "0"
                }
                validator: DoubleValidator { bottom: 0; top: 999999; decimals: 6 }
                onEditingFinished: {
                    var val = parseFloat(text)
                    if (!isNaN(val)) autoTestPlanDialog.setScriptParam("limitLower", val)
                }
            }
            QC.Label { text: qsTr("Giá trị giới hạn đạt trên (Ω)") }
            QC.TextField {
                id: limitUpperField
                Layout.fillWidth: true
                // Bài thông chập: không cần cận trên
                enabled: autoTestPlanDialog.selectedScriptType !== "continuity"
                text: {
                    if (autoTestPlanDialog.selectedScriptType === "continuity") return "NA"
                    if (autoTestPlanDialog.selectedScript) return String(autoTestPlanDialog.selectedScript.limitUpper)
                    return "0.8"
                }
                validator: DoubleValidator { bottom: 0; top: 999999; decimals: 6 }
                onEditingFinished: {
                    var val = parseFloat(text)
                    if (!isNaN(val)) autoTestPlanDialog.setScriptParam("limitUpper", val)
                }
            }
            QC.Label { text: qsTr("Nhãn giắc đầu A") }
            QC.TextField {
                Layout.fillWidth: true
                text: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.labelA : ""
                onTextChanged: { autoTestPlanDialog.setScriptParam("labelA", text); autoTestPlanDialog.updateDisplayText() }
            }
            QC.Label { text: qsTr("Nhãn giắc đầu B") }
            QC.TextField {
                Layout.fillWidth: true
                text: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.labelB : ""
                onTextChanged: { autoTestPlanDialog.setScriptParam("labelB", text); autoTestPlanDialog.updateDisplayText() }
            }
            QC.Label { text: qsTr("Tên chân đầu A") }
            QC.TextField {
                Layout.fillWidth: true
                text: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.pinA : ""
                onTextChanged: { autoTestPlanDialog.setScriptParam("pinA", text); autoTestPlanDialog.updateDisplayText() }
            }
            QC.Label { text: qsTr("Tên chân đầu B") }
            QC.TextField {
                Layout.fillWidth: true
                text: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.pinB : ""
                onTextChanged: { autoTestPlanDialog.setScriptParam("pinB", text); autoTestPlanDialog.updateDisplayText() }
            }
            QC.Label { text: qsTr("Chân đo cổng A") }
            QC.SpinBox {
                id: portPinASpin
                editable: true
                value: autoTestPlanDialog.selectedScript && autoTestPlanDialog.selectedScript.portPinA !== undefined && !isNaN(Number(autoTestPlanDialog.selectedScript.portPinA)) && Number(autoTestPlanDialog.selectedScript.portPinA) >= 0 ? Number(autoTestPlanDialog.selectedScript.portPinA) : -1
                from: -1
                to: 255
                Layout.fillWidth: true
                onValueChanged: {
                    if (value >= 0) {
                        autoTestPlanDialog.setScriptParam("portPinA", value)
                    } else {
                        // Nếu value = -1, xóa property portPinA khỏi model
                        autoTestPlanDialog.setScriptParam("portPinA", undefined)
                    }
                }
            }
            QC.Label { text: qsTr("Chân đo cổng B") }
            QC.SpinBox {
                id: portPinBSpin
                editable: true
                value: autoTestPlanDialog.selectedScript && autoTestPlanDialog.selectedScript.portPinB !== undefined && !isNaN(Number(autoTestPlanDialog.selectedScript.portPinB)) && Number(autoTestPlanDialog.selectedScript.portPinB) >= 0 ? Number(autoTestPlanDialog.selectedScript.portPinB) : -1
                from: -1
                to: 255
                Layout.fillWidth: true
                onValueChanged: {
                    if (value >= 0) {
                        autoTestPlanDialog.setScriptParam("portPinB", value)
                    } else {
                        // Nếu value = -1, xóa property portPinB khỏi model
                        autoTestPlanDialog.setScriptParam("portPinB", undefined)
                    }
                }
            }
            QC.Label { text: qsTr("Số lần đọc kết quả đo") }
            QC.SpinBox {
                editable: true
                value: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.numReadings : 3
                from: 1
                to: 100
                Layout.fillWidth: true
                onValueModified: autoTestPlanDialog.setScriptParam("numReadings", value)
            }
            QC.Label { text: qsTr("Trễ giữa các lần đọc (ms)") }
            QC.SpinBox {
                editable: true
                value: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.delayBetween : 10
                from: 0
                to: 9999
                Layout.fillWidth: true
                onValueModified: autoTestPlanDialog.setScriptParam("delayBetween", value)
            }
            QC.Label { text: qsTr("Trễ sau khi chuyển mạch (ms)") }
            QC.SpinBox {
                editable: true
                value: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.delayAfter : 100
                from: 0
                to: 9999
                Layout.fillWidth: true
                onValueModified: autoTestPlanDialog.setScriptParam("delayAfter", value)
            }

            // ═══ Nút áp dụng ═══
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.columnSpan: 2
                spacing: 8
                QC.Button {
                    text: qsTr("📌 Script này")
                    Layout.fillWidth: true
                    font.pixelSize: 12
                    font.bold: true
                    onClicked: {
                        if (!autoTestPlanDialog.selectedScript) return
                        if (typeof keithley2110 !== "undefined" && keithley2110 && keithley2110.isOpen) {
                            var range = String(autoTestPlanDialog.selectedScript.resistanceRange || "RANGE_1KΩ")
                            var speed = String(autoTestPlanDialog.selectedScript.deviceSpeed || "FAST")
                            keithley2110.configureRM3544(range, speed)
                            console.log("[CONFIG] ✅ Đã cấu hình RM3544 cho script này")
                        }
                    }
                    background: Rectangle {
                        color: parent.pressed ? "#1565C0" : parent.hovered ? "#42A5F5" : "#2196F3"
                        radius: 4
                    }
                    contentItem: Text {
                        text: parent.text; color: "white"; font.bold: true; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                }
                QC.Button {
                    text: qsTr("📋 Toàn bài đo")
                    Layout.fillWidth: true
                    font.pixelSize: 12
                    font.bold: true
                    highlighted: true
                    onClicked: autoTestPlanDialog.applyDeviceConfigToAll()
                }
            }
        }
    }

    Component {
        id: sheathParams
        GridLayout {
            columns: 2
            rowSpacing: 6
            columnSpacing: 12
            QC.Label { text: qsTr("Đơn vị đo") }
            QC.ComboBox {
                model: ["Ω", "kΩ", "MΩ"]
                currentIndex: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.unitIndex : 0
                Layout.fillWidth: true
                onCurrentIndexChanged: autoTestPlanDialog.setScriptParam("unitIndex", currentIndex)
            }
            QC.Label { text: qsTr("Giá trị giới hạn đạt dưới (Ω)") }
            QC.TextField {
                id: sheathLimitLowerField
                Layout.fillWidth: true
                text: autoTestPlanDialog.selectedScript ? String(autoTestPlanDialog.selectedScript.limitLower) : "1000"
                validator: DoubleValidator { bottom: 0; top: 999999; decimals: 6 }
                onEditingFinished: {
                    var val = parseFloat(text)
                    if (!isNaN(val)) autoTestPlanDialog.setScriptParam("limitLower", val)
                }
            }

            QC.Label { text: qsTr("Nhãn giắc đầu đo (không phải GND)") }
            QC.TextField {
                Layout.fillWidth: true
                text: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.labelA : ""
                onTextChanged: { autoTestPlanDialog.setScriptParam("labelA", text); autoTestPlanDialog.updateDisplayText() }
            }
            QC.Label { text: qsTr("Tên chân đầu đo") }
            QC.TextField {
                Layout.fillWidth: true
                text: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.pinA : ""
                onTextChanged: { autoTestPlanDialog.setScriptParam("pinA", text); autoTestPlanDialog.updateDisplayText() }
            }
            QC.Label { text: qsTr("Đầu kia") }
            QC.Label { text: "GND"; color: "#666" }
            QC.Label { text: qsTr("Số lần đọc kết quả đo") }
            QC.SpinBox {
                editable: true
                value: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.numReadings : 3
                from: 1
                to: 100
                Layout.fillWidth: true
                onValueModified: autoTestPlanDialog.setScriptParam("numReadings", value)
            }
            QC.Label { text: qsTr("Trễ giữa các lần đọc (ms)") }
            QC.SpinBox {
                editable: true
                value: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.delayBetween : 10
                from: 0
                to: 9999
                Layout.fillWidth: true
                onValueModified: autoTestPlanDialog.setScriptParam("delayBetween", value)
            }
            QC.Label { text: qsTr("Trễ sau khi chuyển mạch (ms)") }
            QC.SpinBox {
                editable: true
                value: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.delayAfter : 100
                from: 0
                to: 9999
                Layout.fillWidth: true
                onValueModified: autoTestPlanDialog.setScriptParam("delayAfter", value)
            }

            // ═══ Nút áp dụng ═══
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.columnSpan: 2
                spacing: 8
                QC.Button {
                    text: qsTr("📌 Script này")
                    Layout.fillWidth: true
                    font.pixelSize: 12
                    font.bold: true
                    onClicked: {
                        if (!autoTestPlanDialog.selectedScript) return
                        if (typeof keithley2110 !== "undefined" && keithley2110 && keithley2110.isOpen) {
                            var range = String(autoTestPlanDialog.selectedScript.resistanceRange || "RANGE_1KΩ")
                            var speed = String(autoTestPlanDialog.selectedScript.deviceSpeed || "FAST")
                            keithley2110.configureRM3544(range, speed)
                            console.log("[CONFIG] ✅ Đã cấu hình RM3544 cho script này")
                        }
                    }
                    background: Rectangle {
                        color: parent.pressed ? "#1565C0" : parent.hovered ? "#42A5F5" : "#2196F3"
                        radius: 4
                    }
                    contentItem: Text {
                        text: parent.text; color: "white"; font.bold: true; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                }
                QC.Button {
                    text: qsTr("📋 Toàn bài đo")
                    Layout.fillWidth: true
                    font.pixelSize: 12
                    font.bold: true
                    highlighted: true
                    onClicked: autoTestPlanDialog.applyDeviceConfigToAll()
                }
            }
        }
    }

    // Thông số máy đo: thông chập / cách điện vỏ (continuity, sheath_insulation)
    Component {
        id: deviceParamsResistance
        GridLayout {
            columns: 2
            rowSpacing: 6
            columnSpacing: 12
            QC.Label { text: qsTr("Cấu hình máy đo") }
            QC.CheckBox {
                checked: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.deviceConfig : false
                Layout.leftMargin: 4
                onToggled: autoTestPlanDialog.setScriptParam("deviceConfig", checked)
            }
            QC.Label { text: qsTr("Dải đo điện trở") }
            QC.ComboBox {
                id: resistanceRangeCombo
                model: ["RANGE_1KΩ", "RANGE_10KΩ", "RANGE_100KΩ", "RANGE_1MΩ", "RANGE_10MΩ"]
                currentIndex: {
                    var v = autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.resistanceRange : "RANGE_1KΩ"
                    var idx = model.indexOf(v)
                    return idx >= 0 ? idx : 0
                }
                Layout.fillWidth: true
                onCurrentIndexChanged: autoTestPlanDialog.setScriptParam("resistanceRange", model[currentIndex])
            }
            QC.Label { text: qsTr("Tốc độ máy đo") }
            QC.ComboBox {
                id: deviceSpeedResistanceCombo
                model: ["FAST", "MED", "SLOW", "SLOW2"]
                currentIndex: {
                    var v = autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.deviceSpeed : "FAST"
                    var idx = model.indexOf(v)
                    return idx >= 0 ? idx : 0
                }
                Layout.fillWidth: true
                onCurrentIndexChanged: autoTestPlanDialog.setScriptParam("deviceSpeed", model[currentIndex])
            }
        }
    }

    // Thông số máy đo: điện trở cách điện / cách điện vỏ (insulation, sheath_insulation)
    Component {
        id: deviceParamsInsulation
        GridLayout {
            columns: 2
            rowSpacing: 6
            columnSpacing: 12
            QC.Label { text: qsTr("Cấu hình máy đo") }
            QC.CheckBox {
                checked: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.deviceConfig : false
                Layout.leftMargin: 4
                onToggled: autoTestPlanDialog.setScriptParam("deviceConfig", checked)
            }
            QC.Label { text: qsTr("Điện áp đo (V)") }
            QC.SpinBox {
                editable: true
                value: autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.measureVoltage : 250
                from: 0
                to: 1000
                Layout.fillWidth: true
                onValueModified: autoTestPlanDialog.setScriptParam("measureVoltage", value)
            }
            QC.Label { text: qsTr("Giới hạn dòng đo") }
            QC.ComboBox {
                id: currentLimitCombo
                model: ["Auto", "1mA", "10mA", "100mA"]

                currentIndex: {
                    var v = autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.currentLimit : "Auto"
                    var idx = model.indexOf(v)
                    return idx >= 0 ? idx : 0
                }
                Layout.fillWidth: true
                onCurrentIndexChanged: autoTestPlanDialog.setScriptParam("currentLimit", model[currentIndex])
            }
            QC.Label { text: qsTr("Tốc độ máy đo") }
            QC.ComboBox {
                id: deviceSpeedInsulationCombo
                model: ["FAST", "MED", "SLOW", "SLOW2"]
                currentIndex: {
                    var v = autoTestPlanDialog.selectedScript ? autoTestPlanDialog.selectedScript.deviceSpeed : "MED"
                    var idx = model.indexOf(v)
                    return idx >= 0 ? idx : 1
                }
                Layout.fillWidth: true
                onCurrentIndexChanged: autoTestPlanDialog.setScriptParam("deviceSpeed", model[currentIndex])
            }
            // ⚠️ AN TOÀN: Thời gian xả điện sau mỗi phép đo
            QC.Label {
                text: qsTr("⚡ Thời gian xả điện (ms)")
                color: "#D32F2F"
                font.bold: true
            }
            QC.SpinBox {
                editable: true
                value: autoTestPlanDialog.selectedScript ? (autoTestPlanDialog.selectedScript.dischargeDelay !== undefined ? autoTestPlanDialog.selectedScript.dischargeDelay : 100) : 100
                from: 100
                to: 10000
                stepSize: 100
                Layout.fillWidth: true
                onValueModified: autoTestPlanDialog.setScriptParam("dischargeDelay", value)
                QC.ToolTip.visible: hovered
                QC.ToolTip.text: qsTr("Thời gian chờ xả điện áp cao sau mỗi phép đo.\nTối thiểu 100ms, khuyến nghị ≥ 1000ms cho an toàn.\nGiá trị càng cao = càng an toàn nhưng đo chậm hơn.")
            }
            // DELAY: thời gian chờ trước khi đo (giây)
            QC.Label {
                text: qsTr("⏱ DELAY - chờ ổn định (s)")
                color: "#1565C0"
                font.bold: true
            }
            QC.SpinBox {
                editable: true
                value: autoTestPlanDialog.selectedScript
                    ? (autoTestPlanDialog.selectedScript.trigDelay !== undefined ? autoTestPlanDialog.selectedScript.trigDelay : 1) : 1
                from: 0
                to: 999
                Layout.fillWidth: true
                onValueModified: autoTestPlanDialog.setScriptParam("trigDelay", value)
                QC.ToolTip.visible: hovered
                QC.ToolTip.text: qsTr("DELAY trên máy SM7110.\nSau khi áp điện áp, máy chờ N giây\nđể điện trở ổn định rồi mới đo.\nVD: cách điện GΩ cần delay 1-5s.")
            }
            // AVG: bật/tắt trung bình
            QC.Label {
                text: qsTr("📊 AVG - lấy trung bình")
                color: "#1565C0"
                font.bold: true
            }
            QC.CheckBox {
                checked: autoTestPlanDialog.selectedScript
                    ? (autoTestPlanDialog.selectedScript.avgEnabled !== undefined ? autoTestPlanDialog.selectedScript.avgEnabled : false) : false
                Layout.leftMargin: 4
                text: qsTr("Bật Average")
                onToggled: autoTestPlanDialog.setScriptParam("avgEnabled", checked)
                QC.ToolTip.visible: hovered
                QC.ToolTip.text: qsTr("AVG trên máy SM7110.\nMáy đo nhiều lần rồi tính trung bình để giảm nhiễu.")
            }
            // AVG: số lần lấy trung bình
            QC.Label { text: qsTr("Số lần AVG") }
            QC.SpinBox {
                editable: true
                value: autoTestPlanDialog.selectedScript
                    ? (autoTestPlanDialog.selectedScript.avgCount !== undefined ? autoTestPlanDialog.selectedScript.avgCount : 1) : 1
                from: 1
                to: 100
                Layout.fillWidth: true
                onValueModified: autoTestPlanDialog.setScriptParam("avgCount", value)
                QC.ToolTip.visible: hovered
                QC.ToolTip.text: qsTr("Số lần đo để lấy average.\nVD: AVG=5 → máy đo 5 lần rồi trả kết quả trung bình.")
            }
        }
    }

    FileDialog {
        id: addFromFileDialog
        title: qsTr("Chọn file Excel/CSV cáp kết nối")
        nameFilters: [qsTr("File Excel hoặc CSV") + " (*.xlsx *.xls *.csv *.txt)", qsTr("Tất cả") + " (*.*)"]
        fileMode: FileDialog.OpenFile
        onAccepted: {
            var path = selectedFile.toString()
            if (path && typeof cableListManager !== "undefined" && cableListManager) {
                var rows = cableListManager.loadTableData(path)
                var idx = scriptContextMenuIndex >= 0 ? scriptContextMenuIndex + 1 : scriptModel.count
                appendScriptsFromExcel(rows || [], idx)
            }
        }
    }

    QC.Menu {
        id: scriptContextMenu
        QC.MenuItem {
            text: qsTr("Thêm vào từ tệp")
            onTriggered: addFromFileDialog.open()
        }
        Repeater {
            model: templateListModel
            delegate: QC.MenuItem {
                text: model.displayText
                onTriggered: insertTemplateScript(model.scriptType, (autoTestPlanDialog.scriptContextMenuIndex >= 0 ? autoTestPlanDialog.scriptContextMenuIndex + 1 : scriptModel.count), model.displayText)
            }
        }
        QC.MenuSeparator { }
        QC.MenuItem {
            text: autoTestPlanDialog.selectedIndices.length > 1 ? qsTr("Xóa %1 bài đo đã chọn").arg(autoTestPlanDialog.selectedIndices.length) : qsTr("Xóa bài đo")
            onTriggered: {
                if (autoTestPlanDialog.selectedIndices.length > 1) {
                    autoTestPlanDialog.deleteSelectedScripts()
                } else {
                    deleteScriptAt(scriptContextMenuIndex)
                }
            }
        }
        QC.MenuItem {
            text: qsTr("Chèn từ tệp")
            onTriggered: addFromFileDialog.open()
        }
        Repeater {
            model: templateListModel
            delegate: QC.MenuItem {
                text: qsTr("Chèn: ") + model.displayText
                onTriggered: insertTemplateScript(model.scriptType, (autoTestPlanDialog.scriptContextMenuIndex >= 0 ? autoTestPlanDialog.scriptContextMenuIndex + 1 : scriptModel.count), model.displayText)
            }
        }
        QC.MenuSeparator { }
        QC.MenuItem {
            text: qsTr("Di chuyển lên trên")
            onTriggered: moveScriptAt(scriptContextMenuIndex, "up")
        }
        QC.MenuItem {
            text: qsTr("Di chuyển xuống dưới")
            onTriggered: moveScriptAt(scriptContextMenuIndex, "down")
        }
        QC.MenuSeparator { }
        QC.MenuItem {
            text: qsTr("Sao chép")
            onTriggered: copyScriptAt(scriptContextMenuIndex)
        }
        QC.MenuItem {
            text: qsTr("Dán")
            onTriggered: pasteScriptAt(scriptContextMenuIndex >= 0 ? scriptContextMenuIndex + 1 : scriptModel.count)
        }
    }

    Component.onCompleted: {
        if (scriptModel.count === 0)
            buildScriptListFromTemplate()
    }

    // ╔══════════════════════════════════════════════════════════════════════╗
    // ║ Dialog: Thêm cặp cổng mới (UI dạng bảng)                          ║
    // ╚══════════════════════════════════════════════════════════════════════╝
    QC.Dialog {
        id: addConnectorPairDialog
        title: ""
        modal: true
        width: 660
        height: 560
        standardButtons: QC.Dialog.NoButton
        x: parent ? (parent.width - width) / 2 : 100
        y: parent ? (parent.height - height) / 2 : 100

        property int _insertAtIndex: -1

        // Cố định chiều rộng các cột để header và body thẳng nhau
        readonly property int colStt: 30
        readonly property int colPinA: 120
        readonly property int colPortA: 100
        readonly property int colPinB: 120
        readonly property int colPortB: 100
        readonly property int colDel: 28

        ListModel { id: pinRowsModel }

        header: Rectangle {
            width: parent.width; height: 46
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#1565C0" }
                GradientStop { position: 1.0; color: "#0D47A1" }
            }
            radius: 8
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 8; color: "#0D47A1" }
            Row {
                anchors.centerIn: parent; spacing: 8
                Text { text: "➕"; font.pixelSize: 16; color: "white" }
                Text { text: qsTr("Thêm cặp cổng mới"); font.pixelSize: 14; font.bold: true; color: "white" }
            }
            // Kéo dialog bằng header
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeAllCursor
                property point pressPos
                onPressed: function(mouse) { pressPos = Qt.point(mouse.x, mouse.y) }
                onPositionChanged: function(mouse) {
                    addConnectorPairDialog.x += mouse.x - pressPos.x
                    addConnectorPairDialog.y += mouse.y - pressPos.y
                }
            }
        }

        onOpened: {
            labelAField2.text = ""
            labelBField2.text = ""
            pinRowsModel.clear()
            // Tạo sẵn 1 hàng trống cho user nhập luôn
            pinRowsModel.append({ pinNameA: "", portMcuA: "", pinNameB: "", portMcuB: "" })
            connPairError2.visible = false
        }

        // Tự thêm hàng trống khi hàng cuối được nhập
        function _autoAddRow() {
            if (pinRowsModel.count === 0) return
            var last = pinRowsModel.get(pinRowsModel.count - 1)
            if (String(last.pinNameA || "").trim() !== "" || String(last.portMcuA || "").trim() !== "" ||
                String(last.pinNameB || "").trim() !== "" || String(last.portMcuB || "").trim() !== "") {
                pinRowsModel.append({ pinNameA: "", portMcuA: "", pinNameB: "", portMcuB: "" })
            }
        }

        contentItem: ColumnLayout {
            anchors.margins: 14
            spacing: 10

            // ── Nhãn cổng ──
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                // Cổng A
                Rectangle {
                    Layout.fillWidth: true; height: 44; radius: 8
                    color: "#F0F4FF"; border.color: "#BBDEFB"; border.width: 1
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                        Rectangle { width: 8; height: 8; radius: 4; color: "#1565C0" }
                        Text { text: qsTr("Cổng A:"); font.pixelSize: 12; font.bold: true; color: "#1565C0" }
                        QC.TextField {
                            id: labelAField2; Layout.fillWidth: true; font.pixelSize: 13; font.bold: true
                            placeholderText: qsTr("VD: CS")
                            color: "#1565C0"
                            background: Rectangle { radius: 5; color: "white"; border.color: labelAField2.activeFocus ? "#1565C0" : "#E0E0E0"; border.width: labelAField2.activeFocus ? 2 : 1 }
                        }
                    }
                }
                // Cổng B
                Rectangle {
                    Layout.fillWidth: true; height: 44; radius: 8
                    color: "#F0FFF0"; border.color: "#C8E6C9"; border.width: 1
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                        Rectangle { width: 8; height: 8; radius: 4; color: "#2E7D32" }
                        Text { text: qsTr("Cổng B:"); font.pixelSize: 12; font.bold: true; color: "#2E7D32" }
                        QC.TextField {
                            id: labelBField2; Layout.fillWidth: true; font.pixelSize: 13; font.bold: true
                            placeholderText: qsTr("VD: NT-23-1")
                            color: "#2E7D32"
                            background: Rectangle { radius: 5; color: "white"; border.color: labelBField2.activeFocus ? "#2E7D32" : "#E0E0E0"; border.width: labelBField2.activeFocus ? 2 : 1 }
                        }
                    }
                }
            }

            // ── Mô tả ngắn ──
            Text {
                text: qsTr("Nhập tên chân và số port MCU cho từng cặp. Hàng mới tự thêm khi bạn nhập.")
                font.pixelSize: 11; color: "#888"; Layout.fillWidth: true
            }

            // ── Header bảng (cố định width từng cột) ──
            Rectangle {
                Layout.fillWidth: true; height: 30; radius: 4; color: "#ECEFF1"
                Row {
                    anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 0
                    Item { width: addConnectorPairDialog.colStt; height: parent.height
                        Text { anchors.centerIn: parent; text: "#"; font.pixelSize: 10; font.bold: true; color: "#78909C" }
                    }
                    Rectangle { width: 1; height: parent.height - 6; anchors.verticalCenter: parent.verticalCenter; color: "#CFD8DC" }
                    Rectangle { width: addConnectorPairDialog.colPinA; height: parent.height - 4; anchors.verticalCenter: parent.verticalCenter; radius: 3; color: "#E3F2FD"
                        Text { anchors.centerIn: parent; text: qsTr("Tên chân A"); font.pixelSize: 10; font.bold: true; color: "#1565C0" }
                    }
                    Rectangle { width: addConnectorPairDialog.colPortA; height: parent.height - 4; anchors.verticalCenter: parent.verticalCenter; radius: 3; color: "#BBDEFB"
                        Text { anchors.centerIn: parent; text: qsTr("Port MCU A"); font.pixelSize: 10; font.bold: true; color: "#1565C0" }
                    }
                    Rectangle { width: 2; height: parent.height - 4; anchors.verticalCenter: parent.verticalCenter; color: "#90A4AE" }
                    Rectangle { width: addConnectorPairDialog.colPinB; height: parent.height - 4; anchors.verticalCenter: parent.verticalCenter; radius: 3; color: "#E8F5E9"
                        Text { anchors.centerIn: parent; text: qsTr("Tên chân B"); font.pixelSize: 10; font.bold: true; color: "#2E7D32" }
                    }
                    Rectangle { width: addConnectorPairDialog.colPortB; height: parent.height - 4; anchors.verticalCenter: parent.verticalCenter; radius: 3; color: "#C8E6C9"
                        Text { anchors.centerIn: parent; text: qsTr("Port MCU B"); font.pixelSize: 10; font.bold: true; color: "#2E7D32" }
                    }
                    Rectangle { width: 1; height: parent.height - 6; anchors.verticalCenter: parent.verticalCenter; color: "#CFD8DC" }
                    Item { width: addConnectorPairDialog.colDel; height: parent.height }
                }
            }

            // ── Bảng chân ──
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: 8
                color: "white"; border.color: "#E0E0E0"; border.width: 1; clip: true

                ListView {
                    id: pinRowsList
                    anchors.fill: parent; anchors.margins: 3
                    model: pinRowsModel
                    spacing: 0

                    delegate: Rectangle {
                        width: pinRowsList.width; height: 34
                        color: {
                            var isEmpty = String(model.pinNameA || "").trim() === "" && String(model.portMcuA || "").trim() === "" &&
                                          String(model.pinNameB || "").trim() === "" && String(model.portMcuB || "").trim() === ""
                            if (isEmpty) return "#FAFAFA"
                            return index % 2 === 0 ? "white" : "#F8FAFE"
                        }
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#F0F0F0" }

                        Row {
                            anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 0
                            // STT
                            Item { width: addConnectorPairDialog.colStt; height: parent.height
                                Text { anchors.centerIn: parent; text: (index + 1); font.pixelSize: 11; font.bold: true; color: "#90A4AE" }
                            }
                            Rectangle { width: 1; height: parent.height - 6; anchors.verticalCenter: parent.verticalCenter; color: "#EEE" }
                            // Tên chân A
                            QC.TextField {
                                width: addConnectorPairDialog.colPinA; height: parent.height; font.pixelSize: 12; text: model.pinNameA || ""
                                horizontalAlignment: Text.AlignHCenter
                                placeholderText: index === pinRowsModel.count - 1 ? qsTr("nhập...") : ""
                                background: Rectangle { radius: 3; color: parent.activeFocus ? "#EBF5FB" : "transparent"; border.color: parent.activeFocus ? "#1565C0" : "#EEE"; border.width: parent.activeFocus ? 2 : 1 }
                                onTextChanged: { pinRowsModel.setProperty(index, "pinNameA", text); addConnectorPairDialog._autoAddRow() }
                            }
                            // Port MCU A
                            QC.TextField {
                                width: addConnectorPairDialog.colPortA; height: parent.height; font.pixelSize: 12; text: model.portMcuA || ""
                                horizontalAlignment: Text.AlignHCenter; inputMethodHints: Qt.ImhDigitsOnly
                                background: Rectangle { radius: 3; color: parent.activeFocus ? "#EBF5FB" : "transparent"; border.color: parent.activeFocus ? "#1565C0" : "#EEE"; border.width: parent.activeFocus ? 2 : 1 }
                                onTextChanged: { pinRowsModel.setProperty(index, "portMcuA", text); addConnectorPairDialog._autoAddRow() }
                            }
                            // Vạch ngăn A|B
                            Rectangle { width: 2; height: parent.height - 4; anchors.verticalCenter: parent.verticalCenter; color: "#E0E0E0" }
                            // Tên chân B
                            QC.TextField {
                                width: addConnectorPairDialog.colPinB; height: parent.height; font.pixelSize: 12; text: model.pinNameB || ""
                                horizontalAlignment: Text.AlignHCenter
                                background: Rectangle { radius: 3; color: parent.activeFocus ? "#EBF8E8" : "transparent"; border.color: parent.activeFocus ? "#2E7D32" : "#EEE"; border.width: parent.activeFocus ? 2 : 1 }
                                onTextChanged: { pinRowsModel.setProperty(index, "pinNameB", text); addConnectorPairDialog._autoAddRow() }
                            }
                            // Port MCU B
                            QC.TextField {
                                width: addConnectorPairDialog.colPortB; height: parent.height; font.pixelSize: 12; text: model.portMcuB || ""
                                horizontalAlignment: Text.AlignHCenter; inputMethodHints: Qt.ImhDigitsOnly
                                background: Rectangle { radius: 3; color: parent.activeFocus ? "#EBF8E8" : "transparent"; border.color: parent.activeFocus ? "#2E7D32" : "#EEE"; border.width: parent.activeFocus ? 2 : 1 }
                                onTextChanged: { pinRowsModel.setProperty(index, "portMcuB", text); addConnectorPairDialog._autoAddRow() }
                            }
                            Rectangle { width: 1; height: parent.height - 6; anchors.verticalCenter: parent.verticalCenter; color: "#EEE" }
                            // Nút xóa
                            Item { width: addConnectorPairDialog.colDel; height: parent.height
                                Rectangle {
                                    anchors.centerIn: parent; width: 22; height: 22; radius: 11
                                    visible: pinRowsModel.count > 1
                                    color: delMa3.containsMouse ? "#FFEBEE" : "transparent"
                                    Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 11; color: delMa3.containsMouse ? "#D32F2F" : "#CFD8DC" }
                                    MouseArea { id: delMa3; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (pinRowsModel.count > 1) pinRowsModel.remove(index) } }
                                }
                            }
                        }
                    }
                }
            }

            // ── Thống kê + Nút hành động ──
            RowLayout {
                Layout.fillWidth: true; spacing: 8

                // Thống kê
                Text {
                    id: connPairPreview2
                    Layout.fillWidth: true; font.pixelSize: 11; color: "#1976D2"
                    text: {
                        var validCount = 0
                        for (var i = 0; i < pinRowsModel.count; i++) {
                            var r = pinRowsModel.get(i)
                            if (String(r.pinNameA || "").trim() !== "" || String(r.portMcuA || "").trim() !== "") validCount++
                        }
                        return validCount > 0 ? qsTr("📋 %1 cặp chân → %2 scripts").arg(validCount).arg(5 + validCount * 4) : ""
                    }
                }

                // Error
                Text {
                    id: connPairError2
                    visible: false; font.pixelSize: 11; color: "#D32F2F"
                }

                // Nút Tạo
                Rectangle {
                    width: 140; height: 38; radius: 8
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: createBtnMa2.pressed ? "#0D47A1" : createBtnMa2.containsMouse ? "#1565C0" : "#1976D2" }
                        GradientStop { position: 1.0; color: createBtnMa2.pressed ? "#0A3A80" : createBtnMa2.containsMouse ? "#0D47A1" : "#1565C0" }
                    }
                    Row { anchors.centerIn: parent; spacing: 5
                        Text { text: "✅"; font.pixelSize: 13 }
                        Text { text: qsTr("Tạo Scripts"); font.pixelSize: 13; font.bold: true; color: "white" }
                    }
                    MouseArea {
                        id: createBtnMa2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var result = addConnectorPairDialog._parseConnectorPairInput()
                            if (result.error) { connPairError2.text = result.error; connPairError2.visible = true; return }
                            connPairError2.visible = false
                            buildScriptsForConnectorPair(result.labelA, result.labelB, result.pinsA, result.pinsB, addConnectorPairDialog._insertAtIndex)
                            if (typeof window !== "undefined" && window.addLog)
                                window.addLog("Sửa bài đo", "Chèn script mới: ➕ Thêm cặp cổng mới tại vị trí " + (addConnectorPairDialog._insertAtIndex + 1))
                            addConnectorPairDialog.close()
                        }
                    }
                }

                // Nút Hủy
                Rectangle {
                    width: 70; height: 38; radius: 8
                    color: cancelBtnMa2.containsMouse ? "#FFEBEE" : "#F5F5F5"
                    border.color: "#E0E0E0"; border.width: 1
                    Text { anchors.centerIn: parent; text: qsTr("Hủy"); font.pixelSize: 12; color: "#757575" }
                    MouseArea {
                        id: cancelBtnMa2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: addConnectorPairDialog.close()
                    }
                }
            }
        }

        // ── Parse dữ liệu từ bảng ──
        function _parseConnectorPairInput() {
            var labelA = labelAField2.text.trim()
            var labelB = labelBField2.text.trim()
            if (!labelA) return { error: qsTr("Vui lòng nhập Nhãn cổng A") }
            if (!labelB) return { error: qsTr("Vui lòng nhập Nhãn cổng B") }

            var pinsA = [], pinsB = []
            for (var i = 0; i < pinRowsModel.count; i++) {
                var row = pinRowsModel.get(i)
                var nameA = String(row.pinNameA || "").trim()
                var portA = String(row.portMcuA || "").trim()
                var nameB = String(row.pinNameB || "").trim()
                var portB = String(row.portMcuB || "").trim()
                // Bỏ qua hàng trống hoàn toàn
                if (nameA === "" && portA === "" && nameB === "" && portB === "") continue
                var pA = parseInt(portA, 10)
                var pB = parseInt(portB, 10)
                pinsA.push({ pin: nameA || portA || "0", port: isNaN(pA) ? 0 : pA })
                pinsB.push({ pin: nameB || portB || "0", port: isNaN(pB) ? 0 : pB })
            }

            if (pinsA.length === 0) return { error: qsTr("Vui lòng nhập ít nhất 1 cặp chân") }
            return { labelA: labelA, labelB: labelB, pinsA: pinsA, pinsB: pinsB }
        }
    }
}

