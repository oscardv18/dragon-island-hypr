// =============================================================================
// dragon-island — NotifFx.qml
// Service: the choreography of a notification leaving the island (docs/design/28-emergentes.png).
// The drop crosses two layer windows without breaking «one blur region per window»: the ISLAND window (dragon-island,
// full width, never blurred) draws the 12 px cyan drop travelling between the notch and the card; the card's own
// window (dragon-notifications) draws the trace, the fill and the content. This service only holds the flights and
// tells each side when the other one is done.
//
//   arrival   island widens + cyan halo (IslandState "notification") → launch(): drop island → card top (440 ms, orbita)
//             → landed(id): the card traces its outline (320 ms), fills (300 ms, emergente), rows in (45 ms apart),
//             a light band sweeps once, then the 2 px time line shrinks (hover pauses it)
//   leaving   content out (120 ms) → collapse to a line (200 ms, salida) → recall(): the drop flies back (320 ms)
//             → home(id): the island pulses «Guardada en el centro»
// =============================================================================
/**
 * Properties:
 *   - flights: list<var> [readonly] ({ id, screen, x, y, dir: "out" | "in", born }; x / y = the card's top centre)
 *   - ready: var [readonly] (notification id → true once its drop has landed: the card may draw)
 *
 * Functions:
 *   - launch(id, screen: string, x: real, y: real): void (the card asks for its drop)
 *   - landed(id): void (the island's drop reached the card)
 *   - recall(id, screen: string, x: real, y: real): void (the collapsed card sends its drop home)
 *   - home(id): void (the drop is back: island pulse)
 *   - isReady(id): bool
 */
pragma Singleton
import Quickshell
import QtQuick
import ".."

Singleton {
    id: root

    property var flights: []
    property var ready: ({})

    function _drop(id): void { root.flights = root.flights.filter(f => f.id !== id); }

    function launch(id, screen: string, x: real, y: real): void {
        if (Settings.calmMotion || !Theme.animationsEnabled) { root.landed(id); return; }
        root._drop(id);
        root.flights = root.flights.concat([{ id: id, screen: screen, x: x, y: y, dir: "out", born: Date.now() }]);
    }
    function landed(id): void {
        root._drop(id);
        const r = Object.assign({}, root.ready);
        r[id] = true;
        root.ready = r;
    }
    function recall(id, screen: string, x: real, y: real): void {
        const r = Object.assign({}, root.ready);
        delete r[id];
        root.ready = r;
        if (Settings.calmMotion || !Theme.animationsEnabled) { root.home(id); return; }
        root._drop(id);
        root.flights = root.flights.concat([{ id: id, screen: screen, x: x, y: y, dir: "in", born: Date.now() }]);
    }
    function home(id): void {
        root._drop(id);
        IslandState.notice("Guardada en el centro", "bell", Theme.durNotice);
    }
    function isReady(id): bool { return root.ready[id] === true; }
}
