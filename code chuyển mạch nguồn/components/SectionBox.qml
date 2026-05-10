import QtQuick
import QtQuick.Controls

Rectangle {
    property string title: ""
    property alias content: innerCol.data

    color:  "#1e2235"
    border.color: "#2e3a5a"
    border.width: 1
    radius: 6

    Column {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // Title bar
        Rectangle {
            width:  parent.width
            height: 28
            color:  "#252d48"
            radius: 5
            // square bottom corners
            Rectangle { width: parent.width; height: 5; anchors.bottom: parent.bottom; color: parent.color }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10
                text: title
                color: "#7ec8e3"
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 1
            }
        }

        // Content area
        Column {
            id: innerCol
            width: parent.width
            padding: 10
            spacing: 6
        }
    }
}
