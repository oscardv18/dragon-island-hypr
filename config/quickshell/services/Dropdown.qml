// =============================================================================
// dragon-island — Dropdown.qml
// Service: the drop-down terminal (special:dropdown). Filled in phase 2 §7.
// =============================================================================
/**
 * Properties:
 *   - shown: bool [readonly] (island state "dropdown")
 */
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root
    property bool shown: false
}
