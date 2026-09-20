import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "components"

/**
 * DankHermes bar widget.
 *
 * Reads the shared HermesService published by the daemon surface, so every
 * bar and dock instance renders from one poller.
 */
PluginComponent {
    id: root

    readonly property var service: pluginService ? pluginService.getGlobalVar(pluginId, "service", null) : null

    readonly property string pillMode: String(pluginData?.pillText ?? "auto")

    readonly property string pillLabel: {
        const svc = root.service;
        if (!svc) return "";
        if (root.pillMode === "none") return "";
        if (root.pillMode === "model") return svc.modelLabel.replace(/^.*\//, "");
        if (root.pillMode === "tokens") return svc.todayTokens;
        if (root.pillMode === "sessions") return String(svc.sessions?.length ?? 0);
        // auto: live work beats a static count
        if (svc.agentActive) return svc.todayTokens;
        if (svc.liveCount > 0) return String(svc.liveCount);
        return "";
    }

    readonly property color pillColor: {
        const svc = root.service;
        if (!svc || !svc.status) return Theme.surfaceVariantText;
        if (svc.status.gateway?.running !== true) return Theme.error;
        if (svc.agentActive) return Theme.primary;
        return Theme.surfaceText;
    }

    readonly property string pillTooltip: {
        const svc = root.service;
        if (!svc || !svc.status) return "Hermes: starting…";
        const lines = [];
        lines.push(svc.status.gateway?.running ? "Gateway running" : "Gateway stopped");
        if (svc.modelLabel) lines.push(svc.modelLabel);
        lines.push("Today: " + svc.todayTokens + " · " + svc.todayCost);
        if (svc.agentActive) lines.push("Recently active");
        return lines.join("\n");
    }

    popoutWidth: 700
    popoutHeight: 860

    horizontalBarPill: Component {
        StyledRect {
            width: pillRow.implicitWidth + Theme.spacingM * 2
            height: parent.widgetThickness
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: "smart_toy"
                    size: root.iconSize
                    color: root.pillColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    visible: root.pillLabel.length > 0
                    text: root.pillLabel
                    color: root.pillColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    verticalBarPill: Component {
        StyledRect {
            width: parent.widgetThickness
            height: pillColumn.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            Column {
                id: pillColumn
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: "smart_toy"
                    size: root.iconSize
                    color: root.pillColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    visible: root.pillLabel.length > 0
                    text: root.pillLabel
                    color: root.pillColor
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    popoutContent: Component {
        HermesPopout {
            service: root.service
        }
    }

    // right-click: open a fresh Hermes TUI session
    pillRightClickAction: () => root.service?.openTui("", "")
}
