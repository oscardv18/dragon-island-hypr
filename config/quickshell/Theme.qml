// =============================================================================
// dragon-island — Theme.qml (visual design tokens)
// Source of truth: .agents/skills/dragon-island/references/design.md
// Components read every color, size, font and duration from here. No literals elsewhere.
// =============================================================================
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root

    // -------------------------------------------------------------------------
    // Palette (Sweet / Garuda Dragonized)
    // -------------------------------------------------------------------------
    readonly property color bg:         "#0b0c14" // wallpaper fallback / deepest background
    readonly property color surface0:   "#161925" // islands (72-86 % opacity), hyprbars bar
    readonly property color surface1:   "#12131e" // cards inside panels
    readonly property color surface2:   "#1d2031" // capsules, list rows, off toggles
    readonly property color surface3:   "#22243a" // inactive pills, progress tracks
    readonly property color surfaceHi:  "#34385a" // capsule hover / while its popover is open
    readonly property color outline:    "#262838" // inactive window border
    readonly property color muted:      "#3a3d55" // inactive hyprbars buttons, empty dots
    readonly property color text:       "#e6e8ef" // primary text
    readonly property color textSoft:   "#c3c7d1" // body text
    readonly property color textDim:    "#8a8fa3" // captions, empty workspaces
    readonly property color accent:     "#c50ed2" // magenta brand accent
    readonly property color violet:     "#7c3aed" // gradient end
    readonly property color violetSoft: "#a855f7" // RAM, secondary accents
    readonly property color cyan:       "#00c1e4" // CPU, links, info
    readonly property color ok:         "#06c993" // battery, success
    readonly property color warn:       "#f9ae58" // warnings, temperature
    readonly property color error:      "#ed254e" // errors, power button
    readonly property color island:     "#000000" // Dynamic Island & dashboard background
    readonly property color onBrand:    "#ffffff" // text/icons on the brand gradient
    readonly property color transparent: "transparent"

    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // Derived colors
    readonly property real islandSurfaceAlpha: 0.82                        // spec 72-86 %
    readonly property real popoverAlpha:       0.94
    readonly property real scrimAlpha:         0.45
    readonly property color barIsland:     alpha(surface0, islandSurfaceAlpha)
    readonly property color popoverBg:     alpha(surface0, popoverAlpha)
    readonly property color hairline:      Qt.rgba(1, 1, 1, 0.07)          // island border, white 7 %
    readonly property color divider:       Qt.rgba(1, 1, 1, 0.10)          // divider, white 10 %
    readonly property color islandBorder:  alpha(accent, 0.32)             // 1 px accent 30-35 %
    readonly property color glow:          alpha(accent, 0.18)             // ~18 %
    readonly property color glowStrong:    alpha(accent, 0.55)             // active pill / unread dot
    readonly property color scrim:         Qt.rgba(0, 0, 0, scrimAlpha)
    readonly property color errorTint:     alpha(error, 0.16)
    readonly property color hoverOverlay:  Qt.rgba(1, 1, 1, 0.06)

    // Gradients (135°)
    readonly property var brandStops:  [accent, violet]
    readonly property var borderStops: [accent, violet, cyan]

    // -------------------------------------------------------------------------
    // Typography (pixel sizes; Text.font.pixelSize is an int, 12.5 rounds to 13)
    // -------------------------------------------------------------------------
    readonly property string fontUi:   "Outfit"
    readonly property string fontMono: "JetBrains Mono Nerd Font"

    readonly property real sizeCaption:  11
    readonly property real sizeBar:      12.5
    readonly property real sizeBody:     13
    readonly property real sizeBodyLg:   14
    readonly property real sizeTitle:    16
    readonly property real sizeGreeting: 22
    readonly property real sizeHero:     40
    readonly property real captionTracking: 0.08 // em, uppercase captions

    readonly property int weightRegular:  Font.Normal   // 400
    readonly property int weightMedium:   Font.Medium   // 500
    readonly property int weightSemiBold: Font.DemiBold // 600
    readonly property int weightBold:     Font.Bold     // 700

    readonly property real iconSm: 14
    readonly property real iconMd: 16
    readonly property real iconLg: 18

    // -------------------------------------------------------------------------
    // Geometry
    // -------------------------------------------------------------------------
    // Bar
    readonly property real barHeight:     40
    readonly property real barMarginTop:  10
    readonly property real barMarginSide: 14
    readonly property real barIslandRadius: 14
    readonly property real barIslandPadH:   6
    readonly property real barIslandGap:    5
    readonly property real launcherButton:  30
    readonly property real dividerHeight:   18

    // Capsules
    readonly property real capsuleHeight: 28
    readonly property real capsuleRadius: 9
    readonly property real capsulePadH:   10
    readonly property real capsuleGap:    6

    // Workspace pills
    readonly property real pillHeight:  22
    readonly property real pillRadius:  8
    readonly property real pillMinWidth: 22
    readonly property real pillDot:     4

    // Dynamic Island / dashboard
    readonly property real islandHeight:   36
    readonly property real islandRadius:   18
    readonly property real islandY:        10
    readonly property real islandPadH:     14
    readonly property real islandHiddenY:  -60
    readonly property real islandMaxPillWidth: 420
    readonly property real dashboardWidth: 860
    readonly property real dashboardRadius: 34
    readonly property real dashboardPadTop: 22
    readonly property real dashboardPadH:   24
    readonly property real dashboardPadBottom: 24
    readonly property real handleWidth:  48
    readonly property real handleHeight: 5
    readonly property real glowBlur:     30
    readonly property real artSmall:     24
    readonly property real artSmallRadius: 7

    // Popovers & cards
    readonly property real popoverWidth:   360
    readonly property real popoverWidthSm: 320
    readonly property real popoverWidthLg: 380
    readonly property real popoverRadius:  22
    readonly property real popoverPad:     18
    readonly property real popoverGap:     8
    readonly property real popoverMaxListHeight: 420
    readonly property real cardRadius:     18
    readonly property real cardPad:        14
    readonly property real rowRadius:      12
    readonly property real rowHeight:      44
    readonly property real tileMinHeight:  64
    readonly property real tileRadius:     18
    readonly property real touchTarget:    44
    readonly property real trackHeight:    6
    readonly property real sliderHeight:   28
    readonly property real spacingXs:      4
    readonly property real spacingSm:      8
    readonly property real spacingMd:      12
    readonly property real spacingLg:      16

    // Controls
    readonly property real switchWidth:   40
    readonly property real switchHeight:  22
    readonly property real knobInset:     3
    readonly property real knobSize:      14
    readonly property real tileMinWidth:  120
    readonly property real eqBar:         3
    readonly property real eqGap:         2
    readonly property real statusDot:     8
    readonly property real glowBlurSmall: 12

    // Workspace pills (extra)
    readonly property real pillPadH:          8
    readonly property real pillActiveMinWidth: 40
    readonly property var  wsDotColors:       [accent, cyan, violetSoft, ok, warn]

    // Island content
    readonly property real islandIcon:          20
    readonly property real islandOsdBar:        120
    readonly property real islandMediaTitleMax: 200

    // Dashboard content
    readonly property real dashColumnGap:  14
    readonly property real artLarge:       64
    readonly property real artLargeRadius: 14
    readonly property real tempMaxC:       100
    readonly property real tempHotC:       85

    // Popover animation, calendar, notifications
    readonly property real popoverScaleFrom: 0.96
    readonly property real popoverShift:     10
    readonly property real calendarCell:     34
    readonly property real notifIcon:        32
    readonly property int  maxPopups:        3

    // Launcher / power menu
    readonly property real launcherWidth:   560
    readonly property real launcherTop:     140
    readonly property int  launcherRows:    8
    readonly property real clipThumbHeight: 56
    readonly property real powerButton:     88

    // -------------------------------------------------------------------------
    // Motion (spec "Motion" table). Every duration goes through motionScale.
    // -------------------------------------------------------------------------
    // Set by the Settings service (settings.json → KDE AnimationDurationFactor → 1.0). 0 = no animations.
    property real motionScale: 1.0
    readonly property bool animationsEnabled: motionScale > 0
    function ms(v: real): int { return Math.round(v * motionScale); }

    readonly property int durDropIn:       ms(700)  // island first appearance, OutBack
    readonly property real dropInOvershoot: 1.6
    readonly property int durDropSquash:   ms(320)  // slight horizontal squash at the start
    readonly property real dropSquashX:    1.12
    readonly property real dropSquashY:    0.86
    readonly property int durOpenWidth:    ms(420)  // pour: width OutBack
    readonly property int durOpenHeight:   ms(480)  // pour: height OutCubic (also y and radii)
    readonly property int durContentDelay: ms(168)  // ~35 % into the open animation
    readonly property int durContentIn:    ms(260)
    readonly property int durClose:        ms(300)  // reverse, OutCubic
    readonly property int durContentOut:   ms(120)  // content fades out first
    readonly property int durScrim:        ms(240)  // 220-250
    readonly property int durPopover:      ms(280)  // OutBack
    readonly property int durPopoverOut:   ms(160)
    // display times (how long something stays on screen): NOT scaled by motionScale
    readonly property int durTransient:    2000     // OSD / workspace island states
    readonly property int durNotif:        4000     // notification popups
    readonly property int durPill:         ms(200)  // workspace pill width + color, OutCubic
    readonly property int durHover:        ms(120)  // capsule hover
    readonly property int durFade:         ms(180)  // generic cross-fades

    // Compatibility aliases (DebugPanel and services written in the base phase)
    readonly property real radiusCard: cardRadius
    readonly property int durationToast: durTransient
    readonly property int durationNotif: durNotif
}
