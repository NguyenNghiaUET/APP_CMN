import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import CMN_TESTING

ApplicationWindow {
    id: root
    visible: true
    minimumWidth:  1300
    minimumHeight: 820
    width:  1440
    height: 900
    title: "CMN TESTING — HỆ THỐNG KIỂM TRA THIẾT BỊ CHUYỂN MẠCH NGUỒN"

    // Cửa sổ đo kiểm cáp (mở bằng nút AUTO)



    AutoTestWindow    { id: autoTestWindow }
    CmnAutoTestWindow { id: cmnAutoWindow }

    // ── Dark steel military palette ────────────────────────────────────
    readonly property color cBg:      "#0c1014"
    readonly property color cPanel:   "#121c22"
    readonly property color cHdr:     "#0a1318"
    readonly property color cRow0:    "#111a20"
    readonly property color cRow1:    "#162028"
    readonly property color cBorder:  "#2a4050"
    readonly property color cText:    "#b8ccc0"
    readonly property color cDim:     "#526860"
    readonly property color cAccent:  "#3a8060"
    readonly property color cGreen:   "#2eb870"
    readonly property color cRed:     "#c03838"
    readonly property color cYellow:  "#c09030"
    readonly property color cCyan:    "#38a8a0"
    readonly property color cPurple:  "#7898a8"
    readonly property color cInput:   "#080e12"

    // login state
    property bool loggedIn: false

    // ── Manual relay state (COL 2) ────────────────────────────────────
    property var  relayStates:    ({})   // {name: true/false}, undefined = chưa đặt
    property var  _relayQueue:    []
    property int  _relayQueueIdx: 0
    property bool _sendingRelays: false

    function _sendAllRelays() {
        if (_sendingRelays) return
        var keys = Object.keys(relayStates)
        if (keys.length === 0) { appController.addLog("[MCU] Không có relay nào được đặt!"); return }
        if (!mcuSender.isOpen)  { appController.addLog("[MCU] Cổng COM chưa kết nối!");    return }
        _relayQueue = []
        for (var i = 0; i < keys.length; i++)
            _relayQueue.push({name: keys[i], state: relayStates[keys[i]]})
        _relayQueueIdx = 0
        _sendingRelays = true
        _sendNextRelayItem()
    }

    function _sendNextRelayItem() {
        if (_relayQueueIdx >= _relayQueue.length) {
            _sendingRelays = false
            relayAckTimer.stop()
            appController.addLog("[MCU] << SET RELAY hoàn tất " + _relayQueue.length + " relay")
            return
        }
        var r = _relayQueue[_relayQueueIdx]
        if (!mcuSender.sendRelayByName(r.name, r.state)) {
            // sendRelayByName trả false (port đóng...) → abort
            _sendingRelays = false
            relayAckTimer.stop()
            appController.addLog("[MCU] LỖI gửi relay " + r.name + " — dừng queue")
            return
        }
        appController.addLog("[MCU] >> " + r.name + (r.state ? "  ON (0xA0)" : "  OFF (0x00)"))
        relayAckTimer.restart()   // bắt đầu đếm timeout
    }

    // Timeout chờ ACK relay — nếu MCU không trả lời trong 2s thì skip
    Timer {
        id: relayAckTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (!root._sendingRelays) return
            var r = root._relayQueue[root._relayQueueIdx]
            appController.addLog("[MCU] TIMEOUT relay " + (r ? r.name : "?") + " — không nhận ACK, bỏ qua")
            root._relayQueueIdx++
            root._sendNextRelayItem()
        }
    }

    background: Rectangle { color: cBg }

    // ── Button ────────────────────────────────────────────────────────
    component CBtn: Rectangle {
        id: cb
        property string lbl: ""; property color bc: cAccent
        property bool   ena: true; property int  fs: 11
        signal tapped()
        radius: 4
        color: !ena ? "#0a100a" : ma.pressed ? Qt.darker(bc,1.6) : ma.containsMouse ? Qt.lighter(bc,1.2) : Qt.darker(bc,1.1)
        border.color: ena ? bc : "#1a2a1a"
        Text { anchors.centerIn: parent; text: cb.lbl
               color: ena ? (ma.containsMouse ? "white" : cText) : cDim
               font.pixelSize: cb.fs; font.bold: true; font.family: "Consolas" }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true
                    enabled: cb.ena; onClicked: cb.tapped() }
    }

    // ═════════════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent; spacing: 0

        // ── TOP BAR ──────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 50; color: cHdr
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 14

                Column {
                    spacing: 2
                    Text { text: "CMN TESTING"; color: cCyan
                           font.pixelSize: 17; font.bold: true; font.letterSpacing: 3; font.family: "Consolas" }
                    Text { text: "HỆ THỐNG KIỂM TRA THIẾT BỊ CHUYỂN MẠCH NGUỒN"
                           color: cDim; font.pixelSize: 8; font.letterSpacing: 1; font.family: "Consolas" }
                }
                Rectangle { width: 1; height: 36; color: cBorder }

                Text { text: "S/N DUT:"; color: cDim; font.pixelSize: 12 }
                TextField {
                    id: snField; width: 155; height: 32
                    placeholderText: "Nhập serial number..."; placeholderTextColor: "#445577"
                    color: cText; font.pixelSize: 12; font.family: "Consolas"; leftPadding: 8
                    background: Rectangle { color: cInput; border.color: cBorder; radius: 4 }
                }
                CBtn { lbl: "▶  RUN TEST"; bc: cGreen; width: 108; height: 32; fs: 12
                    onTapped: appController.addLog("▶ Run — S/N: " + (snField.text || "(trống)")) }
                CBtn { lbl: "ĐO KIỂM CÁP"; bc: cPurple; width: 100; height: 32; fs: 11
                    onTapped: autoTestWindow.openWindow() }
                CBtn { lbl: "AUTO TEST"; bc: "#c06020"; width: 90; height: 32; fs: 11
                    onTapped: cmnAutoWindow.openWindow() }

              Rectangle { width: 1; height: 36; color: cBorder }

                Repeater {
                    model: [
                        {l:"TOTAL", v: appController.totalTests.toString(),    c: cCyan},
                        {l:"OK",    v: appController.okTests.toString(),       c: cGreen},
                        {l:"NG",    v: appController.ngTests.toString(),       c: cRed},
                        {l:"FAIL%", v: appController.failRate.toFixed(1)+" %", c: cYellow}
                    ]
                    delegate: Column {
                        spacing: 1
                        Text { text: modelData.l; color: cDim; font.pixelSize: 9
                               anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: modelData.v; color: modelData.c
                               font.pixelSize: 15; font.bold: true; font.family: "Consolas" }
                    }
                }
                CBtn { lbl: "CLR"; bc: "#37474f"; width: 42; height: 28; fs: 10
                    onTapped: appController.clearStats() }

                Rectangle { width: 1; height: 36; color: cBorder }

                Repeater {
                    model: [
                        {l:"Ctrl Box", on: controllerBox.connected},
                        {l:"MR3K160",  on: mrController.connected},
                        {l:"MDL400",   on: mdlController.connected},
                        {l:"SigMeter", on: sigMeasure.connected}
                    ]
                    delegate: Row {
                        spacing: 5
                        Rectangle {
                            width: 11; height: 11; radius: 6
                            color: modelData.on ? cGreen : cRed
                            anchors.verticalCenter: parent.verticalCenter
                            SequentialAnimation on opacity {
                                running: modelData.on; loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 800 }
                                NumberAnimation { to: 1.0; duration: 800 }
                            }
                        }
                        Text { text: modelData.l; color: cDim; font.pixelSize: 11
                               anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 2; color: cAccent; opacity: 0.7 }

        // ── 3 COLUMNS ─────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.margins: 8; spacing: 8

            // ════════════════════════════════════════════
            // COL 1 — Power  (fixed 270 px)
            // ════════════════════════════════════════════
            ColumnLayout {
                Layout.preferredWidth: 270
                Layout.maximumWidth:   270
                Layout.fillHeight: true
                spacing: 8

                // Kích hoạt
                Rectangle {
                    Layout.fillWidth: true; height: 108
                    color: cPanel; border.color: cBorder; radius: 8

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 0; spacing: 0

                        Rectangle {
                            Layout.fillWidth: true; height: 30; color: cHdr; radius: 8
                            Rectangle { Layout.fillWidth: true; height: 8; color: cHdr
                                        anchors.bottom: parent.bottom }
                            Text { anchors.verticalCenter: parent.verticalCenter
                                   anchors.left: parent.left; anchors.leftMargin: 12
                                   text: "Kích hoạt"; color: cCyan; font.pixelSize: 12; font.bold: true }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            Layout.margins: 10; spacing: 8

                            Rectangle {
                                Layout.fillWidth: true; height: 28; radius: 5
                                color: mrController.outputEnabled ? "#0a2818" : "#2a0e0e"
                                border.color: mrController.outputEnabled ? cGreen : cRed
                                Row {
                                    anchors.centerIn: parent; spacing: 8
                                    Rectangle { width: 10; height: 10; radius: 5
                                                color: mrController.outputEnabled ? "#69f0ae" : "#ff5252"
                                                anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: mrController.outputEnabled ? "OUTPUT  ON" : "OUTPUT  OFF"
                                           color: mrController.outputEnabled ? "#69f0ae" : "#ff5252"
                                           font.pixelSize: 13; font.bold: true; font.letterSpacing: 1 }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                CBtn { lbl: "ON";  bc: cGreen; Layout.preferredWidth: 68; height: 28; fs: 12
                                    onTapped: { mrController.setOutput(true);  appController.addLog("[MR3K] >> OUTPUT ON") } }
                                CBtn { lbl: "OFF"; bc: cRed;   Layout.preferredWidth: 68; height: 28; fs: 12
                                    onTapped: { mrController.setOutput(false); appController.addLog("[MR3K] >> OUTPUT OFF") } }
                                CBtn { lbl: "Bật File"; bc: "#1565c0"; Layout.fillWidth: true; height: 28; fs: 10
                                    onTapped: appController.addLog("Bật File...") }
                            }
                        }
                    }
                }

                // Điều khiển cấp nguồn
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: cPanel; border.color: cBorder; radius: 8

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 0; spacing: 0

                        Rectangle {
                            Layout.fillWidth: true; height: 30; color: cHdr; radius: 8
                            Rectangle { width: parent.width; height: 8; anchors.bottom: parent.bottom; color: cHdr }
                            Text { anchors.verticalCenter: parent.verticalCenter
                                   anchors.left: parent.left; anchors.leftMargin: 12
                                   text: "Điều khiển cấp nguồn  —  BK MR3K160120"
                                   color: cCyan; font.pixelSize: 11; font.bold: true }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            Layout.leftMargin: 10; Layout.rightMargin: 10
                            Layout.topMargin: 10; Layout.bottomMargin: 10
                            spacing: 10

                            // IP + connect
                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                Rectangle {
                                    Layout.fillWidth: true; height: 28; radius: 4
                                    color: cInput; border.color: cBorder
                                    TextInput { id: mrIp; anchors.fill: parent; anchors.margins: 6
                                        text: "192.168.1.100"; color: cText
                                        font.pixelSize: 11; font.family: "Consolas" }
                                }
                                CBtn { lbl: mrController.connected ? "Ngắt" : "Kết nối"
                                    bc: mrController.connected ? "#546e7a" : cAccent
                                    Layout.preferredWidth: 78; height: 28; fs: 11
                                    onTapped: {
                                        if (mrController.connected) {
                                            mrController.disconnectDevice()
                                            appController.addLog("[MR3K] Ngắt kết nối")
                                        } else {
                                            mrController.connectDevice(mrIp.text, 5025)
                                            appController.addLog("[MR3K] Kết nối tới " + mrIp.text + ":5025...")
                                        }
                                    } }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: cBorder }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2; columnSpacing: 8; rowSpacing: 8

                                Text { text: "Điện áp (V)";     color: cDim; font.pixelSize: 11; Layout.preferredWidth: 106 }
                                Rectangle {
                                    Layout.fillWidth: true; height: 36; radius: 4
                                    color: cInput; border.color: cBorder
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 6
                                        TextInput {
                                            Layout.fillWidth: true
                                            text: mrController.setVoltage.toFixed(1)
                                            color: cYellow; font.pixelSize: 16; font.bold: true; font.family: "Consolas"
                                            onEditingFinished: mrController.setVoltage = parseFloat(text)||0
                                        }
                                        Text { text: "V"; color: cDim; font.pixelSize: 11 }
                                    }
                                }

                                Text { text: "Dòng tối đa (A)"; color: cDim; font.pixelSize: 11; Layout.preferredWidth: 106 }
                                Rectangle {
                                    Layout.fillWidth: true; height: 36; radius: 4
                                    color: cInput; border.color: cBorder
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 6
                                        TextInput {
                                            Layout.fillWidth: true
                                            text: mrController.setCurrent.toFixed(2)
                                            color: cYellow; font.pixelSize: 16; font.bold: true; font.family: "Consolas"
                                            onEditingFinished: mrController.setCurrent = parseFloat(text)||0
                                        }
                                        Text { text: "A"; color: cDim; font.pixelSize: 11 }
                                    }
                                }

                                Text { text: "Dòng OCP (A)";    color: cDim; font.pixelSize: 11; Layout.preferredWidth: 106 }
                                Rectangle {
                                    Layout.fillWidth: true; height: 36; radius: 4
                                    color: cInput; border.color: cBorder
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 6
                                        TextInput {
                                            Layout.fillWidth: true
                                            text: mrController.setOCP.toFixed(2)
                                            color: cYellow; font.pixelSize: 16; font.bold: true; font.family: "Consolas"
                                            onEditingFinished: mrController.setOCP = parseFloat(text)||0
                                        }
                                        Text { text: "A"; color: cDim; font.pixelSize: 11 }
                                    }
                                }
                            }

                            CBtn { lbl: "SET"; bc: cAccent; Layout.fillWidth: true; height: 34; fs: 14
                                onTapped: {
                                    mrController.applySettings()
                                    appController.addLog("[MR3K] >> SET V=" + mrController.setVoltage.toFixed(1)
                                        + "V  I=" + mrController.setCurrent.toFixed(2)
                                        + "A  OCP=" + mrController.setOCP.toFixed(2) + "A")
                                } }

                            Rectangle { Layout.fillWidth: true; height: 1; color: cBorder }

                            Repeater {
                                model: [
                                    {l:"ĐIỆN ÁP ĐO",   v: mrController.measVoltage.toFixed(3)+" V", c: cGreen},
                                    {l:"DÒNG ĐIỆN ĐO", v: mrController.measCurrent.toFixed(4)+" A", c: cCyan},
                                    {l:"CÔNG SUẤT ĐO", v: mrController.measPower.toFixed(3)  +" W", c: cYellow}
                                ]
                                delegate: Rectangle {
                                    Layout.fillWidth: true; height: 38; radius: 5
                                    color: cRow0; border.color: cBorder
                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                        Text { text: modelData.l; color: cDim; font.pixelSize: 11; Layout.preferredWidth: 100 }
                                        Text { text: modelData.v; color: modelData.c
                                               font.pixelSize: 17; font.bold: true; font.family: "Consolas" }
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════
            // COL 2 — Relay  (fixed 320 px)
            // ════════════════════════════════════════════
            Rectangle {
                Layout.preferredWidth: 320
                Layout.maximumWidth:   320
                Layout.fillHeight: true
                color: cPanel; border.color: cBorder; radius: 8

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 0; spacing: 0

                    Rectangle {
                        Layout.fillWidth: true; height: 30; color: cHdr; radius: 8
                        Rectangle { width: parent.width; height: 8; anchors.bottom: parent.bottom; color: cHdr }
                        Text { anchors.verticalCenter: parent.verticalCenter
                               anchors.left: parent.left; anchors.leftMargin: 12
                               text: "Nút nhấn thao tác lệnh"; color: cCyan; font.pixelSize: 12; font.bold: true }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        Layout.margins: 10; spacing: 8

                        // COM port — MCU relay (mcuSender)
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Text { text: "MCU:"; color: cDim; font.pixelSize: 10; font.family: "Consolas" }
                            ComboBox {
                                id: mcuRelayPort
                                Layout.fillWidth: true; height: 26; font.pixelSize: 11
                                background: Rectangle { color: cInput; border.color: cBorder; radius: 3 }
                                contentItem: Text { text: mcuRelayPort.displayText; color: cText
                                                    font.pixelSize: 11; leftPadding: 6
                                                    verticalAlignment: Text.AlignVCenter }
                                Component.onCompleted: {
                                    var ports = mcuSender.getAvailablePorts()
                                    model = ports
                                    var idx = ports.indexOf(mcuSender.portName)
                                    currentIndex = idx >= 0 ? idx : (ports.length > 0 ? 0 : -1)
                                }
                            }
                            // Refresh
                            CBtn { lbl: "↻"; bc: "#37474f"; width: 24; height: 26; fs: 12
                                onTapped: {
                                    var cur = mcuRelayPort.currentText
                                    var ports = mcuSender.getAvailablePorts()
                                    mcuRelayPort.model = ports
                                    var idx = ports.indexOf(cur)
                                    mcuRelayPort.currentIndex = idx >= 0 ? idx : (ports.length > 0 ? 0 : -1)
                                } }
                            CBtn {
                                lbl: mcuSender.isOpen ? "Ngắt" : "Kết nối"
                                bc:  mcuSender.isOpen ? "#546e7a" : cAccent
                                width: 72; height: 26; fs: 10
                                onTapped: {
                                    if (mcuSender.isOpen) {
                                        mcuSender.closePort()
                                        appController.addLog("[MCU] Ngắt cổng " + mcuRelayPort.currentText)
                                    } else {
                                        if (mcuRelayPort.currentText) mcuSender.portName = mcuRelayPort.currentText
                                        mcuSender.openPort()
                                        appController.addLog("[MCU] Kết nối cổng " + mcuRelayPort.currentText + " @115200")
                                    }
                                }
                            }
                            // Status dot
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: mcuSender.isOpen ? cGreen : cRed
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // COM port — ControllerBox (JSON protocol, giữ lại)
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Text { text: "BOX:"; color: cDim; font.pixelSize: 10; font.family: "Consolas" }
                            ComboBox {
                                id: boxPort; model: availablePorts
                                Layout.fillWidth: true; height: 26; font.pixelSize: 11
                                background: Rectangle { color: cInput; border.color: cBorder; radius: 3 }
                                contentItem: Text { text: boxPort.displayText; color: cText
                                                    font.pixelSize: 11; leftPadding: 6
                                                    verticalAlignment: Text.AlignVCenter }
                            }
                            CBtn { lbl: controllerBox.connected ? "Ngắt" : "Kết nối"
                                bc: controllerBox.connected ? "#546e7a" : "#37474f"
                                width: 72; height: 26; fs: 10
                                onTapped: {
                                    if (controllerBox.connected) {
                                        controllerBox.disconnectPort()
                                        appController.addLog("[BOX] Ngắt cổng " + boxPort.currentText)
                                    } else {
                                        controllerBox.connectPort(boxPort.currentText, 115200)
                                        appController.addLog("[BOX] Kết nối cổng " + boxPort.currentText + " @115200...")
                                    }
                                } }
                        }

                        // Table header
                        Rectangle {
                            Layout.fillWidth: true; height: 28; color: cHdr; radius: 3
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; spacing: 0
                                Text { text: "Tên relay";  Layout.preferredWidth: 120; height: 28
                                       verticalAlignment: Text.AlignVCenter
                                       color: cCyan; font.pixelSize: 11; font.bold: true }
                                Text { text: "ON";  Layout.preferredWidth: 60; height: 28
                                       horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                       color: cCyan; font.pixelSize: 11; font.bold: true }
                                Text { text: "OFF"; Layout.preferredWidth: 60; height: 28
                                       horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                       color: cCyan; font.pixelSize: 11; font.bold: true }
                                Text { text: "Đáp ứng"; Layout.fillWidth: true; height: 28
                                       horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                       color: cCyan; font.pixelSize: 11; font.bold: true }
                            }
                        }

                        // Rows
                        ListView {
                            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                            model: ["VLS_ON","Bat1_ON","Bat2_ON","Gen_ON",
                                    "VLS_BatON","VLS_BatOFF","MPSS_TBKT",
                                    "CMD_ERM","CMD_PUMP","CCBH_in",
                                    "CMD_PPA","CMD_Pyro1","CMD_Pyro2",
                                    "CMD_TJE","CMD_FUZE"]
                            delegate: Rectangle {
                                width: ListView.view.width; height: 32
                                color: index % 2 === 0 ? cRow0 : cRow1
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 0
                                    Text { text: modelData; Layout.preferredWidth: 120
                                           color: cText; font.pixelSize: 12; font.family: "Consolas" }
                                    CBtn {
                                        lbl: "ON"
                                        bc: root.relayStates[modelData] === true  ? cGreen
                                          : root.relayStates[modelData] === false ? "#203020"
                                          : "#37474f"
                                        Layout.preferredWidth: 52; height: 22; fs: 10
                                        onTapped: {
                                            var ns = Object.assign({}, root.relayStates)
                                            ns[modelData] = true
                                            root.relayStates = ns
                                        }
                                    }
                                    Item { Layout.preferredWidth: 4 }
                                    CBtn {
                                        lbl: "OFF"
                                        bc: root.relayStates[modelData] === false ? cRed
                                          : root.relayStates[modelData] === true  ? "#302020"
                                          : "#37474f"
                                        Layout.preferredWidth: 52; height: 22; fs: 10
                                        onTapped: {
                                            var ns = Object.assign({}, root.relayStates)
                                            ns[modelData] = false
                                            root.relayStates = ns
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                    // LED: xanh=ON đặt, đỏ=OFF đặt, xám=chưa đặt
                                    Rectangle {
                                        width: 12; height: 12; radius: 6
                                        color: root.relayStates[modelData] === true  ? "#69f0ae"
                                             : root.relayStates[modelData] === false ? "#ff5252"
                                             : "#334466"
                                        border.color: root.relayStates[modelData] === true  ? "#00c853"
                                                   : root.relayStates[modelData] === false ? "#c62828"
                                                   : "#445577"
                                    }
                                }
                            }
                        }

                        CBtn { lbl: "Restart trạng thái"; bc: "#37474f"; Layout.fillWidth: true; height: 28; fs: 10
                            onTapped: {
                                controllerBox.requestStatus()
                                appController.addLog("[BOX] >> REQUEST STATUS")
                            } }

                        // ── SET RELAY — gửi toàn bộ trạng thái đã chọn xuống MCU ──
                        CBtn {
                            lbl: root._sendingRelays ? "⏳  ĐANG GỬI..." : "▼  SET RELAY"
                            bc: "#1565c0"; Layout.fillWidth: true; height: 34; fs: 12
                            ena: !root._sendingRelays && mcuSender.isOpen
                                 && Object.keys(root.relayStates).length > 0
                            onTapped: root._sendAllRelays()
                        }
                    }
                }
            }

            // ════════════════════════════════════════════
            // COL 3 — Load + Signal  (fill)
            // ════════════════════════════════════════════
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8

                // ── Kết nối nguồn đầu ra ─────────────────
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 302
                    color: cPanel; border.color: cBorder; radius: 8

                    ColumnLayout {
                        anchors.fill: parent; spacing: 0

                        Rectangle {
                            Layout.fillWidth: true; height: 30; color: cHdr; radius: 8
                            Rectangle { width: parent.width; height: 8; anchors.bottom: parent.bottom; color: cHdr }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10
                                Text { text: "Kết nối nguồn đầu ra"; color: cCyan
                                       font.pixelSize: 12; font.bold: true; Layout.fillWidth: true }
                                CBtn { lbl: "Set"; bc: cAccent; width: 60; height: 22; fs: 11
                                    onTapped: {
                                        mdlController.applyAll()
                                        appController.addLog("[MDL] >> APPLY ALL CHANNELS")
                                    } }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            Layout.leftMargin: 10; Layout.rightMargin: 10
                            Layout.topMargin: 8; Layout.bottomMargin: 8; spacing: 6

                            // connect row
                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                Text { text: "MDL400"; color: cDim; font.pixelSize: 11 }
                                Rectangle {
                                    Layout.preferredWidth: 140; height: 26; radius: 4
                                    color: cInput; border.color: cBorder
                                    TextInput { id: mdlIp; anchors.fill: parent; anchors.margins: 5
                                        text: "192.168.1.101"; color: cText; font.pixelSize: 11; font.family: "Consolas" }
                                }
                                CBtn { lbl: mdlController.connected ? "Ngắt" : "Kết nối"
                                    bc: mdlController.connected ? "#546e7a" : cAccent
                                    Layout.preferredWidth: 82; height: 26; fs: 11
                                    onTapped: {
                                        if (mdlController.connected) {
                                            mdlController.disconnectDevice()
                                            appController.addLog("[MDL] Ngắt kết nối")
                                        } else {
                                            mdlController.connectDevice(mdlIp.text, 5025)
                                            appController.addLog("[MDL ] Kết nối tới " + mdlIp.text + ":5025...")
                                        }
                                    } }
                                Item { Layout.fillWidth: true }
                            }

                            // Table header
                            Rectangle {
                                Layout.fillWidth: true; height: 26; color: cHdr; radius: 3
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 8; spacing: 0
                                    Repeater {
                                        model: [{t:"Tải điện tử",w:88},{t:"Nguồn",w:72},
                                                {t:"Dòng đặt (A)",w:100},{t:"Dòng điện (A)",w:-1},
                                                {t:"Điện áp (V)",w:96},{t:"ENABLE",w:90}]
                                        delegate: Text {
                                            text: modelData.t
                                            Layout.preferredWidth: modelData.w > 0 ? modelData.w : undefined
                                            Layout.fillWidth: modelData.w < 0
                                            height: 26; verticalAlignment: Text.AlignVCenter
                                            color: cCyan; font.pixelSize: 11; font.bold: true
                                        }
                                    }
                                }
                            }

                            // 6 channel rows
                            Repeater {
                                model: mdlController.channelData
                                delegate: Rectangle {
                                    Layout.fillWidth: true; height: 28
                                    color: index % 2 === 0 ? cRow0 : cRow1; radius: 3
                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 6; spacing: 0
                                        Text { text: modelData.name; Layout.preferredWidth: 88
                                               color: cText; font.pixelSize: 12; font.family: "Consolas"; font.bold: true }
                                        Rectangle { Layout.preferredWidth: 66; height: 20; radius: 2; color:"#081208"; border.color: cBorder
                                            Text { anchors.centerIn: parent; text: modelData.source
                                                   color: cGreen; font.pixelSize: 11; font.bold: true; font.family: "Consolas" } }
                                        Item { Layout.preferredWidth: 6 }
                                        Rectangle { Layout.preferredWidth: 88; height: 22; radius: 3; color: cInput; border.color: cBorder
                                            TextInput {
                                                anchors.fill: parent; anchors.margins: 5
                                                text: modelData.setCurrentA.toFixed(3)
                                                color: cYellow; font.pixelSize: 13; font.family: "Consolas"; font.bold: true
                                                horizontalAlignment: TextInput.AlignRight
                                                onEditingFinished: mdlController.setChannelCurrent(modelData.channel, parseFloat(text)||0)
                                            }
                                        }
                                        Text { text: modelData.measCurrentA.toFixed(3); Layout.fillWidth: true
                                               color: cPurple; font.pixelSize: 13; font.bold: true; font.family: "Consolas"
                                               horizontalAlignment: Text.AlignHCenter }
                                        Text { text: modelData.measVoltageV.toFixed(3); Layout.preferredWidth: 96
                                               color: "#64b5f6"; font.pixelSize: 13; font.bold: true; font.family: "Consolas"
                                               horizontalAlignment: Text.AlignHCenter }
                                        RowLayout {
                                            Layout.preferredWidth: 84; spacing: 4
                                            CBtn { lbl:"ON";  bc:cGreen; width:30; height:20; fs:9
                                                onTapped: {
                                                    mdlController.setChannelEnabled(modelData.channel, true)
                                                    appController.addLog("[MDL] >> CH" + modelData.channel + " " + modelData.name + " ENABLE")
                                                } }
                                            CBtn { lbl:"OFF"; bc:cRed;   width:30; height:20; fs:9
                                                onTapped: {
                                                    mdlController.setChannelEnabled(modelData.channel, false)
                                                    appController.addLog("[MDL] >> CH" + modelData.channel + " " + modelData.name + " DISABLE")
                                                } }
                                            Rectangle { width:10; height:10; radius:5
                                                        color: modelData.enabled ? "#69f0ae" : "#334466" }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Đo kiểm tín hiệu ─────────────────────
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: cPanel; border.color: cBorder; radius: 8

                    ColumnLayout {
                        anchors.fill: parent; spacing: 0

                        Rectangle {
                            Layout.fillWidth: true; height: 30; color: cHdr; radius: 8
                            Rectangle { width: parent.width; height: 8; anchors.bottom: parent.bottom; color: cHdr }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10
                                Text { text: "Đo kiểm tín hiệu"; color: cCyan
                                       font.pixelSize: 12; font.bold: true; Layout.fillWidth: true }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            Layout.margins: 10; spacing: 8

                            // Controls
                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                ComboBox {
                                    id: sigPort; model: availablePorts
                                    Layout.preferredWidth: 100; height: 28; font.pixelSize: 11
                                    background: Rectangle { color: cInput; border.color: cBorder; radius: 3 }
                                    contentItem: Text { text: sigPort.displayText; color: cText
                                                        font.pixelSize: 11; leftPadding: 6
                                                        verticalAlignment: Text.AlignVCenter }
                                }
                                CBtn { lbl: sigMeasure.connected ? "Ngắt" : "Kết nối"
                                    bc: sigMeasure.connected ? "#546e7a" : cAccent
                                    Layout.preferredWidth: 82; height: 28; fs: 11
                                    onTapped: {
                                        if (sigMeasure.connected) {
                                            sigMeasure.disconnectPort()
                                            appController.addLog("[SIG] Ngắt cổng " + sigPort.currentText)
                                        } else {
                                            sigMeasure.connectPort(sigPort.currentText, 115200)
                                            appController.addLog("[SIG] Kết nối cổng " + sigPort.currentText + " @115200...")
                                        }
                                    } }
                                Item { Layout.fillWidth: true }
                                CBtn {
                                    lbl: sigMeasure.measuring ? "■  Stop Measure" : "▶  Start Measure"
                                    bc:  sigMeasure.measuring ? cRed : cGreen
                                    Layout.preferredWidth: 148; height: 28; fs: 11
                                    onTapped: {
                                        if (sigMeasure.measuring) {
                                            sigMeasure.stopMeasure()
                                            appController.addLog("[SIG] >> STOP MEASURE")
                                        } else {
                                            sigMeasure.startMeasure()
                                            appController.addLog("[SIG] >> START MEASURE")
                                        }
                                    }
                                }
                                Rectangle {
                                    width: 10; height: 10; radius: 5; visible: sigMeasure.measuring; color: cGreen
                                    SequentialAnimation on opacity {
                                        running: sigMeasure.measuring; loops: Animation.Infinite
                                        NumberAnimation { to: 0.1; duration: 350 }
                                        NumberAnimation { to: 1.0; duration: 350 }
                                    }
                                }
                            }

                            // 2-column signal table
                            RowLayout {
                                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8

                                Repeater {
                                    model: [
                                        ["BOOST","FUZE_EN","FIRE","SIGNAL_GND","MLD","TELE","ERM","PM77"],
                                        ["GEN1_1","SS1","PPA","PYRO","27V_COMMAND","PYROFLARE_GND","VALVE_GND","RESERVE"]
                                    ]
                                    delegate: ColumnLayout {
                                        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 2

                                        Rectangle {
                                            Layout.fillWidth: true; height: 24; color: cHdr; radius: 3
                                            RowLayout {
                                                anchors.fill: parent; anchors.leftMargin: 10; spacing: 0
                                                Text { text: "Tên tín hiệu"; Layout.fillWidth: true; height: 24
                                                       verticalAlignment: Text.AlignVCenter
                                                       color: cCyan; font.pixelSize: 11; font.bold: true }
                                                Text { text: "Giá trị (V)"; Layout.preferredWidth: 90; height: 24
                                                       verticalAlignment: Text.AlignVCenter
                                                       horizontalAlignment: Text.AlignRight
                                                       color: cCyan; font.pixelSize: 11; font.bold: true }
                                            }
                                        }

                                        Repeater {
                                            model: modelData
                                            delegate: Rectangle {
                                                Layout.fillWidth: true; Layout.fillHeight: true
                                                color: index % 2 === 0 ? cRow0 : cRow1; radius: 3
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 10; anchors.rightMargin: 10
                                                    Text { text: modelData; Layout.fillWidth: true
                                                           color: cText; font.pixelSize: 12; font.family: "Consolas" }
                                                    Text {
                                                        text: (sigMeasure.signalVoltages[modelData] || 0).toFixed(3) + " V"
                                                        color: {
                                                            const v = sigMeasure.signalVoltages[modelData] || 0
                                                            return v >= 22 ? "#69f0ae" : v >= 2 ? cYellow : cDim
                                                        }
                                                        font.pixelSize: 14; font.bold: true; font.family: "Consolas"
                                                        Layout.preferredWidth: 90
                                                        horizontalAlignment: Text.AlignRight
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
        }

        // ── CONSOLE LOG ───────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 125; color: "#0e1828"; border.color: cBorder

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 6; spacing: 4
                RowLayout {
                    Text { text: "// CONSOLE LOG"; color: cGreen; font.pixelSize: 10; font.bold: true
                           font.letterSpacing: 2; font.family: "Consolas" }
                    Item { Layout.fillWidth: true }
                    CBtn { lbl: "CLEAR"; bc: "#37474f"; width: 54; height: 20; fs: 9
                        onTapped: appController.clearLog() }
                }
                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    model: appController.logMessages
                    delegate: Text {
                        width: parent ? parent.width : 0; text: modelData
                        color: modelData.indexOf("ERROR")  >= 0 ? cRed
                             : modelData.indexOf("TIMEOUT")>= 0 ? cRed
                             : modelData.indexOf("<<")     >= 0 ? cGreen
                             : modelData.indexOf(">>")     >= 0 ? cCyan
                             : modelData.indexOf("[SIG]")  >= 0 ? "#80ff80"
                             : modelData.indexOf("[MDL]")  >= 0 ? cCyan
                             : modelData.indexOf("[MR3K]") >= 0 ? cYellow
                             : cDim
                        font.pixelSize: 10; font.family: "Consolas"
                    }
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOn }
                }
            }
        }
    }

    // ── Relay ACK/NAK handler (manual SET RELAY) ─────────────────────
    Connections {
        target: mcuSender
        function onMcuRelayAck() {
            if (!root._sendingRelays) return
            relayAckTimer.stop()
            root._relayQueueIdx++
            root._sendNextRelayItem()
        }
        function onMcuRelayNak(errCode) {
            if (!root._sendingRelays) return
            relayAckTimer.stop()
            var r = root._relayQueue[root._relayQueueIdx]
            appController.addLog("[MCU] NAK " + (r ? r.name : "?")
                + " err=0x" + errCode.toString(16).toUpperCase())
            root._relayQueueIdx++
            root._sendNextRelayItem()
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // LOGIN OVERLAY
    // ══════════════════════════════════════════════════════════════════
    Rectangle {
        id: loginOverlay
        anchors.fill: parent
        z: 100
        opacity: 1
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.InQuad } }
        onOpacityChanged: if (opacity === 0) root.loggedIn = true

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#1a2a3a" }
                GradientStop { position: 1.0; color: "#0e1820" }
            }
        }

        Repeater {
            model: Math.ceil(loginOverlay.width / 44)
            delegate: Rectangle {
                x: index * 44; y: 0; width: 1; height: loginOverlay.height
                color: "#ffffff"; opacity: 0.04
            }
        }
        Repeater {
            model: Math.ceil(loginOverlay.height / 44)
            delegate: Rectangle {
                x: 0; y: index * 44; width: loginOverlay.width; height: 1
                color: "#ffffff"; opacity: 0.04
            }
        }

        Text {
            anchors.centerIn: parent; anchors.verticalCenterOffset: -10
            text: "CMN"; color: "#ffffff"; opacity: 0.03
            font.pixelSize: 320; font.bold: true; font.family: "Consolas"
        }

        // ── Login card ───────────────────────────────────────────────
        Rectangle {
            anchors.centerIn: parent
            width: 400; height: loginCol.implicitHeight + 80
            color: "#1c2e3e"
            border.color: "#3a6080"; border.width: 1
            radius: 10

            Rectangle {
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                height: 3; radius: 10
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#266080" }
                    GradientStop { position: 0.5; color: "#40a8c0" }
                    GradientStop { position: 1.0; color: "#266080" }
                }
            }

            ColumnLayout {
                id: loginCol
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                anchors.margins: 40; anchors.topMargin: 44
                spacing: 0

                Text {
                    text: "CMN TESTING"
                    color: "#60c8e0"; font.pixelSize: 26; font.bold: true
                    font.letterSpacing: 4; font.family: "Consolas"
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: "HỆ THỐNG KIỂM TRA THIẾT BỊ CHUYỂN MẠCH NGUỒN"
                    color: "#5a8090"; font.pixelSize: 9; font.letterSpacing: 2
                    font.family: "Consolas"; Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 28
                }

                Rectangle {
                    id: errBox
                    Layout.fillWidth: true; height: 32; radius: 4
                    color: "#2a1010"; border.color: "#c03838"
                    visible: false; Layout.bottomMargin: 12
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 8; spacing: 8
                        Text { text: "✕"; color: "#c03838"; font.pixelSize: 12; font.bold: true }
                        Text { text: "Sai tên đăng nhập hoặc mật khẩu"
                               color: "#e05050"; font.pixelSize: 11; font.family: "Consolas" }
                    }
                }

                Rectangle {
                    id: okBox
                    Layout.fillWidth: true; height: 32; radius: 4
                    color: "#102a18"; border.color: "#2e8050"
                    visible: false; Layout.bottomMargin: 12
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 8; spacing: 8
                        Text { text: "✓"; color: "#2eb870"; font.pixelSize: 12; font.bold: true }
                        Text { text: "Đăng nhập thành công — đang vào hệ thống..."
                               color: "#60d090"; font.pixelSize: 11; font.family: "Consolas" }
                    }
                }

                Text { text: "TÊN ĐĂNG NHẬP"; color: "#5a8090"; font.pixelSize: 10
                       font.letterSpacing: 1; font.family: "Consolas"; Layout.bottomMargin: 6 }
                Rectangle {
                    Layout.fillWidth: true; height: 44; radius: 5; Layout.bottomMargin: 14
                    color: "#101e28"
                    border.color: userF.activeFocus ? "#40a8c0" : "#2a4858"; border.width: userF.activeFocus ? 2 : 1
                    TextInput {
                        id: userF
                        anchors.fill: parent; anchors.margins: 12
                        color: "#c8dce8"; font.pixelSize: 15; font.family: "Consolas"
                        Keys.onReturnPressed: passF.forceActiveFocus()
                        onTextChanged: errBox.visible = false
                    }
                }

                Text { text: "MẬT KHẨU"; color: "#5a8090"; font.pixelSize: 10
                       font.letterSpacing: 1; font.family: "Consolas"; Layout.bottomMargin: 6 }
                Rectangle {
                    Layout.fillWidth: true; height: 44; radius: 5; Layout.bottomMargin: 28
                    color: "#101e28"
                    border.color: passF.activeFocus ? "#40a8c0" : "#2a4858"; border.width: passF.activeFocus ? 2 : 1
                    TextInput {
                        id: passF
                        anchors.fill: parent; anchors.margins: 12
                        echoMode: TextInput.Password
                        color: "#c8dce8"; font.pixelSize: 15; font.family: "Consolas"
                        onTextChanged: errBox.visible = false
                        Keys.onReturnPressed: {
                            if (userF.text === "admin" && passF.text === "1234") {
                                errBox.visible = false
                                okBox.visible  = true
                                appController.addLog("✓ Đăng nhập: " + userF.text)
                                loginTimer.start()
                            } else {
                                errBox.visible = true
                                passF.text = ""
                                passF.forceActiveFocus()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; height: 46; radius: 6
                    color: btnMa.pressed ? "#1a5060"
                         : btnMa.containsMouse ? "#2a7090" : "#226080"
                    border.color: "#40a8c0"
                    Text { anchors.centerIn: parent; text: "ĐĂNG NHẬP"
                           color: "white"; font.pixelSize: 14; font.bold: true
                           font.letterSpacing: 3; font.family: "Consolas" }
                    MouseArea {
                        id: btnMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            if (userF.text === "" && passF.text === "") {
                                errBox.visible = false
                                okBox.visible  = true
                                appController.addLog("✓ Đăng nhập: " + userF.text)
                                loginTimer.start()
                            } else {
                                errBox.visible = true
                                passF.text = ""
                                passF.forceActiveFocus()
                            }
                        }
                    }
                }

                Item { height: 20 }

                Text {
                    text: "© CMN TESTING SYSTEM  v1.0"
                    color: "#2a4858"; font.pixelSize: 9; font.family: "Consolas"
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        Timer {
            id: loginTimer; interval: 600; repeat: false
            onTriggered: loginOverlay.opacity = 0
        }

        Component.onCompleted: userF.forceActiveFocus()
    }
}




