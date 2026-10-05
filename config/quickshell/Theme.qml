// =============================================================================
// dragon-island — Theme.qml (Visual Design Tokens)
// Spec: Sweet / Garuda Dragonized palette & Outfit / JetBrains typography
// =============================================================================
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root

    // -------------------------------------------------------------------------
    // Colors (Palette)
    // -------------------------------------------------------------------------
    readonly property color bg:         "#0b0c14" // wallpaper fallback / deepest background
    readonly property color surface0:   "#161925" // islands (72-86% opacity), hyprbars bar
    readonly property color surface1:   "#12131e" // cards inside panels
    readonly property color surface2:   "#1d2031" // capsules, list rows, off toggles
    readonly property color surface3:   "#22243a" // inactive pills, progress tracks
    readonly property color surfaceHi:  "#34385a" // capsule hover / active popover open
    readonly property color outline:    "#262838" // inactive window border
    readonly property color muted:      "#3a3d55" // inactive hyprbars buttons, empty dots
    readonly property color text:       "#e6e8ef" // primary text
    readonly property color textSoft:   "#c3c7d1" // body text
    readonly property color textDim:    "#8a8fa3" // captions, empty workspaces
    readonly property color accent:     "#c50ed2" // magenta brand accent
    readonly property color violet:     "#7c3aed" // gradient end
    readonly property color violetSoft: "#a855f7" // RAM, secondary accents
    readonly property color cyan:       "#00c1e4" // CPU, links, info
    readonly property color ok:         "#06c993" // battery, success, float button
    readonly property color warn:       "#f9ae58" // warnings, fullscreen button, temp
    readonly property color error:      "#ed254e" // errors, close button
    readonly property color island:     "#000000" // Dynamic Island & dashboard background

    // Alpha / Opacity Presets
    readonly property real opacityIslandSurface: 0.82
    readonly property real opacityCardSurface:   0.94
    readonly property real opacityScrim:         0.45

    // -------------------------------------------------------------------------
    // Typography
    // -------------------------------------------------------------------------
    readonly property string fontUi:   "Outfit"
    readonly property string fontMono: "JetBrains Mono Nerd Font"

    readonly property real sizeCaption:   11.0
    readonly property real sizeBar:       12.5
    readonly property real sizeBody:      13.5
    readonly property real sizeTitle:     16.0
    readonly property real sizeGreeting:  22.0
    readonly property real sizeHero:      40.0

    readonly property int weightRegular: Font.Normal    // 400
    readonly property int weightMedium:  Font.Medium    // 500
    readonly property int weightSemiBold:Font.DemiBold  // 600
    readonly property int weightBold:    Font.Bold      // 700

    // -------------------------------------------------------------------------
    // Geometry & Radii
    // -------------------------------------------------------------------------
    readonly property real radiusPill:            8
    readonly property real radiusCapsule:         9
    readonly property real radiusIsland:          14
    readonly property real radiusCard:            18
    readonly property real radiusPopover:         22
    readonly property real radiusDashboardBottom: 34
    readonly property real radiusWindow:          14

    readonly property real barHeight:          40
    readonly property real barMarginTop:       10
    readonly property real barMarginSides:     14
    readonly property real islandHeightClosed: 36
    readonly property real dashboardWidth:     860
    readonly property real popoverWidth:       360

    // -------------------------------------------------------------------------
    // Motion & Animation Durations (multiplied by motionScale)
    // -------------------------------------------------------------------------
    property real motionScale: 1.0

    readonly property int durationFast:     Math.round(120 * motionScale)
    readonly property int durationNormal:   Math.round(220 * motionScale)
    readonly property int durationPopover:  Math.round(280 * motionScale)
    readonly property int durationMedium:   Math.round(300 * motionScale)
    readonly property int durationSlow:     Math.round(420 * motionScale)
    readonly property int durationPour:     Math.round(480 * motionScale)
    readonly property int durationDropIn:   Math.round(700 * motionScale)
    readonly property int durationToast:    Math.round(2000 * motionScale)
    readonly property int durationNotif:    Math.round(4000 * motionScale)
}
