import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    property string label: "Device"
    property bool   online: false
    property string hostDefault: "192.168.1.1"
    property int    portDefault: 5025
    property bool   isSerial: false          // serial port vs TCP
    property var    availablePorts: []

    signal connectRequested(string host, int port)
    signal connectSerialRequested(string portName)
    signal disconnectRequested()

    spacing: 6

    // LED indicator
    Rectangle {
        width: 10; height: 10; radius: 5
        color: online ? "#3fb950" : "#f85149"
        border.color: online ? "#2ea043" : "#da3633"
        border.width: 1
    }

    Text {
        text: label
        color: "#c9d1d9"
        font.pixelSize: 11
        Layout.minimumWidth: 80
    }

    // Connect / Disconnect button
    Rectangle {
        width: 60; height: 20; radius: 3
        color: online ? "#2d333b" : "#0d419d"
        border.color: online ? "#444c56" : "#388bfd"
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: online ? "Ngắt" : "Kết nối"
            color: online ? "#8b949e" : "#79c0ff"
            font.pixelSize: 10
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (online) {
                    disconnectRequested()
                } else {
                    connectDialog.open()
                }
            }
        }
    }

    // --- Connection dialog ---
    Dialog {
        id: connectDialog
        title: "Kết nối " + label
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        width: 280

        background: Rectangle { color: "#1e2235"; border.color: "#2e3a5a"; radius: 6 }

        Column {
            spacing: 8
            width: parent.width

            // TCP fields
            Loader {
                active: !isSerial
                width: parent.width
                sourceComponent: Column {
                    spacing: 6
                    Row {
                        spacing: 6
                        Text { text: "IP:"; color: "#8b949e"; font.pixelSize: 11; width: 40; anchors.verticalCenter: parent.verticalCenter }
                        TextField {
                            id: hostField
                            text: hostDefault
                            width: 150
                            font.pixelSize: 11
                            background: Rectangle { color: "#2d333b"; border.color: "#444c56"; radius: 3 }
                            color: "#e6edf3"
                        }
                    }
                    Row {
                        spacing: 6
                        Text { text: "Port:"; color: "#8b949e"; font.pixelSize: 11; width: 40; anchors.verticalCenter: parent.verticalCenter }
                        TextField {
                            id: portField
                            text: portDefault.toString()
                            width: 80
                            font.pixelSize: 11
                            inputMethodHints: Qt.ImhDigitsOnly
                            background: Rectangle { color: "#2d333b"; border.color: "#444c56"; radius: 3 }
                            color: "#e6edf3"
                        }
                    }
                    Component.onCompleted: {
                        connectDialog.onAccepted.connect(function() {
                            connectRequested(hostField.text, parseInt(portField.text) || portDefault)
                        })
                    }
                }
            }

            // Serial fields
            Loader {
                active: isSerial
                width: parent.width
                sourceComponent: Column {
                    spacing: 6
                    Row {
                        spacing: 6
                        Text { text: "COM:"; color: "#8b949e"; font.pixelSize: 11; width: 40; anchors.verticalCenter: parent.verticalCenter }
                        ComboBox {
                            id: portCombo
                            model: availablePorts
                            width: 120
                            font.pixelSize: 11
                            background: Rectangle { color: "#2d333b"; border.color: "#444c56"; radius: 3 }
                            contentItem: Text { text: portCombo.displayText; color: "#e6edf3"; font.pixelSize: 11; leftPadding: 6; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                    Component.onCompleted: {
                        connectDialog.onAccepted.connect(function() {
                            connectSerialRequested(portCombo.currentText)
                        })
                    }
                }
            }
        }
    }
}
