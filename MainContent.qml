import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    anchors.fill: parent

    // Bài đo đang chọn (từ Danh sách bài đo) để dùng khi Bắt đầu
    property string currentPlanName: ""
    property string mcuLastError: ""
    property var notificationDialog: null
    property bool isStopped: false  // Flag để biết bài đo đã bị dừng
    property string interfaceMode: "auto" // auto | manual
    property var editPlanDialog: null
    property string calibrationMode: "" // Mode hiệu chuẩn đã chọn
    property var calibrationDialog: null // Reference đến CalibrationDialog để tra cứu hiệu chuẩn
    property var cableCalibrationDialog: null // Reference đến CableCalibrationDialog
    property string productSerialNumber: "" // Serial Number sản phẩm
    property string testStartTime: "" // Thời gian bắt đầu đo
    property string testEndTime: ""   // Thời gian kết thúc đo
    property string _lastExcelPath: "" // Đường dẫn Excel vừa xuất ra

    function updateCalibrationMode() {
        if (typeof fileHelper !== "undefined" && fileHelper) {
            var mode = fileHelper.loadCalibrationMode()    // load mode from file
            console.log("Calibrartion mode: " + mode)
            root.calibrationMode = mode || qsTr("Chưa chọn mode")
        } else {
            root.calibrationMode = qsTr("Chưa chọn mode")
        }
    }

    function logMessage(msg, isError) {
        var ts = new Date().toLocaleTimeString("vi-VN")
        var color = isError ? "#d32f2f" : "#1565c0"
        var prefix = isError ? "⚠ LỖI:" : "ℹ INFO:"
        var formatted = "<font color='" + color + "'><b>[" + ts + "]</b> " + prefix + " " + msg + "</font>"

        if (typeof statusAreaText !== "undefined" && statusAreaText) {
            if (statusAreaText.text !== "") {
                statusAreaText.text += "<br>" + formatted
            } else {
                statusAreaText.text = formatted
            }
            statusAreaText.cursorPosition = statusAreaText.text.length
        }
    }

    Component.onCompleted: {
        updateCalibrationMode()
    }

    function onStopRequested() {
        console.log("[DEBUG] Yeu cau dung bai do")
        isStopped = true
    }


    // === Xuất kết quả đo ra Excel ===
    function exportToExcel() {
        if (!mainTestListModel || mainTestListModel.count === 0) return

        // Tìm thời gian kết thúc thật nếu bài đo đã kết thúc
        var realEndTime = root.testEndTime || ""
        if (!realEndTime) {
            for (var m = 0; m < mainTestListModel.count; m++) {
                var tm = mainTestListModel.get(m).measureTime;
                if (tm) realEndTime = tm; 
            }
        }
        if (!realEndTime) realEndTime = new Date().toLocaleString("en-US")

        // Thu thập station info
        var stationInfo = { 
            serialNumber: productSerialNumber, 
            startTime: testStartTime || new Date().toLocaleString("en-US"),
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
        if (!stationInfo.startTime) {
            stationInfo.startTime = new Date().toLocaleString("en-US")
        }

        // Thu thập kết quả đo
        var results = []
        var failCount = 0
        var passCount = 0
        for (var i = 0; i < mainTestListModel.count; i++) {
            var item = mainTestListModel.get(i)
            var t = String(item.scriptType || "")
            var measuredValue = String(item.measuredValue || "")
            var limitLower = item.limitLower !== undefined ? Number(item.limitLower) : 0
            var limitUpper = item.limitUpper !== undefined ? Number(item.limitUpper) : 999999

            // Đọc kết quả PASS/FAIL đã được tính sẵn bởi logic đo (chính xác, không parse lại chuỗi)
            var result = String(item.resultStatus || "")
            if (result === "PASS") passCount++
            else if (result === "FAIL") failCount++

            results.push({
                displayText: String(item.displayText || ""),
                scriptType: t,
                limitLower: _formatBound(t, limitLower, false),
                limitUpper: _formatBound(t, limitUpper, true),
                measuredValue: measuredValue,
                measureTime: String(item.measureTime || ""),
                result: result
            })
        }

        // Tạo tên file mặc định
        var now = new Date()
        var dateStr = now.getFullYear() + "" +
            String(now.getMonth() + 1).padStart(2, "0") +
            String(now.getDate()).padStart(2, "0") + "_" +
            String(now.getHours()).padStart(2, "0") +
            String(now.getMinutes()).padStart(2, "0") +
            String(now.getSeconds()).padStart(2, "0")
        var sn = productSerialNumber || "NoSN"
        var defaultName = sn + "_" + (currentPlanName || "test") + "_" + dateStr + ".xlsx"

        // Lấy đường dẫn log từ config hoặc dùng app dir
        var savePath = ""
        if (typeof fileHelper !== "undefined" && fileHelper) {
            var cfgStr2 = fileHelper.loadStationConfig()
            if (cfgStr2) {
                try {
                    var cfg2 = JSON.parse(cfgStr2)
                    savePath = cfg2.logPath || ""
                } catch(e2) {}
            }
            if (!savePath) savePath = fileHelper.applicationDirPath() + "/results"
        }
        // Đảm bảo folder tồn tại (dùng JS trick)
        var filePath = savePath + "/" + defaultName

        var stationJson = JSON.stringify(stationInfo)
        var resultsJson = JSON.stringify(results)

        if (typeof fileHelper !== "undefined" && fileHelper) {
            var ok = fileHelper.exportExcel(filePath, stationJson, resultsJson)
            if (ok) {
                exportMessageLabel.text = qsTr("✓ Đã xuất: %1").arg(defaultName)
                exportMessageLabel.color = "#2E7D32"
                // Lưu đường dẫn để hỏi người dùng có muốn mở không
                _lastExcelPath = filePath
                openExcelDialog.open()
            } else {
                exportMessageLabelz.text = qsTr("✕ Lỗi xuất Excel!")
                exportMessageLabel.color = "#D32F2F"
            }
            exportMessageTimer.restart()

            // Tạo file log HTML
            _generateTestLog(savePath, sn, dateStr, stationInfo, results, passCount, failCount)
        }
    }

    // ═══ Tạo file log HTML ═══
    function _generateTestLog(savePath, sn, dateStr, stationInfo, results, passCount, failCount) {
        var totalTests = passCount + failCount
        var overallResult = (failCount === 0 && totalTests > 0) ? "PASS" : "FAIL"
        var logFileName = sn + "_" + (currentPlanName || "test") + "_" + dateStr + "_log.html"
        var logPath = savePath + "/" + logFileName

        var html = "<!DOCTYPE html><html><head><meta charset='utf-8'>"
        html += "<title>Log kết quả đo - " + sn + "</title>"
        html += "<style>"
        html += "body { font-family: 'Segoe UI', sans-serif; margin: 20px; background: #fafafa; }"
        html += "h1 { color: #1a237e; border-bottom: 2px solid #1a237e; padding-bottom: 8px; }"
        html += "h2 { color: #283593; margin-top: 20px; font-size: 18px; }"
        html += ".info { background: #e8eaf6; padding: 12px; border-radius: 6px; margin: 10px 0; }"
        html += ".info span { font-weight: bold; }"
        html += ".pass-badge { background: #2E7D32; color: white; padding: 4px 16px; border-radius: 4px; font-weight: bold; font-size: 18px; }"
        html += ".fail-badge { background: #D32F2F; color: white; padding: 4px 16px; border-radius: 4px; font-weight: bold; font-size: 18px; }"
        html += "table { border-collapse: collapse; width: 100%; margin-top: 10px; }"
        html += "th { background: #283593; color: white; padding: 10px 8px; text-align: left; font-size: 13px; }"
        html += "td { padding: 8px; border-bottom: 1px solid #ddd; font-size: 12px; }"
        html += "tr:nth-child(even) { background: #f5f5f5; }"
        html += "tr.fail { background: #ffebee !important; }"
        html += "tr.fail td { color: #D32F2F; font-weight: bold; }"
        html += "tr.header { background: #e8eaf6 !important; }"
        html += "tr.header td { color: #283593; font-weight: bold; font-size: 13px; }"
        html += ".result-pass { color: #2E7D32; font-weight: bold; }"
        html += ".result-fail { color: #D32F2F; font-weight: bold; font-size: 13px; }"
        html += ".summary { margin-top: 15px; padding: 12px; border-radius: 6px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }"
        html += ".summary-pass { background: #e8f5e9; border-left: 4px solid #2E7D32; }"
        html += ".summary-fail { background: #ffebee; border-left: 4px solid #D32F2F; }"
        html += "/* CSS Tab */"
        html += ".tab { overflow: hidden; border: 1px solid #ccc; background-color: #e8eaf6; border-radius: 6px 6px 0 0; margin-top: 25px; }"
        html += ".tab button { background-color: inherit; float: left; border: none; outline: none; cursor: pointer; padding: 14px 20px; transition: 0.3s; font-size: 14px; font-weight: bold; color: #1a237e; border-right: 1px solid #c5cae9; }"
        html += ".tab button:hover { background-color: #c5cae9; }"
        html += ".tab button.active { background-color: #283593; color: white; }"
        html += ".tabcontent { display: none; padding: 16px; border: 1px solid #ccc; border-top: none; border-radius: 0 0 6px 6px; background-color: white; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }"
        html += "</style>"
        html += "<script>"
        html += "function openTab(evt, tabName) {"
        html += "  var i, tabcontent, tablinks;"
        html += "  tabcontent = document.getElementsByClassName('tabcontent');"
        html += "  for (i = 0; i < tabcontent.length; i++) { tabcontent[i].style.display = 'none'; }"
        html += "  tablinks = document.getElementsByClassName('tablinks');"
        html += "  for (i = 0; i < tablinks.length; i++) { tablinks[i].className = tablinks[i].className.replace(' active', ''); }"
        html += "  document.getElementById(tabName).style.display = 'block';"
        html += "  evt.currentTarget.className += ' active';"
        html += "}"
        html += "</script>"
        html += "</head><body>"

        // Header
        html += "<h1>📋 LOG KẾT QUẢ ĐO VÀ HOẠT ĐỘNG</h1>"
        html += "<div class='info'>"
        html += "<p><span>Serial Number:</span> " + sn + "</p>"
        html += "<p><span>Bài đo:</span> " + (currentPlanName || "N/A") + "</p>"
        html += "<p><span>Trạm:</span> " + (stationInfo.stationName || "N/A") + " &nbsp;|&nbsp; <span>Công ty:</span> " + (stationInfo.companyName || "N/A") + "</p>"
        html += "<p><span>Thời gian bắt đầu:</span> " + (stationInfo.startTime || "N/A") + "</p>"
        html += "<p><span>Thời gian kết thúc:</span> " + (stationInfo.endTime || "N/A") + "</p>"
        html += "<p><span>Thời gian xuất log:</span> " + new Date().toLocaleString("vi-VN") + "</p>"
        html += "</div>"

        // Kết quả tổng
        html += "<div class='summary " + (overallResult === "PASS" ? "summary-pass" : "summary-fail") + "'>"
        html += "<span class='" + (overallResult === "PASS" ? "pass-badge" : "fail-badge") + "'>" + overallResult + "</span>"
        html += " &nbsp; Đạt: <strong>" + passCount + "</strong> | Lỗi: <strong style='color:#D32F2F'>" + failCount + "</strong> | Tổng: <strong>" + totalTests + "</strong>"
        html += "</div>"

        // === TAB MENU ===
        html += "<div class='tab'>"
        html += "  <button class='tablinks active' onclick=\"openTab(event, 'TestResults')\">📝 CHI TIẾT KẾT QUẢ ĐO</button>"
        html += "  <button class='tablinks' onclick=\"openTab(event, 'SystemLog')\">📜 NHẬT KÝ HỆ THỐNG </button>"
        html += "</div>"

        // === TAB 1: KẾT QUẢ ĐO ===
        html += "<div id='TestResults' class='tabcontent' style='display:block;'>"
        html += "<h2>Bảng chi tiết thông số đo kiểm của cáp</h2>"
        html += "<table><tr><th>STT</th><th>Bài đo</th><th>Giá trị đo</th><th>Cận dưới</th><th>Cận trên</th><th>Thực hiện lúc</th><th>Kết quả</th></tr>"

        var stt = 0
        for (var i = 0; i < results.length; i++) {
            var r = results[i]
            var st = String(r.scriptType || "")
            var isHdr = st.indexOf("_header") >= 0
            var isNot = st === "notification"
            var isSys = st === "system_init"

            if (isHdr) {
                html += "<tr class='header'><td></td><td colspan='6'>" + r.displayText + "</td></tr>"
            } else if (isNot || isSys) {
                // Bỏ qua notification/system_init trong log
            } else {
                stt++
                var rowClass = r.result === "FAIL" ? "fail" : ""
                var resultClass = r.result === "PASS" ? "result-pass" : (r.result === "FAIL" ? "result-fail" : "")
                html += "<tr class='" + rowClass + "'>"
                html += "<td>" + stt + "</td>"
                html += "<td>" + r.displayText + "</td>"
                html += "<td>" + (r.measuredValue || "—") + "</td>"
                html += "<td>" + r.limitLower + "</td>"
                html += "<td>" + r.limitUpper + "</td>"
                html += "<td>" + (r.measureTime || "—") + "</td>"
                html += "<td class='" + resultClass + "'>" + (r.result || "—") + "</td>"
                html += "</tr>"
            }
        }
        html += "</table>"

        // Danh sách lỗi riêng (nếu có)
        if (failCount > 0) {
            html += "<h2 style='color:#D32F2F; margin-top:30px; border-bottom:1px solid #ffcdd2; padding-bottom:5px;'>⚠ DANH SÁCH CÁC CHÂN ĐO LỖI</h2>"
            html += "<table><tr><th>STT</th><th>Bài đo</th><th>Giá trị đo</th><th>Cận dưới</th><th>Cận trên</th></tr>"
            var fStt = 0
            for (var j = 0; j < results.length; j++) {
                if (results[j].result === "FAIL") {
                    fStt++
                    html += "<tr class='fail'>"
                    html += "<td>" + fStt + "</td>"
                    html += "<td>" + results[j].displayText + "</td>"
                    html += "<td>" + (results[j].measuredValue || "—") + "</td>"
                    html += "<td>" + results[j].limitLower + "</td>"
                    html += "<td>" + results[j].limitUpper + "</td>"
                    html += "</tr>"
                }
            }
            html += "</table>"
        }
        html += "</div>" // End Tab 1

        // === TAB 2: NHẬT KÝ HOẠT ĐỘNG THAO TÁC (SYSTEM LOG) ===
        html += "<div id='SystemLog' class='tabcontent'>"
        html += "<h2>Lịch sử thao tác máy </h2>"
        if (typeof window !== "undefined" && window.activityLog && window.activityLog.length > 0) {
            html += "<table><tr><th style='width: 15%'>Thời gian</th><th style='width: 15%'>Danh mục</th><th>Nội dung sự kiện</th></tr>"
            for (var k = 0; k < window.activityLog.length; k++) {
                var itemLog = window.activityLog[k]
                html += "<tr>"
                html += "<td>" + itemLog.time + "</td>"
                html += "<td><strong style='color:#000;'>" + itemLog.category + "</strong></td>"
                html += "<td>" + itemLog.action + "</td>"
                html += "</tr>"
            }
            html += "</table>"
        } else {
            html += "<p style='color:#888; font-style:italic; padding: 20px;'>Không có nhật ký hoạt động nào được ghi nhận trong phiên làm việc này.</p>"
        }
        html += "</div>" // End Tab 2

        html += "<br><p style='color:#999; font-size:11px; margin-top:20px; text-align:center;'>File HTML Log tự động tạo bởi ProjectTestCap " + new Date().getFullYear() + "</p>"
        html += "</body></html>"

        // Lưu file log
        if (typeof fileHelper !== "undefined" && fileHelper) {
            fileHelper.writeTextFile(logPath, html)
            console.log("[LOG] Đã tạo file log:", logPath)

            // Không tự mở file HTML nữa - người dùng tự mở khi cần
            // if (failCount > 0) {
            //     Qt.openUrlExternally("file:///" + logPath.replace(/\\/g, "/"))
            // }
        }
    }

    // Độ rộng cột "Bài đo" (kéo cạnh phải cột để đổi)
    property int baiDoColumnWidth: 280

    // mainTestListModel: continuity/sheath_insulation đo bằng RM3544 (Ω), pass khi >= 1000 Ω
    ListModel {
        id: mainTestListModel
    }
  // format
    function _formatBound(scriptType, value, isUpper) {
        var t = String(scriptType || "")
        if (t === "system_init" || t === "notification") return "NA"
        if (value === undefined || value === null) return isUpper ? "NA" : "—"
        var v = Number(value)
        if (isNaN(v)) return "—"
        if (t === "continuity") {
            // Pass khi ≤ limitUpper (upper limit quan trọng)
            if (!isUpper) return "NA"  // lower = 0, không hiển thị
            if (v >= 999999) return "NA"
            if (v >= 1000) return "≤ " + (v / 1000).toFixed(3) + " kΩ"
            return "≤ " + (v % 1 === 0 ? String(v) : v.toFixed(3)) + " Ω"
        }
        if (t === "sheath_insulation") {
            // Pass khi ≥ limitLower (lower limit quan trọng)
            if (isUpper) return "NA"  // upper = 999999, không hiển thị
            if (v <= 0) return "NA"
            if (v >= 1000) return "≥ " + (v / 1000).toFixed(1) + " kΩ"
            return "≥ " + (v % 1 === 0 ? String(v) : v.toFixed(1)) + " Ω"
        }
        if (isUpper && v >= 999999) return "NA"

        return String(v)
    }

    function _formatMeasuredValue(scriptType, value) {
        var t = String(scriptType || "")
        if (!value || value === "") return ""
        if (value === "LỖI") return "LỖI"
        var v = Number(value)
        if (isNaN(v)) return String(value)
        if (t === "continuity" || t === "sheath_insulation") {
            // RM3544 trả về đơn vị Ω (NR3 format)
            if (v >= 1e15) return "OL (∞)"
            if (v >= 1e6) return (v / 1e6).toFixed(3) + " MΩ"
            if (v >= 1000) return (v / 1000).toFixed(3) + " kΩ"
            if (v >= 1) return v.toFixed(3) + " Ω"
            if (v >= 0.001) return (v * 1000).toFixed(3) + " mΩ"
            return (v * 1e6).toFixed(1) + " µΩ"
        }
        // Fallback: tránh e+ notation
        if (Math.abs(v) >= 1e9) return "OL"
        return v.toFixed(4)
    }

    function _isMeasurable(scriptType) {
        var st = String(scriptType || "")
        return st === "continuity" || st === "sheath_insulation"
    }

    // Xóa kết quả đo và thời gian cho tất cả scripts
    function clearMeasurementResults() {
        for (var i = 0; i < mainTestListModel.count; i++) {
            var item = mainTestListModel.get(i)
            if (_isMeasurable(item.scriptType)) {
                mainTestListModel.setProperty(i, "measuredValue", "")
                mainTestListModel.setProperty(i, "measureTime", "")
                mainTestListModel.setProperty(i, "resultStatus", "")
            }
        }
        console.log("[MainContent] Đã xóa kết quả đo cho", mainTestListModel.count, "scripts")
    }

    function _updateMeasurementForScript(displayText, scriptType, rawValue, elapsedMs) {
        // Tìm script trong model và cập nhật giá trị đo (có áp dụng hiệu chuẩn)
        for (var i = 0; i < mainTestListModel.count; i++) {
            var item = mainTestListModel.get(i)
            if (item.displayText === displayText && item.scriptType === scriptType) {
                var adjustedValue = rawValue

                console.log("═══ [MEASURE] ═══ Script:", displayText, "| Type:", scriptType, "| Raw:", rawValue)
                console.log("  calibrationDialog:", root.calibrationDialog ? "CÓ" : "NULL")

                // Áp dụng hiệu chuẩn nếu có calibrationDialog
                var calibDialogToUse = null
                var isCableCalibration = (root.calibrationMode === qsTr("Hiệu chuẩn theo cáp đo"))

                if (isCableCalibration) {
                    calibDialogToUse = root.cableCalibrationDialog
                } else {
                    calibDialogToUse = root.calibrationDialog
                }

                console.log("  Sử dụng mode hiệu chuẩn:", root.calibrationMode)

                if (calibDialogToUse && _isMeasurable(scriptType)) {
                    var portA = (item.portPinA !== undefined) ? Number(item.portPinA) : -1
                    var portB = (item.portPinB !== undefined) ? Number(item.portPinB) : -1
                    console.log("  portA:", portA, "portB:", portB)

                    if (portA >= 0 || portB >= 0) {
                        if (typeof calibDialogToUse.getCalibrationOffset === "function") {
                            var calib = calibDialogToUse.getCalibrationOffset(portA, portB, scriptType)
                            var cableRes = 0
                            if (!isCableCalibration) {
                                cableRes = calibDialogToUse.cableResistance || 0
                            }
                            console.log("  calibKey:", calib.calibKey, "offset:", calib.offset, "cableRes:", cableRes)
                            if (calib.offset !== 0 || cableRes !== 0) {
                                adjustedValue = rawValue - calib.offset - cableRes

                                console.log("  ✅ HIỆU CHUẨN:", rawValue, "-", calib.offset, "(offset) -", cableRes, "(cáp) =", adjustedValue)
                            } else {
                                console.log("  ⚠ Offset=0 và cableRes=0 → không hiệu chuẩn")
                            }
                        } else {
                            console.log("  ❌ calibDialogToUse KHÔNG có hàm getCalibrationOffset!")
                        }
                    } else {
                        console.log("  ⚠ portPin không hợp lệ → bỏ qua hiệu chuẩn")
                    }
                } else {
                    console.log("  ⚠ Không hiệu chuẩn:", !calibDialogToUse ? "calibDialogToUse=NULL" : "không đo được")
                }

                var formattedValue = _formatMeasuredValue(scriptType, adjustedValue)

                // Tính thời gian đo (duration) — elapsedMs = thời gian máy đo mất để ra kết quả
                var timeStr = ""
                if (elapsedMs !== undefined && elapsedMs > 0) {
                    if (elapsedMs >= 1000) {
                        timeStr = (elapsedMs / 1000).toFixed(2) + " s"
                    } else {
                        timeStr = Math.round(elapsedMs) + " ms"
                    }
                }
                console.log("  → Final:", formattedValue, "| Duration:", timeStr)
                // Cập nhật giá trị vào model
                mainTestListModel.setProperty(i, "measuredValue", formattedValue)
                mainTestListModel.setProperty(i, "measureTime", timeStr)

                // Tính toán Pass/Fail dựa trên giá trị số thực (adjustedValue)
                // KHÔNG dựa trên chuỗi đã định dạng (formattedValue) để tránh sai lệch đơn vị (mΩ, kΩ, MΩ)
                var limitLower = item.limitLower !== undefined ? Number(item.limitLower) : 0
                var limitUpper = item.limitUpper !== undefined ? Number(item.limitUpper) : 999999
                var passFailStr = ""

                // Sử dụng adjustedValue thay vì parse từ chuỗi formattedValue
                var numValForComparison = adjustedValue

                if (rawValue < 0) {
                    mainTestListModel.setProperty(i, "resultStatus", "NAK")
                    mainTestListModel.setProperty(i, "measuredValue", "NAK")
                    logMessage(displayText + " → MCU NAK (hết retry, bỏ qua)", true)
                    break
                }

                if (!isNaN(numValForComparison)) {
                    var isPass = false

                    if (scriptType === "continuity") {
                        isPass = (numValForComparison <= limitUpper)
                    } else {
                        // sheath_insulation: pass khi >= limitLower
                        isPass = (numValForComparison >= limitLower)
                    }

                    passFailStr = isPass ? " [PASS]" : " [FAIL]"
                    mainTestListModel.setProperty(i, "resultStatus", isPass ? "PASS" : "FAIL")

                    if (!isPass) {
                        var limitDesc = scriptType === "continuity"
                            ? "<= " + limitUpper + " Ω"
                            : ">= " + limitLower + " Ω"
                        logMessage(displayText + " → " + formattedValue + " (Giới hạn: " + limitDesc + ")", true)
                    }
                } else {
                    mainTestListModel.setProperty(i, "resultStatus", "FAIL")
                    logMessage(displayText + " → " + formattedValue + " (Không đọc được giá trị)", true)
                }

                // Log chi tiết kết quả đo
                if (typeof window !== "undefined") {
                    var portA_log = (item.portPinA !== undefined) ? item.portPinA : "?"
                    var portB_log = (item.portPinB !== undefined) ? item.portPinB : "?"
                    window.addLog("Kết quả Script", displayText + " → " + formattedValue + passFailStr + " (Chân A:" + portA_log + " B:" + portB_log + ")")
                }

                break
            }
        }
    }

    property var _pendingBatchItems: []
    property int _batchIndex: 0

    Timer {   // Timer là để thêm các items vào model 1 cách chậm 
        id: batchAppendTimer   //  id của timer 
        interval: 1  // khoảng thời gian giữa các lần trigger 
        repeat: true     //  
        property int chunkSize: 80   // số lượng tối đa được thêm vào model mỗi lần trigger 
        
        onTriggered: {             // hàm được gọi sau mỗi lần trigger 
            var items = root._pendingBatchItems       // lấy ra các item cần thêm vào 
            var end = Math.min(root._batchIndex + chunkSize, items.length) // tính toán số lượng item cần thêm vào 
            for (var i = root._batchIndex; i < end; i++) {  // thêm các item vào model 
                mainTestListModel.append(items[i])    //  thêm item vào model 
            }
            root._batchIndex = end     // cập nhật item index để tiếp tục thêm item vào model 
            if (root._batchIndex >= items.length) {
                stop()    // dừng timer 
                root._pendingBatchItems = []    // xóa các item cần thêm vào 
                mainCheckAll.updateChecked()    // cập nhật checked state của các item trong model 
            }
        }
    }

    function _runScripts(scripts) {
        if (!scripts || scripts.length === 0) return
        if (typeof mcuSender === "undefined" || !mcuSender) return
        if (!mcuSender.portName || String(mcuSender.portName).trim() === "") return
        if (!mcuSender.isOpen) {
            if (!mcuSender.openPort()) return
        }
        
        root.testStartTime = new Date().toLocaleString("en-US")
        root.testEndTime = ""
        root.isStopped = false
        root._sendScriptsWithNotifications(scripts, 0)
    }

    function loadPlanIntoMainList(planName) {
        batchAppendTimer.stop()
        mainTestListModel.clear()
        _pendingBatchItems = []
        _batchIndex = 0

        if (!planName || typeof testPlanManager === "undefined" || !testPlanManager)
            return
        var scripts = testPlanManager.loadScripts(planName) || []
        var items = []
        for (var i = 0; i < scripts.length; i++) {
            var s = scripts[i]
            var t = String(s.scriptType || "")
            if (!t) continue
            var displayText = String(s.displayText || "")
            if (!displayText) continue

            var isHeader = t.indexOf("_header") >= 0
            var isNotification = (t === "notification")
            var isSystemInit = (t === "system_init")
            var isMeasurable = !isHeader && !isNotification && !isSystemInit
                               && t !== "relay" && t !== "save_result"

            if (!isHeader && s.allowRun === false) continue


            var limitLower = 0, limitUpper = 999999
            if (isMeasurable) {
                limitLower = (s.limitLower !== undefined && s.limitLower !== null) ? Number(s.limitLower) : 0
                limitUpper = (s.limitUpper !== undefined && s.limitUpper !== null) ? Number(s.limitUpper) : 999999
            }

            var ppA = (s.portPinA !== undefined && s.portPinA !== null && !isNaN(Number(s.portPinA))) ? Number(s.portPinA) : -1
            var ppB = (s.portPinB !== undefined && s.portPinB !== null && !isNaN(Number(s.portPinB))) ? Number(s.portPinB) : -1
            items.push({
                "displayText": displayText,
                "scriptType": t,
                "limitLower": limitLower,
                "limitUpper": limitUpper,
                "allowRun": isMeasurable ? (s.allowRun !== false) : true,
                "measuredValue": "",
                "measureTime": "",
                "resultStatus": "",
                "expanded": isHeader ? (t !== "continuity_header") : (s.expanded !== undefined ? s.expanded : true),
                "portPinA": ppA,
                "portPinB": ppB,
                "scriptEnabled": s.allowRun !== false,
                "scriptIndex": i,
                "scriptObject": s
            })
        }

        if (items.length <= 100) {
            for (var j = 0; j < items.length; j++) {
                mainTestListModel.append(items[j])
            }
            mainCheckAll.updateChecked()
        } else {
            _pendingBatchItems = items
            _batchIndex = 0
            batchAppendTimer.start()
        }
    }


    onCurrentPlanNameChanged: loadPlanIntoMainList(currentPlanName)


    function _sendScriptsWithNotifications(scripts, startIndex, enableWireResistance, enableContinuity, enableInsulation, enableSheathInsulation) {
        if (typeof enableWireResistance === "undefined") enableWireResistance = true
        if (typeof enableContinuity === "undefined") enableContinuity = true
        if (typeof enableInsulation === "undefined") enableInsulation = true
        if (typeof enableSheathInsulation === "undefined") enableSheathInsulation = true

        console.log("[DEBUG] _sendScriptsWithNotifications: startIndex=", startIndex, "total scripts=", scripts.length)
        console.log("[DEBUG] Filter: continuity=", enableContinuity, "sheath_insulation=", enableSheathInsulation)

        // Kiểm tra xem bài đo đã bị dừng chưa
        if (root.isStopped) {
            console.log("[DEBUG] Bai do da bi dung - khong tiep tuc gui scripts")
            return
        }

        if (startIndex >= scripts.length) {
            console.log("Da gui xong tat ca scripts")
            // Đóng dialog nếu đang mở
            if (root.notificationDialog && root.notificationDialog.visible) {
                root.notificationDialog.wasAccepted = true
                root.notificationDialog.close()
            }
            return
        }

        // Kiểm tra script đầu tiên có phải notification không
        var firstScript = scripts[startIndex]
        var firstScriptType = String(firstScript.scriptType || "")
        console.log("[DEBUG] Script dau tien tai index", startIndex, "scriptType=", firstScriptType)

        // Nếu script đầu tiên là notification → hiển thị dialog ngay, KHÔNG gửi gì
        if (firstScriptType === "notification") {
            console.log("[DEBUG] GAP NOTIFICATION - HIEN THI DIALOG")
            var labelA = String(firstScript.labelA || "")
            var labelB = String(firstScript.labelB || "")

            if (root.notificationDialog) {
                root.notificationDialog.labelA = labelA
                root.notificationDialog.labelB = labelB
                root.notificationDialog.scripts = scripts
                root.notificationDialog.validScriptsStartIndex = startIndex + 1  // bỏ qua chính notification này
                root.notificationDialog.nextIndex = startIndex + 1

                root.notificationDialog.enableWireResistance = enableWireResistance
                root.notificationDialog.enableContinuity = enableContinuity
                root.notificationDialog.enableInsulation = enableInsulation
                root.notificationDialog.enableSheathInsulation = enableSheathInsulation
                console.log("[DEBUG] Mo dialog - CHO NGUOI DUNG thao tac GỬI / START TEST / ĐÃ CẮM")
                root.notificationDialog.open()
            } else {
                console.log("[ERROR] Khong tim thay notificationDialog!")
            }
            return
        }

        // Tìm notification tiếp theo từ startIndex
        var notificationIndex = -1
        for (var i = startIndex; i < scripts.length; i++) {
            var s = scripts[i]
            var scriptType = String(s.scriptType || "")
            if (scriptType === "notification") {
                notificationIndex = i
                console.log("[DEBUG] Tim thay notification tai index", i)
                break
            }
        }

        // Nếu có notification ở sau → hiển thị dialog cho cặp chân hiện tại
        // Dialog sẽ xử lý việc gửi scripts khi user bấm "Gửi"
        if (notificationIndex >= 0) {
            var notifScript = scripts[notificationIndex]
            var labelA2 = String(notifScript.labelA || "")
            var labelB2 = String(notifScript.labelB || "")
            console.log("[DEBUG] Hien thi dialog cho cap chan: labelA=", labelA2, "labelB=", labelB2)

            if (root.notificationDialog) {
                if (root.notificationDialog.visible) {
                    root.notificationDialog.close()
                }

                root.notificationDialog.labelA = labelA2
                root.notificationDialog.labelB = labelB2
                root.notificationDialog.scripts = scripts
                root.notificationDialog.validScriptsStartIndex = startIndex
                root.notificationDialog.nextIndex = notificationIndex + 1

                root.notificationDialog.enableWireResistance = enableWireResistance
                root.notificationDialog.enableContinuity = enableContinuity
                root.notificationDialog.enableInsulation = enableInsulation
                root.notificationDialog.enableSheathInsulation = enableSheathInsulation

                Qt.callLater(function() {
                    if (root.notificationDialog && !root.notificationDialog.visible) {
                        root.notificationDialog.open()
                    }
                })
            }
            return
        }

        // Không có notification nữa → hiển thị dialog "last pair" cho scripts còn lại
        // Nếu có scripts hợp lệ, hiện dialog để user bấm GỬI / START TEST
        console.log("[DEBUG] Khong co notification nao nua - xu ly scripts con lai tu index", startIndex)
        var hasValidScripts = false
        for (var k = startIndex; k < scripts.length; k++) {
            var s3 = scripts[k]
            var scriptType3 = String(s3.scriptType || "")
            if (scriptType3.indexOf("_header") >= 0 || scriptType3 === "notification" || scriptType3 === "system_init") continue

            var shouldInclude = false
            if (scriptType3 === "wire_resistance" && enableWireResistance) shouldInclude = true
            else if (scriptType3 === "continuity" && enableContinuity) shouldInclude = true
            else if (scriptType3 === "insulation" && enableInsulation) shouldInclude = true
            else if (scriptType3 === "sheath_insulation" && enableSheathInsulation) shouldInclude = true

            if (shouldInclude) {
                hasValidScripts = true
                break
            }
        }

        if (hasValidScripts && root.notificationDialog) {
            // Hiện dialog cho batch cuối cùng (không có notification sau nữa)
            root.notificationDialog.labelA = qsTr("Cặp chân cuối cùng")
            root.notificationDialog.labelB = ""
            root.notificationDialog.scripts = scripts
            root.notificationDialog.validScriptsStartIndex = startIndex
            root.notificationDialog.nextIndex = scripts.length  // Hết scripts — onAccepted sẽ return ngay
            root.notificationDialog.enableWireResistance = enableWireResistance
            root.notificationDialog.enableContinuity = enableContinuity
            root.notificationDialog.enableInsulation = enableInsulation
            root.notificationDialog.enableSheathInsulation = enableSheathInsulation

            Qt.callLater(function() {
                if (root.notificationDialog && !root.notificationDialog.visible) {
                    root.notificationDialog.open()
                }
            })
        } else {
            console.log("[DEBUG] Khong co script hop le nao de gui")
            // Đóng dialog vì không còn gì
            if (root.notificationDialog && root.notificationDialog.visible) {
                root.notificationDialog.wasAccepted = true
                root.notificationDialog.close()
            }
        }
    }

    Connections {
        target: typeof mcuSender !== "undefined" ? mcuSender : null
        function onErrorOccurred(message) { mcuLastError = message || "" }
        function onDataReceived(measurementData) {
            // Nhận data từ MCU nhưng không hiển thị lên UI
            // Data vẫn được xử lý ở backend nếu cần
        }
    }


    // Kết nối MCU — không ghi vào ô log (ô log chỉ dành cho FAIL)
    Connections {
        target: typeof mcuSender !== "undefined" ? mcuSender : null
        function onOpenChanged() {
            if (mcuSender && mcuSender.isOpen) {
                console.log(">>> CONNECTED:", mcuSender.portName || "COM")
            }
        }
    }

    Connections {
        target: typeof testPlanManager !== "undefined" ? testPlanManager : null
        function onTestPlansChanged() {
            // Reload bài đo hiện tại khi có bài đo được sửa/lưu
            if (root.currentPlanName) {
                loadPlanIntoMainList(root.currentPlanName)
            }
        }
    }

    // Toast notification khi gửi test packet thành công
    Rectangle {
        id: testSuccessToast
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 20
        width: 300
        height: 60
        color: "#4CAF50"
        radius: 8
        opacity: 0
        visible: opacity > 0
        z: 1000

        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
                text: "✓"
                font.pixelSize: 24
                color: "white"
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Đã gửi bản tin xuống MCU")
                font.pixelSize: 14
                color: "white"
                font.bold: true
            }
        }


        function show() {
            opacity = 1
            hideTimer.restart()
        }

        Timer {
            id: hideTimer
            interval: 2000 // 2 giây
            onTriggered: {
                testSuccessToast.opacity = 0
            }
        }

    }

    ColumnLayout {
        id: manualTopBar
        visible: root.interfaceMode === "manual"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 4
        spacing: 4

        Rectangle {

            Layout.fillWidth: true
            Layout.preferredHeight: 30
            color: window.darkMode ? "#1E293B" : "#1565C0"
            radius: 2
            Behavior on color { ColorAnimation { duration: 400 } }
            Text {
                anchors.centerIn: parent
                text: qsTr("Test Script - %1").arg(root.currentPlanName || qsTr("Chưa chọn bài đo"))
                color: "white"
                font.bold: true
            }
        }
    }

    ColumnLayout {
        id: mainColumn
        visible: root.interfaceMode !== "manual"
        anchors.fill: parent
        anchors.margins: 4
        spacing: 4

        // Hàng trên: vùng đồ thị + bảng bài đo (kéo cạnh để đổi kích thước)
        SplitView {
            id: mainSplitView
            visible: root.interfaceMode !== "manual"
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal

            // Vùng thông tin bài đo + kết quả
            Rectangle {
                id: plotArea
                SplitView.preferredWidth: 400
                SplitView.minimumWidth: 400
                SplitView.maximumWidth: 630
                color: window.darkMode ? "#0F172A" : "#F8FAFC"
                border.color: window.darkMode ? "#334155" : "#E2E8F0"
                Behavior on color { ColorAnimation { duration: 400 } }
                Behavior on border.color { ColorAnimation { duration: 400 } }
                radius: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    // ═══ Card thông tin ═══
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: infoCol.implicitHeight + 24
                        color: window.darkMode ? "#1E293B" : "#ffffff"
                        radius: 8
                        border.color: window.darkMode ? "#334155" : "#E0E0E0"
                        Behavior on color { ColorAnimation { duration: 400 } }
                        Behavior on border.color { ColorAnimation { duration: 400 } }
                        border.width: 1

                        ColumnLayout {
                            id: infoCol
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 0

                            // Tên bài đo — nổi bật
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.bottomMargin: 8
                                spacing: 8

                                Label {
                                    text: root.currentPlanName || qsTr("Chưa chọn bài đo")
                                    font.pixelSize: 18
                                    font.bold: true
                                    color: root.currentPlanName ? "#1565C0" : "#BDBDBD"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                // Status badge
                                Rectangle {
                                    visible: root.currentPlanName !== "" && !batchAppendTimer.running
                                    Layout.preferredWidth: statusBadgeText.implicitWidth + 16
                                    Layout.preferredHeight: 22
                                    radius: 11
                                    color: mcuPairCountLabel.totalPairs > 0 ? "#E8F5E9" : "#FFF3E0"

                                    Label {
                                        id: statusBadgeText
                                        anchors.centerIn: parent
                                        text: mcuPairCountLabel.totalPairs > 0 ? qsTr("Sẵn sàng") : qsTr("Chờ")
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: mcuPairCountLabel.totalPairs > 0 ? "#2E7D32" : "#E65100"
                                    }
                                }

                                // Loading badge
                                Rectangle {
                                    visible: batchAppendTimer.running
                                    Layout.preferredWidth: loadingText.implicitWidth + 16
                                    Layout.preferredHeight: 22
                                    radius: 11
                                    color: "#E3F2FD"

                                    Label {
                                        id: loadingText
                                        anchors.centerIn: parent
                                        text: qsTr("Đang tải... %1%").arg(
                                            root._pendingBatchItems.length > 0
                                                ? Math.round(root._batchIndex / root._pendingBatchItems.length * 100)
                                                : 0)
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: "#1565C0"
                                    }
                                }
                            }

                            // Loading progress bar
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 3
                                color: "#F0F0F0"
                                radius: 2
                                visible: batchAppendTimer.running
                                Layout.bottomMargin: 6

                                Rectangle {
                                    height: parent.height
                                    radius: 2
                                    color: "#42A5F5"
                                    width: parent.width * (root._pendingBatchItems.length > 0
                                        ? root._batchIndex / root._pendingBatchItems.length : 0)

                                    Behavior on width { NumberAnimation { duration: 100 } }
                                }
                            }

                            // Divider
                            Rectangle { Layout.fillWidth: true; height: 1; color: "#F0F0F0" }

                            // Info rows
                            GridLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 8
                                columns: 2
                                columnSpacing: 12
                                rowSpacing: 6

                                // Row 1: Mode
                                Label {
                                    text: qsTr("Mode hiệu chuẩn")
                                    font.pixelSize: 12
                                    color: "#8C8C8C"
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: root.calibrationMode || "—"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#1976D2"
                                    elide: Text.ElideRight
                                }

                                // Row 2: Số cặp
                                Label {
                                    text: qsTr("Cặp điểm đo")
                                    font.pixelSize: 12
                                    color: "#8C8C8C"
                                    visible: root.currentPlanName !== ""
                                }
                                ////Count Pair
                                Label {
                                    id: mcuPairCountLabel
                                    Layout.fillWidth: true
                                    visible: root.currentPlanName !== ""
                                    property int totalPairs: {
                                        var _ = root.currentPlanName
                                        if (batchAppendTimer.running) return 0
                                        var count = 0
                                        for (var i = 0; i < mainTestListModel.count; i++) {
                                            var t = String(mainTestListModel.get(i).scriptType || "")
                                            if (t === "continuity" || t === "sheath_insulation")
                                                count++
                                        }
                                        return count
                                    }
                                    text: batchAppendTimer.running ? "..." : (totalPairs + " cặp")
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: "#E65100"
                                }

                                // Row 3: Serial Number
                                Label {
                                    text: qsTr("Serial (SN)")
                                    font.pixelSize: 12
                                    color: "#8C8C8C"
                                }
                                TextField {
                                    id: snInput
                                    Layout.fillWidth: true
                                    placeholderText: qsTr("Nhập SN sản phẩm...")
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#1565C0"
                                    text: root.productSerialNumber
                                    onTextChanged: root.productSerialNumber = text
                                }

                                // Row 4: Thời gian bắt đầu
                                Label {
                                    text: qsTr("Bắt đầu")
                                    font.pixelSize: 12
                                    color: "#8C8C8C"
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: root.testStartTime ? root.testStartTime : "--"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#2E7D32"
                                }

                                // Row 5: Thời gian kết thúc
                                Label {
                                    text: qsTr("Kết thúc")
                                    font.pixelSize: 12
                                    color: "#8C8C8C"
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: root.testEndTime ? root.testEndTime : "--"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#D32F2F"
                                }
                            }
                        }
                    }

                    // ═══ Nút Xóa kết quả đo ═══
                    Button {
                        id: clearResultsBtn
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        text: qsTr("🗑 Xóa kết quả đo")
                        font.pixelSize: 12
                        font.bold: true
                        enabled: mainTestListModel.count > 0
                        background: Rectangle {
                            color: clearResultsBtn.enabled
                                ? (clearResultsBtn.pressed ? "#B71C1C" : clearResultsBtn.hovered ? "#D32F2F" : "#EF5350")
                                : "#ccc"
                            radius: 6
                        }
                        contentItem: Text {
                            text: clearResultsBtn.text
                            color: "white"
                            font: clearResultsBtn.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: root.clearMeasurementResults()
                    }

                    // ═══ Nút Xuất Excel ═══
                    Button {
                        id: exportExcelBtn
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        text: qsTr("📊 Xuất Excel kết quả đo")
                        font.pixelSize: 12
                        font.bold: true
                        enabled: mainTestListModel.count > 0
                        background: Rectangle {
                            color: exportExcelBtn.enabled
                                ? (exportExcelBtn.pressed ? "#1B5E20" : "#2E7D32")
                                : "#ccc"
                            radius: 6
                        }
                        contentItem: Text {
                            text: exportExcelBtn.text
                            color: "white"
                            font: exportExcelBtn.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: root.exportToExcel()
                    }
                    Label {
                        id: exportMessageLabel
                        text: ""
                        font.pixelSize: 11
                        visible: text !== ""
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Timer {
                        id: exportMessageTimer
                        interval: 4000
                        onTriggered: exportMessageLabel.text = ""
                    }

                    // Dialog hỏi mở file Excel
                    Dialog {
                        id: openExcelDialog
                        title: "Xuất Excel thành công"
                        modal: true
                        anchors.centerIn: Overlay.overlay
                        width: 380
                        standardButtons: Dialog.Yes | Dialog.No
                        onAccepted: {
                            if (root._lastExcelPath) {
                                Qt.openUrlExternally("file:///" + root._lastExcelPath.replace(/\\/g, "/"))
                            }
                        }

                        Column {
                            spacing: 12
                            width: parent.width
                            Text {
                                text: "✅ Tệp Excel báo cáo đã được lưu lại!"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#2E7D32"
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                            Text {
                                text: "Bạn có muốn mở tệp Excel này lên ngay bây giờ không?"
                                font.pixelSize: 13
                                color: "#333"
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }
                    // ═══ Vùng kết quả đo ═══
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        Text {
                            id: plotAreaText
                            width: plotArea.width - 28
                            text: ""
                            color: "#808080"
                            wrapMode: Text.WordWrap
                        }
                    }

                    // ═══ DEBUG: Test máy đo ═══
                    Rectangle {
                        id: debugTestPanel
                        Layout.fillWidth: true
                        Layout.preferredHeight: debugExpanded ? debugContent.implicitHeight + 40 : 30
                        color: "#FFF8E1"
                        border.color: "#FFB300"
                        border.width: 1
                        radius: 6
                        property bool debugExpanded: false
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 200 } }

                        Rectangle {
                            id: debugHeader
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            height: 28; color: "transparent"
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                Text { text: debugTestPanel.debugExpanded ? "▼" : "▶"; font.pixelSize: 10; color: "#E65100" }
                                Text { text: "🔧 Test máy đo"; font.pixelSize: 11; font.bold: true; color: "#E65100" }
                                Text {
                                    text: {
                                        var p = []
                                        if (typeof keithley2110 !== "undefined" && keithley2110 && keithley2110.isOpen) p.push("Keithley 2110 ✓"); else p.push("Keithley 2110 ✕")
                                        return p.join(" | ")
                                    }
                                    font.pixelSize: 10; color: "#888"; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight
                                }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: debugTestPanel.debugExpanded = !debugTestPanel.debugExpanded }
                        }

                        ColumnLayout {
                            id: debugContent
                            anchors.top: debugHeader.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 8
                            spacing: 6; visible: debugTestPanel.debugExpanded

                            RowLayout {
                                Layout.fillWidth: true; spacing: 4
                                Button {
                                    text: "📖 Đọc Keithley 2110"; Layout.fillWidth: true; Layout.preferredHeight: 30; font.pixelSize: 11
                                    enabled: typeof keithley2110 !== "undefined" && keithley2110 && keithley2110.isOpen
                                    background: Rectangle { color: parent.enabled ? (parent.pressed ? "#E65100" : "#FF9800") : "#ccc"; radius: 15 }
                                    contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    onClicked: { debugResultText.text = "Đang đọc Keithley 2110..."; debugResultText.color = "#666"; keithley2110.readResistance() }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true; spacing: 4
                                ComboBox { id: debugDeviceCombo; model: ["Keithley 2110"]; Layout.preferredWidth: 110; Layout.preferredHeight: 28; font.pixelSize: 11 }
                                TextField { id: debugCmdField; Layout.fillWidth: true; Layout.preferredHeight: 28; placeholderText: "Nhập lệnh SCPI..."; font.pixelSize: 11 }
                                Button {
                                    text: "Gửi"; Layout.preferredWidth: 50; Layout.preferredHeight: 28
                                    background: Rectangle { color: parent.pressed ? "#2E7D32" : "#66BB6A"; radius: 14 }
                                    contentItem: Text { text: "Gửi"; color: "white"; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    onClicked: {
                                        var cmd = debugCmdField.text.trim(); if (cmd === "") return
                                        if (typeof keithley2110 !== "undefined" && keithley2110 && keithley2110.isOpen) { keithley2110.sendCommand(cmd); debugResultText.text = "→ Keithley 2110:" + cmd }
                                        else { debugResultText.text = "⚠ Máy chưa kết nối"; debugResultText.color = "#E53935" }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true; spacing: 4
                                Repeater {
                                    model: ["*IDN?", "*RST", ":READ?", ":FETC?", ":MEAS?"]
                                    delegate: Button {
                                        text: modelData; Layout.fillWidth: true; Layout.preferredHeight: 24
                                        background: Rectangle { color: parent.pressed ? "#555" : "#777"; radius: 12 }
                                        contentItem: Text { text: modelData; color: "white"; font.pixelSize: 9; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        onClicked: {
                                            if (typeof keithley2110 !== "undefined" && keithley2110 && keithley2110.isOpen) { keithley2110.sendCommand(modelData); debugResultText.text = "→ Keithley 2110:" + modelData }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 24; color: "#FFFDE7"; border.color: "#FFD54F"; radius: 4
                                Text { id: debugResultText; anchors.fill: parent; anchors.margins: 4; text: "Sẵn sàng"; font.pixelSize: 11; color: "#666"; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                    }

                    // Connections nhận kết quả debug từ RM3544
                    Connections {
                        target: typeof keithley2110 !== "undefined" ? keithley2110 : null
                        function onResistanceRead(value) { debugResultText.text = "✓ RM3545: " + value.toFixed(6) + " Ω"; debugResultText.color = "#2E7D32" }
                        function onErrorOccurred(error) { debugResultText.text = "✕ RM3545: " + error; debugResultText.color = "#E53935" }
                    }
                }
            }

            // Bảng danh sách bài đo bên phải (kéo cạnh trái để to/nhỏ)
            Rectangle {
                id: testListPanel
                SplitView.fillWidth: true
                color: window.darkMode ? "#0F172A" : "#ffffff"
                border.color: window.darkMode ? "#334155" : "#c0c0c0"
                radius: 2
                Behavior on color { ColorAnimation { duration: 400 } }
                Behavior on border.color { ColorAnimation { duration: 400 } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 2

                    // Header: Tick, STT, Bài đo, Giá trị đo, Cận dưới, Cận trên, Thời gian đo
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        // CheckBox tích tất cả (chỉ ảnh hưởng script đo được) — chỉ hiện khi đã đăng nhập
                        CheckBox {
                            id: mainCheckAll
                            visible: window.isLoggedIn
                            Layout.preferredWidth: 28
                            padding: 0
                            indicator.width: 14
                            indicator.height: 14
                            tristate: false

                            function _isMeasurable(scriptType) {
                                var t = String(scriptType || "")
                                return t !== "" && t.indexOf("_header") < 0
                                       && t !== "notification" && t !== "system_init"
                                       && t !== "relay" && t !== "save_result"
                            }

                            // Debounce timer để không loop model mỗi lần tick
                            Timer {
                                id: updateCheckTimer
                                interval: 100
                                repeat: false
                                onTriggered: mainCheckAll._doUpdateChecked()
                            }

                            function updateChecked() {
                                updateCheckTimer.restart()
                            }

                            function _doUpdateChecked() {
                                var hasMeasurable = false
                                var allChecked = true
                                for (var i = 0; i < mainTestListModel.count; i++) {
                                    var item = mainTestListModel.get(i)
                                    if (!_isMeasurable(item.scriptType)) continue
                                    hasMeasurable = true
                                    if (item.allowRun === false) {
                                        allChecked = false
                                        break
                                    }
                                }
                                mainCheckAll.checked = hasMeasurable && allChecked
                            }
                            Component.onCompleted: _doUpdateChecked()
                            onClicked: {
                                var newValue = checked
                                for (var i = 0; i < mainTestListModel.count; i++) {
                                    if (_isMeasurable(mainTestListModel.get(i).scriptType))
                                        mainTestListModel.setProperty(i, "allowRun", newValue)
                                }
                            }
                        }
                        Label {
                            text: qsTr("STT")
                            Layout.preferredWidth: 30
                            horizontalAlignment: Text.AlignHCenter
                            font.bold: true
                            padding: 2
                            background: Rectangle { color: window.darkMode ? "#1E293B" : "#e0e0e0"; Behavior on color { ColorAnimation { duration: 400 } } }
                            color: window.darkMode ? "#CBD5E1" : "#333"
                        }
                        Label {
                            text: qsTr("Bài đo")
                            Layout.preferredWidth: root.baiDoColumnWidth
                            horizontalAlignment: Text.AlignHCenter
                            font.bold: true
                            padding: 2
                            background: Rectangle { color: window.darkMode ? "#1E293B" : "#e0e0e0"; Behavior on color { ColorAnimation { duration: 400 } } }
                            color: window.darkMode ? "#CBD5E1" : "#333"
                        }
                        Item {
                            Layout.preferredWidth: 6
                            Layout.preferredHeight: 24
                            Layout.alignment: Qt.AlignVCenter
                            MouseArea {
                                id: baiDoDragMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.SplitHCursor
                                property int startX: 0
                                property int startW: 0
                                onPressed: (mouse) => { startX = mouse.x; startW = root.baiDoColumnWidth }
                                onPositionChanged: (mouse) => {
                                    if (pressed)
                                        root.baiDoColumnWidth = Math.max(100, Math.min(500, startW + (mouse.x - startX)))
                                }
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: baiDoDragMa.hovered || baiDoDragMa.pressed ? "#2196F3" : "#ccc"
                                opacity: baiDoDragMa.hovered || baiDoDragMa.pressed ? 0.5 : 0.4
                            }
                        }
                        Label {
                            text: qsTr("Giá trị đo")
                            Layout.preferredWidth: 85  // Đồng bộ với Delegate
                            horizontalAlignment: Text.AlignHCenter
                            font.bold: true
                            padding: 2
                            background: Rectangle { color: window.darkMode ? "#1E293B" : "#e0e0e0"; Behavior on color { ColorAnimation { duration: 400 } } }
                            color: window.darkMode ? "#CBD5E1" : "#333"
                        }
                        Label {
                            text: qsTr("Cận dưới")
                            Layout.preferredWidth: 70  // Nới rộng chống dính chữ
                            horizontalAlignment: Text.AlignHCenter
                            font.bold: true
                            padding: 2
                            background: Rectangle { color: window.darkMode ? "#1E293B" : "#e0e0e0"; Behavior on color { ColorAnimation { duration: 400 } } }
                            color: window.darkMode ? "#CBD5E1" : "#333"
                        }
                        Label {
                            text: qsTr("Cận trên")
                            Layout.preferredWidth: 70  // Nới rộng chống dính chữ
                            horizontalAlignment: Text.AlignHCenter
                            font.bold: true
                            padding: 2
                            background: Rectangle { color: window.darkMode ? "#1E293B" : "#e0e0e0"; Behavior on color { ColorAnimation { duration: 400 } } }
                            color: window.darkMode ? "#CBD5E1" : "#333"
                        }
                        Label {
                            text: qsTr("Thời gian đo")
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            font.bold: true
                            padding: 2
                            background: Rectangle { color: window.darkMode ? "#16213e" : "#e0e0e0"; Behavior on color { ColorAnimation { duration: 400 } } }
                            color: window.darkMode ? "#ccc" : "#333"
                        }
                    }

                    ListView {
                        id: testListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        cacheBuffer: 2000
                        reuseItems: false
                        model: mainTestListModel
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AlwaysOn
                            size: 0.5
                        }

                        delegate: Rectangle {
                            id: testDelegate
                            width: ListView.view.width

                            property string sType: model.scriptType || ""
                            property bool isHeader: sType.indexOf("_header") >= 0
                            property bool isNotification: sType === "notification"
                            property bool isSystemInit: sType === "system_init"
                            property bool isRelay: sType === "relay"
                            property bool isSaveResult: sType === "save_result"
                            property bool isMeasurable: !isHeader && !isNotification && !isSystemInit
                                                        && !isRelay && !isSaveResult

                            // Cache formatted bounds để không gọi _formatBound mỗi frame
                            property string fmtLower: isMeasurable ? root._formatBound(sType, model.limitLower, false) : ""
                            property string fmtUpper: isMeasurable ? root._formatBound(sType, model.limitUpper, true) : ""
                            property string resStatus: model.resultStatus || ""

                            height: testDelegate.isCollapsed ? 0 : 24
                            clip: true
                            color: isHeader ? (window.darkMode ? "#1E1B4B" : "#E8EAF6")
                                 : isNotification ? (window.darkMode ? "#422006" : "#FFF8E1")
                                 : isSystemInit ? (window.darkMode ? "#064E3B" : "#E0F2F1")
                                 : isRelay ? (window.darkMode ? "#172554" : "#E3F2FD")
                                 : isSaveResult ? (window.darkMode ? "#14532D" : "#E8F5E9")
                                 : resStatus === "PASS" ? (window.darkMode ? "rgba(16, 185, 129, 0.15)" : "#C8E6C9")
                                 : resStatus === "FAIL" ? (window.darkMode ? "rgba(239, 68, 68, 0.2)" : "#FFCDD2")
                                 : resStatus === "NAK"  ? (window.darkMode ? "rgba(251, 146, 60, 0.25)" : "#FFE0B2")
                                 : (index % 2 === 0 ? (window.darkMode ? "#1E293B" : "#ffffff") : (window.darkMode ? "#0F172A" : "#f8f8f8"))
                            opacity: isMeasurable ? ((model.allowRun !== false) ? 1.0 : 0.4) : 1.0

                            // Kiểm tra xem script này có bị ẩn bởi header gập không
                            property bool isCollapsed: {
                                if (isHeader) return false  // Header luôn hiện
                                // Tìm header gần nhất phía trên
                                for (var h = index - 1; h >= 0; h--) {
                                    var item = mainTestListModel.get(h)
                                    if (item && String(item.scriptType || "").indexOf("_header") >= 0) {
                                        return item.expanded === false
                                    }
                                }
                                return false
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 1
                                spacing: 1

                                // CheckBox — chỉ hiện khi đã đăng nhập + bài đo
                                CheckBox {
                                    visible: testDelegate.isMeasurable && window.isLoggedIn
                                    Layout.preferredWidth: 28
                                    padding: 0
                                    indicator.width: 14
                                    indicator.height: 14
                                    checked: model.allowRun !== false
                                    onToggled: {
                                        mainTestListModel.setProperty(index, "allowRun", checked)
                                        mainCheckAll.updateChecked()
                                    }
                                }
                                // Spacer — thay checkbox cho header/notification/system_init (chỉ khi đã login)
                                Item {
                                    visible: !testDelegate.isMeasurable && window.isLoggedIn
                                    Layout.preferredWidth: 28
                                }
                                // Icon cho các loại đặc biệt
                                Label {
                                    visible: !testDelegate.isMeasurable && !testDelegate.isHeader
                                    text: testDelegate.isNotification ? "📋"
                                        : testDelegate.isSystemInit ? "⚙"
                                        : testDelegate.isRelay ? "🔌"
                                        : testDelegate.isSaveResult ? "💾" : ""
                                    font.pixelSize: 12
                                    verticalAlignment: Text.AlignVCenter
                                }
                                // STT — chỉ cho bài đo
                                // STT — chỉ cho bài đo
                                Label {
                                    visible: testDelegate.isMeasurable
                                    text: index + 1
                                    Layout.preferredWidth: testDelegate.isMeasurable ? 30 : 0
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 11
                                    color: window.darkMode ? "#bbb" : "#333"
                                    padding: 2
                                }
                                // Tên bài đo / tên nhóm / thông báo
                                Label {
                                    text: testDelegate.isHeader
                                        ? ((model.expanded !== false ? "▼ " : "▶ ") + (model.displayText || ""))
                                        : (model.displayText || "")
                                    Layout.fillWidth: !testDelegate.isMeasurable
                                    Layout.preferredWidth: testDelegate.isMeasurable ? root.baiDoColumnWidth : -1
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: testDelegate.isHeader ? 12 : 11
                                    font.bold: testDelegate.isHeader
                                    font.italic: testDelegate.isNotification
                                    color: testDelegate.isHeader ? (window.darkMode ? "#818CF8" : "#283593")
                                         : testDelegate.isNotification ? (window.darkMode ? "#FBBF24" : "#E65100")
                                         : testDelegate.isSystemInit ? (window.darkMode ? "#34D399" : "#00695C")
                                         : testDelegate.isRelay ? (window.darkMode ? "#60A5FA" : "#1565C0")
                                         : testDelegate.isSaveResult ? (window.darkMode ? "#A7F3D0" : "#2E7D32")
                                         : (window.darkMode ? "#F1F5F9" : "#333")
                                    padding: 2
                                    leftPadding: testDelegate.isHeader ? 4 : 12

                                    // Header click → toggle expand/collapse
                                    MouseArea {
                                        anchors.fill: parent
                                        visible: testDelegate.isHeader
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var exp = mainTestListModel.get(index).expanded
                                            mainTestListModel.setProperty(index, "expanded", !exp)
                                        }
                                    }
                                }
                                // Các cột đo — chỉ hiện cho bài đo
                                Label {
                                    visible: testDelegate.isMeasurable
                                    text: model.measuredValue || ""
                                    Layout.preferredWidth: 85  // Phải khớp với Header
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 11
                                    color: window.darkMode ? "#ddd" : "#333"
                                    padding: 2
                                }
                                Label {
                                    visible: testDelegate.isMeasurable
                                    text: testDelegate.fmtLower
                                    Layout.preferredWidth: 70  // Phải khớp với Header
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 11
                                    color: window.darkMode ? "#aab" : "#333"
                                    padding: 2
                                }
                                Label {
                                    visible: testDelegate.isMeasurable
                                    text: testDelegate.fmtUpper
                                    Layout.preferredWidth: 70  // Phải khớp với Header
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 11
                                    color: window.darkMode ? "#aab" : "#333"
                                    padding: 2
                                }
                                Label {
                                    visible: testDelegate.isMeasurable
                                    text: model.measureTime || ""
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 11
                                    color: window.darkMode ? "#99a" : "#333"
                                    padding: 2
                                }
                            }
                        }
                    }
                }
            }
        }

        // Hàng dưới: SN + trạng thái + nút bắt đầu/gửi
        Rectangle {
            id: bottomBar
            visible: root.interfaceMode !== "manual"
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            color: window.darkMode ? "#0F172A" : "#f0f0f0"
            border.color: window.darkMode ? "#334155" : "#c0c0c0"
            Behavior on color { ColorAnimation { duration: 400 } }
            Behavior on border.color { ColorAnimation { duration: 400 } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                Rectangle {
                    visible: root.interfaceMode === "manual"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 6
                    color: "#E3F2FD"
                    border.color: "#90CAF9"
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        Text {
                            text: qsTr("Chế độ thủ công: tick script cần chạy, rồi bấm Gửi đã chọn hoặc Sửa bài đo")
                            color: "#1565C0"
                            font.pixelSize: 12
                            font.bold: true
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                        Button {
                            text: qsTr("Sửa bài đo")
                            onClicked: {
                                if (root.editPlanDialog && root.currentPlanName) {
                                    root.editPlanDialog.openEditTab(root.currentPlanName)
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    ColumnLayout {
                        Layout.fillHeight: true
                        Layout.fillWidth: true

                        Rectangle {
                            id: statusPanel
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: window.darkMode ? "#1E293B" : "#f8f9fa"
                            border.color: window.darkMode ? "#334155" : "#c0c0c0"
                            Behavior on color { ColorAnimation { duration: 400 } }
                            Behavior on border.color { ColorAnimation { duration: 400 } }

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 0

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 26
                                    color: window.darkMode ? "#0F172A" : "#e0e0e0"
                                    Behavior on color { ColorAnimation { duration: 400 } }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 4
                                        Text {
                                            text: "NHẬT KÝ HỆ THỐNG / LỖI"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: window.darkMode ? "#aab" : "#555"
                                            Layout.fillWidth: true
                                        }
                                        Button {
                                            text: "🗑 Xóa"
                                            Layout.preferredHeight: 20
                                            Layout.preferredWidth: 60
                                            font.pixelSize: 11
                                            background: Rectangle { color: "#ffcdd2"; radius: 3; border.color: "#ef5350" }
                                            contentItem: Text { text: parent.text; color: "#c62828"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                            onClicked: { statusAreaText.text = "" }
                                        }
                                    }
                                }

                                ScrollView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true

                                    TextArea {
                                        id: statusAreaText
                                        readOnly: true
                                        color: window.darkMode ? "#F8FAFC" : "#333"
                                        font.pixelSize: 12
                                        wrapMode: Text.Wrap
                                        background: null
                                        textFormat: Text.RichText
                                        text: ""
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: startButtonRect
                        Layout.preferredWidth: 260
                        Layout.fillHeight: true
                        color: window.darkMode ? (mouseArea.pressed ? "#D97706" : "#F59E0B") : (mouseArea.pressed ? "#F59E0B" : "#FBBF24")
                        border.color: window.darkMode ? "#B45309" : "#D97706"
                        radius: 8

                        Behavior on color { ColorAnimation { duration: 200 } }

                        Text {
                            anchors.centerIn: parent
                            text: root.interfaceMode === "manual" ? qsTr("GỬI ĐÃ CHỌN") : qsTr("BẮT ĐẦU")
                            font.pixelSize: root.interfaceMode === "manual" ? 28 : 40
                            font.bold: true
                            color: window.darkMode ? "#1E1B4B" : "#000000"
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            onClicked: {
                                if (!root.currentPlanName) {
                                    logMessage("Chưa chọn bài đo. Vào Danh sách bài đo → chọn bài trước khi bắt đầu.", true)
                                    return
                                }
                                if (typeof testPlanManager === "undefined" || !testPlanManager) {
                                    logMessage("testPlanManager chưa sẵn sàng.", true)
                                    return
                                }
                                var rawScripts = testPlanManager.loadScripts(root.currentPlanName) || []
                                var scripts = []
                                for (var fi = 0; fi < rawScripts.length; fi++) {
                                    if (rawScripts[fi].allowRun !== false)
                                        scripts.push(rawScripts[fi])
                                }
                                if (scripts.length === 0) {
                                    logMessage("Bài đo \"" + root.currentPlanName + "\" không có script nào (hoặc tất cả bị bỏ tick).", true)
                                    return
                                }
                                if (typeof mcuSender === "undefined" || !mcuSender) {
                                    logMessage("Bộ chuyển mạch (mcuSender) chưa sẵn sàng.", true)
                                    return
                                }
                                if (!mcuSender.portName || String(mcuSender.portName).trim() === "") {
                                    logMessage("Chưa cấu hình cổng COM bộ chuyển mạch. Vào: Tùy chọn → Thiết bị → chọn Cổng COM → OK.", true)
                                    return
                                }
                                if (!mcuSender.isOpen) {
                                    if (!mcuSender.openPort()) {
                                        logMessage("Không mở được cổng COM" + mcuSender.portName + ". Kiểm tra thiết bị đã cắm và đúng số cổng trong Tùy chọn → Thiết bị.", true)
                                        return
                                    } else {
                                        logMessage("Đã mở cổng COM" + mcuSender.portName + " thành công.", false)
                                    }
                                }
                                root._runScripts(scripts)

                            }
                        }
                    }
                }
            }
        }
    }
}



