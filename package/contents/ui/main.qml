import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    property var usageWindows: []
    property double fetchedAt: 0
    property string planType: ""
    property string creditBalance: "0"
    property int resetCredits: 0
    property string accountStatus: i18n("Usage available")
    property string accountState: "loading"
    property string stateMessage: ""
    property string errorMessage: ""
    property string activeOperation: ""
    property bool loading: false
    property bool hasData: usageWindows.length > 0
    readonly property int compactWindowLimit: 2
    readonly property int refreshMinutes: Math.max(1, Math.min(1440,
        Number(Plasmoid.configuration.refreshIntervalMinutes) || 5))
    property date currentTime: new Date()

    readonly property string appearance: ["auto", "dark", "light"].indexOf(Plasmoid.configuration.appearance) >= 0
        ? Plasmoid.configuration.appearance : "auto"
    readonly property bool forcedAppearance: appearance !== "auto"
    readonly property bool darkAppearance: appearance === "dark" || (appearance === "auto"
        && (systemTheme.Kirigami.Theme.backgroundColor.r * 0.299
            + systemTheme.Kirigami.Theme.backgroundColor.g * 0.587
            + systemTheme.Kirigami.Theme.backgroundColor.b * 0.114) < 0.5)

    Item {
        id: systemTheme
        Kirigami.Theme.inherit: false
        Kirigami.Theme.colorSet: Kirigami.Theme.Window
    }

    Kirigami.Theme.inherit: false
    Kirigami.Theme.backgroundColor: forcedAppearance
        ? (darkAppearance ? "#232629" : "#fafafa") : systemTheme.Kirigami.Theme.backgroundColor
    Kirigami.Theme.textColor: forcedAppearance
        ? (darkAppearance ? "#eff0f1" : "#232629") : systemTheme.Kirigami.Theme.textColor
    Kirigami.Theme.disabledTextColor: forcedAppearance
        ? (darkAppearance ? "#b0b7be" : "#5c636a") : systemTheme.Kirigami.Theme.disabledTextColor
    Kirigami.Theme.linkColor: forcedAppearance
        ? (darkAppearance ? "#70b9f0" : "#1769a6") : systemTheme.Kirigami.Theme.linkColor
    Kirigami.Theme.positiveTextColor: forcedAppearance
        ? (darkAppearance ? "#7dcea0" : "#237a46") : systemTheme.Kirigami.Theme.positiveTextColor
    Kirigami.Theme.neutralTextColor: forcedAppearance
        ? (darkAppearance ? "#f0bf63" : "#875800") : systemTheme.Kirigami.Theme.neutralTextColor
    Kirigami.Theme.negativeTextColor: forcedAppearance
        ? (darkAppearance ? "#ff8a86" : "#b3261e") : systemTheme.Kirigami.Theme.negativeTextColor

    readonly property string scriptPath: decodeURIComponent(
        Qt.resolvedUrl("../code/fetch_usage.py").toString().replace("file://", ""))

    Plasmoid.icon: "view-statistics"
    Plasmoid.status: errorMessage.length > 0 || accountState === "auth_required"
        || accountState === "codex_missing" || accountState === "unsupported_auth"
        ? PlasmaCore.Types.NeedsAttentionStatus
        : PlasmaCore.Types.ActiveStatus

    toolTipMainText: i18n("Codex Usage")
    toolTipSubText: tooltipDetails()

    preferredRepresentation: compactRepresentation

    function percentText(value) {
        return value < 0 ? "\u2014" : value + "%"
    }

    function friendlyDateTime(epochSeconds) {
        const date = new Date(epochSeconds * 1000)
        const today = new Date(currentTime)
        const tomorrow = new Date(today)
        tomorrow.setDate(today.getDate() + 1)
        const time = Qt.formatTime(date, Qt.locale().timeFormat(Locale.ShortFormat))
        if (date.toDateString() === today.toDateString())
            return i18n("Today at %1", time)
        if (date.toDateString() === tomorrow.toDateString())
            return i18n("Tomorrow at %1", time)
        return i18n("%1 at %2", Qt.formatDate(date, Qt.locale().dateFormat(Locale.LongFormat)), time)
    }

    function resetText(epochSeconds) {
        return epochSeconds ? friendlyDateTime(epochSeconds) : i18n("Unavailable")
    }

    function updatedText() {
        return fetchedAt ? friendlyDateTime(fetchedAt) : i18n("Not updated yet")
    }

    function windowIcon(minutes) {
        return Number(minutes) >= 1440 ? "view-calendar" : "clock"
    }

    function planText() {
        if (!planType)
            return i18n("Unknown")
        return planType.charAt(0).toUpperCase() + planType.slice(1)
    }

    function usageColor(value, minutes) {
        if (value < 0)
            return Kirigami.Theme.disabledTextColor
        if (value <= 20)
            return Kirigami.Theme.negativeTextColor
        if (value <= 50)
            return Kirigami.Theme.neutralTextColor
        return Number(minutes) >= 1440
            ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.linkColor
    }

    function durationShort(minutes) {
        const value = Number(minutes)
        if (!isFinite(value) || value <= 0)
            return i18n("Window")
        if (value % 10080 === 0)
            return i18n("%1w", value / 10080)
        if (value % 1440 === 0)
            return i18n("%1d", value / 1440)
        if (value % 60 === 0)
            return i18n("%1h", value / 60)
        return i18n("%1m", value)
    }

    function durationLong(minutes) {
        const value = Number(minutes)
        if (!isFinite(value) || value <= 0)
            return i18n("Usage window")
        if (value % 10080 === 0)
            return i18n("%1-week window", value / 10080)
        if (value % 1440 === 0)
            return i18n("%1-day window", value / 1440)
        if (value % 60 === 0)
            return i18n("%1-hour window", value / 60)
        return i18n("%1-minute window", value)
    }

    function windowTitle(window) {
        const duration = durationLong(window.windowDurationMins)
        return window.limitName ? i18n("%1 · %2", window.limitName, duration) : duration
    }

    function compactWindows() {
        return usageWindows.slice(0, compactWindowLimit)
    }

    function tooltipDetails() {
        if (errorMessage.length > 0)
            return i18n("Unable to update: %1", errorMessage)
        if (!hasData) {
            if (loading)
                return activeOperation === "login" ? i18n("Waiting for ChatGPT sign-in…") : i18n("Updating usage…")
            return stateMessage.length > 0 ? stateMessage : i18n("Usage is not available yet")
        }
        const lines = []
        for (let index = 0; index < usageWindows.length; ++index) {
            const window = usageWindows[index]
            lines.push(i18n("%1: %2 remaining (resets %3)",
                            windowTitle(window), percentText(window.remainingPercent),
                            resetText(window.resetsAt || 0)))
        }
        lines.push(i18n("Plan: %1", planText()))
        lines.push(i18n("Additional credits: %1", creditBalance))
        lines.push(i18n("Reset credits: %1", resetCredits))
        lines.push(i18n("Status: %1", accountStatus))
        lines.push(i18n("Updated: %1", updatedText()))
        return lines.join("\n")
    }

    function shellQuote(value) {
        return "'" + value.replace(/'/g, "'\\''") + "'"
    }

    function refresh() {
        if (loading)
            return
        loading = true
        activeOperation = "usage"
        errorMessage = ""
        executable.connectSource("/usr/bin/python3 " + shellQuote(scriptPath) + " usage")
    }

    function signIn() {
        if (loading)
            return
        loading = true
        activeOperation = "login"
        errorMessage = ""
        stateMessage = i18n("Complete sign-in in the browser window")
        executable.connectSource("/usr/bin/python3 " + shellQuote(scriptPath) + " login")
    }

    function openInstallPage() {
        Qt.openUrlExternally("https://github.com/openai/codex")
    }

    function applyPayload(payload) {
        accountState = payload.state || (payload.ok ? "ready" : "error")
        stateMessage = payload.message || ""
        if (accountState === "login_complete") {
            Qt.callLater(refresh)
            return
        }
        if (!payload.ok) {
            if (accountState === "auth_required" || accountState === "unsupported_auth"
                    || accountState === "codex_missing") {
                usageWindows = []
                fetchedAt = 0
                planType = ""
                creditBalance = "0"
                resetCredits = 0
                accountStatus = i18n("Usage unavailable")
                errorMessage = ""
            }
            if (accountState === "error")
                errorMessage = payload.message || i18n("Unknown error")
            return
        }
        usageWindows = payload.windows || []
        fetchedAt = payload.fetchedAt || 0
        planType = payload.planType || ""
        creditBalance = payload.credits && payload.credits.unlimited
            ? i18n("Unlimited")
            : (payload.credits ? payload.credits.balance : "0")
        resetCredits = payload.resetCredits || 0
        accountStatus = payload.spendControlReached
            ? i18n("Spending control reached")
            : (payload.rateLimitReachedType ? i18n("Rate limit reached") : i18n("Usage available"))
        errorMessage = ""
    }

    Component.onCompleted: refresh()

    Timer {
        interval: root.refreshMinutes * 60 * 1000
        repeat: true
        running: true
        triggeredOnStart: false
        onTriggered: root.refresh()
    }

    Timer {
        interval: 60 * 1000
        repeat: true
        running: true
        onTriggered: root.currentTime = new Date()
    }

    onExpandedChanged: if (expanded) currentTime = new Date()

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            executable.disconnectSource(sourceName)
            root.loading = false
            root.activeOperation = ""
            const output = (data.stdout || "").trim()
            if (!output) {
                root.errorMessage = (data.stderr || "").trim() || i18n("No response from Codex")
                return
            }
            try {
                root.applyPayload(JSON.parse(output))
            } catch (error) {
                root.errorMessage = i18n("Invalid response from Codex")
            }
        }
    }

    compactRepresentation: MouseArea {
        Kirigami.Theme.inherit: false
        Kirigami.Theme.backgroundColor: root.Kirigami.Theme.backgroundColor
        Kirigami.Theme.textColor: root.Kirigami.Theme.textColor
        Kirigami.Theme.disabledTextColor: root.Kirigami.Theme.disabledTextColor
        Kirigami.Theme.linkColor: root.Kirigami.Theme.linkColor
        Kirigami.Theme.positiveTextColor: root.Kirigami.Theme.positiveTextColor
        Kirigami.Theme.neutralTextColor: root.Kirigami.Theme.neutralTextColor
        Kirigami.Theme.negativeTextColor: root.Kirigami.Theme.negativeTextColor

        id: compact
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        Layout.minimumWidth: compactRow.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.preferredWidth: Layout.minimumWidth
        Layout.minimumHeight: Math.max(compactRow.implicitHeight, Kirigami.Units.iconSizes.smallMedium)
        Layout.preferredHeight: Layout.minimumHeight
        implicitWidth: compactRow.implicitWidth + Kirigami.Units.smallSpacing * 2
        implicitHeight: Math.max(compactRow.implicitHeight, Kirigami.Units.iconSizes.smallMedium)

        Rectangle {
            anchors.fill: parent
            visible: root.forcedAppearance
            color: root.Kirigami.Theme.backgroundColor
            radius: Kirigami.Units.smallSpacing
        }

        RowLayout {
            id: compactRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: Qt.resolvedUrl("../images/chatgpt.png")
                Accessible.name: i18n("ChatGPT / Codex usage")
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                color: root.errorMessage.length > 0
                    ? Kirigami.Theme.negativeTextColor
                    : Kirigami.Theme.textColor
            }

            Repeater {
                model: root.compactWindows()

                RowLayout {
                    required property var modelData
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: root.windowIcon(modelData.windowDurationMins)
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small
                        color: root.usageColor(modelData.remainingPercent, modelData.windowDurationMins)
                    }

                    PlasmaComponents.Label {
                        text: root.durationShort(modelData.windowDurationMins)
                            + " " + root.percentText(modelData.remainingPercent)
                        color: root.usageColor(modelData.remainingPercent, modelData.windowDurationMins)
                        font.weight: Font.DemiBold
                    }
                }
            }

            PlasmaComponents.Label {
                visible: root.usageWindows.length > root.compactWindowLimit
                text: i18n("+%1", root.usageWindows.length - root.compactWindowLimit)
                color: Kirigami.Theme.disabledTextColor
                font.weight: Font.DemiBold
            }

            PlasmaComponents.Label {
                visible: !root.hasData
                text: {
                    if (root.loading)
                        return root.activeOperation === "login" ? i18n("Signing in…") : i18n("Updating…")
                    if (root.accountState === "auth_required")
                        return i18n("Sign in")
                    if (root.accountState === "codex_missing")
                        return i18n("Install Codex")
                    return i18n("Unavailable")
                }
                color: root.accountState === "ready"
                    ? Kirigami.Theme.textColor
                    : Kirigami.Theme.neutralTextColor
                font.weight: Font.DemiBold
            }

            PlasmaComponents.BusyIndicator {
                visible: root.loading
                running: visible
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
            }
        }
    }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 19
        Layout.preferredWidth: Kirigami.Units.gridUnit * 21
        Layout.minimumHeight: Kirigami.Units.gridUnit * 26
        Kirigami.Theme.inherit: false
        Kirigami.Theme.backgroundColor: root.Kirigami.Theme.backgroundColor
        Kirigami.Theme.textColor: root.Kirigami.Theme.textColor
        Kirigami.Theme.disabledTextColor: root.Kirigami.Theme.disabledTextColor
        Kirigami.Theme.linkColor: root.Kirigami.Theme.linkColor
        Kirigami.Theme.positiveTextColor: root.Kirigami.Theme.positiveTextColor
        Kirigami.Theme.neutralTextColor: root.Kirigami.Theme.neutralTextColor
        Kirigami.Theme.negativeTextColor: root.Kirigami.Theme.negativeTextColor

        Rectangle {
            anchors.fill: parent
            anchors.margins: -Kirigami.Units.largeSpacing
            z: -1
            color: root.Kirigami.Theme.backgroundColor
            visible: root.forcedAppearance
            radius: Kirigami.Units.smallSpacing
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Layout.fillWidth: true

                Kirigami.Icon {
                    source: Qt.resolvedUrl("../images/chatgpt.png")
                    implicitWidth: Kirigami.Units.iconSizes.medium
                    implicitHeight: Kirigami.Units.iconSizes.medium
                }

                Kirigami.Heading {
                    text: i18n("Codex Usage")
                    level: 2
                    Layout.fillWidth: true
                }

                PlasmaComponents.ToolButton {
                    icon.name: "view-refresh"
                    text: i18n("Refresh")
                    display: PlasmaComponents.AbstractButton.IconOnly
                    enabled: !root.loading
                    onClicked: root.refresh()
                    PlasmaComponents.ToolTip.text: text
                    PlasmaComponents.ToolTip.visible: hovered
                }
            }

            Repeater {
                model: root.usageWindows

                UsageSection {
                    required property var modelData
                    Layout.fillWidth: true
                    title: root.windowTitle(modelData)
                    remaining: modelData.remainingPercent
                    resetText: root.resetText(modelData.resetsAt || 0)
                    accentColor: root.usageColor(modelData.remainingPercent, modelData.windowDurationMins)
                    iconName: root.windowIcon(modelData.windowDurationMins)
                }
            }

            Kirigami.Separator {
                visible: root.hasData
                Layout.fillWidth: true
            }

            ColumnLayout {
                visible: !root.hasData
                spacing: Kirigami.Units.largeSpacing
                Layout.fillWidth: true
                Layout.fillHeight: true

                Item { Layout.fillHeight: true }

                Kirigami.Icon {
                    source: root.accountState === "codex_missing" ? "application-x-executable" : "user-identity"
                    implicitWidth: Kirigami.Units.iconSizes.huge
                    implicitHeight: Kirigami.Units.iconSizes.huge
                    Layout.alignment: Qt.AlignHCenter
                }

                PlasmaComponents.Label {
                    text: root.loading
                        ? (root.activeOperation === "login" ? i18n("Waiting for ChatGPT sign-in…") : i18n("Checking Codex…"))
                        : (root.stateMessage.length > 0 ? root.stateMessage : i18n("Usage is unavailable"))
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                PlasmaComponents.Button {
                    visible: root.accountState === "auth_required" || root.accountState === "unsupported_auth"
                    text: i18n("Sign in with ChatGPT")
                    icon.name: "user-identity"
                    enabled: !root.loading
                    Layout.alignment: Qt.AlignHCenter
                    onClicked: root.signIn()
                }

                PlasmaComponents.Button {
                    visible: root.accountState === "codex_missing"
                    text: i18n("Install Codex")
                    icon.name: "internet-services"
                    Layout.alignment: Qt.AlignHCenter
                    onClicked: root.openInstallPage()
                }

                PlasmaComponents.Button {
                    visible: root.accountState === "error"
                    text: i18n("Try Again")
                    icon.name: "view-refresh"
                    enabled: !root.loading
                    Layout.alignment: Qt.AlignHCenter
                    onClicked: root.refresh()
                }

                Item { Layout.fillHeight: true }
            }

            GridLayout {
                visible: root.hasData
                columns: 2
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true

                PlasmaComponents.Label { text: i18n("Plan") }
                PlasmaComponents.Label {
                    text: root.planText()
                    font.weight: Font.DemiBold
                    Layout.alignment: Qt.AlignRight
                }

                PlasmaComponents.Label { text: i18n("Additional credits") }
                PlasmaComponents.Label {
                    text: root.creditBalance
                    font.weight: Font.DemiBold
                    Layout.alignment: Qt.AlignRight
                }

                PlasmaComponents.Label { text: i18n("Reset credits") }
                PlasmaComponents.Label {
                    text: root.resetCredits.toString()
                    font.weight: Font.DemiBold
                    Layout.alignment: Qt.AlignRight
                }

                PlasmaComponents.Label { text: i18n("Status") }
                PlasmaComponents.Label {
                    text: root.errorMessage.length > 0 ? i18n("Update failed") : root.accountStatus
                    color: root.errorMessage.length > 0
                        ? Kirigami.Theme.negativeTextColor
                        : Kirigami.Theme.positiveTextColor
                    font.weight: Font.DemiBold
                    Layout.alignment: Qt.AlignRight
                }
            }

            PlasmaComponents.Label {
                visible: root.errorMessage.length > 0 && root.hasData
                text: root.errorMessage
                color: Kirigami.Theme.negativeTextColor
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    text: i18n("Appearance")
                    Layout.fillWidth: true
                }
                Basic.ComboBox {
                    palette.window: root.Kirigami.Theme.backgroundColor
                    palette.base: root.Kirigami.Theme.backgroundColor
                    palette.button: root.Kirigami.Theme.backgroundColor
                    palette.text: root.Kirigami.Theme.textColor
                    palette.buttonText: root.Kirigami.Theme.textColor
                    palette.windowText: root.Kirigami.Theme.textColor
                    palette.highlight: root.Kirigami.Theme.linkColor
                    palette.highlightedText: root.darkAppearance ? "#232629" : "#ffffff"
                    model: [i18n("Auto"), i18n("Dark"), i18n("Light")]
                    currentIndex: ["auto", "dark", "light"].indexOf(root.appearance)
                    onActivated: index => Plasmoid.configuration.appearance = ["auto", "dark", "light"][index]
                    Accessible.name: i18n("Widget appearance")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    text: i18n("Refresh every")
                    Layout.fillWidth: true
                }
                Basic.SpinBox {
                    palette.window: root.Kirigami.Theme.backgroundColor
                    palette.base: root.Kirigami.Theme.backgroundColor
                    palette.button: root.Kirigami.Theme.backgroundColor
                    palette.text: root.Kirigami.Theme.textColor
                    palette.buttonText: root.Kirigami.Theme.textColor
                    palette.windowText: root.Kirigami.Theme.textColor
                    palette.highlight: root.Kirigami.Theme.linkColor
                    palette.highlightedText: root.darkAppearance ? "#232629" : "#ffffff"
                    id: refreshInterval
                    from: 1
                    to: 1440
                    editable: true
                    value: root.refreshMinutes
                    Accessible.name: i18n("Automatic refresh interval in minutes")
                    onValueModified: Plasmoid.configuration.refreshIntervalMinutes = value
                }
                PlasmaComponents.Label { text: i18n("minutes") }
            }

            PlasmaComponents.Label {
                visible: root.hasData
                text: i18n("Last updated: %1", root.updatedText())
                wrapMode: Text.Wrap
                color: Kirigami.Theme.disabledTextColor
                font: Kirigami.Theme.smallFont
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
