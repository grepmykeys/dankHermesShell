import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root
    required property var service

    readonly property var usage: service?.usage ?? null
    readonly property var series: usage?.series ?? []
    readonly property int peak: {
        let max = 0;
        for (let i = 0; i < series.length; i++) max = Math.max(max, series[i].tokens ?? 0);
        return max;
    }

    function fmtTokens(n) {
        const v = Number(n ?? 0);
        if (v >= 1000000) return (v / 1000000).toFixed(1) + "M";
        if (v >= 10000) return Math.round(v / 1000) + "k";
        if (v >= 1000) return (v / 1000).toFixed(1) + "k";
        return String(v);
    }

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

        StyledText {
            text: "Usage (session totals by last activity)"
            font.pixelSize: Theme.fontSizeLarge
            font.bold: true
            color: Theme.surfaceText
        }

        Flow {
            width: parent.width
            spacing: Theme.spacingL

            Column {
                spacing: 2
                StyledText { text: "Today"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                StyledText {
                    text: root.usage ? (root.usage.pretty.today + " · " + root.usage.pretty.todayCost) : "—"
                    color: Theme.surfaceText
                    font.bold: true
                }
            }

            Column {
                spacing: 2
                StyledText { text: "7 days"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                StyledText {
                    text: root.usage ? (root.usage.pretty.week + " · " + root.usage.pretty.weekCost) : "—"
                    color: Theme.surfaceText
                    font.bold: true
                }
            }

            Column {
                spacing: 2
                StyledText { text: "All time"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                StyledText {
                    text: root.usage ? (root.usage.pretty.allTime + " · " + root.usage.pretty.allTimeCost) : "—"
                    color: Theme.surfaceText
                    font.bold: true
                }
            }

            Column {
                spacing: 2
                StyledText { text: "API calls (today)"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                StyledText {
                    text: root.usage ? String(root.usage.today.calls) : "—"
                    color: Theme.surfaceText
                    font.bold: true
                }
            }
        }

        // 7-day sparkline: one narrow bar per day, height proportional to tokens
        Row {
            id: chart
            width: parent.width
            height: 46
            spacing: 4
            visible: root.series.length > 0

            Repeater {
                model: root.series
                delegate: Column {
                    required property var modelData
                    width: Math.max(12, (chart.width - (root.series.length - 1) * 4) / Math.max(1, root.series.length))
                    spacing: 2

                    Item {
                        width: parent.width
                        height: 30

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(18, parent.width)
                            radius: 3
                            height: {
                                if (root.peak <= 0) return 2;
                                const ratio = (modelData.tokens ?? 0) / root.peak;
                                return Math.max(2, Math.round(ratio * 30));
                            }
                            color: (modelData.tokens ?? 0) > 0 ? Theme.primary : Theme.outline
                        }
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label ?? ""
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }
        }

        StyledText {
            width: parent.width
            visible: !root.usage
            text: "Loading usage…"
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
        }

        // per-model breakdown for the current week
        Column {
            width: parent.width
            spacing: 2
            visible: (root.usage?.byModel?.length ?? 0) > 0

            Repeater {
                model: root.usage?.byModel ?? []
                delegate: Row {
                    required property var modelData
                    id: modelRow
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        width: Math.max(0, modelRow.width - weekTokens.implicitWidth
                            - modelCost.implicitWidth - modelRow.spacing * 2)
                        text: modelData.model
                        elide: Text.ElideMiddle
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        textFormat: Text.PlainText
                    }

                    StyledText {
                        id: weekTokens
                        text: root.fmtTokens(modelData.weekTokens) + " this week"
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    StyledText {
                        id: modelCost
                        text: "$" + (modelData.cost ?? 0).toFixed(2)
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }
        }
    }
}
