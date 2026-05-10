import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: manualReadDialog
    title: qsTr("Đọc giá trị điện trở - Keithley 2110")
    modal: true
    standardButtons: Dialog.Close
    width: 480
    height: 460

    property real rmValue: 0
    property bool rmReading: false

    background: Rectangle { color: "#f0f0f0"; radius: 8 }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // ═══ Chọn chân ═══
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 72
            color: "#90CAF9"
            radius: 6

            GridLayout {
                anchors.fill: parent
                anchors.margins: 8
                columns: 2
                columnSpacing: 12
                rowSpacing: 6

                Label { text: qsTr("Chân cổng A"); font.pixelSize: 13; font.bold: true }
                ComboBox {
                    id: pinACombo
                    Layout.fillWidth: true
                    model: _buildPinList("A")
                    currentIndex: 0
                    font.pixelSize: 13
                }

                Label { text: qsTr("Chân cổng B"); font.pixelSize: 13; font.bold: true }
                ComboBox {
                    id: pinBCombo
                    Layout.fillWidth: true
                    model: _buildPinList("B")
                    currentIndex: 0
                    font.pixelSize: 13
                }
            }
        }

        // ═══ Panel Keithley 2110 ═══
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#ffffff"
            radius: 6
            border.color: "#e0e0e0"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Label {
                    text: qsTr("Đo điện trở (Keithley 2110)")
                    font.pixelSize: 16
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#e0e0e0" }

                Label { text: qsTr("Cài đặt Keithley 2110"); font.pixelSize: 12; font.bold: true; color: "#666" }

                GridLayout {
                    columns: 2
                    Layout.fillWidth: true
                    columnSpacing: 8
                    rowSpacing: 4

                    Label { text: qsTr("Dải đo"); font.pixelSize: 12 }
                    ComboBox {
                        id: rmRangeCombo
                        Layout.fillWidth: true
                        model: ["RANGE_100Ω", "RANGE_1KΩ", "RANGE_10KΩ", "RANGE_100KΩ", "RANGE_1MΩ", "RANGE_10MΩ"]
                        currentIndex: 1
                        font.pixelSize: 12
                    }

                    Label { text: qsTr("Tốc độ (NPLC)"); font.pixelSize: 12 }
                    ComboBox {
                        id: rmSpeedCombo
                        Layout.fillWidth: true
                        model: ["FAST", "MED", "SLOW", "SLOW2"]
                        currentIndex: 1
                        font.pixelSize: 12
                    }
                }

                Item { Layout.fillHeight: true }

                Button {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 160
                    Layout.preferredHeight: 50
                    text: rmReading ? qsTr("Đang đọc...") : qsTr("Đọc")
                    enabled: !rmReading && _isConnected()
                    font.pixelSize: 20
                    font.bold: true
                    background: Rectangle {
                        color: parent.enabled ? (parent.pressed ? "#1565C0" : "#ffffff") : "#e0e0e0"
                        border.color: "#999"
                        border.width: 1
                        radius: 6
                    }
                    onClicked: _readMeter()
                }
            }
        }

        // ═══ Kết quả ═══
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            Layout.maximumHeight: 44
            color: "#CDDC39"
            radius: 6

            Label {
                anchors.centerIn: parent
                text: rmReading ? "..." : rmValue.toFixed(6) + " Ω"
                font.pixelSize: 28
                font.bold: true
                color: "#000"
            }
        }
    }

    function _buildPinList(port) {
        var list = []
        for (var i = 1; i <= 128; i++) list.push(port + "_" + i)
        return list
    }

    function _isConnected() {
        return typeof keithley2110 !== "undefined" && keithley2110 && keithley2110.isOpen
    }

    function _switchPins() {
        if (typeof mcuSender === "undefined" || !mcuSender || !mcuSender.isOpen) return false
        var pinA = pinACombo.currentIndex + 1
        var pinB = pinBCombo.currentIndex + 1
        console.log("[ManualRead] Switch pins:", pinACombo.currentText, "→", pinBCombo.currentText)
        return mcuSender.sendPinPairs([{ pinA: pinA, pinB: pinB }])
    }

    function _readMeter() {
        if (!_isConnected()) return
        rmReading = true
        _switchPins()
        rmReadTimer.start()
    }

    Timer {
        id: rmReadTimer
        interval: 300
        onTriggered: {
            if (_isConnected()) {
                keithley2110.readResistance()
            } else {
                rmReading = false
            }
        }
    }

    Connections {
        target: typeof keithley2110 !== "undefined" ? keithley2110 : null
        function onResistanceRead(value) {
            if (manualReadDialog.visible) {
                manualReadDialog.rmValue = value
                manualReadDialog.rmReading = false
            }
        }
        function onErrorOccurred(error) {
            if (manualReadDialog.visible) {
                console.log("[ManualRead] Keithley error:", error)
                manualReadDialog.rmReading = false
            }
        }
    }

    onOpened: {
        rmValue = 0
        rmReading = false
    }
}
