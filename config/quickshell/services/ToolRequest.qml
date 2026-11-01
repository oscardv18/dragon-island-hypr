// One bounded JSON request, owned by a data service. Caller may destroy it to cancel reads.
import Quickshell.Io

Process {
    id: root
    property var callback: null
    property var result: null
    property bool ended: false
    property bool collected: false
    property int code: 0
    function finish(): void {
        if (!ended || !collected) return;
        const value = result ?? {ok:false,error:{code:code === 127 ? "missing_tool" : "invalid_response",message:"Herramienta no disponible. Ejecuta ./update.sh"}};
        if (callback) callback(value);
        Qt.callLater(() => root.destroy());
    }
    stdout: StdioCollector {
        onStreamFinished: {
            try { root.result = JSON.parse(this.text); } catch (e) { root.result = null; }
            root.collected = true; root.finish();
        }
    }
    onExited: (exitCode, exitStatus) => { root.code = exitCode; root.ended = true; root.finish(); }
}
