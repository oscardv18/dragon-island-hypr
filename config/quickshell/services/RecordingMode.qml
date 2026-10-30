// =============================================================================
// dragon-island — RecordingMode.qml
// Service: recording mode (rules while the screen is recorded or shared). Filled in phase 2 §5.
// =============================================================================
/**
 * Properties:
 *   - active: bool [readonly] (island state "recording")
 */
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root
    readonly property bool active: false
}
