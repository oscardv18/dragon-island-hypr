// =============================================================================
// dragon-island — Icons.qml
// Nerd Font glyphs (Material Design "nf-md-*" set, rendered with Theme.fontMono).
// Components use names from here, never raw code points.
// =============================================================================
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root

    function g(cp: int): string { return String.fromCodePoint(cp); }

    // Brand / launcher
    readonly property string apps:          g(0xF003B)
    readonly property string search:        g(0xF0349)
    readonly property string shuffle:       g(0xF049D)
    readonly property string folder:        g(0xF024B)
    readonly property string dashboard:     g(0xF056E)

    // System
    readonly property string cpu:           g(0xF061A)
    readonly property string memory:        g(0xF035B)
    readonly property string gpu:           g(0xF08AE)
    readonly property string thermometer:   g(0xF050F)
    readonly property string disk:          g(0xF02CA)

    // Network
    readonly property string wifiOff:       g(0xF092E)
    readonly property var    wifiLevels:    [g(0xF092B), g(0xF091F), g(0xF0922), g(0xF0925), g(0xF0928)]
    readonly property string ethernet:      g(0xF0200)
    readonly property string lock:          g(0xF033E)
    readonly property string lockOpen:      g(0xF033F)

    // Bluetooth
    readonly property string bluetooth:     g(0xF00AF)
    readonly property string btConnected:   g(0xF00B1)
    readonly property string btOff:         g(0xF00B2)
    readonly property string headphones:    g(0xF02CB)

    // Audio
    readonly property string volumeHigh:    g(0xF057E)
    readonly property string volumeLow:     g(0xF057F)
    readonly property string volumeMid:     g(0xF0580)
    readonly property string volumeOff:     g(0xF0581)
    readonly property string mic:           g(0xF036C)
    readonly property string micOff:        g(0xF036D)
    readonly property string speaker:       g(0xF04C3)

    // Power / battery
    readonly property var    batteryLevels: [g(0xF008E), g(0xF007A), g(0xF007B), g(0xF007C), g(0xF007D), g(0xF007E),
                                             g(0xF007F), g(0xF0080), g(0xF0081), g(0xF0082), g(0xF0079)]
    readonly property string batteryCharging: g(0xF0084)
    readonly property string batteryAlert:  g(0xF0083)
    readonly property string bolt:          g(0xF140B)
    readonly property string leaf:          g(0xF032A)
    readonly property string balance:       g(0xF05D1)
    readonly property string rocket:        g(0xF14DE)
    readonly property string sun:           g(0xF05A8)

    // Notifications
    readonly property string bell:          g(0xF009A)
    readonly property string bellOff:       g(0xF009B)
    readonly property string bellRing:      g(0xF009E)
    readonly property string broom:         g(0xF00E2)

    // Media
    readonly property string play:          g(0xF040A)
    readonly property string pause:         g(0xF03E4)
    readonly property string next:          g(0xF04AD)
    readonly property string previous:      g(0xF04AE)
    readonly property string music:         g(0xF075A)

    // Toggles
    readonly property string nightLight:    g(0xF0594)
    readonly property string camera:        g(0xF0100)
    readonly property string record:        g(0xF044A)

    // Session
    readonly property string sleep:         g(0xF04B2)
    readonly property string power:         g(0xF0425)
    readonly property string restart:       g(0xF0709)
    readonly property string logout:        g(0xF0343)

    // Generic
    readonly property string close:         g(0xF0156)
    readonly property string check:         g(0xF012C)
    readonly property string chevronRight:  g(0xF0142)
    readonly property string chevronLeft:   g(0xF0141)
    readonly property string refresh:       g(0xF0450)
    readonly property string cog:           g(0xF0493)
    readonly property string keyboard:      g(0xF030C)
    readonly property string shield:        g(0xF0565)   // VPN
    readonly property string coffee:        g(0xF0176)   // caffeine
    readonly property string microphone:    g(0xF036C)
    readonly property string webcam:        g(0xF0567)
    readonly property string screenShare:   g(0xF0E51)
    readonly property string arrowDown:     g(0xF0045)
    readonly property string arrowUp:       g(0xF005D)
    readonly property string update:        g(0xF06B0)
    readonly property string pin:           g(0xF0403)
    readonly property string pinOff:        g(0xF0404)
    readonly property string windowFloat:   g(0xF0E58)
    readonly property string dots:          g(0xF01D8)
    readonly property string calendar:      g(0xF00ED)
    readonly property string clock:         g(0xF0150)
    readonly property string desktop:       g(0xF01C4)
    readonly property string window:        g(0xF05AF)

    // Helpers
    function wifiFor(strength: real, enabled: bool): string {
        if (!enabled) return wifiOff;
        return wifiLevels[Math.max(0, Math.min(4, Math.ceil(strength * 4)))];
    }

    function batteryFor(pct: int, charging: bool): string {
        if (charging) return batteryCharging;
        return batteryLevels[Math.max(0, Math.min(10, Math.round(pct / 10)))];
    }

    function volumeFor(v: real, muted: bool): string {
        if (muted || v <= 0) return volumeOff;
        return v < 0.34 ? volumeLow : (v < 0.67 ? volumeMid : volumeHigh);
    }

    // Osd.icon semantic names → glyph
    function named(name: string): string {
        switch (name) {
            case "volume-high": return volumeHigh;
            case "volume-low":  return volumeLow;
            case "volume-off":  return volumeOff;
            case "mic":         return mic;
            case "mic-off":     return micOff;
            case "sun":         return sun;
            default:            return "";
        }
    }
}
