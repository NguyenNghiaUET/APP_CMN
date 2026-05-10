import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    color: "transparent"

    readonly property var signalNames: [
        "BOOST",        "FUZE_EN",
        "FIRE",         "SIGNAL_GND",
        "MLD",          "TELE",
        "ERM",          "PM77",
        "GEN1_1",       "SS1",
        "PPA",          "PYRO",
        "27V_COMMAND",  "PYROFLARE_GND",
        "VALVE_GND",    ""           // padding to make even columns
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // Start / Stop row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                text: "▶ BẮT ĐẦU ĐO"
                enabled: controllerBox.connected && !controllerBox.measuring
                font.pixelSize: 11; font.bold: true
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? "#1a7f37" : "#238636") : "#21262d"
                    radius: 3
                    border.color: parent.enabled ? "#3fb950" : "#30363d"
                }
                contentItem: Text { text: parent.text; color: parent.enabled ? "#3fb950" : "#484f58"; font: parent.font }
                onClicked: controllerBox.startMeasure()
            }
            Button {
                text: "■ DỪNG ĐO"
                enabled: controllerBox.connected && controllerBox.measuring
                font.pixelSize: 11; font.bold: true
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? "#b62324" : "#8b1a1a") : "#21262d"
                    radius: 3
                    border.color: parent.enabled ? "#f85149" : "#30363d"
                }
                contentItem: Text { text: parent.text; color: parent.enabled ? "#f85149" : "#484f58"; font: parent.font }
                onClicked: controllerBox.stopMeasure()
            }

            Rectangle {
                visible: controllerBox.measuring
                width: 10; height: 10; radius: 5; color: "#3fb950"
                SequentialAnimation on opacity {
                    running: controllerBox.measuring
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                }
            }

            Item { Layout.fillWidth: true }
        }

        // Signal grid (2 columns)
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 4

            Repeater {
                model: signalNames

                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 30
                    visible: modelData !== ""
                    color: index % 4 < 2 ? "#161b22" : "#1c2128"
                    radius: 3

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 4

                        Text {
                            text: modelData
                            Layout.fillWidth: true
                            color: "#c9d1d9"
                            font.pixelSize: 11
                            font.family: "Consolas"
                        }

                        Text {
                            text: {
                                const v = controllerBox.signalVoltages[modelData]
                                return (v !== undefined ? v : 0).toFixed(3) + " V"
                            }
                            color: {
                                const v = controllerBox.signalVoltages[modelData] || 0
                                if (v > 20) return "#3fb950"
                                if (v > 2)  return "#d29922"
                                return "#8b949e"
                            }
                            font.pixelSize: 13
                            font.bold: true
                            font.family: "Consolas"
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
