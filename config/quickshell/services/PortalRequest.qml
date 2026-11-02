// One dragon-portal call (take / reply). Same contract as FilesRequest (JSON on stdout, `input` on stdin, auto-destroys); only the tool differs.
// Not a singleton and never used by the UI: FilePicker owns it.
import Quickshell
import QtQuick

FilesRequest {
    tool: `${Quickshell.env("HOME")}/.local/bin/dragon-portal`
}
