pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Blobs
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    signal close

    property int tabIndex: 0

    readonly property var tabs: [
        { label: qsTr("Lights"), icon: "lightbulb" },
        { label: qsTr("Equalizer"), icon: "equalizer" },
        { label: qsTr("Haptics"), icon: "vibration", wip: true },
        { label: qsTr("Microphone"), icon: "mic", wip: true },
        { label: qsTr("THX"), icon: "spatial_audio", wip: true },
    ]

    // Matching Nexus's own structure now: ONE BlobGroup, a BlobInvertedRect
    // with a real (not hairline) border that IS the light frame, and the
    // dark content sits as a plain rect inside the hole that border leaves --
    // no second blob layer, no fake "solid fill" hack.
    BlobGroup {
        id: testBlobGroup

        smoothing: Tokens.rounding.medium
        color: Colours.palette.m3surfaceContainerLow // frame / border colour (window edge + close button chip)
    }

    BlobInvertedRect {
        anchors.fill: parent
        group: testBlobGroup
        radius: 10
        borderLeft: Tokens.padding.medium
        borderRight: Tokens.padding.medium
        borderTop: Tokens.padding.medium
        borderBottom: Tokens.padding.medium
    }

    StyledRect {
        id: darkRect

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        radius: 10
        color: Colours.palette.m3surface // main dark background (behind tabs + tab content)
        clip: true // keep tab content from bleeding past the window edge at small sizes

        Row {
            id: batteryIndicator

            visible: KrakenBattery.available
            anchors.right: parent.right
            anchors.verticalCenter: tabsRow.verticalCenter
            anchors.rightMargin: Tokens.padding.large
            spacing: Tokens.spacing.small / 2

            MaterialIcon {
                fontStyle: Tokens.font.icon.medium
                text: Icons.getBatteryIcon(KrakenBattery.percentage / 100, KrakenBattery.charging)
                fill: 1
                color: {
                    if (KrakenBattery.percentage <= 10)
                        return "#f44336";
                    if (KrakenBattery.percentage <= 20)
                        return "#ff9800";
                    return Colours.palette.m3onSurfaceVariant;
                }
            }

            StyledText {
                text: `${KrakenBattery.percentage}%`
                font: Tokens.font.body.medium
                color: Colours.palette.m3onSurfaceVariant
            }
        }

        Row {
            id: tabsRow

            // Centred within the space to the left of the battery
            // indicator, not the full width -- otherwise the two overlap
            // at the window's default/minimum size.
            readonly property real reserved: batteryIndicator.visible ? batteryIndicator.width + Tokens.padding.large * 2 : 0

            anchors.top: parent.top
            anchors.topMargin: Tokens.padding.large
            x: (parent.width - reserved - width) / 2
            spacing: Tokens.spacing.small

            Repeater {
                model: root.tabs

                ButtonBase {
                    id: tabBtn

                    required property var modelData
                    required property int index

                    implicitWidth: 96
                    implicitHeight: 64
                    radiusMorph: false
                    defaultRadius: Tokens.rounding.large
                    checkedRadius: Tokens.rounding.large

                    checked: root.tabIndex === index
                    activeColour: Colours.palette.m3primary // selected-state highlight (also used for active EQ preset + "Lights on" toggle)
                    inactiveColour: Colours.palette.m3surfaceBright // unselected tab background
                    activeOnColour: Colours.palette.m3surfaceContainerLow // dark text/icon so it reads on the light activeColour above
                    inactiveOnColour: Colours.palette.m3onSurfaceVariant

                    onClicked: root.tabIndex = index

                    Column {
                        id: tabContent

                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small / 2

                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tabBtn.modelData.icon
                            fill: tabBtn.internalChecked ? 1 : 0
                            color: tabBtn.onColour
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tabBtn.modelData.label
                            font: Tokens.font.body.small
                            color: tabBtn.onColour
                        }
                    }
                }
            }
        }

        StyledRect {
            id: divider

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: tabsRow.bottom
            anchors.margins: Tokens.padding.medium
            anchors.topMargin: Tokens.padding.large
            implicitHeight: 1
            color: Colours.palette.m3surfaceContainerHigh // divider line colour (also section dividers + unselected EQ/toggle rows)
            opacity: 0.5
        }

        VerticalFadeFlickable {
            id: tabFlick

            anchors.top: divider.bottom
            anchors.topMargin: Tokens.padding.large
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Tokens.padding.large
            anchors.leftMargin: Tokens.padding.large
            anchors.rightMargin: Tokens.padding.large

            contentWidth: width
            contentHeight: tabLoader.height
            boundsBehavior: Flickable.StopAtBounds

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: tabFlick
            }

            Loader {
                id: tabLoader

                width: tabFlick.width
                // Tabs with real intrinsic content (Lights) report a positive
                // implicitHeight so they size to their own content and can
                // scroll; tabs without one (Equalizer, WIP placeholders) fall
                // back to filling the viewport so their fillHeight layouts
                // and centered content still work as before.
                height: item ? (item.implicitHeight > 0 ? item.implicitHeight : tabFlick.height) : tabFlick.height
                y: 0
                opacity: 0

                onLoaded: entranceAnim.restart()

                ParallelAnimation {
                    id: entranceAnim

                    Anim {
                        type: Anim.DefaultEffects
                        target: tabLoader
                        property: "opacity"
                        from: 0
                        to: 1
                    }

                    Anim {
                        type: Anim.DefaultEffects
                        target: tabLoader
                        property: "y"
                        from: 16
                        to: 0
                    }
                }

                sourceComponent: {
                    const tab = root.tabs[root.tabIndex];
                    if (tab.wip)
                        return wipComp;
                    return root.tabIndex === 0 ? lightsComp : eqComp;
                }

                Component {
                    id: lightsComp

                    KrakenLightsTab {}
                }

                Component {
                    id: eqComp

                    KrakenEqTab {}
                }

                Component {
                    id: wipComp

                    KrakenWipTab {
                        label: root.tabs[root.tabIndex].label
                    }
                }
            }
        }
    }

    BlobRect {
        id: testWindowBtnRect

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 0

        group: testBlobGroup
        radius: Tokens.rounding.medium
        topLeftRadius: Tokens.rounding.medium
        topRightRadius: Tokens.rounding.medium
        bottomLeftRadius: Tokens.rounding.medium
        bottomRightRadius: Tokens.rounding.medium

        implicitWidth: testWindowBtn.implicitWidth + Tokens.padding.extraSmall * 2
        implicitHeight: testWindowBtn.implicitHeight + Tokens.padding.extraSmall
    }

    // BlobRect only seems to drive the notch math against the other blob --
    // its own corners don't render rounded when viewed on its own, so a
    // plain rounded rect gives the button its actual visible (rounded)
    // shape, matching testWindowBtnRect's geometry exactly.
    StyledRect {
        anchors.fill: testWindowBtnRect
        radius: Tokens.rounding.medium
        color: Colours.palette.m3surfaceContainerLow // same frame colour as testBlobGroup above, kept in sync manually
    }

    IconButton {
        id: testWindowBtn

        anchors.centerIn: testWindowBtnRect

        icon: "close"
        type: IconButton.Text
        font: Tokens.font.icon.small
        label.fill: 0
        inactiveOnColour: hovered ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
        stateLayer.opacity: 0
        onClicked: root.close()

        label.scale: pressed ? 0.8 : 1
        label.renderType: Text.QtRendering

        Behavior on label.scale {
            Anim {}
        }
    }

    /* Real content, disabled -- rebuilding it piece by piece on top of the
       validated rig above instead of merging it all back in one go.

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.large

        Row {
            id: tabsRow

            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: root.tabs

                ButtonBase {
                    id: tabBtn

                    required property var modelData
                    required property int index

                    implicitWidth: 96
                    implicitHeight: 64
                    radiusMorph: false
                    defaultRadius: Tokens.rounding.large
                    checkedRadius: Tokens.rounding.large

                    checked: root.tabIndex === index
                    activeColour: Colours.tPalette.m3primaryContainer
                    inactiveColour: "#19181C"
                    activeOnColour: Colours.palette.m3onPrimaryContainer
                    inactiveOnColour: Colours.palette.m3onSurfaceVariant

                    onClicked: root.tabIndex = index

                    Column {
                        id: tabContent

                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small / 2

                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tabBtn.modelData.icon
                            fill: tabBtn.internalChecked ? 1 : 0
                            color: tabBtn.onColour
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tabBtn.modelData.label
                            font: Tokens.font.body.small
                            color: tabBtn.onColour
                        }
                    }
                }
            }
        }

        Item {
            id: contentPanel

            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledRect {
                anchors.fill: parent
                radius: Tokens.rounding.large
                color: "#19181C"
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.large

                StyledText {
                    Layout.fillWidth: true
                    text: root.tabs[root.tabIndex].label
                    font: Tokens.font.title.large
                    elide: Text.ElideRight
                }

                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    sourceComponent: {
                        const tab = root.tabs[root.tabIndex];
                        if (tab.wip)
                            return wipComp;
                        return root.tabIndex === 0 ? lightsComp : eqComp;
                    }

                    Component {
                        id: lightsComp

                        KrakenLightsTab {}
                    }

                    Component {
                        id: eqComp

                        KrakenEqTab {}
                    }

                    Component {
                        id: wipComp

                        KrakenWipTab {
                            label: root.tabs[root.tabIndex].label
                        }
                    }
                }
            }
        }
    }
    */
}
