// Small bounded history; redraw only when a sample or geometry changes.
import QtQuick
import "../.."
Canvas {
    id: root
    property var values: []
    property color tone: Theme.cyan
    implicitWidth: Theme.taller.sparkWidth
    implicitHeight: Theme.taller.sparkHeight
    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onToneChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d"); ctx.reset();
        if (!values.length) return;
        const max = Math.max(1, ...values), pad = Theme.taller.sparkStroke;
        ctx.strokeStyle = tone; ctx.lineWidth = pad; ctx.beginPath();
        for (let i = 0; i < values.length; i++) {
            const x = pad + i / Math.max(1, values.length-1) * (width-pad*2);
            const y = height-pad-values[i]/max*(height-pad*2);
            if (i === 0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
        }
        ctx.stroke();
    }
}
