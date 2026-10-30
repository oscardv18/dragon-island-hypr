// =============================================================================
// dragon-island — Idle.qml
// Service: the idle sequence (warning, dim, lock, screens off, suspend). Filled in phase 2 §8.
// =============================================================================
/**
 * Properties:
 *   - warning: bool [readonly] (island state "idleWarn")
 */
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root
    property bool warning: false
}
