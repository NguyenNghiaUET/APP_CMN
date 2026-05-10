import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ApplicationWindow {
    id: window
    width: 1280
    height: 720
    visible: false
    title: qsTr("CMN — Đo kiểm cáp điện")

    function openWindow() {
        show()
        raise()
        requestActivate()
    }

    property bool isLoggedIn: false

    // ═══ Hệ thống ghi log hoạt động người dùng ═══
    property var activityLog: [] // mảng chứa log hoạt động người dùng
    function addLog(category, action) {   // hàm thêm log vào mảng activity log
        var ts = new Date().toLocaleString("vi-VN")   // biến ts để lưu thời gian hiện tại
        activityLog.push({ "time " : ts , "category" : category , "action" : action })
        activityLogChanged()
        console.log("LOG",ts,"/",category,"/",action) // log ra console
        // ghi vao file log
        if(typeof fileHelper != undefined && fileHelper)
        {
            fileHelper.appendLogRealtime(category,action)
        }

    }

    // ── Dialog đăng nhập ──
    property bool _loginShowError: false

    Rectangle {
        id: loginBackdrop
        anchors.fill: parent
        z: 9998
        visible: loginDialog.visible
        color: "#60000000"
        MouseArea { anchors.fill: parent }
    }


    Dialog {
        id: loginDialog
        modal: false
        anchors.centerIn: parent
        width: 370
        height: 320
        padding: 0
        standardButtons: Dialog.NoButton
        z: 9999

        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Easing.InCubic } }

        background: Rectangle {
            radius: 14
            color: "#FAFBFC"
            border.color: "#D0D5DD"
            border.width: 1

            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                radius: 15
                color: "transparent"
                border.color: "#15000000"
                border.width: 2
                z: -1
            }
        }

        header: Rectangle {
            width: parent.width
            height: 75
            radius: 14
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#2E86AB" }
                GradientStop { position: 0.6; color: "#1B6B93" }
                GradientStop { position: 1.0; color: "#155A7C" }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 14
                color: "#155A7C"
            }
            Column {
                anchors.centerIn: parent
                spacing: 3
                Text {
                    text: "🔐"
                    font.pixelSize: 18
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: qsTr("Xác thực quản trị")
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: "#FFFFFF"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: qsTr("Nhập mật khẩu để mở khóa chức năng")
                    font.pixelSize: 10
                    color: "#B8DFF0"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        contentItem: Item {
            clip: true
            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                anchors.topMargin: 14
                anchors.bottomMargin: 14
                spacing: 10

                // Label
                Text {
                    text: qsTr("MẬT KHẨU")
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                    color: "#6B7280"
                }

                // Password field
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 8
                    color: dlgPasswordField.activeFocus ? "#FFFFFF" : "#F3F4F6"
                    border.color: _loginShowError ? "#EF4444" : dlgPasswordField.activeFocus ? "#2E86AB" : "#D1D5DB"
                    border.width: dlgPasswordField.activeFocus ? 2 : 1

                    Behavior on border.color { ColorAnimation { duration: 200 } }
                    Behavior on color { ColorAnimation { duration: 200 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 6
                        spacing: 4

                        TextField {
                            id: dlgPasswordField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            placeholderText: qsTr("Nhập mật khẩu...")
                            placeholderTextColor: "#9CA3AF"
                            echoMode: dlgShowPwBtn.checked ? TextInput.Normal : TextInput.Password
                            font.pixelSize: 13
                            color: "#1F2937"
                            background: Item {}

                            onAccepted: dlgLoginBtn.doLogin()
                            onTextChanged: _loginShowError = false
                        }

                        Rectangle {
                            width: 30; height: 30
                            radius: 6
                            color: dlgShowPwMa.containsMouse ? "#E5E7EB" : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: dlgShowPwBtn.checked ? "🙈" : "👀"
                                font.pixelSize: 12
                            }

                            property alias checked: dlgShowPwBtn.checked
                            CheckBox { id: dlgShowPwBtn; visible: false }
                            MouseArea {
                                id: dlgShowPwMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dlgShowPwBtn.checked = !dlgShowPwBtn.checked
                            }
                        }
                    }
                }

                // Error message — between password and login button
                Rectangle {
                    Layout.fillWidth: true
                    height: _loginShowError ? 28 : 0
                    radius: 6
                    color: "#FEF2F2"
                    border.color: "#FECACA"
                    border.width: 1
                    visible: _loginShowError
                    clip: true

                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "⚠"
                            font.pixelSize: 12
                            color: "#DC2626"
                        }
                        Text {
                            text: qsTr("Mật khẩu không đúng, vui lòng thử lại")
                            color: "#DC2626"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                    }
                }

                // Login button
                Rectangle {
                    id: dlgLoginBtn
                    Layout.fillWidth: true
                    height: 40
                    radius: 8

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: dlgLoginBtnMa.pressed ? "#155A7C" : dlgLoginBtnMa.containsMouse ? "#3494B9" : "#2E86AB" }
                        GradientStop { position: 1.0; color: dlgLoginBtnMa.pressed ? "#0E4A66" : dlgLoginBtnMa.containsMouse ? "#1B6B93" : "#155A7C" }
                    }

                    function doLogin() {
                        var currentYear = new Date().getFullYear()
                        var correctPw = "6"
                        if (dlgPasswordField.text === correctPw) {
                            isLoggedIn = true
                            _loginShowError = false
                            loginDialog.close()
                            addLog("Hệ thống", "Đăng nhập thành công")
                        } else {
                            _loginShowError = true
                            dlgPasswordField.selectAll()
                            dlgPasswordField.forceActiveFocus()
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "→"
                            color: "#FFFFFF"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                        }
                        Text {
                            text: qsTr("Xác nhận đăng nhập")
                            color: "#FFFFFF"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: dlgLoginBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dlgLoginBtn.doLogin()
                    }
                }
            }
        }

        onOpened: {
            dlgPasswordField.text = ""
            _loginShowError = false
            dlgPasswordField.forceActiveFocus()
        }
    }


    property string interfaceMode: "auto"
    property int activeTabIndex: 0

    menuBar: MenuBar {
        Menu {
            title: qsTr("Tùy chọn")
            MenuItem {
                text: qsTr("Ứng dụng")
                enabled: isLoggedIn
                onTriggered: appConfigDialog.open()

            }
            MenuItem {
                text: qsTr("Thiết bị")
                onTriggered: { addLog("Cấu hình", "Mở cài đặt thiết bị"); deviceConfigDialog.open() }
            }
        }
        Menu {
            title: qsTr("Bài đo")
            MenuItem {
                text: qsTr("Danh sách cáp kết nối")
                enabled: isLoggedIn
                onTriggered: { addLog("Bài đo", "Mở danh sách cáp kết nối"); cableListDialog.open() }
            }
            MenuItem {
                text: qsTr("Danh sách bài đo")
                onTriggered: {
                    if (!testPlanListDialogInstance) {
                        testPlanListDialogInstance = testPlanListDialogComponent.createObject(window)
                        if (testPlanListDialogInstance)
                            testPlanListDialogInstance.mainWindow = window
                    }
                    if (testPlanListDialogInstance)
                         testPlanListDialogInstance.open()
                    addLog("Bài đo", "Mở danh sách bài đo")
                }
            }
            MenuItem {
                text: qsTr("Chỉnh sửa bài đo")
                enabled: isLoggedIn
                onTriggered: { addLog("Bài đo", "Mở chỉnh sửa bài đo: " + selectedPlanName); autoTestPlanDialog.openEditTab(selectedPlanName) }
            }
            MenuItem { text: qsTr("Cấu hình thông số bài đo"); enabled: isLoggedIn }
        }
        Menu {
            title: qsTr("Công cụ")
            enabled: isLoggedIn
            MenuItem { text: qsTr("Hiệu chuẩn thiết bị tự động") }
            MenuItem {
                text: qsTr("Điều chỉnh tham số hiệu chuẩn")
                onTriggered: {
                    if (!calibrationDialogInstance) {
                        calibrationDialogInstance = calibrationDialogComponent.createObject(window)
                        if (calibrationDialogInstance) {
                            calibrationDialogInstance.mainWindow = window
                            calibrationDialogInstance.mainContent = mainContent
                        }
                    }
                    if (calibrationDialogInstance) {
                        var rows = []
                        for (var i = 0; i < cableListDialog.tableDataModel.count; i++) {
                            var r = cableListDialog.tableDataModel.get(i)
                            rows.push({
                                col0: r.col0 || "", col1: r.col1 || "", col2: r.col2 || "",
                                col3: r.col3 || "", col4: r.col4 || "", col5: r.col5 || "",
                                col6: r.col6 || "", col7: r.col7 || ""
                            })
                        }
                        calibrationDialogInstance.setCableData(rows)
                        calibrationDialogInstance.open()
                        addLog("Hiệu chuẩn", "Mở điều chỉnh tham số hiệu chuẩn")
                    }
                }
            }
            MenuItem {
                text: qsTr("Hiệu chuẩn theo cáp đo")
                onTriggered: {
                    if (!cableCalibrationDialogInstance) {
                        cableCalibrationDialogInstance = cableCalibrationDialogComponent.createObject(window)
                        if (cableCalibrationDialogInstance) {
                            cableCalibrationDialogInstance.mainWindow = window
                            cableCalibrationDialogInstance.mainContent = mainContent
                            mainContent.cableCalibrationDialog = cableCalibrationDialogInstance
                        }
                    }
                    if (cableCalibrationDialogInstance) {
                        var rows = []
                        for (var i = 0; i < cableListDialog.tableDataModel.count; i++) {
                            var r = cableListDialog.tableDataModel.get(i)
                            rows.push({
                                col0: r.col0 || "", col1: r.col1 || "", col2: r.col2 || "",
                                col3: r.col3 || "", col4: r.col4 || "", col5: r.col5 || "",
                                col6: r.col6 || "", col7: r.col7 || ""
                            })
                        }

                        if (typeof testPlanManager !== "undefined" && testPlanManager && selectedPlanName) {
                            var scripts = testPlanManager.loadScripts(selectedPlanName) || []
                            var existingKeys = {}
                            for (var e = 0; e < rows.length; e++) {
                                var ek = String(rows[e].col2 || "") + "_" + String(rows[e].col5 || "")
                                if (ek !== "_") existingKeys[ek] = true
                            }
                            for (var s = 0; s < scripts.length; s++) {
                                var sc = scripts[s]
                                if (String(sc.scriptType || "") !== "wire_resistance") continue
                                var ppA = sc.portPinA !== undefined ? String(sc.portPinA) : ""
                                var ppB = sc.portPinB !== undefined ? String(sc.portPinB) : ""
                                var key = ppA + "_" + ppB
                                if (key === "_" || existingKeys[key]) continue
                                existingKeys[key] = true
                                rows.push({
                                    col0: sc.labelA || "", col1: sc.pinA || "", col2: ppA,
                                    col3: sc.labelB || "", col4: sc.pinB || "", col5: ppB,
                                    col6: "", col7: ""
                                })
                            }
                        }

                        cableCalibrationDialogInstance.setCableData(rows)
                        cableCalibrationDialogInstance.open()
                        addLog("Hiệu chuẩn", "Mở hiệu chuẩn theo cáp đo")
                    }
                }
            }
            MenuItem {
                text: qsTr("Đọc giá trị điện trở từ máy đo")
                onTriggered: manualReadDialog.open()
            }
        }
        Menu {
            title: isLoggedIn ? qsTr("🔓 Đăng xuất") : qsTr("🔒 Đăng Nhập")
            MenuItem {
                text: isLoggedIn ? qsTr("Đăng xuất") : qsTr("Đăng nhập")
                onTriggered: {
                    if (isLoggedIn) {
                        isLoggedIn = false
                    } else {
                        loginDialog.open()
                    }
                }
            }
        }
        Menu {
            title: qsTr("Giao diện")
            MenuItem {
                text: qsTr("Đo tự động")
                checkable: true
                checked: activeTabIndex === 0
                onTriggered: { activeTabIndex = 0; interfaceMode = "auto" }
            }
            MenuItem {
                text: qsTr("Đo thủ công")
                enabled: isLoggedIn
                checkable: true
                checked: activeTabIndex === 1
                onTriggered: { activeTabIndex = 1; interfaceMode = "manual" }
            }
        }
        Menu {
            title: qsTr("Trợ giúp")
            MenuItem {
                text: qsTr("Giới thiệu về phần mềm")
                onTriggered: aboutDialog.open()
            }
            MenuItem {
                text: qsTr("Mở thư mục phiếu đo")
                onTriggered: resultsFolderDialog.open()
            }
            MenuItem {
                text: qsTr("Mở thư mục log")
                onTriggered: logFolderDialog.open()
            }
        }
    }
    // Status bar hiển thị trạng thái connected ở trên app
    Rectangle {
        id: statusBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 30
        color: "#FFFFFF"
        border.color: "#E2E8F0"
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 4
            anchors.leftMargin: 8
            spacing: 8

            Image {
                source: "qrc:/qt/qml/ProjectTestCap/logo.png"
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                fillMode: Image.PreserveAspectFit
                // Placeholder fallback if image is missing
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: "#999"
                    visible: parent.status === Image.Error || parent.status === Image.Null
                    Text { anchors.centerIn: parent; text: "🚀"; color: "white" }
                }
            }

            Label {
                id: connectionStatusLabel
                text: typeof mcuSender !== "undefined" && mcuSender && mcuSender.isOpen
                      ? "✓ CONNECTED: " + (mcuSender.portName || "COM")
                      : "Disconnected"
                color: typeof mcuSender !== "undefined" && mcuSender && mcuSender.isOpen ? "#00AA00" : "#808080"
                font.pixelSize: 12
                font.bold: typeof mcuSender !== "undefined" && mcuSender && mcuSender.isOpen
            }

            Item {
                Layout.fillWidth: true
            }
        }

        Connections {
            target: typeof mcuSender !== "undefined" ? mcuSender : null
            function onOpenChanged() {
                if (mcuSender && mcuSender.isOpen) {
                    connectionStatusLabel.text = "✓ CONNECTED: " + (mcuSender.portName || "COM")
                    connectionStatusLabel.color = "#00AA00"
                    connectionStatusLabel.font.bold = true
                } else {
                    connectionStatusLabel.text = "Disconnected"
                    connectionStatusLabel.color = "#808080"
                    connectionStatusLabel.font.bold = false
                }
            }
        }
    }

    Rectangle {
        id: tabBar
        anchors.top: statusBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 36
        color: "#F8FAFC"
        border.color: "#E2E8F0"

        RowLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 6

            Repeater {
                model: [qsTr("Đo tự động"), qsTr("Đo thủ công")]
                delegate: Rectangle {
                    Layout.preferredWidth: 120
                    Layout.fillHeight: true
                    radius: 8
                    color: index === window.activeTabIndex ? "#2563EB" : "transparent"
                    border.color: index === window.activeTabIndex ? "#1D4ED8" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: index === window.activeTabIndex ? "#FFFFFF" : "#475569"
                        font.bold: true
                        font.pixelSize: 12
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            window.activeTabIndex = index
                            window.interfaceMode = index === 0 ? "auto" : "manual"
                        }
                    }
                }
            }
            Item { Layout.fillWidth: true }
        }
    }

    MainContent {
        id: mainContent
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: window.activeTabIndex === 0
        currentPlanName: selectedPlanName
        notificationDialog: notificationDialog
        interfaceMode: window.interfaceMode
        editPlanDialog: autoTestPlanDialog
    }
    ManualTestView {
        id: manualTestView
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: window.activeTabIndex === 1
        currentPlanName: selectedPlanName
        calibrationMode: mainContent.calibrationMode
        mainContent: mainContent
    }
    AppConfigDialog {
        id:appConfigDialog
        parent:window.contentItem
    }
    DeviceConfigDialog {
        id: deviceConfigDialog
        parent: window.contentItem
    }
    ManualReadDialog {
        id: manualReadDialog
        parent: window.contentItem
    }
    CableListDialog {
        id: cableListDialog
        mainWindow: window
    }

    AutoTestPlanDialog {
        id: autoTestPlanDialog
        mainWindow: window
        onPlanSaved: function(planName) {
            // Khi lưu bài đo xong → reload MainContent nếu đang xem cùng bài đo
            addLog("Bài đo", "Đã lưu bài đo: " + planName)
            if (mainContent.currentPlanName === planName) {
                mainContent.loadPlanIntoMainList(planName)
            }
        }
    }

    property var calibrationDialogInstance: null
    Component {
        id: calibrationDialogComponent
        CalibrationDialog {
            mainWindow: window
            visible: false
        }
    }

    // Auto-init calibration dialog khi app khởi chạy
    Timer {
        interval: 500; running: true; repeat: false
        onTriggered: {
            if (!calibrationDialogInstance) {
                calibrationDialogInstance = calibrationDialogComponent.createObject(window)
                if (calibrationDialogInstance) {
                    calibrationDialogInstance.mainWindow = window
                    calibrationDialogInstance.mainContent = mainContent
                    calibrationDialogInstance.visible = false
                    mainContent.calibrationDialog = calibrationDialogInstance
                    // Load cable data nếu có
                    var rows = []
                    for (var i = 0; i < cableListDialog.tableDataModel.count; i++) {
                        var r = cableListDialog.tableDataModel.get(i)
                        rows.push({
                            col0: r.col0 || "", col1: r.col1 || "", col2: r.col2 || "",
                            col3: r.col3 || "", col4: r.col4 || "", col5: r.col5 || "",
                            col6: r.col6 || "", col7: r.col7 || ""
                        })
                    }
                    if (rows.length > 0) {
                        calibrationDialogInstance.setCableData(rows)
                    }
                    console.log("[Main] Auto-initialized CalibrationDialog, cable rows:", rows.length)
                }
            }
            if (!cableCalibrationDialogInstance) {
                cableCalibrationDialogInstance = cableCalibrationDialogComponent.createObject(window)
                if (cableCalibrationDialogInstance) {
                    cableCalibrationDialogInstance.mainWindow = window
                    cableCalibrationDialogInstance.mainContent = mainContent
                    cableCalibrationDialogInstance.visible = false
                    mainContent.cableCalibrationDialog = cableCalibrationDialogInstance

                    var rows2 = []
                    for (var j = 0; j < cableListDialog.tableDataModel.count; j++) {
                        var r2 = cableListDialog.tableDataModel.get(j)
                        rows2.push({
                            col0: r2.col0 || "", col1: r2.col1 || "", col2: r2.col2 || "",
                            col3: r2.col3 || "", col4: r2.col4 || "", col5: r2.col5 || "",
                            col6: r2.col6 || "", col7: r2.col7 || ""
                        })
                    }
                    if (rows2.length > 0) {
                        cableCalibrationDialogInstance.setCableData(rows2)
                    }
                    console.log("[Main] Auto-initialized CableCalibrationDialog, cable rows:", rows2.length)
                }
            }
        }
    }

    property var cableCalibrationDialogInstance: null
    Component {
        id: cableCalibrationDialogComponent
        CableCalibrationDialog {
            mainWindow: window
            visible: false
        }
    }

    // Dialog thông báo khi gặp notification (thay đổi nhãn giắc)
    Dialog {
        id: notificationDialog
        title: qsTr("Thay đổi kết nối")
        modal: false
        width: Math.min(900   , window.width * 0.4)
        height: 520
        clip: true
        parent: window.contentItem
        closePolicy: Dialog.NoAutoClose
        standardButtons: Dialog.NoButton
        x: 10
        y: (window.height - height) / 2

        property string labelA: ""
        property string labelB: ""
        property var scripts: []
        property int nextIndex: 0
        property int validScriptsStartIndex: 0  // start index cho _getValidScriptsForCurrentPair

        // Checkbox cho loại test
        property bool enableWireResistance: false
        property bool enableContinuity: true
        property bool enableInsulation: false
        property bool enableSheathInsulation: true

        // Trạng thái flow
        property bool isSending: false              // Đang gửi packets (queue)
        property bool allPacketsSentDone: false      // Tất cả packets đã gửi + ACK xong
        property bool startTestSent: false           // User đã bấm Start Test
        property bool isMeasuring: false             // Đang trong vòng lặp đo
        property bool allMeasurementsDone: false     // Đã đo hết
        property bool isPaused: false                // Đã bấm Stop (tạm dừng)
        property string pausedDuringPhase: ""      // "sending" hoặc "measuring"
        property bool mcuReady: false                // MCU gửi 0x06 sẵn sàng
        property int currentMeasurementIndex: 0      // Index script đang đo
        property int totalMeasurements: 0            // Tổng số script cần đo
        property double _measureStartTime: 0         // Timestamp (ms) khi bắt đầu đo 1 script
        property string statusMessage: ""
        property var validScriptsForPair: []         // Cache scripts hợp lệ

        // === Đọc nhiều lần (numReadings) ===
        property int currentReadingIndex: 0          // Lần đọc hiện tại (0-based)
        property int targetNumReadings: 1            // Tổng số lần cần đọc cho script hiện tại
        property var readingValues: []               // Mảng lưu các giá trị đã đọc
        property bool isReadingInstrument: false     // true = đang đọc máy đo, bỏ qua 0x05 thừa

        // Danh sách tất cả cặp connector trong bài đo
        property var allConnectorPairs: []
        property int currentPairIndex: 0

        function buildConnectorPairList() {
            var pairs = []
            if (!scripts || scripts.length === 0) return pairs
            for (var i = 0; i < scripts.length; i++) {
                var s = scripts[i]
                if (String(s.scriptType || "") === "notification") {
                    pairs.push({
                        index: i,
                        labelA: String(s.labelA || ""),
                        labelB: String(s.labelB || ""),
                        display: String(s.labelA || "?") + " ↔ " + String(s.labelB || "?")
                    })
                }
            }
            return pairs
        }

        signal stopRequested()

        function resetState() {
            isSending = false
            allPacketsSentDone = false
            startTestSent = false
            isMeasuring = false
            allMeasurementsDone = false
            isPaused = false
            mcuReady = false
            currentMeasurementIndex = 0
            totalMeasurements = 0
            statusMessage = ""
            validScriptsForPair = []
        }
        // Khi hiện dialog thông báo dựa vào việc bấm đã cắm
        onVisibleChanged: {
            if (visible) {
                wasAccepted = false
                wasRejected = false
                resetState()

                // Build danh sách cặp connector
                allConnectorPairs = buildConnectorPairList()
                // Tìm index cặp hiện tại
                for (var i = 0; i < allConnectorPairs.length; i++) {
                    if (allConnectorPairs[i].labelA === labelA && allConnectorPairs[i].labelB === labelB) {
                        currentPairIndex = i
                        break
                    }
                }
            } else {
                // Cleanup timers khi dialog đóng
                ackTimeoutTimer.stop()
                startTestTimeoutTimer.stop()
                measurementReadTimer.stop()

                if (!wasAccepted && !wasRejected && labelA && labelB) {
                    Qt.callLater(function() {
                        if (notificationDialog && !notificationDialog.wasAccepted && !notificationDialog.wasRejected && notificationDialog.labelA) {
                            notificationDialog.visible = true
                            notificationDialog.open()
                        }
                    })
                }
            }
        }

        property bool wasAccepted: false
        property bool wasRejected: false



        // === Kết nối MCU signals ===
        Connections {
            target: typeof mcuSender !== "undefined" ? mcuSender : null

            // Cập nhật status khi queue thay đổi (mỗi khi gửi/ACK 1 packet)
            function onQueueChanged() {
                if (notificationDialog.visible && notificationDialog.isSending && mcuSender.isSendingQueue) {
                    var current = mcuSender.currentPacketIndex + 1
                    var total = mcuSender.queuedPacketCount
                    notificationDialog.statusMessage = qsTr("Gửi packet %1/%2 - chờ ACK...").arg(current).arg(total)
                    ackTimeoutTimer.restart() // Reset timeout cho mỗi packet
                }
            }

            function onAllPacketsSent() {
                if (notificationDialog.visible && notificationDialog.isSending) {
                    console.log("[DEBUG] Dialog: ALL PACKETS SENT & ACK'D!")
                    notificationDialog.isSending = false
                    notificationDialog.allPacketsSentDone = true
                    notificationDialog.isMeasuring = false
                    notificationDialog.statusMessage = qsTr("✓ Đã đo xong %1 phép đo!").arg(notificationDialog.totalMeasurements)
                    ackTimeoutTimer.stop()
                }
            }

            function onMcuAckReceived() {
                if (notificationDialog.visible && notificationDialog.isMeasuring) {
                    ackTimeoutTimer.stop()
                    notificationDialog._measureStartTime = Date.now()
                    notificationDialog.statusMessage = qsTr("Đọc máy đo... (%1/%2)")
                        .arg(notificationDialog.currentMeasurementIndex + 1).arg(notificationDialog.totalMeasurements)
                    measurementReadTimer.interval = 50
                    measurementReadTimer.restart()
                }
            }

            function onMcuNakSkipped(seq) {
                if (notificationDialog.visible && notificationDialog.isMeasuring) {
                    console.log("[MCU] NAK skipped seq", seq, "- advancing measurement index")
                    var idx = notificationDialog.currentMeasurementIndex
                    if (idx < notificationDialog.validScriptsForPair.length) {
                        var script = notificationDialog.validScriptsForPair[idx]
                        if (mainContent) mainContent._updateMeasurementForScript(
                            String(script.displayText || ""), String(script.scriptType || ""), -1, 0)
                    }
                    notificationDialog._resetReadingState()
                    notificationDialog.currentMeasurementIndex++
                    if (notificationDialog.currentMeasurementIndex >= notificationDialog.totalMeasurements) {
                        notificationDialog.isMeasuring = false
                        notificationDialog.allMeasurementsDone = true
                        notificationDialog.statusMessage = qsTr("✓ Đã đo xong %1 phép đo!").arg(notificationDialog.totalMeasurements)
                    }
                }
            }

        }

        // Timer đọc máy đo thật (hoặc fake nếu chưa kết nối)
        // Hỗ trợ đọc nhiều lần (numReadings) → lấy trung bình
        Timer {
            id: measurementReadTimer
            interval: 50
            repeat: false
            onTriggered: {
                if (notificationDialog.currentMeasurementIndex < notificationDialog.validScriptsForPair.length) {
                    var script = notificationDialog.validScriptsForPair[notificationDialog.currentMeasurementIndex]
                    var st = String(script.scriptType || "")
                    var displayText = String(script.displayText || "")

                    // Lần đọc đầu tiên → khởi tạo numReadings
                    if (notificationDialog.currentReadingIndex === 0) {
                        notificationDialog.targetNumReadings = (script.numReadings !== undefined && Number(script.numReadings) > 0) ? Number(script.numReadings) : 1
                        notificationDialog.readingValues = []
                        console.log("[MEASURE] Script", notificationDialog.currentMeasurementIndex + 1,
                                    "/", notificationDialog.totalMeasurements, "type:", st, "name:", displayText,
                                    "numReadings:", notificationDialog.targetNumReadings)
                    }

                    var readLabel = notificationDialog.targetNumReadings > 1
                        ? " (lần " + (notificationDialog.currentReadingIndex + 1) + "/" + notificationDialog.targetNumReadings + ")"
                        : ""

                    // Chọn máy đo theo loại test
                    if (st === "continuity" || st === "sheath_insulation") {
                        if (typeof keithley2110 !== "undefined" && keithley2110 && keithley2110.isOpen) {
                            // Cấu hình máy đo nếu script yêu cầu (chỉ lần đọc đầu tiên)
                            if (script.deviceConfig && notificationDialog.currentReadingIndex === 0) {
                                var range = String(script.resistanceRange || "RANGE_1KΩ")
                                var speed = String(script.deviceSpeed || "FAST")
                                console.log("[MEASURE] Cấu hình Keithley - range:", range, "speed:", speed)
                                keithley2110.configureRM3544(range, speed)

                                var avgCount = (script.numReadings !== undefined && Number(script.numReadings) > 1) ? Number(script.numReadings) : 0
                                keithley2110.configureAverage(avgCount)
                                if (avgCount >= 2) {
                                    console.log("[MEASURE] Keithley Average count:", avgCount)
                                }
                            }
                            notificationDialog.targetNumReadings = 1
                            console.log("[MEASURE] Đọc Keithley 2110 (" + st + ")...")
                            notificationDialog.statusMessage = qsTr("Đọc Keithley... (%1/%2)")
                                .arg(notificationDialog.currentMeasurementIndex + 1).arg(notificationDialog.totalMeasurements)
                            keithley2110.readResistance()
                            return // Chờ signal resistanceRead
                        }
                    }

                    // Máy đo chưa kết nối → dùng giá trị fake để test
                    var fakeVal = parseFloat((Math.random() * 0.5).toFixed(6))
                    console.log("[MEASURE] Fake value:", fakeVal, "for type:", st)
                    if (notificationDialog._handleReadingValue(fakeVal)) {
                        notificationDialog._advanceToNextMeasurement()
                    }
                    return
                }
                notificationDialog._resetReadingState()
                notificationDialog._advanceToNextMeasurement()
            }
        }

        // Hàm xử lý kết quả đọc (tích lũy + tính trung bình khi đủ lần)
        // Trả về true nếu đã đủ lần đọc, false nếu cần đọc thêm
        function _handleReadingValue(value) {
            readingValues.push(value)
            currentReadingIndex++

            console.log("[MEASURE] Reading", currentReadingIndex, "/", targetNumReadings, "value:", value)

            if (currentReadingIndex < targetNumReadings) {
                // Chưa đủ lần đọc → đọc tiếp sau delayBetween ms
                var idx = currentMeasurementIndex
                var betweenDelay = 100 // fallback giảm xuống 100ms
                if (idx < validScriptsForPair.length) {
                    betweenDelay = Number(validScriptsForPair[idx].delayBetween || 100)
                }
                console.log("[MEASURE] Đọc thêm lần", currentReadingIndex + 1, "... (delay:", betweenDelay, "ms)")
                measurementReadTimer.interval = betweenDelay
                measurementReadTimer.restart()
                return false
            }

            // Đã đủ lần đọc → tính trung bình
            var sum = 0
            for (var i = 0; i < readingValues.length; i++) {
                sum += readingValues[i]
            }
            var avgValue = sum / readingValues.length

            if (targetNumReadings > 1) {
                console.log("[MEASURE] Trung bình", readingValues.length, "lần đọc:",
                            readingValues.join(", "), "→ AVG =", avgValue.toFixed(6))
            }

            // Cập nhật kết quả đo — tính thời gian đo (duration)
            var elapsedMs = (_measureStartTime > 0) ? (Date.now() - _measureStartTime) : 0
            var idx = currentMeasurementIndex
            if (idx < validScriptsForPair.length) {
                var script = validScriptsForPair[idx]
                var displayText = String(script.displayText || "")
                var st = String(script.scriptType || "")
                if (mainContent) mainContent._updateMeasurementForScript(displayText, st, avgValue, elapsedMs)
            }

            // Reset và chuyển sang script tiếp - dùng delayAfter từ script
            var scriptIdx2 = currentMeasurementIndex
            var afterDelay = 50 // fallback giảm xuống 50ms
            if (scriptIdx2 < validScriptsForPair.length) {
                afterDelay = Number(validScriptsForPair[scriptIdx2].delayAfter || 50)
            }
            measurementReadTimer.interval = afterDelay
            _resetReadingState()
            return true
        }

        // Reset trạng thái đọc nhiều lần
        function _resetReadingState() {
            currentReadingIndex = 0
            targetNumReadings = 1
            readingValues = []
            //isReadingInstrument = false  // MỞ KHÓA - cho phép nhận 0x05 tiếp
            console.log("[MEASURE] 🔓 Reset reading state - sẵn sàng nhận 0x05 mới")
        }

        // Hàm chuyển sang phép đo tiếp theo
        function _advanceToNextMeasurement() {
            currentMeasurementIndex++

            if (currentMeasurementIndex >= totalMeasurements) {
                console.log("[MEASURE] === ĐÃ ĐO HẾT", totalMeasurements, "SCRIPTS ===")
                isMeasuring = false
                allMeasurementsDone = true
                statusMessage = qsTr("✓ Đã đo xong %1 phép đo! Bấm 'Đã cắm → Tiếp'.").arg(totalMeasurements)
            } else {
                console.log("[MEASURE] Gửi script tiếp theo",
                            currentMeasurementIndex + 1, "/", totalMeasurements)
                statusMessage = qsTr("Chờ MCU... (%1/%2)")
                    .arg(currentMeasurementIndex + 1).arg(totalMeasurements)
            }
            // Luôn gọi sendNextScript() để C++ advance queue (khi hết sẽ emit allPacketsSent)
            if (typeof mcuSender !== "undefined" && mcuSender) {
                mcuSender.sendNextScript()
            }
        }

        // === Nhận kết quả từ RM3544 ===
        Connections {
            target: typeof keithley2110 !== "undefined" ? keithley2110 : null
            function onResistanceRead(value) {
                if (notificationDialog.visible && notificationDialog.isMeasuring) {
                    // Tích lũy giá trị → nếu đủ lần đọc thì tính trung bình & advance
                    if (notificationDialog._handleReadingValue(value)) {
                        notificationDialog._advanceToNextMeasurement()
                    }
                    // Nếu chưa đủ → _handleReadingValue đã restart measurementReadTimer
                }
            }
            function onErrorOccurred(error) {
                if (notificationDialog.visible && notificationDialog.isMeasuring) {
                    console.log("[MEASURE] RM3544 lỗi:", error)
                    var idx = notificationDialog.currentMeasurementIndex
                    var errElapsed = (notificationDialog._measureStartTime > 0) ? (Date.now() - notificationDialog._measureStartTime) : 0
                    if (idx < notificationDialog.validScriptsForPair.length) {
                        var s = notificationDialog.validScriptsForPair[idx]
                        // Ghi lỗi vào kết quả thay vì fake
                        if (mainContent) {
                            mainContent._updateMeasurementForScript(String(s.displayText||""), String(s.scriptType||""), "LỖI", errElapsed)
                        }
                    }
                    notificationDialog._resetReadingState()
                    notificationDialog._advanceToNextMeasurement()
                }
            }
        }

        // === Nhận kết quả từ SM7110 ===
        // ⚠️ AN TOÀN: Sau mỗi phép đo SM7110 (điện áp cao lên tới 1000V),
        // PHẢI xả điện (discharge) trước khi chuyển relay sang script tiếp theo.
        // Flow: đọc giá trị → tắt output → chờ xả điện → advance

        Timer {
            id: ackTimeoutTimer
            interval: 200000
            repeat: false
            onTriggered: {
                if (notificationDialog.isSending) {
                    notificationDialog.isSending = false
                    notificationDialog.statusMessage = qsTr("⚠ Timeout - MCU không phản hồi!")
                }
            }
        }

        property int startTestRetryCount: 0
        property int maxStartTestRetries: 3

        Timer {
            id: startTestTimeoutTimer
            interval: 10000
            repeat: false
            onTriggered: {
                if (notificationDialog.isMeasuring) {
                    notificationDialog.startTestRetryCount++
                    if (notificationDialog.startTestRetryCount <= notificationDialog.maxStartTestRetries) {
                        // Retry - gửi lại 04
                        console.log("[DEBUG] Start Test timeout - retry", notificationDialog.startTestRetryCount,
                                    "/", notificationDialog.maxStartTestRetries)
                        notificationDialog.statusMessage = qsTr("⚠ Timeout - retry %1/%2 (%3/%4)")
                            .arg(notificationDialog.startTestRetryCount).arg(notificationDialog.maxStartTestRetries)
                            .arg(notificationDialog.currentMeasurementIndex + 1).arg(notificationDialog.totalMeasurements)
                        if (typeof mcuSender !== "undefined" && mcuSender) {
                            startTestTimeoutTimer.restart()
                        }
                    } else {
                        // Hết retry - báo lỗi
                        console.log("[ERROR] Start Test timeout - hết retry!")
                        notificationDialog.statusMessage = qsTr("❌ MCU không phản hồi Start Test (%1/%2) sau %3 lần thử!")
                            .arg(notificationDialog.currentMeasurementIndex + 1).arg(notificationDialog.totalMeasurements)
                            .arg(notificationDialog.maxStartTestRetries)
                        notificationDialog.isMeasuring = false
                    }
                }
            }
        }

        // Hàm helper lấy scripts hợp lệ cho cặp chân hiện tại
        function _getValidScriptsForCurrentPair() {
            var result = []
            if (!scripts || scripts.length === 0) return result

            var startIdx = validScriptsStartIndex

            // Tìm notification tiếp theo (= hết scripts của cặp này)
            var endIdx = scripts.length
            for (var j = startIdx; j < scripts.length; j++) {
                if (String(scripts[j].scriptType || "") === "notification") {
                    endIdx = j
                    break
                }
            }

            console.log("[DEBUG] _getValidScripts: startIdx =", startIdx, "endIdx =", endIdx)

            // Thu thập scripts hợp lệ (giữ thứ tự gốc tạm thời)
            var validScripts = []
            for (var k = startIdx; k < endIdx; k++) {
                var script = scripts[k]
                var st = String(script.scriptType || "")
                if (st.indexOf("_header") >= 0 || st === "notification" || st === "system_init") continue

                var include = false
                if (st === "wire_resistance" && enableWireResistance) include = true
                else if (st === "continuity" && enableContinuity) include = true
                else if (st === "insulation" && enableInsulation) include = true
                else if (st === "sheath_insulation" && enableSheathInsulation) include = true

                if (script.allowRun === false) include = false

                if (include) validScripts.push(script)
            }

            // ═══ SẮP XẾP THEO CMD GIỐNG McuSender ═══
            // McuSender gộp theo CMD: tất cả wire_resistance trước, rồi continuity, rồi insulation...
            // MCU xử lý theo thứ tự CMD nhận được → PC phải đọc máy đo theo cùng thứ tự
            var cmdOrder = []  // Thứ tự CMD xuất hiện (giống McuSender)
            var grouped = {}   // Scripts theo type

            for (var m = 0; m < validScripts.length; m++) {
                var sType = String(validScripts[m].scriptType || "")
                if (!grouped[sType]) {
                    grouped[sType] = []
                    cmdOrder.push(sType)
                }
                grouped[sType].push(validScripts[m])
            }

            // Ghép lại theo thứ tự CMD
            for (var c = 0; c < cmdOrder.length; c++) {
                var group = grouped[cmdOrder[c]]
                for (var g = 0; g < group.length; g++) {
                    result.push(group[g])
                }
            }

            console.log("[DEBUG] validScripts sorted by CMD:", result.length, "scripts")
            for (var d = 0; d < result.length; d++) {
                console.log("  [" + d + "]", String(result[d].scriptType || ""), String(result[d].displayText || ""))
            }

            return result
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 0

            // Thanh title kéo được
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                color: "#1565C0"
                radius: 4

                Text {
                    anchors.centerIn: parent
                    text: qsTr("⠿ Thay đổi kết nối - %1 ↔ %2").arg(notificationDialog.labelA || "?").arg(notificationDialog.labelB || "?")
                    font.pixelSize: 13
                    font.bold: true
                    color: "#fff"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeAllCursor
                    property point pressPos: Qt.point(0, 0)
                    onPressed: function(mouse) {
                        pressPos = Qt.point(mouse.x, mouse.y)
                    }
                    onPositionChanged: function(mouse) {
                        var dx = mouse.x - pressPos.x
                        var dy = mouse.y - pressPos.y
                        notificationDialog.x += dx
                        notificationDialog.y += dy
                    }
                }
            }

            // Content area - scrollable
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Layout.topMargin: 4
                Layout.bottomMargin: 8
                contentHeight: contentCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

            ColumnLayout {
                id: contentCol
                width: parent.width
                spacing: 8

            Text {
                Layout.fillWidth: true
                text: qsTr("Vui lòng kết nối cặp chân đo:")
                font.pixelSize: 16
                font.bold: true
                wrapMode: Text.WordWrap
            }

            // ComboBox chọn cặp connector
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                color: "#E3F2FD"
                border.color: "#90CAF9"
                radius: 4
                visible: notificationDialog.allConnectorPairs.length > 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 6

                    Text {
                        text: qsTr("Chọn cặp:")
                        font.pixelSize: 12
                        font.bold: true
                        color: "#1565C0"
                    }

                    ComboBox {
                        id: pairComboBox
                        Layout.fillWidth: true
                        model: {
                            var list = []
                            for (var i = 0; i < notificationDialog.allConnectorPairs.length; i++) {
                                var p = notificationDialog.allConnectorPairs[i]
                                list.push((i + 1) + ". " + p.display)
                            }
                            return list
                        }
                        currentIndex: notificationDialog.currentPairIndex
                        enabled: !notificationDialog.isSending && !notificationDialog.isMeasuring
                        onActivated: function(idx) {
                            if (idx >= 0 && idx < notificationDialog.allConnectorPairs.length && idx !== notificationDialog.currentPairIndex) {
                                var pair = notificationDialog.allConnectorPairs[idx]
                                notificationDialog.currentPairIndex = idx
                                notificationDialog.labelA = pair.labelA
                                notificationDialog.labelB = pair.labelB
                                notificationDialog.nextIndex = pair.index + 1

                                // Reset trạng thái
                                notificationDialog.isSending = false
                                notificationDialog.allPacketsSentDone = false
                                notificationDialog.startTestSent = false
                                notificationDialog.isMeasuring = false
                                notificationDialog.allMeasurementsDone = false
                                notificationDialog.currentMeasurementIndex = 0
                                notificationDialog.statusMessage = qsTr("Đã chuyển sang cặp: %1 ↔ %2").arg(pair.labelA).arg(pair.labelB)

                                // Rebuild valid scripts cho pair mới
                                notificationDialog.validScriptsForPair = notificationDialog._getValidScriptsForCurrentPair()
                                notificationDialog.totalMeasurements = notificationDialog.validScriptsForPair.length
                            }
                        }
                    }

                    Text {
                        text: qsTr("(%1/%2)").arg(notificationDialog.currentPairIndex + 1).arg(notificationDialog.allConnectorPairs.length)
                        font.pixelSize: 11
                        color: "#666"
                    }
                }
            }

            // Đầu A và B hiển thị
            Text {
                Layout.fillWidth: true
                text: qsTr("• Đầu A: %1").arg(notificationDialog.labelA || qsTr("(chưa đặt)"))
                font.pixelSize: 14
                font.bold: true
                color: "#1565C0"
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("• Đầu B: %1").arg(notificationDialog.labelB || qsTr("(chưa đặt)"))
                font.pixelSize: 14
                font.bold: true
                color: "#1565C0"
                wrapMode: Text.WordWrap
            }

            // Bảng checkbox cho các loại test
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: checkboxCol.implicitHeight + 20
                color: "#f9f9f9"
                border.color: "#d0d0d0"
                radius: 4

                ColumnLayout {
                    id: checkboxCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Text {
                        text: qsTr("Chọn loại test cần thực hiện:")
                        font.pixelSize: 13
                        font.bold: true
                        color: "#333"
                    }

                    Row {
                        Layout.fillWidth: true
                        spacing: 20

                        CheckBox {
                            id: continuityCheck
                            checked: notificationDialog.enableContinuity
                            text: qsTr("Thông chập giữa các chân (Keithley 2110)")
                            font.pixelSize: 12
                            enabled: !notificationDialog.isSending && !notificationDialog.isMeasuring && !notificationDialog.allMeasurementsDone
                            onCheckedChanged: {
                                notificationDialog.enableContinuity = checked
                            }
                        }

                        CheckBox {
                            id: sheathInsulationCheck
                            checked: notificationDialog.enableSheathInsulation
                            text: qsTr("Cách điện với vỏ (Keithley 2110)")
                            font.pixelSize: 12
                            enabled: !notificationDialog.isSending && !notificationDialog.isMeasuring && !notificationDialog.allMeasurementsDone
                            onCheckedChanged: {
                                notificationDialog.enableSheathInsulation = checked
                            }
                        }
                    }
                }
            }

            // Thanh trạng thái
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                color: notificationDialog.allMeasurementsDone ? "#e8f5e9"
                     : (notificationDialog.isMeasuring || notificationDialog.isSending) ? "#e3f2fd"
                     : "#f5f5f5"
                border.color: notificationDialog.allMeasurementsDone ? "#4CAF50"
                            : (notificationDialog.isMeasuring || notificationDialog.isSending) ? "#2196F3"
                            : "#ccc"
                radius: 4

                Text {
                    anchors.centerIn: parent
                    text: notificationDialog.statusMessage || qsTr("Sẵn sàng - Bấm 'Gửi' để gửi & đo tự động")
                    font.pixelSize: 13
                    color: notificationDialog.allMeasurementsDone ? "#2E7D32"
                         : (notificationDialog.isMeasuring || notificationDialog.isSending) ? "#1565C0"
                         : "#666"
                    font.bold: notificationDialog.allMeasurementsDone
                }
            }

            // Progress bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                color: "#e0e0e0"
                radius: 3
                visible: notificationDialog.isSending || notificationDialog.isMeasuring

                Rectangle {
                    height: parent.height
                    radius: 3
                    color: notificationDialog.isMeasuring ? "#2196F3" : "#FF9800"
                    width: {
                        if (notificationDialog.isMeasuring && notificationDialog.totalMeasurements > 0) {
                            return parent.width * notificationDialog.currentMeasurementIndex / notificationDialog.totalMeasurements
                        } else if (notificationDialog.isSending && typeof mcuSender !== "undefined" && mcuSender && mcuSender.queuedPacketCount > 0) {
                            return parent.width * (mcuSender.currentPacketIndex + 1) / mcuSender.queuedPacketCount
                        }
                        return 0
                    }
                    Behavior on width { NumberAnimation { duration: 200 } }
                }
            }

            // Hướng dẫn user - nổi bật
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: guideCol.implicitHeight + 16
                radius: 6
                color: notificationDialog.allMeasurementsDone ? "#E8F5E9"
                     : (notificationDialog.isMeasuring || notificationDialog.isSending) ? "#FFF3E0"
                     : "#F3E5F5"
                border.color: notificationDialog.allMeasurementsDone ? "#4CAF50"
                            : (notificationDialog.isMeasuring || notificationDialog.isSending) ? "#FF9800"
                            : "#9C27B0"
                border.width: 2

                ColumnLayout {
                    id: guideCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    // Bước hiện tại
                    Text {
                        Layout.fillWidth: true
                        text: notificationDialog.allMeasurementsDone
                            ? "✅ Bước 3/3: Hoàn thành!"
                            : notificationDialog.isMeasuring || notificationDialog.isSending
                            ? "⏳ Bước 2/3: Đang gửi & đo..."
                            : "👉 Bước 1/3: Kết nối xong → Bấm 「Gửi」"
                        font.pixelSize: 14
                        font.bold: true
                        color: notificationDialog.allMeasurementsDone ? "#2E7D32"
                             : (notificationDialog.isMeasuring || notificationDialog.isSending) ? "#1565C0"
                             : "#6A1B9A"
                        wrapMode: Text.WordWrap
                    }

                    // Mô tả chi tiết
                    Text {
                        Layout.fillWidth: true
                        text: notificationDialog.allMeasurementsDone
                            ? qsTr("Đã đo xong %1 phép đo. Bấm 「Đã cắm → Tiếp」 để chuyển connector.").arg(notificationDialog.totalMeasurements)
                            : (notificationDialog.isMeasuring || notificationDialog.isSending)
                            ? notificationDialog.statusMessage
                            : qsTr("Kết nối Đầu A (%1) và Đầu B (%2), rồi bấm 「Gửi」 để gửi và đo tự động.")
                                .arg(notificationDialog.labelA || "?").arg(notificationDialog.labelB || "?")
                        font.pixelSize: 11
                        color: "#555"
                        wrapMode: Text.WordWrap
                    }
                }
            } // end guide Rectangle
            } // end contentCol ColumnLayout
            } // end Flickable

            // ═══ Hàng nút ═══
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 8

                // Nút Dừng bài đo (góc trái)
                Rectangle {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 36
                    radius: 8
                    color: stopBtnMa.pressed ? "#D32F2F" : stopBtnMa.containsMouse ? "#E57373" : "#FFEBEE"
                    border.color: "#EF9A9A"
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "✕"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter; color: "#C62828" }
                        Text { text: qsTr("Dừng"); font.pixelSize: 12; color: "#C62828"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: stopBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { console.log("[DEBUG] User bam 'Dung bai do'"); notificationDialog.stopRequested() }
                    }
                }

                Item { Layout.fillWidth: true } // spacer

                // Nút Gửi bản tin
                Rectangle {
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 40
                    radius: 10
                    visible: !notificationDialog.allMeasurementsDone && !notificationDialog.isPaused
                    opacity: !notificationDialog.isSending ? 1.0 : 0.6
                    color: sendBtnMa.pressed ? "#1565C0" : sendBtnMa.containsMouse ? "#1976D2" : "#2196F3"
                    border.color: "#0D47A1"
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: notificationDialog.isSending ? "⏳" : "📤"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter; color: "#fff" }
                        Text {
                            text: notificationDialog.isSending ? qsTr("Đang gửi...") : qsTr("Gửi bản tin")
                            font.pixelSize: 14; font.bold: true; color: "#fff"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: sendBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !notificationDialog.isSending && !notificationDialog.isMeasuring && !notificationDialog.allMeasurementsDone
                        onClicked: {
                            console.log("[DEBUG] User bam 'Gui'")
                            notificationDialog.isSending = true
                            notificationDialog.isMeasuring = true
                            notificationDialog.currentMeasurementIndex = 0
                            notificationDialog.statusMessage = qsTr("Đang gửi bản tin xuống MCU...")
                            notificationDialog.validScriptsForPair = notificationDialog._getValidScriptsForCurrentPair()
                            notificationDialog.totalMeasurements = notificationDialog.validScriptsForPair.length
                            console.log("[DEBUG] nextIndex =", notificationDialog.nextIndex, "labelA =", notificationDialog.labelA, "labelB =", notificationDialog.labelB)
                            if (notificationDialog.validScriptsForPair.length > 0) {
                                var first = notificationDialog.validScriptsForPair[0]
                                var last = notificationDialog.validScriptsForPair[notificationDialog.validScriptsForPair.length - 1]
                                console.log("[DEBUG] First script:", first.displayText, "type:", first.scriptType)
                                console.log("[DEBUG] Last script:", last.displayText, "type:", last.scriptType)
                                console.log("[DEBUG] Gui", notificationDialog.validScriptsForPair.length, "scripts")
                                if (typeof mcuSender !== "undefined" && mcuSender && mcuSender.sendTestScripts(notificationDialog.validScriptsForPair)) {
                                    notificationDialog.statusMessage = qsTr("Gửi packet 1/%1 - chờ ACK...").arg(mcuSender.queuedPacketCount)
                                    ackTimeoutTimer.restart()
                                } else {
                                    notificationDialog.isSending = false
                                    notificationDialog.statusMessage = qsTr("⚠ Lỗi gửi!")
                                }
                            } else {
                                notificationDialog.isSending = false
                                notificationDialog.statusMessage = qsTr("Không có script nào (kiểm tra checkbox)")
                            }
                        }
                    }
                }

                // Nút Stop / Resume
                Rectangle {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 40
                    radius: 10
                    visible: (notificationDialog.isSending || notificationDialog.isMeasuring || notificationDialog.isPaused) && !notificationDialog.allMeasurementsDone
                    color: notificationDialog.isPaused
                        ? (resumeBtnMa.pressed ? "#1565C0" : resumeBtnMa.containsMouse ? "#1976D2" : "#2196F3")
                        : (resumeBtnMa.pressed ? "#C62828" : resumeBtnMa.containsMouse ? "#D32F2F" : "#EF5350")
                    border.color: notificationDialog.isPaused ? "#0D47A1" : "#B71C1C"
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: notificationDialog.isPaused ? "▶" : "⏸"
                            font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter; color: "#fff"
                        }
                        Text {
                            text: notificationDialog.isPaused ? qsTr("Resume") : qsTr("Stop")
                            font.pixelSize: 14; font.bold: true; color: "#fff"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: resumeBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (notificationDialog.isPaused) {
                                console.log("[DEBUG] User bam 'Resume' - gui 0x07, phase:", notificationDialog.pausedDuringPhase)
                                notificationDialog.isPaused = false
                                if (notificationDialog.pausedDuringPhase === "sending") {
                                    notificationDialog.statusMessage = qsTr("Resume - gửi lại bản tin...")
                                    notificationDialog.isSending = true
                                    notificationDialog.allPacketsSentDone = false
                                    notificationDialog.mcuReady = false
                                    notificationDialog.startTestSent = false
                                    if (mcuSender && mcuSender.sendTestScripts(notificationDialog.validScriptsForPair)) {
                                        notificationDialog.statusMessage = qsTr("Gửi packet 1/%1 - chờ ACK...").arg(mcuSender.queuedPacketCount)
                                        ackTimeoutTimer.restart()
                                    }
                                } else if (notificationDialog.pausedDuringPhase === "measuring") {
                                    notificationDialog.statusMessage = qsTr("Resume - tiếp tục đo từ %1/%2...").arg(notificationDialog.currentMeasurementIndex + 1).arg(notificationDialog.totalMeasurements)
                                    notificationDialog.isMeasuring = true
                                    if (mcuSender) { startTestTimeoutTimer.restart() }
                                } else {
                                    notificationDialog.statusMessage = qsTr("Resume - chờ MCU sẵn sàng...")
                                    notificationDialog.mcuReady = false
                                }
                                notificationDialog.pausedDuringPhase = ""
                            } else {
                                console.log("[DEBUG] User bam 'Stop' - gui 0x02")
                                if (notificationDialog.isSending) { notificationDialog.pausedDuringPhase = "sending" }
                                else if (notificationDialog.isMeasuring) { notificationDialog.pausedDuringPhase = "measuring" }
                                else { notificationDialog.pausedDuringPhase = "waiting" }
                                notificationDialog.isPaused = true
                                notificationDialog.isSending = false
                                notificationDialog.isMeasuring = false
                                notificationDialog.statusMessage = qsTr("⏸ Đã tạm dừng (%1). Bấm Resume để tiếp tục.").arg(notificationDialog.pausedDuringPhase === "sending" ? "đang gửi" : notificationDialog.pausedDuringPhase === "measuring" ? "đang đo" : "chờ")
                                if (typeof mcuSender !== "undefined" && mcuSender) { mcuSender.cancelQueue() }
                                ackTimeoutTimer.stop(); startTestTimeoutTimer.stop(); measurementReadTimer.stop()
                            }
                        }
                    }
                }

                // Nút Start Test
                // Start Test button removed — measurement now starts automatically on MCU ACK

                // Nút Đã cắm → Tiếp
                Rectangle {
                    Layout.preferredWidth: 160
                    Layout.preferredHeight: 40
                    radius: 10
                    visible: notificationDialog.allMeasurementsDone
                    color: nextBtnMa.pressed ? "#F9A825" : nextBtnMa.containsMouse ? "#FBC02D" : "#FDD835"
                    border.color: "#F57F17"
                    border.width: 1

                    SequentialAnimation on scale {
                        running: notificationDialog.allMeasurementsDone
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.06; duration: 500; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "➡"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter; color: "#333" }
                        Text {
                            text: qsTr("Đã cắm → Tiếp")
                            font.pixelSize: 14; font.bold: true; color: "#333"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: nextBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { console.log("[DEBUG] User bam 'Da cam -> Tiep'"); notificationDialog.accept() }
                    }
                }
            }

        } // end outer ColumnLayout


        Component.onCompleted: {
            console.log("[DEBUG] NotificationDialog component completed, width=", width, "height=", height)
        }

        onAccepted: {
            wasAccepted = true
            console.log("[DEBUG] Dialog accepted - Tiep tuc gui scripts tu index", nextIndex)

            // Tiếp tục quy trình: gửi scripts sau notification
            if (mainContent && typeof mainContent._sendScriptsWithNotifications === "function") {
                mainContent._sendScriptsWithNotifications(scripts, nextIndex, enableWireResistance, enableContinuity, enableInsulation, enableSheathInsulation)
            } else {
                console.log("[ERROR] Khong the tiep tuc gui scripts - mainContent hoac ham khong ton tai")
            }
            wasAccepted = false
        }

        onRejected: {
            wasRejected = true
            console.log("[DEBUG] Dialog rejected - Nguoi dung huy - dung gui scripts")
            wasRejected = false
        }

        onStopRequested: {
            wasRejected = true
            console.log("[DEBUG] User bam 'Dung bai do' - STOP")
            addLog("Đo lường", "Dừng đo (User bấm Stop) - Script thứ " + (notificationDialog.currentMeasurementIndex + 1) + "/" + notificationDialog.totalMeasurements)
            ackTimeoutTimer.stop()
            startTestTimeoutTimer.stop()
            measurementReadTimer.stop()
            if (typeof mcuSender !== "undefined" && mcuSender) {
                mcuSender.cancelQueue()
                console.log("User clicked stop button")
            }
            close()
            if (mainContent && typeof mainContent.onStopRequested === "function") {
                mainContent.onStopRequested()
            }
        }
        // Cleanup khi dialog đóng — xử lý trong onVisibleChanged ở trên
    }

    property var testPlanListDialogInstance: null
    property string selectedPlanName: ""

    // Auto-save khi chọn bài đo khác
    onSelectedPlanNameChanged: {
        if (selectedPlanName && typeof fileHelper !== "undefined" && fileHelper) {
            var appDir = fileHelper.applicationDirPath()
            fileHelper.writeTextFile(appDir + "/last_plan.txt", selectedPlanName)
        }
    }

    // Auto-load bài đo cuối cùng khi mở app
    Component.onCompleted: {
        if (typeof fileHelper !== "undefined" && fileHelper) {
            var appDir = fileHelper.applicationDirPath()
            var lastPlan = fileHelper.readTextFile(appDir + "/last_plan.txt")
            if (lastPlan && lastPlan.trim() !== "") {
                selectedPlanName = lastPlan.trim()
                console.log("[Main] Auto-loaded last plan:", selectedPlanName)
                addLog("Hệ thống", "Khởi động app — Tự động load bài đo: " + selectedPlanName)
            }
        }
    }
    Component {
        id: testPlanListDialogComponent
        TestPlanListDialog {
            mainWindow: window
            visible: false
        }
    }

    Connections {
        target: cableListDialog
        function onRequestCreateAutoTestPlan(cableName, tableRows) {
            autoTestPlanDialog.openWithCable(cableName, tableRows || [])
        }
    }

    Connections {
        target: testPlanListDialogInstance
        function onPlanSelected(planName) {
            selectedPlanName = planName || ""
            addLog("Bài đo", "Chọn bài đo: " + planName)
        }
    }

    // ═══════════════════════════════════════════════════════
    // Dialog: Giới thiệu phần mềm
    // ═══════════════════════════════════════════════════════
    Dialog {
        id: aboutDialog
        modal: true
        anchors.centerIn: parent
        width: 420
        padding: 0
        standardButtons: Dialog.Close

        background: Rectangle {
            radius: 12
            color: "#FAFBFC"
            border.color: "#D0D5DD"
            border.width: 1
        }

        header: Rectangle {
            width: parent.width
            height: 80
            radius: 12
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#2E86AB" }
                GradientStop { position: 0.5; color: "#1B6B93" }
                GradientStop { position: 1.0; color: "#155A7C" }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 12
                color: "#155A7C"
            }
            Column {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    text: "⚡"
                    font.pixelSize: 20
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: qsTr("Phần mềm đo kiểm cáp điện")
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: "#FFFFFF"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        contentItem: Item {
            implicitHeight: aboutCol.implicitHeight + 32
            Column {
                id: aboutCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 24
                spacing: 14

                // Version info
                Rectangle {
                    width: parent.width
                    height: versionCol.implicitHeight + 20
                    radius: 8
                    color: "#F0F7FF"
                    border.color: "#D0E3F7"
                    border.width: 1

                    Column {
                        id: versionCol
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: qsTr("Phiên bản: 1.0.0")
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: "#1B6B93"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: qsTr("Build: Qt 6.10.1 — MinGW 64-bit")
                            font.pixelSize: 11
                            color: "#5A8FAF"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // Description
                Text {
                    width: parent.width
                    text: qsTr("Phần mềm chuyên dụng hỗ trợ đo kiểm tra chất lượng cáp điện, bao gồm:")
                    font.pixelSize: 12
                    color: "#374151"
                    wrapMode: Text.WordWrap
                }

                Column {
                    spacing: 6
                    Repeater {
                        model: [
                            "🔌  Đo điện trở dây dẫn (Wire Resistance)",
                            "⚡  Kiểm tra thông chập giữa các chân (Continuity)",
                            "🛡️  Đo điện trở cách điện (Insulation)",
                            "📊  Xuất kết quả đo kiểm ra file Excel",
                            "📋  Quản lý bài đo tự động & thủ công",
                            "🔧  Hiệu chuẩn máy đo theo cáp chuẩn"
                        ]
                        Text {
                            required property string modelData
                            text: modelData
                            font.pixelSize: 11
                            color: "#4B5563"
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // Separator
                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#E5E7EB"
                }

                Text {
                    width: parent.width
                    text: qsTr("© 2026 — Phát triển bởi đội ngũ kỹ thuật TKC")
                    font.pixelSize: 10
                    color: "#9CA3AF"
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════
    // Dialog: Mở thư mục phiếu đo
    // ═══════════════════════════════════════════════════════
    property string _resultsPath: (typeof fileHelper !== "undefined" && fileHelper) ? fileHelper.applicationDirPath() + "/results" : ""

    Dialog {
        id: resultsFolderDialog
        modal: true
        anchors.centerIn: parent
        width: 540
        height: 340
        padding: 0
        standardButtons: Dialog.NoButton

        background: Rectangle { radius: 14; color: "#FAFBFC"; border.color: "#D0D5DD"; border.width: 1 }

        header: Rectangle {
            width: parent.width; height: 70; radius: 14
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#0369A1" }
                GradientStop { position: 1.0; color: "#075985" }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 14; color: "#075985" }
            Row {
                anchors.centerIn: parent; spacing: 10
                Text { text: "📂"; font.pixelSize: 22 }
                Text { text: qsTr("Thư mục lưu kết quả đo kiểm"); font.pixelSize: 17; font.weight: Font.Bold; color: "#FFFFFF" }
            }
        }

        contentItem: Item {
            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 14

                Text {
                    width: parent.width
                    text: qsTr("File Excel kết quả và phiếu đo HTML được lưu tại đường dẫn bên dưới.\nBạn có thể thay đổi bằng nút \"Đổi thư mục\".")
                    font.pixelSize: 12; color: "#6B7280"; wrapMode: Text.WordWrap; lineHeight: 1.4
                }

                // Path label
                Text { text: qsTr("ĐƯỜNG DẪN HIỆN TẠI"); font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.2; color: "#9CA3AF" }

                Rectangle {
                    width: parent.width; height: 44; radius: 10
                    color: "#EFF6FF"; border.color: "#BFDBFE"; border.width: 1
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                        Text { text: "📁"; font.pixelSize: 14 }
                        Text { width: parent.parent.width - 50; text: _resultsPath || "N/A"; font.pixelSize: 12; font.family: "Consolas"; color: "#1E3A5F"; elide: Text.ElideMiddle }
                    }
                }

                Row {
                    spacing: 10; width: parent.width
                    Rectangle {
                        width: (parent.width - 20) / 3; height: 42; radius: 10
                        color: _rfOpenMa.pressed ? "#075985" : _rfOpenMa.containsMouse ? "#0284C7" : "#0369A1"
                        Text { anchors.centerIn: parent; text: qsTr("📁  Mở thư mục"); color: "#FFF"; font.pixelSize: 13; font.weight: Font.DemiBold }
                        MouseArea { id: _rfOpenMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { if (_resultsPath) Qt.openUrlExternally("file:///" + _resultsPath.replace(/\\/g, "/")) }
                        }
                    }
                    Rectangle {
                        width: (parent.width - 20) / 3; height: 42; radius: 10
                        color: _rfChangeMa.pressed ? "#6D28D9" : _rfChangeMa.containsMouse ? "#7C3AED" : "#7E22CE"
                        Text { anchors.centerIn: parent; text: qsTr("📂  Đổi thư mục"); color: "#FFF"; font.pixelSize: 13; font.weight: Font.DemiBold }
                        MouseArea { id: _rfChangeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: resultsFolderPicker.open()
                        }
                    }
                    Rectangle {
                        width: (parent.width - 20) / 3; height: 42; radius: 10
                        color: _rfCopyMa.pressed ? "#1F2937" : _rfCopyMa.containsMouse ? "#4B5563" : "#374151"
                        property bool _rfCopied: false
                        Text { anchors.centerIn: parent; text: parent._rfCopied ? qsTr("✅  Đã chép!") : qsTr("📋  Sao chép"); color: "#FFF"; font.pixelSize: 13; font.weight: Font.DemiBold }
                        MouseArea { id: _rfCopyMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { if (_resultsPath && typeof clipboard !== "undefined") clipboard.setText(_resultsPath); parent._rfCopied = true; _rfCopyTimer.restart() }
                        }
                        Timer { id: _rfCopyTimer; interval: 2000; onTriggered: parent._rfCopied = false }
                    }
                }

                Text { id: _rfStatus; width: parent.width; font.pixelSize: 11; color: "#059669"; horizontalAlignment: Text.AlignHCenter; visible: text !== "" }
                Timer { id: _rfStatusTimer; interval: 3000; onTriggered: _rfStatus.text = "" }

                Rectangle {
                    width: parent.width; height: 36; radius: 8
                    color: _rfCloseMa.containsMouse ? "#F3F4F6" : "#FFFFFF"; border.color: "#D1D5DB"; border.width: 1
                    Text { anchors.centerIn: parent; text: qsTr("Đóng"); color: "#374151"; font.pixelSize: 13 }
                    MouseArea { id: _rfCloseMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: resultsFolderDialog.close() }
                }
            }
        }
    }

    FolderDialog {
        id: resultsFolderPicker
        title: qsTr("Chọn thư mục lưu kết quả đo")
        onAccepted: {
            var p = String(selectedFolder).replace("file:///", "")
            _resultsPath = p
            // Lưu vào station_config.json
            if (typeof fileHelper !== "undefined" && fileHelper) {
                var cfgStr = fileHelper.loadStationConfig() || "{}"
                try {
                    var cfg = JSON.parse(cfgStr)
                    cfg.logPath = p
                    fileHelper.saveStationConfig(JSON.stringify(cfg))
                    _rfStatus.text = qsTr("✅ Đã lưu đường dẫn mới: %1").arg(p)
                    _rfStatusTimer.restart()
                } catch(e) {}
            }
        }
    }

    // ═══════════════════════════════════════════════════════
    // Dialog: Mở thư mục log
    // ═══════════════════════════════════════════════════════
    property string _logPath: (typeof fileHelper !== "undefined" && fileHelper) ? fileHelper.applicationDirPath() + "/results" : ""

    Dialog {
        id: logFolderDialog
        modal: true
        anchors.centerIn: parent
        width: 540
        height: 340
        padding: 0
        standardButtons: Dialog.NoButton

        background: Rectangle { radius: 14; color: "#FAFBFC"; border.color: "#D0D5DD"; border.width: 1 }

        header: Rectangle {
            width: parent.width; height: 70; radius: 14
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#059669" }
                GradientStop { position: 1.0; color: "#047857" }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 14; color: "#047857" }
            Row {
                anchors.centerIn: parent; spacing: 10
                Text { text: "📝"; font.pixelSize: 22 }
                Text { text: qsTr("Thư mục lưu log hoạt động"); font.pixelSize: 17; font.weight: Font.Bold; color: "#FFFFFF" }
            }
        }

        contentItem: Item {
            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 14

                Text {
                    width: parent.width
                    text: qsTr("File log ghi lại hoạt động hệ thống theo ngày.\nĐường dẫn có thể thay đổi bằng nút \"Đổi thư mục\".")
                    font.pixelSize: 12; color: "#6B7280"; wrapMode: Text.WordWrap; lineHeight: 1.4
                }

                Text { text: qsTr("ĐƯỜNG DẪN HIỆN TẠI"); font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.2; color: "#9CA3AF" }

                Rectangle {
                    width: parent.width; height: 44; radius: 10
                    color: "#ECFDF5"; border.color: "#A7F3D0"; border.width: 1
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                        Text { text: "📝"; font.pixelSize: 14 }
                        Text { width: parent.parent.width - 50; text: _logPath || "N/A"; font.pixelSize: 12; font.family: "Consolas"; color: "#065F46"; elide: Text.ElideMiddle }
                    }
                }

                Row {
                    spacing: 10; width: parent.width
                    Rectangle {
                        width: (parent.width - 20) / 3; height: 42; radius: 10
                        color: _lfOpenMa.pressed ? "#047857" : _lfOpenMa.containsMouse ? "#10B981" : "#059669"
                        Text { anchors.centerIn: parent; text: qsTr("📁  Mở thư mục"); color: "#FFF"; font.pixelSize: 13; font.weight: Font.DemiBold }
                        MouseArea { id: _lfOpenMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { if (_logPath) Qt.openUrlExternally("file:///" + _logPath.replace(/\\/g, "/")) }
                        }
                    }
                    Rectangle {
                        width: (parent.width - 20) / 3; height: 42; radius: 10
                        color: _lfChangeMa.pressed ? "#6D28D9" : _lfChangeMa.containsMouse ? "#7C3AED" : "#7E22CE"
                        Text { anchors.centerIn: parent; text: qsTr("📂  Đổi thư mục"); color: "#FFF"; font.pixelSize: 13; font.weight: Font.DemiBold }
                        MouseArea { id: _lfChangeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: logFolderPicker.open()
                        }
                    }
                    Rectangle {
                        width: (parent.width - 20) / 3; height: 42; radius: 10
                        color: _lfCopyMa.pressed ? "#1F2937" : _lfCopyMa.containsMouse ? "#4B5563" : "#374151"
                        property bool _lfCopied: false
                        Text { anchors.centerIn: parent; text: parent._lfCopied ? qsTr("✅  Đã chép!") : qsTr("📋  Sao chép"); color: "#FFF"; font.pixelSize: 13; font.weight: Font.DemiBold }
                        MouseArea { id: _lfCopyMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { if (_logPath && typeof clipboard !== "undefined") clipboard.setText(_logPath); parent._lfCopied = true; _lfCopyTimer.restart() }
                        }
                        Timer { id: _lfCopyTimer; interval: 2000; onTriggered: parent._lfCopied = false }
                    }
                }

                Text { id: _lfStatus; width: parent.width; font.pixelSize: 11; color: "#059669"; horizontalAlignment: Text.AlignHCenter; visible: text !== "" }
                Timer { id: _lfStatusTimer; interval: 3000; onTriggered: _lfStatus.text = "" }

                Rectangle {
                    width: parent.width; height: 36; radius: 8
                    color: _lfCloseMa.containsMouse ? "#F3F4F6" : "#FFFFFF"; border.color: "#D1D5DB"; border.width: 1
                    Text { anchors.centerIn: parent; text: qsTr("Đóng"); color: "#374151"; font.pixelSize: 13 }
                    MouseArea { id: _lfCloseMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: logFolderDialog.close() }
                }
            }
        }
    }

    FolderDialog {
        id: logFolderPicker
        title: qsTr("Chọn thư mục lưu log")
        onAccepted: {
            var p = String(selectedFolder).replace("file:///", "")
            _logPath = p
            if (typeof fileHelper !== "undefined" && fileHelper) {
                var cfgStr = fileHelper.loadStationConfig() || "{}"
                try {
                    var cfg = JSON.parse(cfgStr)
                    cfg.logPath = p
                    fileHelper.saveStationConfig(JSON.stringify(cfg))
                    _lfStatus.text = qsTr("✅ Đã lưu đường dẫn mới: %1").arg(p)
                    _lfStatusTimer.restart()
                } catch(e) {}
            }
        }
    }

}






