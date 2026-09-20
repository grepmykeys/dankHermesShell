import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root
    required property var service

    property bool showFullAnswer: false
    readonly property string answer: service?.answerText ?? ""
    readonly property bool waiting: service?.answerRunning === true || service?.watching === true

    implicitHeight: body.implicitHeight + Theme.spacingL * 2
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh

    function send() {
        const text = promptField.text.trim();
        if (text.length === 0) return;
        root.service.ask(text);
        promptField.text = "";
        root.showFullAnswer = false;
    }

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
            text: "Ask Hermes"
            font.pixelSize: Theme.fontSizeLarge
            font.bold: true
            color: Theme.surfaceText
        }

        DankTextField {
            id: promptField
            width: parent.width
            labelText: "One-shot query (answers in the background)"
            placeholderText: "Summarize today's git activity…"
            maximumLength: 4000
        }

        Row {
            spacing: Theme.spacingS

            DankButton {
                text: root.waiting ? "Working…" : "Ask"
                iconName: "send"
                enabled: !root.waiting && (promptField.text ?? "").trim().length > 0 && !!root.service
                onClicked: root.send()
            }

            DankButton {
                text: "Open TUI"
                iconName: "terminal"
                enabled: !!root.service
                onClicked: root.service.openTui("", promptField.text)
            }

            DankButton {
                text: "Answer file"
                visible: root.answer.length > 0
                enabled: !!root.service
                onClicked: root.service.openAnswerFile()
            }
        }

        StyledText {
            width: parent.width
            visible: root.waiting
            text: "Waiting for Hermes to finish…"
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
        }

        StyledText {
            width: parent.width
            visible: root.answer.length > 0 && !root.waiting
            text: {
                const text = root.answer.trim();
                if (root.showFullAnswer || text.length <= 400) return text;
                return text.slice(0, 400) + "…";
            }
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            color: Theme.surfaceText
            maximumLineCount: root.showFullAnswer ? -1 : 14
            elide: Text.ElideRight
        }

        Row {
            spacing: Theme.spacingS
            visible: root.answer.trim().length > 400

            DankButton {
                text: root.showFullAnswer ? "Show less" : "Show all"
                onClicked: root.showFullAnswer = !root.showFullAnswer
            }

            StyledText {
                visible: !!root.service?.answerAgo
                text: root.service?.answerAgo ?? ""
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
