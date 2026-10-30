// Active state of the new identity: purple as a tint, never as a solid fill.
// accentTint fill + 1 px inner accentEdge border; both follow Theme.accentIntensity (Settings → Apariencia).
// Text and icons on top use Theme.lavenderInk. Replaces BrandFill in normal states (BrandFill stays for special cases).
import QtQuick
import ".."

Rectangle {
    color: Theme.accentTint
    border.width: 1
    border.color: Theme.accentEdge
    Behavior on color { ColorAnimation { duration: Theme.durHover } }
}
