import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "."

PopoutComponent {
    id: root
    required property var service

    property bool showDetails: false
    property var doctorResult: null

    headerText: "Hermes Agent"
    detailsText: {
        const agent = root.service?.status?.agent;
        if (!agent) return "Dank Hermes Shell";
        const bits = [];
        if (agent.provider) bits.push(agent.provider);
        if (agent.model) bits.push(agent.model);
        return bits.join("  ·  ");
    }
    showCloseButton: true

    function refreshAll() {
        if (!root.service) return;
        root.service.refresh();
        root.service.refreshUsage();
    }

    ScrollView {
        width: parent.width
        height: 750
        clip: true
        contentWidth: availableWidth

        Column {
            // gutter on the right so an overlay scrollbar never covers the buttons,
            // and an even inset on both sides so cards never sit on the panel edge
            x: Theme.spacingL
            width: parent.width - Theme.spacingL - Theme.spacingXL
            spacing: Theme.spacingL

            // top breathing room under the popout header
            Item {
                width: 1
                height: Theme.spacingM
            }

            // ---- service unavailable ----------------------------------
            StyledText {
                width: parent.width
                visible: !root.service
                text: "Hermes service is not running. Enable the Dank Hermes Shell daemon component for this plugin."
                wrapMode: Text.WordWrap
                color: Theme.error
            }

            // ---- error banner -----------------------------------------
            Column {
                width: parent.width
                spacing: Theme.spacingXS
                visible: !!root.service?.error

                StyledText {
                    width: parent.width
                    text: root.service?.error ?? ""
                    wrapMode: Text.WordWrap
                    color: Theme.error
                    textFormat: Text.PlainText
                }

                Row {
                    spacing: Theme.spacingS

                    DankButton {
                        text: "Retry"
                        iconName: "refresh"
                        onClicked: root.refreshAll()
                    }

                    DankButton {
                        text: root.showDetails ? "Hide doctor" : "Run doctor"
                        onClicked: {
                            if (root.showDetails) {
                                root.showDetails = false;
                                return;
                            }
                            root.service.doctor((ok, res) => {
                                root.doctorResult = res;
                                root.showDetails = true;
                            });
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    visible: root.showDetails
                    text: {
                        const checks = root.doctorResult?.checks ?? [];
                        if (checks.length === 0) return "No doctor output yet.";
                        return checks.map(c => (c.ok ? "[ok] " : "[fail] ") + c.name + (c.ok ? "" : " — " + c.detail)).join("\n");
                    }
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            // ---- status / ask / usage ---------------------------------
            HermesStatusCard {
                width: parent.width
                service: root.service
            }

            HermesAskCard {
                width: parent.width
                service: root.service
            }

            HermesUsageCard {
                width: parent.width
                service: root.service
            }

            // ---- sessions ---------------------------------------------
            Column {
                width: parent.width
                spacing: Theme.spacingS

                Item {
                    width: parent.width
                    height: Math.max(sessionsTitle.implicitHeight, headerButtons.implicitHeight)

                    StyledText {
                        id: sessionsTitle
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Recent sessions"
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                        color: Theme.surfaceText
                    }

                    Row {
                        id: headerButtons
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankButton {
                            text: "New"
                            iconName: "add"
                            enabled: !!root.service
                            onClicked: root.service.openTui("", "")
                        }

                        DankButton {
                            text: "Refresh"
                            iconName: "refresh"
                            enabled: !!root.service
                            onClicked: root.refreshAll()
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    visible: !!root.service && (root.service.sessions?.length ?? 0) === 0
                    text: "No sessions yet."
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: root.service?.sessions ?? []

                    delegate: HermesSessionRow {
                        required property var modelData
                        width: parent.width
                        session: modelData
                        active: modelData.active === true
                        onOpenRequested: id => root.service?.openTui(id, "")
                    }
                }
            }

            // breathing room so the last card never sits flush on the panel edge
            Item {
                width: 1
                height: Theme.spacingL
            }
        }
    }

    Component.onCompleted: {
        if (root.service) {
            root.service.refresh();
            if (!root.service.usage) root.service.refreshUsage();
        }
    }
}
