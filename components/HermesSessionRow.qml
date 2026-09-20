import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root
    required property var session
    property bool active: false
    signal openRequested(string sessionId)

    height: rowContent.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: hoverArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
    border.width: root.active ? 1 : 0
    border.color: Theme.primary

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openRequested(root.session?.id ?? "")
    }

    Row {
        id: rowContent
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Theme.spacingM
        }
        spacing: Theme.spacingS

        DankIcon {
            id: sessionIcon
            name: root.active ? "bolt" : "history"
            size: root.active ? 20 : 18
            color: root.active ? Theme.primary : Theme.surfaceVariantText
            anchors.top: parent.top
            anchors.topMargin: 2
        }

        Column {
            width: Math.max(0, rowContent.width - sessionIcon.width
                - metrics.width - rowContent.spacing * 2)
            spacing: 2

            StyledText {
                width: parent.width
                text: root.session?.label ?? ""
                elide: Text.ElideRight
                color: Theme.surfaceText
                textFormat: Text.PlainText
            }

            StyledText {
                width: parent.width
                text: {
                    const s = root.session ?? {};
                    const bits = [];
                    if (s.ago) bits.push(s.ago);
                    if (s.model) bits.push(s.model);
                    if (s.profile && s.profile !== "default") bits.push(s.profile);
                    if (s.gitBranch) bits.push(s.gitBranch);
                    if (s.toolCalls) bits.push(s.toolCalls + " tools");
                    return bits.join("  ·  ");
                }
                elide: Text.ElideRight
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                textFormat: Text.PlainText
            }

            StyledText {
                width: parent.width
                visible: !!root.session?.lastActivity
                text: root.session?.lastActivity ?? ""
                elide: Text.ElideRight
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                textFormat: Text.PlainText
            }
        }

        Column {
            id: metrics
            width: Math.max(tokenCount.implicitWidth, sessionCost.implicitWidth,
                openLabel.implicitWidth)
            spacing: 2

            StyledText {
                id: tokenCount
                width: parent.width
                text: root.session?.tokensPretty ?? ""
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignRight
            }

            StyledText {
                id: sessionCost
                width: parent.width
                text: root.session?.costPretty ?? ""
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignRight
            }

            StyledText {
                id: openLabel
                width: parent.width
                text: "open"
                color: Theme.primary
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
