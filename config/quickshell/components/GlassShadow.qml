// The soft shadow under a glass shape (Theme.glassShadow; none with the liquid glass). Its alpha stays below the native
// blur's ignore_alpha (rules.lua), so it is never blurred. Place it as a sibling BEFORE the shape, same geometry.
import QtQuick
import QtQuick.Effects
import ".."

RectangularShadow {
    visible: Theme.glassShadow.a > 0
    offset.y: Theme.glassShadowY
    blur: Theme.glassShadowBlur
    spread: 0
    color: Theme.glassShadow
    // set `radius` (RectangularShadow's corner radius) to the shape's
}
