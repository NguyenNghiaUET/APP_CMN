import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: appConfigDialog
    title: qsTr("Cấu hình ứng dụng")
    modal: true
    standardButtons: Dialog.Ok | Dialog.Cancel
    width: 600
    height: 400

    // Properties lưu giá trị
    property string stationName: ""
    property string companyName: ""
    property string productionLine: "1"
    property string logPath: ""

    // Load config khi mở
    onOpened: {
        if (typeof fileHelper !== "undefined" && fileHelper) {
            var json = fileHelper.loadStationConfig()
            if (json) {
                try {
                    var cfg = JSON.parse(json)
                    stationName = cfg.stationName || ""
                    companyName = cfg.companyName || ""
                    productionLine = cfg.productionLine || "1"
                    logPath = cfg.logPath || ""
                } catch(e) {}
            }
        }
        stationNameField.text = stationName
        companyNameField.text = companyName
        productionLineField.text = productionLine
        logPathField.text = logPath
    }

    // Save khi OK
    onAccepted: {
        stationName = stationNameField.text
        companyName = companyNameField.text
        productionLine = productionLineField.text
        logPath = logPathField.text

        if (typeof fileHelper !== "undefined" && fileHelper) {
            var cfg = JSON.stringify({
                stationName: stationName,
                companyName: companyName,
                productionLine: productionLine,
                logPath: logPath
            })
            fileHelper.saveStationConfig(cfg)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4

        GroupBox {
            title: qsTr("Application Parameter")
            Layout.fillWidth: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: qsTr("Hiển thị cửa sổ Log"); Layout.fillWidth: true }
                    Switch { checked: true }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: qsTr("Loại log file"); Layout.fillWidth: true}
                    ComboBox {
                        model: ["Excel","CSV","TXT"]
                        currentIndex: 0
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Label { text: qsTr("Tham số hiệu chỉnh theo từng loại cáp"); Layout.fillWidth: true }
                    Switch { checked: true }
                }
            }
        }

        GroupBox {
            title: qsTr("Station Parameter")
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridLayout {
                columns: 2
                anchors.fill: parent
                columnSpacing: 8
                rowSpacing: 4

                Label { text: qsTr("Tên trạm test") }
                TextField {
                    id: stationNameField
                    Layout.fillWidth: true
                    placeholderText: qsTr("VD: DOCHITIEU")
                }

                Label { text: qsTr("Tên Xí nghiệp") }
                TextField {
                    id: companyNameField
                    Layout.fillWidth: true
                    placeholderText: qsTr("VD: Viettel")
                }

                Label { text: qsTr("Dây chuyền") }
                TextField {
                    id: productionLineField
                    Layout.fillWidth: true
                    placeholderText: "1"
                }

                Label { text: qsTr("Đường dẫn log") }
                TextField {
                    id: logPathField
                    Layout.fillWidth: true
                    placeholderText: qsTr("VD: D:\\Logs")
                }
            }
        }
    }
}
