import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: deviceConfigDialog
    title: qsTr("Cấu hình thiết bị")
    modal: true
    standardButtons: Dialog.NoButton
    width: 750
    height: 500

    property bool isConnected: false
    property string connectedPort: ""

    // Lưu riêng COM port index cho mỗi thiết bị
    property int switchPortIndex: 4    // COM5 mặc định cho MCU
    property int rm3544PortIndex: 5    // COM6 mặc định cho Keithley 2110

    // Lưu riêng Baudrate index cho mỗi thiết bị
    property int switchBaudIndex: 4    // 115200 mặc định cho MCU
    property int rm3544BaudIndex: 4    // 115200 mặc định cho Keithley 2110

    background: Rectangle {
        color: "#f5f5f5"
        radius: 12
        border.color: "#e0e0e0"
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 20

            // Danh sách thiết bị bên trái
            Rectangle {
                Layout.preferredWidth: 220
                Layout.fillHeight: true
                color: "#ffffff"
                radius: 10
                border.color: "#e0e0e0"
                border.width: 1

                ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        text: qsTr("Danh sách thiết bị")
                        font.pixelSize: 14
                        font.bold: true
                        color: "#333333"
                        verticalAlignment: Text.AlignVCenter
                        padding: 8

                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: "#e0e0e0"
                    }

        ListView {
            id: deviceList
                        Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
                        spacing: 2

            model: ListModel {
                ListElement { name: "Bộ chuyển mạch"; type: "switch" }
                ListElement { name: "Thiết bị đo điện trở"; type: "rm3544" }
            }

            delegate: Rectangle {
                width: ListView.view.width
                            height: 45
                            color: ListView.isCurrentItem ? "#e3f2fd" : (mouseArea.containsMouse ? "#f5f5f5" : "#ffffff")
                            radius: 8
                            border.color: ListView.isCurrentItem ? "#2196F3" : "transparent"
                            border.width: ListView.isCurrentItem ? 2 : 0

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: name
                                font.pixelSize: 13
                                font.bold: ListView.isCurrentItem
                                color: ListView.isCurrentItem ? "#1976D2" : "#333333"
                }

                MouseArea {
                                id: mouseArea
                    anchors.fill: parent
                                hoverEnabled: true
                    onClicked: {
                        deviceList.currentIndex = index
                        _updateConnectionStatus()
                        _loadPortForDevice()
                    }
                }
            }
        }
                }
            }

        // Bảng cài đặt thiết bị (bên phải)
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#ffffff"
                radius: 10
                border.color: "#e0e0e0"
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Cài đặt thiết bị")
                        font.pixelSize: 16
                        font.bold: true
                        color: "#333333"
                    }

                GridLayout {
                    id: deviceGrid
                    columns: 2
                        Layout.fillWidth: true
                        columnSpacing: 16
                        rowSpacing: 16

                        Label {
                            text: qsTr("Baudrate")
                            font.pixelSize: 13
                            color: "#666666"
                        }
                        ComboBox {
                            id: baudField
                            model: ["9600", "19200", "38400", "57600", "115200", "230400", "460800", "921600"]
                            currentIndex: deviceConfigDialog.switchBaudIndex
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            font.pixelSize: 13
                            background: Rectangle {
                                color: "#fafafa"
                                border.color: baudField.activeFocus || baudField.popup.visible ? "#2196F3" : "#e0e0e0"
                                border.width: baudField.activeFocus || baudField.popup.visible ? 2 : 1
                                radius: 18
                            }
                            indicator: Text {
                                text: "▼"
                                font.pixelSize: 10
                                color: "#999999"
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Label {
                            text: qsTr("Cho phép sử dụng")
                            font.pixelSize: 13
                            color: "#666666"
                        }
                        Switch {
                            id: enableSwitch
                            checked: true
                            Layout.preferredHeight: 36

                            indicator: Rectangle {
                                x: enableSwitch.leftPadding
                                anchors.verticalCenter: parent.verticalCenter
                                width: 48
                                height: 26
                                radius: 13
                                color: enableSwitch.checked ? "#2196F3" : "#cccccc"
                                border.color: enableSwitch.checked ? "#1976D2" : "#bbbbbb"
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation { duration: 200 }
                                }

                                Rectangle {
                                    x: enableSwitch.checked ? parent.width - width - 3 : 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: "white"
                                    border.color: "#dddddd"
                                    border.width: 1

                                    Behavior on x {
                                        NumberAnimation { duration: 200 }
                                    }
                                }
                            }
                        }

                        Label {
                            text: qsTr("Cổng COM kết nối")
                            font.pixelSize: 13
                            color: "#666666"
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            ComboBox {
                                id: comPortSpin
                                model: deviceConfigDialog.cachedComPorts
                                currentIndex: deviceConfigDialog.switchPortIndex
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                font.pixelSize: 13
                                background: Rectangle {
                                    color: "#fafafa"
                                    border.color: comPortSpin.activeFocus || comPortSpin.popup.visible ? "#2196F3" : "#e0e0e0"
                                    border.width: comPortSpin.activeFocus || comPortSpin.popup.visible ? 2 : 1
                                    radius: 18
                                }
                                indicator: Text {
                                    text: "▼"
                                    font.pixelSize: 10
                                    color: "#999999"
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Button {
                                text: qsTr("⟳ Quét")
                                Layout.preferredWidth: 70
                                Layout.preferredHeight: 36

                                background: Rectangle {
                                    radius: 18
                                    color: parent.pressed ? "#1976D2" : (parent.hovered ? "#4CAF50" : "#2196F3")
                                    border.width: 0
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    font.pixelSize: 12
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: _refreshComPorts()
                            }
                        }

                        Label {
                            text: qsTr("Mô tả thiết bị")
                            font.pixelSize: 13
                            color: "#666666"
                        }
                        ComboBox {
                            id: deviceDescriptionField
                            model: deviceList.currentIndex === 0 ?
                                   ["Bộ chuyển mạch", "Bộ chuyển mạch V1", "Bộ chuyển mạch V2", "Bộ chuyển mạch V3"] :
                                   ["Thiết bị đo điện trở", "Keithley 2110", "Keithley 2110-220"]
                            currentIndex: 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            font.pixelSize: 13
                            background: Rectangle {
                                color: "#fafafa"
                                border.color: deviceDescriptionField.activeFocus || deviceDescriptionField.popup.visible ? "#2196F3" : "#e0e0e0"
                                border.width: deviceDescriptionField.activeFocus || deviceDescriptionField.popup.visible ? 2 : 1
                                radius: 18
                            }
                            indicator: Text {
                                text: "▼"
                                font.pixelSize: 10
                                color: "#999999"
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Label {
                            text: qsTr("Tên thiết bị")
                            font.pixelSize: 13
                            color: "#666666"
                        }
                        ComboBox {
                            id: deviceNameField
                            model: deviceList.currentIndex === 0 ?
                                   ["Bộ chuyển mạch V2", "Bộ chuyển mạch V1", "Bộ chuyển mạch V3", "Bộ chuyển mạch Pro"] :
                                   ["Keithley 2110", "Keithley 2110-220"]
                            currentIndex: 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            font.pixelSize: 13
                            background: Rectangle {
                                color: "#fafafa"
                                border.color: deviceNameField.activeFocus || deviceNameField.popup.visible ? "#2196F3" : "#e0e0e0"
                                border.width: deviceNameField.activeFocus || deviceNameField.popup.visible ? 2 : 1
                                radius: 18
                            }
                            indicator: Text {
                                text: "▼"
                                font.pixelSize: 10
                                color: "#999999"
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }

        // Nút Connect/Connected ở dưới cùng
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            Layout.alignment: Qt.AlignRight

            Item {
                Layout.fillWidth: true
            }

            Button {
                id: connectButton
                Layout.preferredWidth: 160
                Layout.preferredHeight: 42
                text: deviceConfigDialog.isConnected ? qsTr("✓ Connected — Ngắt") : qsTr("Connect")

                background: Rectangle {
                    color: connectButton.pressed ?
                           (deviceConfigDialog.isConnected ? "#c62828" : "#1976D2") :
                           (deviceConfigDialog.isConnected ? "#4CAF50" : "#2196F3")
                    radius: connectButton.height / 2
                    border.width: 0

                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }
                }

                contentItem: Text {
                    text: connectButton.text
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    var deviceType = deviceList.model.get(deviceList.currentIndex).type

                    // Nếu đã connected → Disconnect
                    if (deviceConfigDialog.isConnected) {
                        if (deviceType === "switch" && typeof mcuSender !== "undefined" && mcuSender && mcuSender.isOpen) {
                            mcuSender.closePort()
                            console.log(">>> MCU DISCONNECTED")
                            if (typeof window !== "undefined") window.addLog("Thiết bị", "Ngắt kết nối MCU")
                        } else if (deviceType === "rm3544" && typeof keithley2110 !== "undefined" && keithley2110 && keithley2110.isOpen) {
                            keithley2110.closePort()
                            console.log(">>> Keithley 2110 DISCONNECTED")
                            if (typeof window !== "undefined") window.addLog("Thiết bị", "Ngắt kết nối Keithley 2110")
                        }
                        deviceConfigDialog.isConnected = false
                        deviceConfigDialog.connectedPort = ""
                        return
                    }

                    // Connect mới
                    var newPortName = comPortSpin.currentText
                    var baud = parseInt(baudField.currentText, 10) || 115200

                    // Lưu port index cho thiết bị hiện tại
                    _savePortForDevice()

                    console.log("Connect:", deviceType, "port:", newPortName, "baud:", baud)

                    // Tránh "Not Responding" UI, ta hiển thị trạng thái đang truy cập trước.
                    connectButton.text = qsTr("Đang kết nối...")
                    connectButton.enabled = false

                    connectActionTimer.targetDeviceType = deviceType
                    connectActionTimer.targetPortName = newPortName
                    connectActionTimer.targetBaud = baud
                    connectActionTimer.start()
                }
            }
        }
    }

    // Thuộc tính lưu mảng COM port
    property var cachedComPorts: []

    function _refreshComPorts() {
        if (typeof mcuSender !== "undefined" && mcuSender) {
            var ports = mcuSender.getAvailablePorts()
            if (ports.length === 0) {
                cachedComPorts = ["(Chưa tìm thấy cổng kết nối)"]
            } else {
                cachedComPorts = ports
            }
        } else {
            // Danh sách giả fallback
            var p = []
            for (var i = 1; i <= 32; i++) p.push("COM" + i)
            cachedComPorts = p
        }
    }

    // Timer thực thi quá trình kết nối mở COM (làm bất đồng bộ)
    Timer {
        id: connectActionTimer
        interval: 100
        repeat: false
        property string targetDeviceType: ""
        property string targetPortName: ""
        property int targetBaud: 115200

        onTriggered: {
            var deviceType = targetDeviceType
            var newPortName = targetPortName
            var baud = targetBaud

            if (deviceType === "switch") {
                if (typeof mcuSender !== "undefined" && mcuSender) {
                    if (mcuSender.isOpen && mcuSender.portName !== newPortName) {
                        mcuSender.closePort()
                    }
                    mcuSender.portName = newPortName
                    mcuSender.baudRate = baud
                    if (mcuSender.openPort()) {
                        console.log(">>> MCU CONNECTED:", newPortName)
                        deviceConfigDialog.isConnected = true
                        deviceConfigDialog.connectedPort = newPortName
                        if (typeof window !== "undefined") window.addLog("Thiết bị", "Kết nối MCU thành công: " + newPortName + " (Baudrate: " + baud + ")")
                    } else {
                        deviceConfigDialog.isConnected = false
                        connectFailPopup.failPort = newPortName
                        connectFailPopup.open()
                        if (typeof window !== "undefined") window.addLog("Thiết bị", "Kết nối MCU THẤT BẠI: " + newPortName)
                    }
                }
            } else if (deviceType === "rm3544") {
                if (typeof keithley2110 !== "undefined" && keithley2110) {
                    if (keithley2110.isOpen) {
                        keithley2110.closePort()
                    }
                    keithley2110.portName = newPortName
                    if (keithley2110.openPort()) {
                        console.log(">>> Keithley 2110 CONNECTED:", newPortName)
                        deviceConfigDialog.isConnected = true
                        deviceConfigDialog.connectedPort = newPortName
                        if (typeof window !== "undefined") window.addLog("Thiết bị", "Kết nối Keithley 2110 thành công: " + newPortName)
                    } else {
                        deviceConfigDialog.isConnected = false
                        connectFailPopup.failPort = newPortName + " (Keithley 2110)"
                        connectFailPopup.open()
                        if (typeof window !== "undefined") window.addLog("Thiết bị", "Kết nối Keithley 2110 THẤT BẠI: " + newPortName)
                    }
                }
            }

            // Re-enable button after connection attempt
            connectButton.enabled = true
            connectButton.text = deviceConfigDialog.isConnected ? qsTr("✓ Connected — Ngắt") : qsTr("Connect")
            _updateConnectionStatus()
        }
    }


    // Reset trạng thái khi dialog mở
    onVisibleChanged: {
        if (visible) {
            _refreshComPorts()
            _updateConnectionStatus()
            _loadPortForDevice()
        }
    }

    // Lưu COM port + baudrate index cho thiết bị đang chọn
    function _savePortForDevice() {
        var deviceType = deviceList.model.get(deviceList.currentIndex).type
        if (deviceType === "switch") {
            switchPortIndex = comPortSpin.currentIndex
            switchBaudIndex = baudField.currentIndex
        } else if (deviceType === "rm3544") {
            rm3544PortIndex = comPortSpin.currentIndex
            rm3544BaudIndex = baudField.currentIndex
        }
    }

    // Load COM port + baudrate index của thiết bị đang chọn vào ComboBox
    function _loadPortForDevice() {
        var deviceType = deviceList.model.get(deviceList.currentIndex).type
        if (deviceType === "switch") {
            comPortSpin.currentIndex = switchPortIndex
            baudField.currentIndex = switchBaudIndex
        } else if (deviceType === "rm3544") {
            comPortSpin.currentIndex = rm3544PortIndex
            baudField.currentIndex = rm3544BaudIndex
        }
    }

    // Cập nhật trạng thái kết nối theo thiết bị đang chọn
    function _updateConnectionStatus() {
        var deviceType = deviceList.model.get(deviceList.currentIndex).type
        isConnected = false
        connectedPort = ""

        if (deviceType === "switch") {
            if (typeof mcuSender !== "undefined" && mcuSender && mcuSender.isOpen) {
                isConnected = true
                connectedPort = mcuSender.portName
            }
        } else if (deviceType === "rm3544") {
            if (typeof keithley2110 !== "undefined" && keithley2110 && keithley2110.isOpen) {
                isConnected = true
                connectedPort = keithley2110.portName
            }
        }
    }

    // Popup thông báo connect fail
    Popup {
        id: connectFailPopup
        property string failPort: ""
        anchors.centerIn: parent
        width: 340
        height: 160
        modal: true
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

        background: Rectangle {
            color: "white"
            radius: 16
            border.color: "#e53935"
            border.width: 2
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            // Icon + Title
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                Text {
                    text: "✕"
                    font.pixelSize: 22
                    font.bold: true
                    color: "#e53935"
                }
                Text {
                    text: "Kết nối thất bại!"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#e53935"
                }
            }

            // Message
            Text {
                text: "Không thể kết nối " + connectFailPopup.failPort + ".\nVui lòng kiểm tra cổng COM và thử lại."
                font.pixelSize: 13
                color: "#555555"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            // OK button
            Button {
                text: "OK"
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 100
                Layout.preferredHeight: 36
                background: Rectangle {
                    color: parent.hovered ? "#c62828" : "#e53935"
                    radius: 18
                }
                contentItem: Text {
                    text: "OK"
                    color: "white"
                    font.pixelSize: 13
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: connectFailPopup.close()
            }
        }
    }
}
