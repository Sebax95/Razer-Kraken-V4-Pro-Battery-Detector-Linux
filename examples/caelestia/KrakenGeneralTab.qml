pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

Item {
    id: root

    implicitHeight: layout.implicitHeight

    // A smaller, denser version of nexus/common's SliderRow -- used for the
    // Chat/Game pair so they don't take as much vertical space as a single
    // full-size row each.
    component CompactSliderRow: ConnectedRect {
        id: crow

        property alias icon: cicon.text
        property alias label: clabel.text
        property alias valueLabel: cvalueLabel.text
        property real value

        signal moved(value: real)

        implicitHeight: crowLayout.implicitHeight + Tokens.padding.medium * 2

        RowLayout {
            id: crowLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.padding.large
            anchors.rightMargin: Tokens.padding.large
            spacing: Tokens.spacing.medium

            MaterialIcon {
                id: cicon

                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.icon.small
            }

            StyledText {
                id: clabel

                Layout.preferredWidth: 55
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: Tokens.padding.small * 2

                StyledSlider {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitHeight: parent.implicitHeight

                    radius: Tokens.rounding.small
                    value: crow.value
                    onInteraction: v => crow.moved(v)
                }
            }

            StyledText {
                id: cvalueLabel

                color: Colours.palette.m3outline
                font: Tokens.font.body.small
            }
        }
    }

    // "value" is 0=chat/1=game (the display convention, left-to-right --
    // callers flip the service's own opposite convention when binding).
    component BalanceTrack: Item {
        id: track

        property real value: 0.5 // 0..1
        signal moved(v: real)

        implicitHeight: statusLabel.implicitHeight + Tokens.spacing.small + barRow.implicitHeight

        StyledText {
            id: statusLabel

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
            text: {
                const v = track.value;
                if (Math.abs(v - 0.5) < 0.02)
                    return qsTr("Centered");
                return v < 0.5 ? qsTr("Leaning chat") : qsTr("Leaning game");
            }
        }

        Item {
            id: barRow

            anchors.top: statusLabel.bottom
            anchors.topMargin: Tokens.spacing.small
            anchors.left: parent.left
            anchors.right: parent.right
            implicitHeight: 20

            StyledText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                text: qsTr("Chat")
            }

            StyledText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                text: qsTr("Game")
            }

            Item {
                id: bar

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 48
                anchors.rightMargin: 48
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: 20

                StyledRect {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitHeight: 12
                    radius: Tokens.rounding.medium
                    color: Colours.palette.m3secondaryContainer
                }

                // Fixed centre tick -- the reference point, not the value.
                StyledRect {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 3
                    implicitHeight: parent.height
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3outline
                }

                StyledRect {
                    id: handle

                    x: Math.max(0, Math.min(1, track.value)) * (bar.width - width)
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 18
                    implicitHeight: 18
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3primary

                    Behavior on x {
                        Anim {}
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true

                    function moveTo(x: real): void {
                        track.moved(Math.max(0, Math.min(1, x / bar.width)));
                    }

                    onPressed: e => moveTo(e.x)
                    onPositionChanged: e => {
                        if (pressed)
                            moveTo(e.x);
                    }
                }
            }
        }
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            Layout.fillWidth: true
            first: true
            text: qsTr("Volume")
        }

        CompactSliderRow {
            Layout.fillWidth: true
            first: true
            icon: "forum"
            label: qsTr("Chat")
            valueLabel: Math.round(value * 100) + "%"
            value: KrakenVolume.pipewireChat
            onMoved: v => KrakenVolume.setVolume("chat", v)
        }

        CompactSliderRow {
            Layout.fillWidth: true
            last: true
            icon: "sports_esports"
            label: qsTr("Game")
            valueLabel: Math.round(value * 100) + "%"
            value: KrakenVolume.pipewireGame
            onMoved: v => KrakenVolume.setVolume("game", v)
        }

        SectionHeader {
            Layout.fillWidth: true
            text: qsTr("Real (device)")
        }

        // Just one slider, following whichever output is currently active
        // (KrakenVolume.output) -- the real gain of the *other* one isn't
        // shown, only ever adjust the one you're actually listening to.
        SliderRow {
            Layout.fillWidth: true
            first: true
            last: true
            icon: KrakenVolume.output === "chat" ? "forum" : "sports_esports"
            label: KrakenVolume.output === "chat" ? qsTr("Chat") : qsTr("Game")
            valueLabel: Math.round(value * 100) + "%"
            value: KrakenVolume.output === "chat" ? KrakenVolume.masterChat : KrakenVolume.masterGame
            onMoved: v => KrakenVolume.setMaster(KrakenVolume.output, v)
        }

        SectionHeader {
            Layout.fillWidth: true
            text: qsTr("Game-chat balance")
        }

        ConnectedRect {
            id: balanceCard

            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: balanceLayout.implicitHeight + balanceLayout.anchors.margins * 2

            RowLayout {
                id: balanceLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.largeIncreased
                anchors.topMargin: Tokens.padding.large
                anchors.bottomMargin: Tokens.padding.large
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.icon.medium
                    text: "balance"
                }

                BalanceTrack {
                    Layout.fillWidth: true
                    // Visually left=Chat/right=Game, matching Synapse's own
                    // slider -- the service's own convention is the
                    // opposite (0=game/1=chat, the device's native scale),
                    // flipped here for display only.
                    value: 1 - KrakenVolume.balance
                    onMoved: v => KrakenVolume.setBalance(1 - v)
                }
            }
        }
    }
}
