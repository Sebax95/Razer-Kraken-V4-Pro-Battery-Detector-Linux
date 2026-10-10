pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Column {
    id: root

    readonly property color levelColour: {
        if (!KrakenBattery.available)
            return Colours.palette.m3outline;
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
            value: KrakenBattery.available ? KrakenBattery.percentage / 100 : 0
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
            id: badge

            readonly property bool fullyCharged: KrakenBattery.via === "cable" && KrakenBattery.percentage >= 100

            anchors.top: parent.top
            anchors.right: parent.right

            visible: KrakenBattery.available && (KrakenBattery.charging || fullyCharged)
            implicitWidth: boltIcon.implicitHeight + Tokens.padding.extraSmall * 2
            implicitHeight: boltIcon.implicitHeight + Tokens.padding.extraSmall * 2
            radius: Tokens.rounding.full
            color: Colours.tPalette.m3surface

            MaterialIcon {
                id: boltIcon

                anchors.centerIn: parent
                text: badge.fullyCharged ? "check_circle" : "bolt"
                fill: 1
                color: badge.fullyCharged ? "#4caf50" : root.levelColour
            }
        }
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter

        text: KrakenBattery.available ? `${KrakenBattery.percentage}%` : qsTr("Battery unknown")
        font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        color: root.levelColour
    }

    IconTextButton {
        anchors.horizontalCenter: parent.horizontalCenter

        text: qsTr("Controls")
        icon: "tune"
        type: IconTextButton.Tonal

        onClicked: KrakenControlWindowFactory.create()
    }
}
