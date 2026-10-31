// The neural core inside Quickshell: NeuralCore (shared/neural-core, also used by SDDM) with the shell's palette and
// timings from Theme (Theme.corePalette, Theme.coreIdentity). Use this everywhere in the shell; pure views that cannot
// import Theme (LockView, LauncherView) pass `palette: tokens.core` to NeuralCore themselves.
import QtQuick
import ".."

NeuralCore {
    palette: Theme.corePalette
    identity: Theme.coreIdentity
}
