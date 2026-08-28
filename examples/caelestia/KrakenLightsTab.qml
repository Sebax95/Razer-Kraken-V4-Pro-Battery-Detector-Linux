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

    property color pendingColour: KrakenRGB.current

    // Picking on the wheel breaks the initial binding above (it's a plain
    // property, not read-only) -- resync whenever the real current color
    // changes for any reason (preset click, restore, an external CLI call),
    // so the preview doesn't get stuck showing a stale unapplied pick.
    Connections {
        target: KrakenRGB

        function onCurrentChanged(): void {
            root.pendingColour = KrakenRGB.current;
        }
    }

    readonly property var swatches: [
        { r: 255, g: 0, b: 0 },
        { r: 255, g: 165, b: 0 },
        { r: 255, g: 255, b: 0 },
        { r: 0, g: 255, b: 0 },
        { r: 0, g: 255, b: 255 },
        { r: 0, g: 0, b: 255 },
        { r: 255, g: 0, b: 255 },
        { r: 128, g: 0, b: 255 },
        { r: 255, g: 105, b: 180 },
        { r: 255, g: 255, b: 255 },
    ]

    readonly property var effects: [
        { icon: "waves", label: qsTr("Breathing") },
        { icon: "cyclone", label: qsTr("Colour cycle") },
    ]

    function hsvToRgb(h, s, v) {
        const c = v * s;
        const x = c * (1 - Math.abs((h / 60) % 2 - 1));
        const m = v - c;
        let rp = 0, gp = 0, bp = 0;
        if (h < 60) { rp = c; gp = x; bp = 0; }
        else if (h < 120) { rp = x; gp = c; bp = 0; }
        else if (h < 180) { rp = 0; gp = c; bp = x; }
        else if (h < 240) { rp = 0; gp = x; bp = c; }
        else if (h < 300) { rp = x; gp = 0; bp = c; }
        else { rp = c; gp = 0; bp = x; }
        return [Math.round((rp + m) * 255), Math.round((gp + m) * 255), Math.round((bp + m) * 255)];
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.large

        ToggleRow {
            Layout.fillWidth: true
            first: true
            last: false
            verticalPadding: Tokens.padding.large
            horizontalPadding: Tokens.padding.large + Tokens.padding.small // match the SectionHeaders' left inset (card margin + their own leftMargin)
            text: qsTr("Lights")
            checked: KrakenRGB.on
            onToggled: KrakenRGB.toggle()
        }

        ConnectedRect {
            id: presetsCard

            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            implicitHeight: presetsLayout.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: presetsLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                SectionHeader {
                    Layout.fillWidth: true
                    first: true
                    text: qsTr("Presets")
                }

                Item {
                    Layout.fillWidth: true
                    Layout.leftMargin: Tokens.padding.large
                    Layout.preferredHeight: 50

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Tokens.spacing.medium

                        Repeater {
                            model: root.swatches

                            StyledRect {
                                id: swatch

                                required property var modelData

                                readonly property color swatchColour: Qt.rgba(swatch.modelData.r / 255, swatch.modelData.g / 255, swatch.modelData.b / 255, 1)
                                readonly property bool active: KrakenRGB.on && KrakenRGB.current === swatch.swatchColour

                                anchors.verticalCenter: parent.verticalCenter
                                implicitWidth: 34
                                implicitHeight: 34
                                radius: Tokens.rounding.full
                                color: swatch.swatchColour
                                border.width: swatch.active ? 2 : 1
                                border.color: swatch.active ? Colours.palette.m3primary : Colours.tPalette.m3outline

                                Behavior on border.color {
                                    CAnim {}
                                }

                                StateLayer {
                                    onClicked: {
                                        KrakenRGB.setColor(swatch.modelData.r, swatch.modelData.g, swatch.modelData.b);
                                        root.pendingColour = swatch.swatchColour;
                                    }
                                }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    visible: swatch.active
                                    fontStyle: Tokens.font.icon.small
                                    text: "check"
                                    fill: 1
                                    color: swatch.modelData.r + swatch.modelData.g + swatch.modelData.b > 400 ? "black" : "white"
                                }
                            }
                        }
                    }
                }
            }
        }

        ConnectedRect {
            id: customColourCard

            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            implicitHeight: customColourLayout.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: customColourLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                SectionHeader {
                    Layout.fillWidth: true
                    first: true
                    text: qsTr("Custom colour")
                }

                Item {
                    Layout.fillWidth: true
                    Layout.leftMargin: Tokens.padding.large
                    Layout.preferredHeight: 110

                    RowLayout {
                        anchors.fill: parent
                        spacing: Tokens.spacing.large

                        Canvas {
                            id: wheel

                            Layout.preferredWidth: 110
                            Layout.preferredHeight: 110
                            Layout.alignment: Qt.AlignVCenter

                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            Component.onCompleted: requestPaint()

                            onPaint: {
                                if (width <= 0 || height <= 0)
                                    return;

                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);

                                const cx = width / 2, cy = height / 2, r = width / 2;
                                const steps = 120;
                                const stepAngle = 360 / steps;

                                for (let i = 0; i < steps; i++) {
                                    const hue = i * stepAngle;
                                    const startAngle = (hue - stepAngle / 2 - 1) * Math.PI / 180;
                                    const endAngle = (hue + stepAngle / 2 + 1) * Math.PI / 180;

                                    const gradient = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
                                    const centreRgb = root.hsvToRgb(hue, 0, 1);
                                    const edgeRgb = root.hsvToRgb(hue, 1, 1);
                                    gradient.addColorStop(0, `rgb(${centreRgb[0]},${centreRgb[1]},${centreRgb[2]})`);
                                    gradient.addColorStop(1, `rgb(${edgeRgb[0]},${edgeRgb[1]},${edgeRgb[2]})`);

                                    ctx.beginPath();
                                    ctx.moveTo(cx, cy);
                                    ctx.arc(cx, cy, r, startAngle, endAngle);
                                    ctx.closePath();
                                    ctx.fillStyle = gradient;
                                    ctx.fill();
                                }
                            }

                            function pick(px, py) {
                                const dx = px - width / 2, dy = py - height / 2;
                                const dist = Math.min(Math.sqrt(dx * dx + dy * dy), width / 2);
                                let angle = Math.atan2(dy, dx) * 180 / Math.PI;
                                if (angle < 0)
                                    angle += 360;
                                const s = dist / (width / 2);
                                const rgb = root.hsvToRgb(angle, s, 1);
                                root.pendingColour = Qt.rgba(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1);
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => wheel.pick(mouse.x, mouse.y)
                                onPositionChanged: mouse => {
                                    if (pressed)
                                        wheel.pick(mouse.x, mouse.y);
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: Tokens.spacing.medium

                            RowLayout {
                                spacing: Tokens.spacing.medium

                                StyledRect {
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    radius: Tokens.rounding.medium
                                    color: root.pendingColour
                                    border.width: 1
                                    border.color: Colours.tPalette.m3outline

                                    Behavior on color {
                                        CAnim {}
                                    }
                                }

                                IconTextButton {
                                    icon: "check"
                                    text: qsTr("Apply")
                                    type: IconTextButton.Filled

                                    onClicked: {
                                        const r = Math.round(root.pendingColour.r * 255);
                                        const g = Math.round(root.pendingColour.g * 255);
                                        const b = Math.round(root.pendingColour.b * 255);
                                        KrakenRGB.setColor(r, g, b);
                                    }
                                }
                            }

                            StyledText {
                                text: qsTr("Pick a colour on the wheel, then Apply")
                                color: Colours.palette.m3outline
                                font: Tokens.font.label.small
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }

        ConnectedRect {
            id: effectsCard

            last: true
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            implicitHeight: effectsLayout.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: effectsLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                SectionHeader {
                    Layout.fillWidth: true
                    first: true
                    text: qsTr("Effects")
                }

                Item {
                    Layout.fillWidth: true
                    Layout.leftMargin: Tokens.padding.large
                    Layout.preferredHeight: 32

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Tokens.spacing.small

                        Repeater {
                            model: root.effects

                            StyledRect {
                                id: fxChip

                                required property var modelData

                                anchors.verticalCenter: parent.verticalCenter
                                implicitWidth: fxRow.implicitWidth + Tokens.padding.medium * 2
                                implicitHeight: 32
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3secondaryContainer // button colour (unselected EQ preset, effects chips, unselected tabs)
                                opacity: 0.55

                                RowLayout {
                                    id: fxRow

                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing.small / 2

                                    MaterialIcon {
                                        fontStyle: Tokens.font.icon.small
                                        text: fxChip.modelData.icon
                                        color: Colours.palette.m3onSurfaceVariant
                                    }

                                    StyledText {
                                        text: fxChip.modelData.label
                                        font: Tokens.font.body.small
                                        color: Colours.palette.m3onSurfaceVariant
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
