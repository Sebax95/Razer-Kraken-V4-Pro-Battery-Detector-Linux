import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property string label

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Tokens.spacing.medium

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            font: Tokens.font.icon.extraLarge
            text: "construction"
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("%1 — work in progress").arg(root.label)
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
            color: Colours.palette.m3onSurfaceVariant
        }
    }
}
