import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    color: "transparent"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // --- Set parameters ---
        GridLayout {
            columns: 4
            columnSpacing: 8
            rowSpacing: 6
            Layout.fillWidth: true

            // Voltage
            Text { text: "Điện áp (V)"; color: "#8b949e"; font.pixelSize: 11 }
            TextField {
                id: voltField
                text: mrController.setVoltage.toFixed(2)
                Layout.fillWidth: true
                font.pixelSize: 12
                color: "#e6edf3"
                background: Rectangle { color: "#2d333b"; border.color: "#444c56"; radius: 3 }
                onEditingFinished: mrController.setVoltage = parseFloat(text) || 0
            }

            // Max current
            Text { text: "Dòng tối đa (A)"; color: "#8b949e"; font.pixelSize: 11 }
            TextField {
                id: currField
                text: mrController.setCurrent.toFixed(3)
                Layout.fillWidth: true
                font.pixelSize: 12
                color: "#e6edf3"
                background: Rectangle { color: "#2d333b"; border.color: "#444c56"; radius: 3 }
                onEditingFinished: mrController.setCurrent = parseFloat(text) || 0
            }

            // OCP
            Text { text: "Bảo vệ OCP (A)"; color: "#8b949e"; font.pixelSize: 11 }
            TextField {
                id: ocpField
                text: mrController.setOCP.toFixed(3)
                Layout.fillWidth: true
                font.pixelSize: 12
                color: "#e6edf3"
                background: Rectangle { color: "#2d333b"; border.color: "#444c56"; radius: 3 }
                onEditingFinished: mrController.setOCP = parseFloat(text) || 0
            }

            // Spacer + Set button
            Item {}
            Button {
                text: "SET"
                Layout.fillWidth: true
                font.pixelSize: 11
                font.bold: true
                enabled: mrController.connected
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? "#1f6feb" : "#0d419d") : "#21262d"
                    radius: 3
                    border.color: parent.enabled ? "#388bfd" : "#30363d"
                }
                contentItem: Text { text: parent.text; color: parent.enabled ? "#79c0ff" : "#484f58"; font: parent.font; horizontalAlignment: Text.AlignHCenter }
                onClicked: mrController.applySettings()
            }
        }

        // --- Output toggle ---
        Rectangle {
            Layout.fillWidth: true
            height: 36
            radius: 4
            color: mrController.outputEnabled ? "#1a3a1a" : "#2d1b1b"
            border.color: mrController.outputEnabled ? "#3fb950" : "#f85149"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8

                Text {
                    text: mrController.outputEnabled ? "OUTPUT  ON" : "OUTPUT  OFF"
                    color: mrController.outputEnabled ? "#3fb950" : "#f85149"
                    font.pixelSize: 13
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                Switch {
                    checked: mrController.outputEnabled
                    enabled: mrController.connected
                    onToggled: mrController.setOutput(checked)
                    // minimal indicator colors via contentItem overlay not needed — color from parent
                }
            }
        }

        // --- Actual measurements ---
        GridLayout {
            columns: 6
            Layout.fillWidth: true
            columnSpacing: 4
            rowSpacing: 4

            Repeater {
                model: [
                    { label: "V meas", value: mrController.measVoltage.toFixed(3) + " V", color: "#79c0ff" },
                    { label: "I meas", value: mrController.measCurrent.toFixed(4) + " A", color: "#d2a8ff" },
                    { label: "P meas", value: mrController.measPower.toFixed(3)   + " W", color: "#ffa657" }
                ]

                delegate: ColumnLayout {
                    spacing: 2
                    Text { text: modelData.label; color: "#8b949e"; font.pixelSize: 10 }
                    Text { text: modelData.value; color: modelData.color; font.pixelSize: 14; font.bold: true; font.family: "Consolas" }
                }
            }
        }
    }
}
