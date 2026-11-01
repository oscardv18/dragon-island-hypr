// One bounded JSON request whose text goes through stdin (prompts, never argv). Owned and destroyed like ToolRequest.
import Quickshell.Io

ToolRequest {
    id: root
    property string input: ""
    stdinEnabled: true
    onStarted: { root.write(root.input); root.stdinEnabled = false; }
}
