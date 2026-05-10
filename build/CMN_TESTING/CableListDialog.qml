import QtQuick
import QtQuick.Controls as QC
import QtQuick.Layouts
import QtQuick.Window
import Qt.labs.platform 1.1

Window {
    id: cableListDialog
    title: qsTr("Danh sách cáp")
    width: 1000
    height: 580
    visible: false
    modality: Qt.ApplicationModal
   flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowMinMaxButtonsHint | Qt.WindowCloseButtonHint

    property int selectedCableIndex: -1
    property Window mainWindow: null
    transientParent: mainWindow
    property alias tableDataModel: tableDataModel

    signal requestCreateAutoTestPlan(string cableName, var tableRows)

    function open() {
        refreshCableList()
        show()
    }

    Shortcut {
        sequence: "Escape"
       // onActivated: cableListDialog.close()
    }

    property bool isLoadingTable: false
    property bool isRefreshing: false
    property string lastLoadedPath: ""

    onSelectedCableIndexChanged: {
        if (!isLoadingTable && !isRefreshing)
            loadTableForCurrentSelection()
    }

    function refreshCableList() {
        if (isRefreshing)
            return
        isRefreshing = true
        lastLoadedPath = ""
        cableListModel.clear()
        var names = cableListManager.cableNames()
        for (var i = 0; i < names.length; i++) {
            cableListModel.append({
                                      "name": names[i],
                                      "path": cableListManager.cablePath(i)
                                  })
        }
        var oldIndex = selectedCableIndex
        if (cableListView.count > 0 && selectedCableIndex < 0)
            selectedCableIndex = 0
        if (selectedCableIndex >= cableListView.count)
            selectedCableIndex = Math.max(0, cableListView.count - 1)
        if (oldIndex === selectedCableIndex)
            loadTableForCurrentSelection()

        isRefreshing = false
    }

    function loadTableForCurrentSelection() {
        if (isLoadingTable)
            return
        if (selectedCableIndex < 0
                || selectedCableIndex >= cableListModel.count) {
            lastLoadedPath = ""
            tableDataModel.clear()
            return
        }
        console.log("selectedCableIndex",selectedCableIndex);

        var path = cableListModel.get(selectedCableIndex).path // lấy đường dẫn file 
        if (path === lastLoadedPath && tableDataModel.count > 0)
            return
        isLoadingTable = true
        lastLoadedPath = path
        tableDataModel.clear()

        var rows = cableListManager.loadTableData(path)
        console.log("[QML] loadTableData trả về:",
                    rows ? rows.length : "null/undefined", "dòng")
        if (rows && rows.length > 0) {
            var firstRow = rows[0]
            console.log("[QML] Dòng đầu tiên:", typeof firstRow, firstRow)
            if (firstRow) {
                console.log("[QML] firstRow[0]:", firstRow[0], "firstRow[1]:",
                            firstRow[1])
                console.log("[QML] Array.isArray(firstRow):",
                            Array.isArray(firstRow))
                if (typeof firstRow === "object") {
                    var keys = Object.keys(firstRow)
                    console.log("[QML] Object.keys(firstRow):", keys)
                }
            }
            for (var i = 0; i < rows.length; i++) {
                var r = rows[i]
                var c0 = (r && r.col0 !== undefined) ? String(r.col0) : ""
                var c1 = (r && r.col1 !== undefined) ? String(r.col1) : ""
                var c2 = (r && r.col2 !== undefined) ? String(r.col2) : ""
                var c3 = (r && r.col3 !== undefined) ? String(r.col3) : ""
                var c4 = (r && r.col4 !== undefined) ? String(r.col4) : ""
                var c5 = (r && r.col5 !== undefined) ? String(r.col5) : ""
                var c6 = (r && r.col6 !== undefined) ? String(r.col6) : ""
                var c7 = ( r&& r.col7 !== undefined) ? String(r.col7) : ""
                if (i < 3) {
                    console.log("[QML] Dòng", i, "c0:", c0, "c1:", c1,
                                "c2:", c2)
                }
                tableDataModel.append({
                                          "col0": c0,
                                          "col1": c1,
                                          "col2": c2,
                                          "col3": c3,
                                          "col4": c4,
                                          "col5": c5,
                                          "col6": c6,
                                          "col7": c7
                                      })
            }
            console.log("[QML] Đã append", tableDataModel.count,
                        "dòng vào tableDataModel")
        } else {
            console.log("[QML] rows rỗng hoặc không hợp lệ")
        }
        isLoadingTable = false
    }

    Component.onCompleted: refreshCableList()

    Connections {
        target: cableListManager
        function onCableListChanged() {
            refreshCableList()
        }
    }

    ListModel {
        id: cableListModel
    }

    ListModel {
        id: tableDataModel
    }
     
    FileDialog {
        id: addFileDialog
        title: qsTr("Chọn file Excel/CSV cáp kết nối")
        nameFilters: [qsTr(
                "File Excel hoặc CSV") + " (*.xlsx *.xls *.csv *.txt)", qsTr(
                "Tất cả") + " (*.*)"]
        fileMode: FileDialog.OpenFile
        onAccepted: {
            var f = file
            if (f) {
                if (cableListManager.addCableFile(f.toString()))
                    refreshCableList()
            }
        }
    }

    QC.Dialog {
        id: confirmDeleteDialog
        title: qsTr("Xác nhận xóa")
        modal: true
        anchors.centerIn: parent
        standardButtons: QC.Dialog.Yes | QC.Dialog.No
        closePolicy: QC.Dialog.CloseOnEscape
        width: 420

        property int indexToDelete: -1

        QC.Label {
            width: 380
            text: qsTr("Bạn có chắc muốn xóa file \"%1\" khỏi danh sách cáp kết nối?").arg(
                      confirmDeleteDialog.indexToDelete >= 0
                      && confirmDeleteDialog.indexToDelete
                      < cableListModel.count ? cableListModel.get(
                                                   confirmDeleteDialog.indexToDelete).name : "")
            wrapMode: Text.WordWrap
        }

        onAccepted: {
            if (confirmDeleteDialog.indexToDelete >= 0) {
                cableListManager.removeCableFile(
                            confirmDeleteDialog.indexToDelete)
                refreshCableList()
            }
            confirmDeleteDialog.indexToDelete = -1
        }
        onRejected: confirmDeleteDialog.indexToDelete = -1
    }

    Item {
        id: cableListContent
        anchors.fill: parent
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
// RowLayout chia màn thành 2 cột trái [Danh sách] phải [Bảng dữ liệu]
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8
                Layout.margins: 8

                Rectangle {
                    Layout.preferredWidth: 220
                    Layout.fillHeight: true
                    color: "#fafafa"
                    border.color: "#d0d0d0"
                    radius: 4

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        QC.Label {
                            text: qsTr("Danh sách cáp kết nối")
                            font.bold: true
                            font.pixelSize: 12
                            color: "#333333"
                            Layout.fillWidth: true
                        }
// ListView hiển thị danh sách cáp kết nối từ file cable_list.json
                        ListView {
                            id: cableListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: cableListModel // danh sách cáp kết nối 
                            currentIndex: cableListDialog.selectedCableIndex
                            highlight: Rectangle {
                                color: "#2196F3"
                                radius: 2
                            }
                            highlightFollowsCurrentItem: true
//// delegate hiển thị danh sách cáp kết nối 
                            delegate: Rectangle {
                                width: cableListView.width
                                height: 36
                                color: cableListView.currentIndex === index ? "#2196F3" : (mouseArea.containsMouse ? "#e3f2fd" : "transparent")
                                radius: 2
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: model.name
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    color: cableListView.currentIndex
                                           === index ? "#ffffff" : "#333333"
                                }
                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: cableListDialog.selectedCableIndex = index
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 44
                                Layout.preferredHeight: 44
                                radius: 22
                                color: addBtnMa.pressed ? "#2e7d32" : (addBtnMa.containsMouse ? "#66bb6a" : "#4caf50")
                                border.color: "#2e7d32"
                                MouseArea {
                                    id: addBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: addFileDialog.open()
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    color: "white"
                                    font.pixelSize: 24
                                    font.bold: true
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 44
                                Layout.preferredHeight: 44
                                radius: 22
                                color: delBtnMa.pressed ? "#c62828" : (delBtnMa.containsMouse
                                                                       && cableListDialog.selectedCableIndex >= 0 ? "#ef5350" : (cableListDialog.selectedCableIndex >= 0 ? "#f44336" : "#bdbdbd"))
                                border.color: cableListDialog.selectedCableIndex
                                              >= 0 ? "#c62828" : "#9e9e9e"
                                MouseArea {
                                    id: delBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (cableListDialog.selectedCableIndex >= 0) {
                                            confirmDeleteDialog.indexToDelete
                                                    = cableListDialog.selectedCableIndex
                                            confirmDeleteDialog.open()
                                        }
                                    }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "−"
                                    color: "white"
                                    font.pixelSize: 24
                                    font.bold: true
                                }
                            }

                            QC.Button {
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 44
                                text: qsTr("Tạo bài đo")
                                font.pixelSize: 12
                                onClicked: {
                                    var name = ""
                                    var rows = []
                                    if (cableListDialog.selectedCableIndex >= 0 && cableListDialog.selectedCableIndex < cableListModel.count) {
                                        name = cableListModel.get(cableListDialog.selectedCableIndex).name   // name = tên cáp đang chọn 
                                        for (var i = 0; i < tableDataModel.count; i++) {
                                            var r = tableDataModel.get(i)
                                            // rows = toàn bộ dữ liệu bảng từ tableDataModel sang dạng mảng 
                                            rows.push({
                                                        col0: r.col0 || "", col1: r.col1 || "", col2: r.col2 || "",
                                                        col3: r.col3 || "", col4: r.col4 || "", col5: r.col5 || "",
                                                        col6: r.col6 || "", col7: r.col7 || ""
                                                    })
                                        }
                                    }
                                    // gọi hàm requestCreateAutoTestPlan để tạo bài đo tự động 
                                    cableListDialog.requestCreateAutoTestPlan(name, rows)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#ffffff"
                    border.color: "#c0c0c0"
                    radius: 4

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Repeater {
                                model: [qsTr("Nhãn giắc đầu A"), qsTr(
                                        "Tên chân đầu A"), qsTr(
                                        "Chân đo cổng A"), qsTr(
                                        "Nhãn giắc đầu B"), qsTr(
                                        "Tên chân đầu B"), qsTr(
                                        "Chân đo cổng B"), qsTr("Điện trở dẫn
(Ω) ≤"), qsTr("Điện trở cách điện
(MΩ) ≥")]
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 70
                                    height: 32
                                    color: "#e8eef4"
                                    border.color: "#c5d0dc"
                                    border.width: 1
                                    Text {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        text: modelData
                                        font.bold: true
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignLeft
                                        color: "#333333"
                                    }
                                }
                            }
                        }

                        QC.ScrollView {
                            id: tableScrollView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 150
                            clip: true
                            ListView {
                                id: tableListView
                                width: tableScrollView.availableWidth
                                height: tableScrollView.availableHeight
                                clip: true
                                model: tableDataModel
                                spacing: 0
                                delegate: RowLayout {
                                    width: ListView.view.width
                                    height: 26
                                    spacing: 0
                                    readonly property color rowColor: index % 2
                                                                      === 0 ? "#ffffff" : "#f5f5f5"
                                    Component.onCompleted: {
                                        if (index < 3) {
                                            console.log("[QML] Delegate row",
                                                        index, "model.col0:",
                                                        model.col0,
                                                        "model.col1:",
                                                        model.col1,
                                                        "width:", width,
                                                        "height:", height)
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.minimumWidth: 60
                                        Layout.preferredHeight: 26
                                        color: rowColor
                                        border.color: "#e0e0e0"
                                        border.width: 1
                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            text: (model && model.col0
                                                   !== undefined) ? String(
                                                                        model.col0) : "EMPTY"
                                            font.pixelSize: 12
                                            font.bold: false
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: Text.AlignLeft
                                            color: "#000000"
                                            visible: true
                                            Component.onCompleted: {
                                                if (index < 3) {
                                                    console.log("[QML] Text col0 completed, text:",
                                                                text,
                                                                "parent width:",
                                                                parent.width,
                                                                "parent height:",
                                                                parent.height)
                                                }
                                            }
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.minimumWidth: 60
                                        Layout.preferredHeight: 26
                                        color: rowColor
                                        border.color: "#e0e0e0"
                                        border.width: 1
                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            text: (model && model.col1
                                                   !== undefined) ? String(
                                                                        model.col1) : ""
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                            color: "#000000"
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.minimumWidth: 60
                                        Layout.preferredHeight: 26
                                        color: rowColor
                                        border.color: "#e0e0e0"
                                        border.width: 1
                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            text: (model && model.col2
                                                   !== undefined) ? String(
                                                                        model.col2) : ""
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                            color: "#000000"
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.minimumWidth: 60
                                        Layout.preferredHeight: 26
                                        color: rowColor
                                        border.color: "#e0e0e0"
                                        border.width: 1
                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            text: (model && model.col3
                                                   !== undefined) ? String(
                                                                        model.col3) : ""
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                            color: "#000000"
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.minimumWidth: 60
                                        Layout.preferredHeight: 26
                                        color: rowColor
                                        border.color: "#e0e0e0"
                                        border.width: 1
                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            text: (model && model.col4
                                                   !== undefined) ? String(
                                                                        model.col4) : ""
                                            color: "#000000"
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.minimumWidth: 60
                                        Layout.preferredHeight: 26
                                        color: rowColor
                                        border.color: "#e0e0e0"
                                        border.width: 1
                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            text: (model && model.col5
                                                   !== undefined) ? String(
                                                                        model.col5) : ""
                                            color: "#000000"
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.minimumWidth: 60
                                        Layout.preferredHeight: 26
                                        color: rowColor
                                        border.color: "#e0e0e0"
                                        border.width: 1
                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            text: (model && model.col6
                                                   !== undefined) ? String(
                                                                        model.col6) : ""
                                            color: "#000000"
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                    Rectangle {
                                        // Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.minimumWidth: 60
                                        Layout.preferredHeight: 26
                                        color: rowColor
                                        border.color: "#e0e0e0"
                                        border.width: 1
                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            text: (model && model.col7
                                                   !== undefined) ? String(
                                                                        model.col7) : ""
                                            color: "#000000"
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
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
