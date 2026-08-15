pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Column {
    id: root

    readonly property color levelColour: {
        if (KrakenBattery.percentage <= 10)
            return "#f44336";
        if (KrakenBattery.percentage <= 20)
            return "#ff9800";
        return Colours.palette.m3primary;
    }

    spacing: Tokens.spacing.small

    Item {
        anchors.horizontalCenter: parent.horizontalCenter

        implicitWidth: ring.implicitWidth
        implicitHeight: ring.implicitHeight

        CircularProgress {
            id: ring

            implicitSize: 80
            value: KrakenBattery.percentage / 100
            fgColour: root.levelColour

            Behavior on clampedVal {
                Anim {}
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: "headphones"
                font: Tokens.font.icon.large
                color: root.levelColour
            }
        }

        StyledRect {
            anchors.top: parent.top
            anchors.right: parent.right

            visible: KrakenBattery.charging
            implicitWidth: boltIcon.implicitHeight + Tokens.padding.extraSmall * 2
            implicitHeight: boltIcon.implicitHeight + Tokens.padding.extraSmall * 2
            radius: Tokens.rounding.full
            color: Colours.tPalette.m3surface

            MaterialIcon {
                id: boltIcon

                anchors.centerIn: parent
                text: "bolt"
                fill: 1
                color: root.levelColour
            }
        }
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter

        text: `${KrakenBattery.percentage}%`
        font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        color: root.levelColour
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Tokens.spacing.small

        Repeater {
            model: [
                { r: 255, g: 0, b: 0 },
                { r: 255, g: 165, b: 0 },
                { r: 255, g: 255, b: 0 },
                { r: 0, g: 255, b: 0 },
                { r: 0, g: 255, b: 255 },
                { r: 0, g: 0, b: 255 },
                { r: 255, g: 0, b: 255 },
            ]

            StyledRect {
                id: swatch

                required property var modelData

                implicitWidth: 20
                implicitHeight: 20
                radius: Tokens.rounding.full
                color: Qt.rgba(swatch.modelData.r / 255, swatch.modelData.g / 255, swatch.modelData.b / 255, 1)
                border.width: 1
                border.color: Colours.tPalette.m3outline

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: KrakenRGB.setColor(swatch.modelData.r, swatch.modelData.g, swatch.modelData.b)
                }
            }
        }
    }

    IconButton {
        anchors.horizontalCenter: parent.horizontalCenter

        icon: KrakenRGB.on ? "lightbulb" : "lightbulb_outline"
        type: IconButton.Tonal
        isToggle: true
        checked: KrakenRGB.on

        onClicked: KrakenRGB.toggle()
    }
}
