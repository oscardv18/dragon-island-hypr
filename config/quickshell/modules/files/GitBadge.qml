// Git mark of a file: M (amber) · A (green) · D (red) · ? (dim), as a small tinted square.
import QtQuick
import "../.."
import "../../components"

Rectangle {
    id: root
    property string mark: ""
    readonly property color tone: ({ M: Theme.files.gitModified, A: Theme.files.gitAdded, D: Theme.files.gitDeleted })[mark] ?? Theme.files.gitUntracked
    visible: mark.length > 0
    width: Theme.files.gitBadge
    height: Theme.files.gitBadge
    radius: Theme.files.chipRadius / 2
    color: Theme.alpha(tone, Theme.files.badgeTint)
    UiText { anchors.centerIn: parent; text: root.mark; mono: true; size: Theme.files.caption; weight: Theme.weightSemiBold; color: root.tone }
}
