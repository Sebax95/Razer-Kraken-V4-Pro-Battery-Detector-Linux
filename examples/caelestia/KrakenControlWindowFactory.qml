pragma Singleton

import QtQuick
import QtQuick.Effects
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.bar.popouts

Singleton {
    id: root

    function create(): void {
        comp.createObject(dummy);
    }

    QtObject {
        id: dummy
    }

    Component {
        id: comp

        FloatingWindow {
            id: win

            color: Colours.palette.m3surface
            surfaceFormat.opaque: false

            onVisibleChanged: {
                if (!visible)
                    destroy();
            }

            implicitWidth: 640
            implicitHeight: 680
            minimumSize.width: 540
            minimumSize.height: 540

            contentItem.Config.screen: screen.name
            contentItem.Tokens.screen: screen.name

            title: qsTr("Razer Kraken V4 Pro")

            /* Corner patch from the Blob-notch experiment, disabled while we
               test the base layering with a minimal blue/red rig.
            StyledRect {
                anchors.top: parent.top
                anchors.right: parent.right
                implicitWidth: 180
                implicitHeight: 85
                topRightRadius: 10
                color: "#27252A"
            }
            */

            Item {
                anchors.fill: parent
                opacity: 0

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    blurMax: 24
                    shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.6)
                }

                Component.onCompleted: Qt.callLater(() => opacity = 1)

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                KrakenControlWindow {
                    anchors.fill: parent
                    onClose: win.destroy()
                }
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
