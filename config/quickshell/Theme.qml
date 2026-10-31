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
    readonly property color bg:         "#07060d" // wallpaper fallback / deepest background
    readonly property color surface0:   "#161925" // islands (72-86 % opacity), hyprbars bar
    readonly property color surface1:   "#12131e" // cards inside panels
    readonly property color surface2:   "#1d2031" // capsules, list rows, off toggles
    readonly property color surface3:   "#22243a" // inactive pills, progress tracks
    readonly property color surfaceHi:  "#34385a" // capsule hover / while its popover is open
    readonly property color outline:    "#262838" // inactive window border
    readonly property color muted:      "#7f7a93" // empty dots, disabled
    readonly property color text:       "#edebf5" // primary text
    readonly property color textSoft:   "#c8c4d8" // body text, neutral icons
    readonly property color textDim:    "#a29eb6" // captions, subtitles
    property color accent:              paletteOn ? wallPalette.glow : dragon.accent   // brand accent (Dragon: magenta)
    readonly property color violet:     "#7c3aed" // gradient end
    readonly property color violetSoft: "#a855f7" // RAM, secondary accents
    readonly property color cyan:       "#67e8f9" // what is alive: CPU, activity, working agents, selection
    readonly property color ok:         "#86efac" // success
    readonly property color warn:       "#f5b04a" // waiting / attention
    readonly property color error:      "#ed254e" // errors, power button
    readonly property color island:     "#05040a" // notch background (opaque, = islandInk)
    readonly property color onBrand:    "#ffffff" // text/icons on the brand gradient
    readonly property color transparent: "transparent"

    // New identity: purple is a tint, never a fill. Active states = accentTint + 1 px accentEdge + lavenderInk text
    // The accent tokens below follow the wallpaper palette (services/WallPalette.qml, bound in shell.qml) while
    // Settings.wallpaperPalette is on and palette.json is valid; otherwise they are the fixed Dragon values (`dragon`).
    // Every change blends with ColorAnimation (curve estandar, motion.paleta). ok / warn / error / cyan never change.
    readonly property QtObject dragon: QtObject {
        readonly property color accent:       "#c50ed2"
        readonly property color lavender:     "#c8b6e6"
        readonly property color lavenderInk:  "#ede3fb"
        readonly property color lavenderDeep: "#a78bcf"
        readonly property color violetBase:   "#b26bff"
        readonly property color coreNode:     "#e896ec"   // the neural core's pink lavender nodes
        readonly property color threadPink:   "#e8c8f5"
        readonly property color textOnAccent:     "#16121f"
        readonly property color accentShade:  "#0d0b16"
    }
    property bool paletteOn: false                 // WallPalette.active
    property var wallPalette: ({})                     // { accent, accentSoft, accentDeep, glow, onAccent, tint } from WallPalette
    property color lavender:     paletteOn ? wallPalette.accent : dragon.lavender           // soft accent: RAM, focus, active states
    property color lavenderInk:  paletteOn ? Qt.tint(wallPalette.accentSoft, Qt.rgba(1, 1, 1, 0.45)) : dragon.lavenderInk   // text on an active state
    property color lavenderDeep: paletteOn ? Qt.tint(wallPalette.accent, alpha(wallPalette.accentDeep, 0.5)) : dragon.lavenderDeep   // lavender data bars
    property color violetBase:   paletteOn ? wallPalette.glow : dragon.violetBase           // base of the tints (never a solid fill)
    property color coreNode:     paletteOn ? wallPalette.accentSoft : dragon.coreNode
    property color textOnAccent:     paletteOn ? wallPalette.onAccent : dragon.textOnAccent         // text on a solid accent fill
    property color accentShade:  paletteOn ? wallPalette.tint : dragon.accentShade          // very dark tone of the accent (glass backgrounds)
    readonly property var coreIdentity: [coreNode, lavender, cyan]                     // NeuralCore.identity
    property color switchOn: paletteOn ? lavender : cyan                       // switches: cyan in the Dragon look (08-ajustes), the accent with a wallpaper palette (14-fondos)
    Behavior on accent       { ColorAnimation { duration: root.motion.paleta; easing.type: Easing.BezierSpline; easing.bezierCurve: root.curveEstandar } }
    Behavior on lavender     { ColorAnimation { duration: root.motion.paleta; easing.type: Easing.BezierSpline; easing.bezierCurve: root.curveEstandar } }
    Behavior on lavenderInk  { ColorAnimation { duration: root.motion.paleta; easing.type: Easing.BezierSpline; easing.bezierCurve: root.curveEstandar } }
    Behavior on lavenderDeep { ColorAnimation { duration: root.motion.paleta; easing.type: Easing.BezierSpline; easing.bezierCurve: root.curveEstandar } }
    Behavior on violetBase   { ColorAnimation { duration: root.motion.paleta; easing.type: Easing.BezierSpline; easing.bezierCurve: root.curveEstandar } }
    Behavior on coreNode     { ColorAnimation { duration: root.motion.paleta; easing.type: Easing.BezierSpline; easing.bezierCurve: root.curveEstandar } }
    Behavior on textOnAccent     { ColorAnimation { duration: root.motion.paleta; easing.type: Easing.BezierSpline; easing.bezierCurve: root.curveEstandar } }
    Behavior on switchOn     { ColorAnimation { duration: root.motion.paleta; easing.type: Easing.BezierSpline; easing.bezierCurve: root.curveEstandar } }
    Behavior on accentShade  { ColorAnimation { duration: root.motion.paleta; easing.type: Easing.BezierSpline; easing.bezierCurve: root.curveEstandar } }
    readonly property color islandInk:    "#05040a" // central island / notch (almost black)
    readonly property real  idleDimOpacity: 0.6     // the idle dim layer
    readonly property color focusTeal:    "#5eead4"   // focus mode countdown ring
    readonly property color captureDim:   Qt.rgba(0, 0, 0, 0.62)   // outside the capture selection
    readonly property color sunWarm:      "#fcd34d" // brightness OSD (with the night light on it warms to warn)

    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // Derived colors
    readonly property real islandSurfaceAlpha: 0.82                        // spec 72-86 %
    readonly property real scrimAlpha:         0.45                        // launcher / power menu only (not the notch)
    readonly property color barIsland:     alpha(surface0, islandSurfaceAlpha)
    readonly property bool textShadows:    false                           // MultiEffect shadows on bar text: rendered through a texture, they made it look soft / pixelated
    readonly property color textShadow:    Qt.rgba(0, 0, 0, 0.55)         // text / icon shadow on glass (only inside the islands)

    // ---- Glass material (Settings.glassStyle → services/Glass.qml → glassStyle, bound in shell.qml) ----
    //   ahumado  native blur with grain (look.lua), fill rgba(14,12,24,.70), white 8 % border, a 1 px light edge on top
    //            (lavender → cyan, transparent at both ends) and a soft shadow — docs/design/28-emergentes.png
    //   clasico  native blur, fill rgba(13,11,22,.78), white 9 % border, no grain and no light edge
    //   liquido  hyprglass: very translucent fills (islands 18 %, panels 30 %) so its refraction shows through
    // The native layer rules ignore alpha < 0.3 (rules.lua): the fills are above it, the shadows below.
    property string glassStyle: "ahumado"
    readonly property bool glassLiquid: glassStyle === "liquido"
    readonly property real glassAlpha:   glassLiquid ? 0.18 : (glassStyle === "clasico" ? 0.78 : 0.70)   // bar islands
    readonly property real popoverAlpha: glassLiquid ? 0.30 : glassAlpha                               // panels / cards
    readonly property color glassFill:   glassLiquid ? alpha(surface0, popoverAlpha)
                                       : (glassStyle === "clasico" ? Qt.rgba(13 / 255, 11 / 255, 22 / 255, 0.78) : Qt.rgba(14 / 255, 12 / 255, 24 / 255, 0.70))
    readonly property color glassBg:     glassLiquid ? alpha(surface0, glassAlpha) : glassFill   // islands
    readonly property color popoverBg:   glassFill                                             // popovers, cards, panels
    readonly property color glassBorder: glassStyle === "ahumado" ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.09)
    readonly property bool  glassLight:  glassStyle === "ahumado"                              // components/GlassLight.qml
    readonly property var   glassLightStops: [alpha(lavender, 0), lavender, cyan, alpha(cyan, 0)]   // at 0 · 0.2 · 0.8 · 1
    readonly property real  glassLightWidth: 1
    readonly property real  glassLightOpacity: 0.85
    readonly property color glassShadow: glassLiquid ? transparent : Qt.rgba(0, 0, 0, 0.28)   // below ignore_alpha: never blurred
    readonly property real  glassShadowBlur: 14
    readonly property real  glassShadowY:    3
    readonly property real  glassShadowBlurSm: 6                                          // bar islands: their window leaves ~8 px around them
    readonly property color pillBg:        alpha(surface2, 0.38)           // dock capsules / launcher pills: translucent, the liquid glass shows through
    readonly property color pillBgHi:      alpha(surfaceHi, 0.55)
    readonly property color hairline:      Qt.rgba(1, 1, 1, 0.07)          // island border, white 7 %
    readonly property color divider:       Qt.rgba(1, 1, 1, 0.10)          // divider, white 10 %
    readonly property color glow:          alpha(accent, 0.18)             // ~18 %
    readonly property color glowStrong:    alpha(accent, 0.55)             // active pill / unread dot
    readonly property color scrim:         Qt.rgba(0, 0, 0, scrimAlpha)
    readonly property color errorTint:     alpha(error, 0.16)
    readonly property color hoverOverlay:  Qt.rgba(1, 1, 1, 0.08)          // hover on a neutral control, white 8 %
    readonly property color neutralFill:   Qt.rgba(1, 1, 1, 0.06)          // clock / neutral capsules, white 6 %
    readonly property color glassHighlight: Qt.rgba(1, 1, 1, 0.06)         // inner top highlight of the islands
    readonly property color coreButtonFill: Qt.rgba(1, 1, 1, 0.05)         // the core button of the left island
    readonly property color trackFaint:     Qt.rgba(1, 1, 1, 0.15)         // ring meters / volume bar track (always visible)
    readonly property var   thumbDusk:      ["#3a3247", "#5b4a52", "#2a2433"]   // Ajustes: the "desktop" of the bar style thumbnails
    readonly property color thumbWindow:    Qt.rgba(0.07, 0.06, 0.1, 0.55)
    readonly property color thumbIsland:    Qt.rgba(0.85, 0.83, 0.92, 0.35)
    readonly property color thumbStrip:     Qt.rgba(0.08, 0.07, 0.12, 0.8)

    // Accent intensity (Settings.accentIntensity, 0–1, bound in shell.qml): how much purple the active states carry
    property real accentIntensity: 0.3
    readonly property color accentTint: alpha(violetBase, 0.06 + accentIntensity * 0.40)   // fill of an active state
    readonly property color accentEdge: alpha(violetBase, 0.15 + accentIntensity * 0.50)   // its 1 px inner border

    // Gradients (135°)
    readonly property var brandStops:  [accent, violet]
    readonly property var borderStops: [accent, violet, cyan]

    // -------------------------------------------------------------------------
    // Typography (pixel sizes; Text.font.pixelSize is an int, 12.5 rounds to 13)
    // -------------------------------------------------------------------------
    readonly property string fontUi:   "Outfit"
    readonly property string fontMono: "JetBrains Mono Nerd Font"

    readonly property real sizeCaption:  11
    readonly property real sizeBar:      12.5 + 0.5 * barStep   // bar text: 12.5 · 13 · 13.5 (Settings.barSize)
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
    // Bar: four styles (Settings.barStyle) × three sizes (Settings.barSize), both bound in shell.qml.
    // Sizes for 1366×768 at scale 1; every bar measure below derives from barHeightFor(style, size) and barStep.
    //   island / strip height and reserved space (zone):
    //               compacta     normal (default)   amplia
    //   A notch     26 → 31      30 → 35            34 → 39     side islands at top 5, notch attached, as high as them
    //   B island    26 → 32      30 → 36            34 → 40     side islands and the floating notch pill at top 6
    //   C joined    24 → 24      28 → 28            32 → 32     one edge-to-edge strip, notch exactly as high, ears
    //   D minimal   18 → 18      22 → 22            26 → 26     constellation pill + orbital clock at top 4; micro-island
    //                                                           only with activity; touching the top edge shows style B
    //                                                           (barRevealed) without changing the reserved space
    property string barStyle: "B"
    property string barSize: "normal"
    property bool barRevealed: false
    readonly property string barLook: barStyle === "D" && barRevealed ? "B" : barStyle   // what is drawn right now
    readonly property var _barBase: ({
        A: { top: 5, h: 26, attached: true },
        B: { top: 6, h: 26, attached: false },
        C: { top: 0, h: 24, attached: true },
        D: { top: 4, h: 18, attached: false }
    })
    readonly property var barSizes: ["compacta", "normal", "amplia"]
    function barStepFor(size: string): int { return Math.max(0, barSizes.indexOf(size)); }   // 0 · 1 · 2
    function barHeightFor(style: string, size: string): real { return (_barBase[style] ?? _barBase.B).h + 4 * barStepFor(size); }
    function barZoneFor(style: string, size: string): real {
        const top = style === "A" || style === "B" ? (_barBase[style]).top : 0;
        return top + barHeightFor(style, size);
    }
    readonly property int  barStep:       barStepFor(barSize)
    readonly property var  barGeo:        _barBase[barLook] ?? _barBase.B
    readonly property real barHeight:     barHeightFor(barLook, barSize)    // side islands (C: the strip)
    readonly property real barMarginTop:  barGeo.top
    readonly property real barZone:       barZoneFor(barStyle, barSize)     // exclusiveZone of dragon-bar-zone (never follows the D reveal)
    readonly property real barWindowHeight: 44                     // constant height of every bar window (the tallest: B amplia 40, + room)
    readonly property real barMarginSide: 14
    readonly property real barIslandRadius: barLook === "A" ? 9 + 2 * barStep : (barLook === "C" ? 0 : barHeight / 2)
    readonly property real barCapsuleHeight: barHeight - (barLook === "D" ? 4 : 6)   // capsules inside the islands
    // content of the islands, in proportion with the height (normal: core 26, planet 20, rings 18, spark 34×14 …)
    readonly property real barCoreButton:  barHeight - 4
    readonly property real barPlanet:      (barLook === "D" ? 12 : 18) + 2 * barStep
    readonly property real barPlanetIcon:  (barLook === "D" ? 8 : 10) + barStep
    readonly property real barNode:        5 + barStep
    readonly property real barNodePitch:   (barLook === "D" ? 14 : 20) + 2 * barStep
    readonly property real barRing:        15 + 3 * barStep
    readonly property real barRingWidth:   2.5 + 0.5 * barStep
    readonly property real barSparkWidth:  30 + 4 * barStep
    readonly property real barSparkHeight: 12 + 2 * barStep
    readonly property real barVolumeWidth: 30 + 4 * barStep
    readonly property real barOrbit:       14 + 2 * barStep
    readonly property real barStripLine: 1                         // C: bottom line of the strip, white 7 %
    readonly property real barDimOpacity: 0.35                     // barAutohide over a maximized window
    readonly property real barEdge: 3                              // D: hot zone at the top edge
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
    readonly property bool notchAttached:      barGeo.attached  // A, C: glued to the edge with ears · B, D: a floating pill
    readonly property real notchTop:           notchAttached ? 0 : barGeo.top
    readonly property real notchHeight:        barHeight        // exactly as high as the side islands / the C strip
    readonly property real notchEarRadius:     notchAttached ? 8 : 0   // concave "ears" where it meets the screen edge
    readonly property real notchRadius:        barLook === "C" ? 9 + barStep : barHeight / 2   // bottom corners (floating: a pill)
    readonly property real dropdownJoinRadius: 6               // the island's bottom corners over the drop-down terminal
    readonly property real notchMicroWidth:    80               // D: the micro-island (only with activity)
    readonly property real notchFloatTopRadius: 22              // B: top corners of the expanded Nook (it grows from the floating pill)
    readonly property real notchExpandedRadius: 34    // expanded bottom corners
    readonly property real notchBaseWidth:     120    // width at first appearance
    readonly property real notchMinWidth:      120
    readonly property real notchRestWidth:     190    // narrowest collapsed width
    readonly property real notchGap:           16     // free space kept on each side towards the bar islands
    readonly property real notchSideReserve:   232    // free centre kept between the islands for the collapsed notch
    readonly property real notchReserve:       300    // centre gap the left island leaves for the notch
    readonly property real notchPadH:          16     // content padding inside the collapsed body
    readonly property real notchPeekDy:        16     // hover / transient peek: grows down ...
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
    readonly property real artSmall:     18
    readonly property real artSmallRadius: 6

    // Calendar popover (calendar | notifications + updates)
    readonly property real calendarPopoverWidth:  720
    readonly property real notificationsListHeight: 250

    // Dock constellation (docs/design/27-dock-constelacion.png): apps are glass nodes on a thread of light, the core in
    // the middle, windows are moons, herdr agents are synapses travelling along the thread
    readonly property real dockPitch:       74     // between node centres
    readonly property int  dockCapacity:    8      // nodes shown at once (half per side of the core); more scroll with the wheel
    readonly property int  dockHideDelay:   600    // ms after the pointer leaves
    readonly property real dockEdge:        3      // hot zone thickness, px
    readonly property real dockWindow:      150    // constant thickness of the dock window (room for lift and label)
    readonly property real dockCenter:      46     // node centres from the screen edge
    readonly property real dockArc:         10     // the thread's ends sit this much closer to the edge than its centre
    readonly property real dockOverhang:    60     // thread beyond the first / last node, fading out
    readonly property real dockThread:      1.6
    readonly property real dockThreadGlow:  7
    readonly property real dockNode:        42
    readonly property real dockNodeFocus:   48     // the focused app = planet
    readonly property real dockNodeGrow:    6      // hovered node
    readonly property real dockIconRatio:   0.56   // icon size inside the glass node (rounded-square themes: see HANDOFF 8b)
    readonly property string dockNodeStyle: "icon"  // "icon": the icon itself is the node (rounded-square themes, HANDOFF 8b) · "glass": inside a glass disc
    readonly property real dockCore:        64
    readonly property real dockLift:        16     // hovered node rises; neighbours follow a gaussian
    readonly property real dockSigma:       1.1    // in nodes
    readonly property real dockMoon:        6
    readonly property real dockMoonOrbit:   18     // orbit diameter = node + this
    readonly property int  dockMoonPeriod:  18000  // ms per turn (6 s with an agent working)
    readonly property int  dockMoonPeriodBusy: 6000
    readonly property real dockSynapse:     7
    readonly property int  dockSynapseLife: 1800   // each particle; two of them, 0.9 s apart
    readonly property real dockHalo:        52     // amber halo of an agent waiting for an answer
    readonly property real dockHiddenLine:  6      // hidden: only the thread, this far from the edge
    readonly property real dockHiddenDot:   2.5
    readonly property int  dockBreath:      2600   // hidden thread: opacity 0.45 ↔ 1
    readonly property int  dockFps:         20     // one shared tick moves moons, synapses and the breathing
    readonly property int  dockFpsHidden:   8      // hidden: only the breathing of the thread's dots
    readonly property color threadPink:     paletteOn ? Qt.tint(coreNode, Qt.rgba(1, 1, 1, 0.3)) : dragon.threadPink
    readonly property color badge:          "#8b6bb8"   // unread count on a dock node
    readonly property color dockNodeBase:   Qt.rgba(13 / 255, 11 / 255, 22 / 255, 0.75)
    readonly property color dockNodeEdge:   Qt.rgba(1, 1, 1, 0.14)
    readonly property color dockNodeShine:  Qt.rgba(1, 1, 1, 0.18)
    readonly property color dockOrbit:      Qt.rgba(1, 1, 1, 0.08)
    readonly property color dockOrbitHi:    Qt.rgba(1, 1, 1, 0.22)
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

    // Ajustes panel (SUPER + F2)
    readonly property real settingsWidth:    900
    readonly property real settingsHeight:   620
    readonly property real settingsNavWidth: 230

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
    // Orbital wallpaper picker (docs/design/16-orbital.png): thumbnails on a ring around the right-click point
    readonly property real orbitalRadiusX:    300    // the ring is an ellipse (to the thumbnail centres): 12 thumbnails 16:9
    readonly property real orbitalRadiusY:    206    // never overlap their neighbours at any angle
    readonly property real orbitalThumbW:     128
    readonly property real orbitalThumbH:     72     // 16:9
    readonly property real orbitalThumbRadius: 12
    readonly property real orbitalHoverScale: 1.14
    readonly property real orbitalCore:       112    // the dashed disc in the middle
    readonly property real orbitalEdge:      18     // the ring keeps this far from the screen edges
    readonly property int  orbitalMax:        12     // thumbnails on the ring at once; more turn with the wheel
    readonly property real orbitalDash:       3      // dash / gap of the disc border, in stroke widths
    readonly property real orbitalStrip:      10     // the palette preview strip under a hovered thumbnail
    readonly property color orbitalDisc:      alpha(islandInk, 0.72)
    readonly property color orbitalDiscEdge:  Qt.rgba(1, 1, 1, 0.38)
    readonly property color orbitalPill:      alpha(islandInk, 0.82)

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
    readonly property real swatchDot:     14     // Ajustes › the wallpaper palette swatches
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
    readonly property real osdWidthVolume:     268    // content width: ~300 with the notch padding
    readonly property real osdWidthBrightness: 228    // ~260
    readonly property real osdBar:             5
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

    // Gravity launcher (docs/design/02-launcher.png, 03-busqueda.png). Sizes are design px on 1366 × 768; the view
    // scales them by the screen (gravityScale). Rings: favourites (inner) · frequent · all.
    readonly property real gravityDesignW:   1366
    readonly property real gravityDesignH:   768
    readonly property var  gravityRingRx:    [250, 410, 575]
    readonly property var  gravityRingRy:    [82, 136, 192]
    readonly property var  gravityRingNames: ["Favoritos", "Frecuentes", "Todas"]
    readonly property var  gravityRingCap:   [8, 16, 36]      // planets per ring; 60 drawn at most, the rest scroll in «Todas»
    readonly property int  gravityMaxPlanets: 60
    readonly property var  gravityPlanet:    [50, 36, 30]     // base planet size per ring
    readonly property real gravityUseMin:    0.85             // planet size by frecency: 0.85× … 1.25× of the base
    readonly property real gravityUseMax:    1.25
    readonly property real gravityBackScale: 0.68             // at the very back of the ring (sin = −1)
    readonly property real gravityBackOpacity: 0.32
    readonly property real gravityBackBlur:  0.55             // MultiEffect blur at the very back
    readonly property real gravityHoverScale: 1.22
    readonly property var  gravitySpinPeriod: [150000, 210000, 280000]   // ms per turn; alternate directions
    readonly property int  gravityFps:       30               // the core and the ring turn tick together at this rate
    readonly property real gravityMoon:      5
    readonly property real gravityMoonOrbit: 16               // moon orbit diameter = planet + this
    readonly property int  gravityMaxMoons:  3
    readonly property int  gravityGhosts:    20               // non-matching planets while searching
    readonly property real gravityGhost:     30
    readonly property real gravityFieldWidth:  360
    readonly property real gravityFieldHeight: 46
    readonly property real gravityPanelWidth:  300            // results panel (right)
    readonly property real gravityModesWidth:  250            // modes panel (left)
    readonly property real gravityResultRow:   50
    readonly property real gravityEdge:        40             // page margin of the corner labels
    readonly property real gravityNameOffset:  132            // name + detail line, under the core's centre
    readonly property real gravityLabelGap:    14             // ring label after the ring's right end
    readonly property real gravityLegendBottom: 100           // «Luna = ventana abierta» legend, from the bottom
    readonly property real gravityHintsBottom: 36             // key legend, from the bottom
    readonly property real gravityDot:         8              // cyan dot of the title / the moon legend
    readonly property real gravityFieldFont:   17
    readonly property real gravityChip:        26             // counter chip / mode chip / key cap height
    readonly property real gravityDockY:       86             // searching: the chosen match sits this far under the centre
    readonly property real gravityDockPitch:   120            // … the other matches beside it, every this much
    readonly property real gravityDockRise:    8              // … each step a little higher (a shallow arc)
    readonly property real gravityDockMain:    72             // the chosen match, px
    readonly property real gravityDockSide:    50             // the others (−4 per step out)
    readonly property int  gravityDockMax:     7              // matches pulled next to the core
    readonly property real gravityPanelTop:    170            // results / modes panels
    readonly property real gravityPanelPad:    18
    readonly property real gravityPanelRadius: 22
    readonly property real gravityRowRadius:   12
    readonly property real gravityModeRow:     44
    readonly property real gravityHalo:        10             // hovered / selected ring around a planet (size + this)
    readonly property real gravityRingLine:    1
    readonly property color gravityRingStroke: Qt.rgba(1, 1, 1, 0.10)
    readonly property color gravityTile:       alpha(islandInk, 0.78)     // planet base behind the icon, result rows
    readonly property color gravityTileEdge:   Qt.rgba(1, 1, 1, 0.10)
    readonly property color gravityPanel:      alpha(islandInk, 0.72)
    readonly property color gravityGhostFill:  Qt.rgba(1, 1, 1, 0.07)
    readonly property color gravityMatch:      cyan                        // matched letters in the results
    readonly property color gravitySelection:  alpha(cyan, 0.10)
    readonly property color gravitySelectionEdge: alpha(cyan, 0.55)
    // search modes: prefix → chip colour (03-busqueda)
    readonly property color pink:             "#f472b6"   // emoji mode chip, image clipboard entries
    readonly property var  searchModeColors: ({ "=": warn, ">": cyan, "?": violetSoft, ":": pink, "@": ok, "/": warn })
    readonly property int  searchDebounce:   80        // ms after the last key before dragon-search runs (not scaled)
    readonly property color gravityBackdrop: alpha(bg, 0.55)                 // the view's own dim over the scrim

    // Alt+Tab orbital switcher (docs/design/10-alttab.png), design px on 1366 × 768 like the Gravity launcher
    readonly property real switcherRingRx:    470
    readonly property real switcherRingRy:    110
    readonly property real switcherCenterY:   0.42           // ring centre, fraction of the screen height
    readonly property real switcherCard:      440            // the chosen card's width (front)
    readonly property real switcherCardSide:  250            // the others at the sides; the back ones shrink with depth
    readonly property real switcherAspect:    0.5625         // card height / width (16:9; the capture keeps its own ratio)
    readonly property real switcherRadius:    16
    readonly property int  switcherMax:       12             // cards on the ring; more turn with the wheel / Tab
    readonly property int  switcherShowDelay: 150            // ms: Alt released before this = switch without showing anything
    readonly property real switcherChipsTop:  34
    readonly property real switcherTitleGap:  56             // big title under the chosen card
    readonly property color switcherCardFill: alpha(islandInk, 0.86)

    // Gravity clipboard ring (docs/design/12-portapapeles.png)
    readonly property real clipFieldTop:    95             // the search field moves up here
    readonly property real clipCenterY:     0.55           // ring centre, fraction of the screen height
    readonly property real clipRingRx:      470
    readonly property real clipRingRy:      125
    readonly property real clipCard:        400            // the chosen card
    readonly property real clipCardH:       170
    readonly property real clipCardSide:    230            // the others (taller than their share: a few more lines show)
    readonly property real clipCardSideExtra: 30
    readonly property int  clipMax:         8              // cards on the ring at once; more turn with ← → / the wheel
    readonly property real clipFieldWidth:  440
    readonly property var  clipKindColors:  ({ text: textSoft, command: warn, link: cyan, path: violetSoft, color: violetBase, image: pink })

    // Workspaces overview (docs/design/11-escritorios.png)
    readonly property real overviewCardW:     220
    readonly property real overviewCardH:     124
    readonly property real overviewGap:       18
    readonly property real overviewTop:       30
    readonly property real overviewPreviewW:  840            // «VISTA PREVIA» panel under the cards
    readonly property real overviewPreviewTop: 232
    readonly property real overviewRadius:    14
    readonly property color overviewWindow:   alpha(islandInk, 0.86)   // a window drawn as a rectangle
    readonly property color overviewDrop:     cyan

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
    // Motion language (docs/design/15-movimiento.png, same curves as config/hypr/animations.lua).
    // Use with easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveX
    readonly property var curveEmergente: [0.2, 0.9, 0.1, 1.08, 1, 1]   // islands, panels, Nook opening (slight overshoot)
    readonly property var curveEstandar:  [0.3, 0, 0, 1, 1, 1]          // state changes, hover, toggles
    readonly property var curveSalida:    [0.4, 0, 1, 1, 1, 1]          // everything that closes or disappears
    readonly property var curveOrbita:    [0.16, 1.2, 0.3, 1, 1, 1]     // planets: the workspace constellation, launcher, Alt+Tab
    readonly property int durEmerge: ms(340)
    readonly property int durStd:    ms(240)
    readonly property int durOut:    ms(160)
    readonly property int durOrbit:  ms(620)
    readonly property int durOrbitStagger: ms(28)   // orbital picker: delay between two thumbnails appearing
    readonly property int durOrbitFly:     ms(560)  // the chosen thumbnail flies to the centre and covers the screen
    readonly property int durOrbitSpin:    ms(260)  // one wheel step of the ring
    readonly property int durOrbitReveal:  ms(420)  // the screen-sized thumbnail fades over the awww reveal
    readonly property QtObject motion: QtObject {
        readonly property int paleta: root.ms(600)   // the shell blending into a new wallpaper palette
    }

    // display times (how long something stays on screen): NOT scaled by motionScale
    readonly property int durTransient:    2000     // OSD / workspace island states
    readonly property int durOsd:          1600     // volume / brightness / Bloq Mayús OSD in the island
    readonly property int durOsdShort:     1000     // keyboard layout change; Bloq Mayús off lingers 800 ms
    readonly property int durNotice:       2000     // short shell notices in the island ("Copiada · guardada")
    readonly property int durCommandDone:  4000     // a long command / an agent finished
    readonly property int durSpin:         1100     // one turn of the spinner (working agent, running command)
    readonly property int durCaptureHide:  180      // the capture overlay unmaps before grim looks at the screen
    readonly property int durDim:          900      // the idle dim layer rises (Estándar curve)
    readonly property int durNotif:        4000     // notification popups
    readonly property int durPill:         ms(200)  // workspace pill width + color, OutCubic
    readonly property int durHover:        ms(120)  // capsule hover
    readonly property int durFade:         ms(180)  // generic cross-fades

    // Compatibility aliases (DebugPanel and services written in the base phase)
    readonly property real radiusCard: cardRadius
    readonly property int durationToast: durTransient
    readonly property int durationNotif: durNotif
}
