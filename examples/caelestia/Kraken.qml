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
            return Colours.palette.m3error;
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
}
