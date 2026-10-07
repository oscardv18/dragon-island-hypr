// App icon shown behind a thumbnail that has not arrived yet (Quickshell.Widgets IconImage)
import QtQuick
import Quickshell.Widgets
import ".."

IconImage {
    implicitSize: Theme.iconLg * 2
    asynchronous: true
    opacity: 0.55
}
