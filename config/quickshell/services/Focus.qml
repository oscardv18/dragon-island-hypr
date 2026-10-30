// =============================================================================
// dragon-island — Focus.qml
// Service: focus mode (DND, minimal bar, muted apps, countdown). Filled in phase 2 §6.
// =============================================================================
/**
 * Properties:
 *   - active: bool [readonly] (island state "focus")
 */
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root
    property bool active: false
}
