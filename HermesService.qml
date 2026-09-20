import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services

/**
 * HermesService — the daemon surface of DankHermes.
 *
 * Owns every call into the bundled `bin/dank-hermes` helper, holds the latest
 * Hermes state (status / usage / sessions), and publishes itself as a plugin
 * global so every bar and dock instance shares one poller.
 *
 * Nothing here writes to Hermes' own files: the helper opens state.db
 * read-only, and actions are argv-based (never a shell string).
 */
PluginComponent {
    id: root

    // ---- published state ------------------------------------------------
    property var status: null
    property var usage: null
    property var sessions: []
    property string error: ""
    property string errorAction: ""
    property bool busy: false
    property bool loggedFirstPoll: false

    // one-shot prompt watch
    property string answerText: ""
    property string answerAgo: ""
    property bool answerRunning: false
    property bool watching: false

    // when false this instance stays private (widget fallback poller)
    property bool publish: true
    // when true, skip polling entirely (Settings/HTTP taps use the real one)
    property bool polling: true

    readonly property string helperPath: {
        const url = Qt.resolvedUrl("bin/dank-hermes").toString().replace(/^file:\/\//, "");
        return decodeURIComponent(url);
    }

    // ---- settings -------------------------------------------------------
    readonly property int refreshSeconds: Math.max(2, Number(pluginData?.refreshSeconds ?? 10))
    readonly property int usageSeconds: Math.max(30, Number(pluginData?.usageSeconds ?? 300))
    readonly property int sessionsLimit: Math.max(1, Number(pluginData?.sessionsLimit ?? 15))
    readonly property string terminalOverride: String(pluginData?.terminalCommand ?? "")
    readonly property bool notifyOnAnswer: pluginData?.notifyOnAnswer !== false

    property bool healthy: !!status?.ok
    readonly property bool gatewayRunning: !!status?.gateway?.running
    readonly property bool agentActive: !!status?.agent?.active
    readonly property string modelLabel: status?.agent?.model ?? ""
    readonly property int liveCount: status?.liveSessions?.length ?? 0
    readonly property string todayTokens: usage?.pretty?.today ?? "—"
    readonly property string todayCost: usage?.pretty?.todayCost ?? ""

    // ---- queue ----------------------------------------------------------
    property var queue: []
    property string currentAction: ""
    property var currentCallback: null

    function enqueue(args, callback) {
        queue = queue.concat([{ args: args, callback: callback || null }]);
        if (!busy) dispatch();
    }

    function dispatch() {
        if (busy || queue.length === 0) return;
        const job = queue[0];
        queue = queue.slice(1);
        busy = true;
        currentAction = job.args[0];
        currentCallback = job.callback;
        proc.command = [helperPath].concat(job.args);
        proc.running = true;
    }

    // ---- public API -----------------------------------------------------
    function refresh() {
        enqueue(["status"]);
        enqueue(["sessions", "--limit", String(sessionsLimit)]);
    }

    function refreshUsage() { enqueue(["usage", "--days", "7"]); }

    function doctor(callback) { enqueue(["doctor"], callback); }

    /** Open the Hermes TUI, optionally resuming a session or seeding a prompt. */
    function openTui(sessionId, query) {
        const args = ["terminal-argv"];
        if (sessionId) args.push("--resume", String(sessionId));
        if (query) args.push("--query", String(query));
        if (terminalOverride) args.push("--terminal", terminalOverride);
        enqueue(args, (ok, res) => {
            if (!ok || !res?.argv) {
                ToastService.showError("Hermes", res?.error ?? "Could not build the terminal command");
                return;
            }
            Quickshell.execDetached(res.argv);
        });
    }

    /** Run a one-shot query in the background and notify when the answer lands. */
    function ask(text) {
        const query = String(text ?? "").trim();
        if (query.length === 0) return;
        enqueue(["prompt", "--text", query], (ok, res) => {
            if (!ok) {
                ToastService.showError("Hermes", res?.error ?? "Could not start the query");
                return;
            }
            answerText = "";
            watching = true;
            answerWatch.restart();
        });
    }

    function openAnswerFile() {
        enqueue(["answer"], (ok, res) => {
            if (ok && res?.exists && res?.path) Quickshell.execDetached(["xdg-open", res.path]);
        });
    }

    // ---- processes ------------------------------------------------------
    Process {
        id: proc
        stdout: StdioCollector { id: out }
        stderr: StdioCollector { id: err }
        onExited: (code, status) => {
            let result = null;
            try { result = JSON.parse(out.text); }
            catch (e) { result = null; }
            const action = root.currentAction;
            const done = root.currentCallback;
            root.currentAction = "";
            root.currentCallback = null;
            root.busy = false;

            const ok = code === 0 && result && result.ok === true;
            if (!ok) {
                const message = (result && result.error)
                    || err.text.trim()
                    || "The Hermes helper did not return a usable response.";
                // polling failures stay quiet in the UI but are visible to the popout
                if (action === "status" || action === "sessions" || action === "usage") {
                    root.error = message;
                    root.errorAction = action;
                } else {
                    root.error = message;
                    root.errorAction = action;
                    ToastService.showError("Hermes", message);
                }
                console.warn("DankHermes: helper failed:", message);
            } else {
                if (action === "status") {
                    root.status = result;
                    root.error = "";
                    root.errorAction = "";
                    if (!root.loggedFirstPoll) {
                        root.loggedFirstPoll = true;
                        console.info("DankHermes: first status poll ok — gateway "
                            + (result.gateway?.running ? "running" : "stopped")
                            + ", model " + (result.agent?.model ?? "unknown")
                            + ", live " + (result.liveSessions?.length ?? 0));
                    }
                } else if (action === "usage") {
                    root.usage = result;
                } else if (action === "sessions") {
                    root.sessions = result.sessions ?? [];
                } else if (action === "answer") {
                    applyAnswer(result);
                }
            }
            if (done) done(ok, result);
            Qt.callLater(root.dispatch);
        }
    }

    Process {
        id: answer
        stdout: StdioCollector { id: answerOut }
        onExited: (code, status) => {
            try {
                const res = JSON.parse(answerOut.text);
                if (res && res.ok !== false) applyAnswer(res);
            } catch (e) {
                // ignored: the next poll retries
            }
        }
    }

    function applyAnswer(res) {
        answerText = res.text ?? "";
        answerAgo = res.ago ?? "";
        answerRunning = res.running === true;
        if (!answerRunning && watching) {
            watching = false;
            answerWatch.stop();
            if (!answerText.trim()) {
                ToastService.showError("Hermes", "The query finished without an answer. Check the answer file for details.");
            } else if (notifyOnAnswer) {
                const summary = answerText.trim().split("\n").filter(l => l.trim().length > 0).slice(-1)[0] ?? "";
                ToastService.showInfo("Hermes answered", summary.length > 160 ? summary.slice(0, 160) + "…" : summary);
            }
        }
    }

    // ---- timers ---------------------------------------------------------
    Timer {
        interval: root.refreshSeconds * 1000
        repeat: true
        running: root.polling
        onTriggered: root.refresh()
    }

    Timer {
        interval: root.usageSeconds * 1000
        repeat: true
        running: root.polling
        onTriggered: root.refreshUsage()
    }

    Timer {
        id: answerWatch
        interval: 4000
        repeat: true
        running: false
        onTriggered: {
            if (answer.running) return;
            answer.command = [root.helperPath, "answer"];
            answer.running = true;
        }
    }

    Component.onCompleted: {
        if (publish && pluginService) pluginService.setGlobalVar(pluginId, "service", root);
        if (root.polling) {
            root.refresh();
            root.refreshUsage();
        }
    }

    Component.onDestruction: {
        // only clear the global if we are the instance that owns it
        if (publish && pluginService && pluginService.getGlobalVar(pluginId, "service", null) === root)
            pluginService.setGlobalVar(pluginId, "service", null);
    }
}
