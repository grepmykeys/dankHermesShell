import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankHermesShell"

    StyledText {
        width: parent.width
        text: "Hermes Agent"
        font.pixelSize: Theme.fontSizeLarge
        font.bold: true
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Dank Hermes Shell reads Hermes' own state (gateway, sessions, token usage) read-only and launches "
            + "the Hermes TUI in your terminal. Nothing is written to ~/.hermes."
        wrapMode: Text.WordWrap
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    SelectionSetting {
        settingKey: "pillText"
        label: "Bar label"
        description: "What the bar pill shows next to the Hermes icon"
        options: [
            { label: "Auto (working state, else live sessions)", value: "auto" },
            { label: "Today's tokens", value: "tokens" },
            { label: "Session count", value: "sessions" },
            { label: "Model name", value: "model" },
            { label: "Icon only", value: "none" }
        ]
        defaultValue: "auto"
    }

    SliderSetting {
        settingKey: "refreshSeconds"
        label: "Status refresh"
        description: "How often gateway status and the session list are re-read"
        defaultValue: 10
        minimum: 2
        maximum: 120
        unit: "s"
    }

    SliderSetting {
        settingKey: "usageSeconds"
        label: "Usage refresh"
        description: "How often token and cost totals are re-read"
        defaultValue: 300
        minimum: 30
        maximum: 3600
        unit: "s"
    }

    SliderSetting {
        settingKey: "sessionsLimit"
        label: "Sessions shown"
        description: "How many recent sessions to list in the popout"
        defaultValue: 15
        minimum: 3
        maximum: 50
    }

    ToggleSetting {
        settingKey: "notifyOnAnswer"
        label: "Notify when a background query finishes"
        description: "Show a DMS notification with the last line of the answer"
        defaultValue: true
    }

    StringSetting {
        settingKey: "terminalCommand"
        label: "Terminal command"
        description: "Leave empty to auto-detect (kitty, ghostty, alacritty, foot, wezterm, konsole)"
        placeholder: "kitty -e"
        defaultValue: ""
    }

    StyledText {
        width: parent.width
        text: "Install check"
        font.pixelSize: Theme.fontSizeLarge
        font.bold: true
        color: Theme.surfaceText
        topPadding: Theme.spacingL
    }

    StyledText {
        width: parent.width
        text: "Run  bin/dank-hermes-shell doctor  in the plugin directory to check the Hermes executable, "
            + "state.db readability and terminal detection."
        wrapMode: Text.WordWrap
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }
}
