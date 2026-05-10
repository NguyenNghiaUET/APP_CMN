import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    color: "transparent"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        // Table header
        Rectangle {
            Layout.fillWidth: true
            height: 24
            color: "#252d48"
            radius: 3

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 6
                spacing: 0

                Text { text: "Kênh";       width: 80;  color: "#7ec8e3"; font.pixelSize: 10; font.bold: true }
                Text { text: "Đặt (A)";    width: 90;  color: "#7ec8e3"; font.pixelSize: 10; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                Text { text: "Thực (A)";   width: 80;  color: "#7ec8e3"; font.pixelSize: 10; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                Text { text: "V thực (V)"; width: 80;  color: "#7ec8e3"; font.pixelSize: 10; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                Text { text: "Enable";     width: 60;  color: "#7ec8e3"; font.pixelSize: 10; font.bold: true; horizontalAlignment: Text.AlignHCenter }
            }
        }

        // Channel rows
        Repeater {
            model: mdlController.channelData

            delegate: Rectangle {
                Layout.fillWidth: true
                height: 34
                color: index % 2 === 0 ? "#161b22" : "#1c2128"
                radius: 3

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    spacing: 0

                    // Channel name
                    Text {
                        text: modelData.name
                        width: 80
                        color: "#e6edf3"
                        font.pixelSize: 11
                        font.family: "Consolas"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Set current input
                    TextField {
                        id: setField
                        width: 80
                        height: 24
                        text: modelData.setCurrentA.toFixed(3)
                        font.pixelSize: 11
                        font.family: "Consolas"
                        color: "#e6edf3"
                        horizontalAlignment: Text.AlignRight
                        rightPadding: 4
                        background: Rectangle { color: "#2d333b"; border.color: "#444c56"; radius: 3 }
                        anchors.verticalCenter: parent.verticalCenter
                        onEditingFinished: mdlController.setChannelCurrent(modelData.channel, parseFloat(text) || 0)
                    }
                    Item { width: 10 }

                    // Actual current
                    Text {
                        text: modelData.measCurrentA.toFixed(3)
                        width: 80
                        color: "#d2a8ff"
                        font.pixelSize: 12
                        font.family: "Consolas"
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Actual voltage
                    Text {
                        text: modelData.measVoltageV.toFixed(3)
                        width: 80
                        color: "#79c0ff"
                        font.pixelSize: 12
                        font.family: "Consolas"
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Enable toggle
                    Switch {
                        checked: modelData.enabled
                        enabled: mdlController.connected
                        anchors.verticalCenter: parent.verticalCenter
                        onToggled: mdlController.setChannelEnabled(modelData.channel, checked)
                    }
                }
            }
        }

        // Apply all button
        Button {
            Layout.fillWidth: true
            text: "ÁP DỤNG TẤT CẢ"
            font.pixelSize: 11
            font.bold: true
            enabled: mdlController.connected
            background: Rectangle {
                color: parent.enabled ? (parent.hovered ? "#1f6feb" : "#0d419d") : "#21262d"
                radius: 3
                border.color: parent.enabled ? "#388bfd" : "#30363d"
            }
            contentItem: Text { text: parent.text; color: parent.enabled ? "#79c0ff" : "#484f58"; font: parent.font; horizontalAlignment: Text.AlignHCenter }
            onClicked: mdlController.applyAll()
        }

        Item { Layout.fillHeight: true }
    }
}
