// =============================================================================
// dragon-island — Capture.qml
// Service: screenshots from the island (region / window / screen, copy, save, annotate, OCR). Filled in phase 2 §4.
// =============================================================================
/**
 * Properties:
 *   - active: bool [readonly] (the capture bar is open: island state "capture")
 */
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root
    property bool active: false
}
