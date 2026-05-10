import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    color: "transparent"

    readonly property var powerRelayNames: ["VLS_ON", "Bat1_ON", "Bat2_ON", "Gen_ON"]
    readonly property var cmdRelayNames:   ["VLS_BatON", "VLS_BatOFF", "MPSS_TBKT",
                                            "CMD_ERM",   "CMD_PUMP",   "CCBH_in",
                                            "CMD_PPA",   "CMD_Pyro1",  "CMD_Pyro2",
                                            "CMD_TJE",   "CMD_FUZE"]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10

        // --- Power relays header ---
        Text {
            text: "RELAY CẤP NGUỒN"
            color: "#7ec8e3"
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1
        }

        // Table header
        Row {
            spacing: 0
            Text { text: "Tên";       width: 90;  color: "#8b949e"; font.pixelSize: 10 }
            Text { text: "Kích hoạt"; width: 80;  color: "#8b949e"; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter }
            Text { text: "Trạng thái";width: 70;  color: "#8b949e"; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter }
        }

        Repeater {
            model: powerRelayNames
            delegate: Rectangle {
                width:  parent.width
                height: 28
                color:  index % 2 === 0 ? "#161b22" : "#1c2128"
                radius: 3

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    spacing: 0

                    Text {
                        text: modelData; width: 90
                        color: "#e6edf3"; font.pixelSize: 11; font.family: "Consolas"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Switch {
                        id: sw
                        width: 80
                        checked: controllerBox.relayStates[modelData] === true
                        enabled: controllerBox.connected
                        anchors.verticalCenter: parent.verticalCenter
                        onToggled: controllerBox.setRelay(modelData, checked)
                    }

                    Rectangle {
                        width: 14; height: 14; radius: 7
                        anchors.verticalCenter: parent.verticalCenter
                        color: controllerBox.relayStates[modelData] === true ? "#3fb950" : "#484f58"
                        border.color: color === "#3fb950" ? "#2ea043" : "#30363d"
                    }
                }
            }
        }

        // Divider
        Rectangle { Layout.fillWidth: true; height: 1; color: "#2e3a5a" }

        // --- Command relays header ---
        Text {
            text: "RELAY LỆNH ĐẾN DUT"
            color: "#7ec8e3"
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1
        }

        Row {
            spacing: 0
            Text { text: "Tên";      width: 100; color: "#8b949e"; font.pixelSize: 10 }
            Text { text: "Gửi";      width: 60;  color: "#8b949e"; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter }
            Text { text: "Đáp ứng";  width: 70;  color: "#8b949e"; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter }
        }

        Repeater {
            model: cmdRelayNames
            delegate: Rectangle {
                width:  parent.width
                height: 28
                color:  index % 2 === 0 ? "#161b22" : "#1c2128"
                radius: 3

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    spacing: 0

                    Text {
                        text: modelData; width: 100
                        color: "#e6edf3"; font.pixelSize: 11; font.family: "Consolas"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Momentary button
                    Rectangle {
                        width: 54; height: 22; radius: 3
                        color: btnArea.pressed ? "#1f6feb" : (btnArea.containsMouse ? "#162d57" : "#21262d")
                        border.color: "#444c56"
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: controllerBox.connected

                        Text { anchors.centerIn: parent; text: "SEND"; color: "#79c0ff"; font.pixelSize: 10; font.bold: true }

                        MouseArea {
                            id: btnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: controllerBox.setRelay(modelData, true)
                        }
                    }

                    Item { width: 6 }

                    // Response LED
                    Rectangle {
                        width: 14; height: 14; radius: 7
                        anchors.verticalCenter: parent.verticalCenter
                        color: controllerBox.relayResponses[modelData] === true ? "#3fb950" : "#484f58"
                        border.color: color === "#3fb950" ? "#2ea043" : "#30363d"
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
