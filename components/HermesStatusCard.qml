import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root
    required property var service

    readonly property var status: service?.status ?? null
    readonly property bool running: status?.gateway?.running === true
    readonly property bool active: status?.agent?.active === true

    implicitHeight: body.implicitHeight + Theme.spacingL * 2
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh

    Column {
        id: body
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Theme.spacingL
        }
        spacing: Theme.spacingS

        Row {
            spacing: Theme.spacingS

            Rectangle {
                width: 10
                height: 10
                radius: 5
                anchors.verticalCenter: parent.verticalCenter
                color: !root.status ? Theme.outline
                     : root.active ? Theme.success
                     : root.running ? Theme.primary
                     : Theme.error
            }

            StyledText {
                text: !root.status ? "Starting…"
                    : root.active ? "Recently active"
                    : root.running ? "Gateway running"
                    : "Gateway stopped"
                font.bold: true
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: 8; height: 1 }

            StyledText {
                visible: !!root.status?.gateway?.pid
                text: "pid " + (root.status?.gateway?.pid ?? "")
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: !!root.status?.gateway?.version
                text: "v" + (root.status?.gateway?.version ?? "")
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        StyledText {
            width: parent.width
            visible: !!root.status?.agent?.reasoning
            text: root.status?.agent?.reasoning ? ("reasoning: " + root.status.agent.reasoning) : ""
            wrapMode: Text.WordWrap
            color: Theme.surfaceVariantText
            textFormat: Text.PlainText
        }

        StyledText {
            width: parent.width
            visible: (root.status?.gateway?.connectedPlatforms?.length ?? 0) > 0
            text: "Platforms: " + (root.status?.gateway?.connectedPlatforms ?? []).join(", ")
                + ((root.status?.liveSessions?.length ?? 0) > 0 ? "   ·   Live: " + root.status.liveSessions.length : "")
            wrapMode: Text.WordWrap
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
            textFormat: Text.PlainText
        }

        StyledText {
            width: parent.width
            visible: root.status?.agent?.active === true
            text: "Session activity recorded within the last five minutes."
            color: Theme.primary
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }
    }
}
