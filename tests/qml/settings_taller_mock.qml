// Ajustes › Taller with fake Settings / Mem: defaults, after editing every control, and with no projects.
// Prints the calls the page makes (CALL …) so tests/fase5c/test_views.py can check them.
import QtQuick
import QtQuick.Window
import "../../config/quickshell"
import "../../config/quickshell/modules/settings"
Window {
    id: win
    visible: true
    width: Theme.settingsWidth - Theme.settingsNavWidth
    height: Theme.settingsHeight
    color: Theme.popoverBg
    readonly property string outDir: Qt.application.arguments[Qt.application.arguments.length - 1]
    QtObject {
        id: settings
        property bool promptHistory: false
        readonly property int tokenStep: 250
        readonly property int tokenMax: 20000
        property int tokenWarnAt: 1500
        property int tokenHighAt: 3000
        function setTokenThresholds(w, h) { console.log("CALL thresholds", w, h); tokenWarnAt = w; tokenHighAt = h; }
        function setFlag(k, v) { console.log("CALL flag", k, v); if (k === "promptHistory") promptHistory = v; }
    }
    QtObject {
        id: memory
        property string status: "ok"
        property string message: ""
        property string selectedSlug: "arxnet"
        property var projects: [
            { slug: "arxnet", name: "arxnet", path: "/home/u/Devs/arxnet", wip_limit: 3, test_cmd: "npm test" },
            { slug: "dragon", name: "dragon-island", path: "/home/u/Devs/dragon", wip_limit: 2, test_cmd: "" }
        ]
        readonly property var project: projects.find(p => p.slug === selectedSlug) ?? null
        function selectProject(s) { console.log("CALL select", s); selectedSlug = s; }
        function setProject(slug, fields, cb) {
            console.log("CALL set", slug, JSON.stringify(fields));
            projects = projects.map(p => p.slug === slug ? Object.assign({}, p, fields) : p);
            cb({ ok: true, project: projects.find(p => p.slug === slug) });
        }
        function exportContext(slug, cb) { console.log("CALL export", slug); cb({ ok: true, path: "/home/u/Devs/arxnet/.dragon/CONTEXT.md", bytes: 1843 }); }
    }
    Rectangle { anchors.fill: parent; color: Theme.bg }
    Rectangle { anchors.fill: parent; color: Theme.popoverBg }
    Flickable {
        anchors.fill: parent
        anchors.margins: Theme.spacingLg
        contentHeight: page.implicitHeight
        TallerSettingsPage { id: page; width: parent.width; settings: settings; mem: memory }
    }
    Timer {
        interval: 300; running: true; repeat: true
        property int step: 0
        onTriggered: {
            const shot = name => win.contentItem.grabToImage(r => r.saveToFile(win.outDir + "/" + name));
            if (step === 0) shot("ajustes-taller.png");
            else if (step === 1) {
                settings.setTokenThresholds(2000, 4000);
                settings.setFlag("promptHistory", true);
                page.setWip(4);
                page.setTestCmd("  pytest -q  ");
                page.setTestCmd("pytest -q");          // unchanged: no second write
                page.exportNow();
                console.log("STATE", memory.project.wip_limit, memory.project.test_cmd, JSON.stringify(page.exported.arxnet));
            }
            else if (step === 2) shot("ajustes-taller-editado.png");
            else if (step === 3) { page.cycle(1); console.log("STATE", memory.selectedSlug, page.notice === ""); }
            else if (step === 4) { memory.projects = []; }
            else if (step === 5) shot("ajustes-taller-vacio.png");
            else if (step === 6) Qt.quit();
            step++;
        }
    }
}
