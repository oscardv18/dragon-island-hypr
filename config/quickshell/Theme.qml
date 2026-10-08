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
    readonly property color island:     "#000000" // notch background (always opaque black)
    readonly property color onBrand:    "#ffffff" // text/icons on the brand gradient
    readonly property color transparent: "transparent"

    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // Derived colors
    readonly property real islandSurfaceAlpha: 0.82                        // spec 72-86 %
    readonly property real popoverAlpha:       0.30                        // panels / cards: the glass shows through
    readonly property real scrimAlpha:         0.45                        // launcher / power menu only (not the notch)
    readonly property real glassAlpha:         0.18                        // bar islands: the liquid glass shows through; above mask_threshold (0.1)
    readonly property color barIsland:     alpha(surface0, islandSurfaceAlpha)
    readonly property color glassBg:       alpha(surface0, glassAlpha)     // acrylic island / popover / card background
    readonly property bool textShadows:    false                           // MultiEffect shadows on bar text: rendered through a texture, they made it look soft / pixelated
    readonly property color textShadow:    Qt.rgba(0, 0, 0, 0.55)         // text / icon shadow on glass (only inside the islands)
    readonly property color glassBorder:   Qt.rgba(1, 1, 1, 0.08)          // 1 px, white 8 %
    readonly property color pillBg:        alpha(surface2, 0.38)           // dock capsules / launcher pills: translucent, the liquid glass shows through
    readonly property color pillBgHi:      alpha(surfaceHi, 0.55)
    readonly property color popoverBg:     alpha(surface0, popoverAlpha)
    readonly property color hairline:      Qt.rgba(1, 1, 1, 0.07)          // island border, white 7 %
    readonly property color divider:       Qt.rgba(1, 1, 1, 0.10)          // divider, white 10 %
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

    // Notch island (v2): attached to the top edge, see references/design.md "Notch Island v2"
    readonly property real notchHeight:        barMarginTop + barHeight // 50: bottom edge = bar islands' bottom edge
    readonly property real notchEarRadius:     12     // concave "ears" where it meets the screen edge
    readonly property real notchRadius:        18     // collapsed bottom corners
    readonly property real notchExpandedRadius: 34    // expanded bottom corners
    readonly property real notchBaseWidth:     120    // width at first appearance
    readonly property real notchMinWidth:      120
    readonly property real notchRestWidth:     190    // narrowest collapsed width
    readonly property real notchGap:           16     // free space kept on each side towards the bar islands
    readonly property real notchSideReserve:   232    // free centre kept between the islands for the collapsed notch
    readonly property real notchReserve:       300    // centre gap the left island leaves for the notch
    readonly property real notchPadH:          16     // content padding inside the collapsed body
    readonly property real notchPeekDy:        8      // hover / transient peek: grows down ...
    readonly property real notchPeekDx:        16      // ... and wider
    readonly property real notchExpandedWidth: 720
    readonly property real notchExpandedHeight: 230
    readonly property real notchWindowHeight:  notchExpandedHeight + 40 // room for spring overshoot
    readonly property real notchPad:           18     // padding inside the expanded body
    readonly property real notchColGap:        16
    readonly property real notchMediaWidth:    252
    readonly property real notchArt:           96
    readonly property real notchArtRadius:     16
    readonly property real notchTabHeight:     28
    readonly property real notchTile:          40
    readonly property real artSmall:     22
    readonly property real artSmallRadius: 7

    // Calendar popover (calendar | notifications + updates)
    readonly property real calendarPopoverWidth:  720
    readonly property real notificationsListHeight: 250

    // Dock: an opaque black tab with the notch's silhouette (NotchShape) that sticks out of the screen edge; as thick as the bar islands
    readonly property real dockPill:       30     // capsule that holds an icon
    readonly property real dockIconInner:  20
    readonly property real dockPitch:      38     // distance between capsules
    readonly property real dockPad:        14     // along the edge, before the first / after the last capsule
    readonly property real dockThickness:  40     // how far it sticks out
    readonly property int  dockCapacity:   8      // capsules shown at once; more scroll with the mouse wheel
    readonly property int  dockHideDelay:  600    // ms after the pointer leaves
    readonly property real dockEdge:       3      // hot zone thickness, px
    // herdr agent states (herdr has no "error" state): working · blocked (needs an answer) · done / idle (ready) · unknown
    function agentColor(state: string): color {
        switch (state) {
            case "working": return cyan;
            case "blocked": return warn;
            case "done":    return ok;
            case "unknown": return violetSoft;
            default:        return textDim;
        }
    }
    function agentLabel(state: string): string {
        switch (state) {
            case "working": return "trabajando";
            case "blocked": return "esperando respuesta";
            case "done":    return "terminado";
            case "idle":    return "inactivo";
            default:        return "sin clasificar";
        }
    }

    // Workspace hover preview
    readonly property real previewThumbWidth: 180

    // Store panel (Tienda)
    readonly property real storeWidth:      760
    readonly property real storeBodyHeight: 340
    readonly property real storeListWidth:  330

    // Wallpaper picker
    readonly property real wallpaperPanelWidth:   980
    readonly property real wallpaperTabsWidth:    300
    readonly property real wallpaperGridHeight:   360
    readonly property real wallpaperPreviewWidth: 280
    readonly property real wallpaperThumbRadius:  14

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

    // Notch content
    readonly property real notchOsdBar:        110
    readonly property real notchMediaTitleMax: 180
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
    readonly property real keybindsWidth:   920
    readonly property real keyCapHeight:    22
    readonly property real keyCapPadH:      7
    readonly property real keyCapRadius:    6
    readonly property real keybindsChrome:  190   // title + search + footer + paddings of the panel
    readonly property real powerButton:     88

    // -------------------------------------------------------------------------
    // Motion (spec "Motion" table). Every duration goes through motionScale.
    // -------------------------------------------------------------------------
    // Set by the Settings service (settings.json → KDE AnimationDurationFactor → 1.0). 0 = no animations.
    property real motionScale: 1.0
    readonly property bool animationsEnabled: motionScale > 0
    function ms(v: real): int { return Math.round(v * motionScale); }

    // Notch springs (SpringAnimation): first appearance and expand / peek
    readonly property real notchAppearSpring:  3.5
    readonly property real notchAppearDamping: 0.32
    readonly property real notchSpring:        3.0
    readonly property real notchDamping:       0.30
    readonly property int durContentDelay: ms(220)  // content fades in at ~40 % of the expand animation
    readonly property int durContentIn:    ms(260)
    readonly property int durContentOut:   ms(120)  // content fades out first, then the shape shrinks
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
