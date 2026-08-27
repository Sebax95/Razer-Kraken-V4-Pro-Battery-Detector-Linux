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

    readonly property var presets: [
        { name: "game", label: qsTr("Game"), icon: "sports_esports" },
        { name: "movie", label: qsTr("Movie"), icon: "movie" },
        { name: "music", label: qsTr("Music"), icon: "music_note" },
        { name: "custom", label: qsTr("Custom"), icon: "tune" },
    ]

    Component.onCompleted: KrakenEQ.refresh()

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.large

        SectionHeader {
            Layout.fillWidth: true
            first: true
            text: qsTr("Equalizer preset")
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            columnSpacing: Tokens.spacing.normal
            rowSpacing: Tokens.spacing.normal

            Repeater {
                model: root.presets

                StyledRect {
                    id: presetBtn

                    required property var modelData

                    readonly property bool active: KrakenEQ.current === modelData.name

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Tokens.rounding.large
                    color: active ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHigh // selected-highlight vs unselected card colour

                    Behavior on color {
                        CAnim {}
                    }

                    StateLayer {
                        color: presetBtn.active ? Colours.palette.m3surfaceContainerLow : Colours.palette.m3onSurfaceVariant // dark ripple/text on the light selected bg
                        onClicked: KrakenEQ.setPreset(presetBtn.modelData.name)
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            font: Tokens.font.icon.extraLarge
                            text: presetBtn.modelData.icon
                            fill: presetBtn.active ? 1 : 0
                            color: presetBtn.active ? Colours.palette.m3surfaceContainerLow : Colours.palette.m3onSurfaceVariant // dark icon on the light selected bg

                            Behavior on fill {
                                Anim {
                                    type: Anim.DefaultEffects
                                }
                            }

                            Behavior on color {
                                CAnim {}
                            }
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: presetBtn.modelData.label
                            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                            color: presetBtn.active ? Colours.palette.m3surfaceContainerLow : Colours.palette.m3onSurfaceVariant // dark label text on the light selected bg

                            Behavior on color {
                                CAnim {}
                            }
                        }
                    }
                }
            }
        }
    }
}
