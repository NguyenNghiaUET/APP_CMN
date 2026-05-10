import QtQuick
import QtQuick.Controls as QC
import QtQuick.Layouts
import QtQuick.Window
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///// UI hiển thị bài đo đã lưu,user click chọn bài đo để load scripts, user click nút "Chỉnh sửa bài đo" để mở tab Chỉnh sửa bài đo
//////// set selectedplanName cho MainContent 
Window {
    id: testPlanListDialog           // id của dialog tab Danh sách bài đo 
    title: qsTr("Danh sách bài đo1 ")  // tiêu đề của dialog
    width: 900
    height: 560
    visible: false
    modality: Qt.ApplicationModal
    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowMinMaxButtonsHint | Qt.WindowCloseButtonHint

    property Window mainWindow: null
    transientParent: mainWindow

    property int selectedPlanIndex: -1
    readonly property string selectedPlanName: selectedPlanIndex >= 0 && selectedPlanIndex < planListModel.count
                                                ? planListModel.get(selectedPlanIndex).name
                                                : ""       
                                                // nếu index < 0 hoặc index >=count return "" 
                                                // nếu index >= 0 hoặc index < count return planListModel.get(selectedPlanIndex).name 


    // Tự động lấy tên bài đo từ planListModel dựa vào selectedPlanIndex

    signal planSelected(string planName)

    function open() {
        refreshPlanList()  //load danh sách bài đo 
        selectedPlanIndex = planListModel.count > 0 ? 0 : -1 // chọn bài đo đầu tiên tại index 0
        show()
    }            

    function refreshPlanList() {
        planListModel.clear()   // xoa dữ liệu cũ
        if (typeof testPlanManager === "undefined" || !testPlanManager)  
            return   // thoat neu testPlanManager chưa sẵn
        var names = testPlanManager.planNames()   // get bài đo từ backend
        for (var i = 0; i < names.length; i++)
            planListModel.append({ "name": names[i] })   //// them bài đo vào model

    }
// tải chi tiết bài đo bên tab Danh sách bài
    function loadScriptsForPlan(planName) {
        scriptListModel.clear()
        if (!planName || typeof testPlanManager === "undefined" || !testPlanManager)   // testPlanManager là đối tượng C++ được export sang QML 
            return
        var scripts = testPlanManager.loadScripts(planName)   // lấy scripts của bài đo đó
        for (var j = 0; j < scripts.length; j++) {   // duyệt qua từng script
            var s = scripts[j]
            var displayText = (s && s.displayText !== undefined) ? String(s.displayText) : ""     // lấy displayText của script
            var scriptType = (s && s.scriptType !== undefined) ? String(s.scriptType) : ""   // lấy scriptType của script
            var isHeader = scriptType.indexOf("_header") >= 0   // kiểm tra xem có phải là header không
            var expanded = isHeader ? (scriptType !== "continuity_header" && scriptType !== "insulation_header") : true   // kiểm tra xem có phải là header không

            scriptListModel.append({ "displayText": displayText, "scriptType": scriptType, "expanded": expanded })   // thêm script vào model
        }
    }

    property int scriptListRefresh: 0
    function _sectionHeaderIndex(scriptType, itemIndex) {   // tìm index của header 
        for (var j = itemIndex - 1; j >= 0; j--) {   // duyệt qua từng script
            if (String(scriptListModel.get(j).scriptType || "") === scriptType + "_header")   // kiểm tra xem có phải là header không
                return j
            if (String(scriptListModel.get(j).scriptType || "") !== scriptType)   // kiểm tra xem có phải là header không
                break
        }
        return -1
    }
    function _isSectionChildVisible(scriptType, itemIndex) {   // Kiểm tra xem có phải header ko 
        var idx = _sectionHeaderIndex(scriptType, itemIndex)   // tìm index của header 
        if (idx < 0) return true   // nếu index < 0 thì return true
        return scriptListModel.get(idx).expanded !== false   // nếu index >= 0 thì return expanded của header
    }

    ListModel {
        id: planListModel 
    }
    ListModel {
        id: scriptListModel
    }

    Connections {     // kết nối với signal onTestPlansChanged của testPlanManager
        target: testPlanManager    // testPlanManager là đối tượng C++ được export sang QML  
        function onTestPlansChanged() {   // khi testPlanManager thay đổi thì gọi hàm này
            if (!testPlanListDialog.visible)  // nếu dialog không hiển thị thì return
                return
            refreshPlanList()   // load danh sách bài đo 
            if (selectedPlanIndex >= planListModel.count) // nếu index >= count thì chọn bài đo đầu tiên tại index 0
                selectedPlanIndex = Math.max(0, planListModel.count - 1)   // chọn bài đo đầu tiên tại index 0
            loadScriptsForPlan(selectedPlanName) // load scripts của bài đo
        //    console.log("loadScript");

        }
    }

    onSelectedPlanNameChanged: {
        if (typeof testPlanManager !== "undefined" && testPlanManager)
            loadScriptsForPlan(selectedPlanName)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        QC.SplitView {
            orientation: Qt.Horizontal
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                id: leftPanel
                QC.SplitView.minimumWidth: 160
                QC.SplitView.preferredWidth: 220
                color: "#f5f5f5"
                border.color: "#ddd"
                radius: 4

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    QC.Label {
                        text: qsTr("Bài đo")
                        font.bold: true
                        font.pixelSize: 13
                        color: "#1976D2"
                        Layout.fillWidth: true
                    }

                    QC.ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        QC.ScrollBar.horizontal.policy: QC.ScrollBar.AlwaysOff
                        contentWidth: leftPanel.width - 24

                        ListView {
                            id: planListView
                            clip: true
                            model: planListModel   //model chứa danh sách bài đo 
                            currentIndex: testPlanListDialog.selectedPlanIndex // chọn bài đo đầu tiên tại index 0
                            onCurrentIndexChanged: testPlanListDialog.selectedPlanIndex = currentIndex // chọn bài đo đầu tiên tại index 0
                            delegate: QC.ItemDelegate { // delegate là giao diện của từng item trong listview
                                width: planListView.width - 8
                                text: model.name // hiển thị tên bài đo
                                highlighted: planListView.currentIndex === index // tô sáng bài đo đang được chọn
                                // Chuột trái chỉ chọn bài đo (xem chi tiết bên phải). Chỉnh sửa chỉ qua menu "Chỉnh sửa bài đo".
                                onClicked: planListView.currentIndex = index 

                            }
                        }
                    }
                }
            }

            Rectangle {
                id: rightPanel
                QC.SplitView.fillWidth: true
                color: "#fff"
                border.color: "#ddd"
                radius: 4

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    QC.Label {
                        text: qsTr("Scripts")
                        font.bold: true
                        font.pixelSize: 13
                        color: "#1976D2"
                        Layout.fillWidth: true
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: scriptCol.height
                        flickableDirection: Flickable.VerticalFlick
                        QC.ScrollBar.vertical: QC.ScrollBar { policy: QC.ScrollBar.AsNeeded }

                        Column {
                            id: scriptCol
                            width: parent.width
                            spacing: 0

                            Repeater {
                                model: scriptListModel
                                delegate: Rectangle {
                                    id: scriptDelegate
                                    width: scriptCol.width
                                    property string sType: model.scriptType || ""
                                    property bool isHeader: sType.indexOf("_header") >= 0
                                    property bool isCollapsed: {
                                        if (isHeader) return false
                                        for (var h = index - 1; h >= 0; h--) {
                                            var item = scriptListModel.get(h)
                                            if (item && String(item.scriptType || "").indexOf("_header") >= 0) {
                                                return item.expanded === false
                                            }
                                        }
                                        return false
                                    }
                                    visible: !isCollapsed
                                    height: isCollapsed ? 0 : (isHeader ? 26 : 22)
                                    color: isHeader ? "#E8EAF6" : "transparent"
                                    radius: isHeader ? 3 : 0

                                    QC.Label {
                                        anchors.fill: parent
                                        anchors.leftMargin: scriptDelegate.isHeader ? 6 : 18
                                        verticalAlignment: Text.AlignVCenter
                                        text: scriptDelegate.isHeader
                                            ? ((model.expanded !== false ? "▼ " : "▶ ") + model.displayText)
                                            : model.displayText
                                        font.pixelSize: scriptDelegate.isHeader ? 12 : 11
                                        font.bold: scriptDelegate.isHeader
                                        color: scriptDelegate.isHeader ? "#283593" : "#333"
                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        visible: scriptDelegate.isHeader
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var exp = scriptListModel.get(index).expanded
                                            scriptListModel.setProperty(index, "expanded", !exp)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item { Layout.fillWidth: true }

            QC.Button {
                text: qsTr("Chọn bài đo")
                enabled: selectedPlanName !== ""
                onClicked: {
                    if (selectedPlanName) {
                        planSelected(selectedPlanName)
                        close()
                    }
                }
            }
            QC.Button {
                text: qsTr("Xóa bài đo")
                enabled: selectedPlanName !== ""
                onClicked: {
                    if (selectedPlanName) {
                        testPlanManager.removeTestPlan(selectedPlanName)
                        refreshPlanList()
                        if (planListModel.count > 0)
                            selectedPlanIndex = 0
                        else
                            selectedPlanIndex = -1
                        loadScriptsForPlan(selectedPlanName)
                    }
                }
            }
        }
    }
}
