// Network view (33-archivos-red.png): hosts found by avahi with their state, «Conectar a un servidor» with an
// address, saved servers as bookmarks and, on the right, the detail of the chosen host with its shares.
// Discovery runs only while this view is on screen (every Theme.files.discoverEvery). Pure: the Devices service
// (or the mock) is injected; passwords are handed over once and go to the keyring through the tool.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "files.js" as F

Item {
    id: root
    property var devices: null
    property var files: null
    property bool active: false
    property var selected: null           // host
    property var shareList: []
    property string shareStatus: ""       // loading | error message | ""
    property string pendingUri: ""        // the address waiting for a user/password
    signal navigate(string path)
    readonly property var hosts: devices?.hosts ?? []
    readonly property int connectedCount: hosts.filter(h => devices?.hostState(h) === "connected").length
    readonly property var authError: pendingUri ? devices?.netErrors?.[pendingUri] ?? null : null
    readonly property bool needsAuth: authError?.code === "auth_required" || authError?.code === "bad_password"

    onActiveChanged: if (active) devices?.discover()
    Timer { interval: Theme.files.discoverEvery; running: root.active; repeat: true; onTriggered: root.devices?.discover() }
    onSelectedChanged: loadShares()
    function loadShares(): void {
        shareList = []; shareStatus = "";
        if (!selected || !devices || selected.protocol !== "smb") return;
        const h = selected;
        shareStatus = "loading";
        devices.shares(h.address || h.name, r => {
            if (root.selected !== h) return;
            if (r.ok) { root.shareList = r.shares ?? []; root.shareStatus = ""; }
            else root.shareStatus = r.error?.message ?? "No se pudieron leer los recursos";
        });
    }
    function connectTo(uri, user, password, save): void {
        if (!uri || !devices) return;
        pendingUri = uri;
        devices.connect(uri, user, password, save, r => {
            if (r.ok) { root.pendingUri = ""; authPassword.text = ""; if (r.mountpoint) root.navigate(r.mountpoint); }
            else if (root.needsAuth) Qt.callLater(() => (authUser.text ? authPassword : authUser).focusInput());
        });
    }
    function hostUri(h): string { return h.uri || (h.protocol + "://" + (h.address || h.name)); }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.files.gap
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.files.inset
            RowLayout {
                Layout.fillWidth: true
                Caption { text: "Red local · " + root.hosts.length + (root.hosts.length === 1 ? " equipo encontrado" : " equipos encontrados") }
                Item { Layout.fillWidth: true }
                Caption {
                    text: root.devices?.netStatus !== "ok" ? "● " + (root.devices?.netMessage ?? "") : root.devices?.discovering ? "● Buscando (avahi)" : "● Actualizado"
                    color: root.devices?.netStatus !== "ok" ? Theme.warn : Theme.cyan
                    Layout.maximumWidth: root.width / 2
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Theme.files.inset
                rowSpacing: Theme.files.inset
                Repeater {
                    model: root.hosts
                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        readonly property string state: root.devices?.hostState(modelData) ?? "available"
                        readonly property bool isSel: root.selected?.name === modelData.name && root.selected?.protocol === modelData.protocol
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: Theme.files.hostCard
                        radius: Theme.files.buttonRadius
                        color: isSel ? Theme.files.selected : cardHit.containsMouse ? Theme.files.hover : Theme.files.card
                        border.width: Theme.files.border
                        border.color: isSel ? Theme.files.selectedBorder : Theme.files.buttonBorder
                        Rectangle {
                            id: iconBox
                            x: Theme.files.inset; anchors.verticalCenter: parent.verticalCenter
                            width: Theme.files.navButton + Theme.files.smallGap; height: width
                            radius: Theme.files.chipRadius
                            color: Theme.files.button
                            Glyph { anchors.centerIn: parent; size: Theme.files.icon + 1; color: Theme.textSoft
                                icon: card.modelData.protocol === "ipp" ? Icons.printer : card.modelData.kind === "pc" ? Icons.monitor : Icons.server }
                        }
                        Column {
                            anchors.left: iconBox.right; anchors.leftMargin: Theme.files.inset
                            anchors.right: chip.left; anchors.rightMargin: Theme.files.smallGap
                            anchors.verticalCenter: parent.verticalCenter
                            UiText { width: parent.width; text: card.modelData.name; size: Theme.files.body; weight: Theme.weightSemiBold }
                            UiText { width: parent.width; text: (card.modelData.protocol ?? "").toUpperCase() + " · " + (card.modelData.address ?? ""); mono: true; size: Theme.files.caption; color: Theme.textDim }
                        }
                        StateChip { id: chip; anchors.right: parent.right; anchors.rightMargin: Theme.files.inset; anchors.verticalCenter: parent.verticalCenter; state: card.state }
                        MouseArea {
                            id: cardHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.selected = card.modelData
                            onDoubleClicked: { const m = root.devices?.mountFor(card.modelData); if (m?.path) root.navigate(m.path); else if (card.modelData.protocol !== "ipp") root.connectTo(root.hostUri(card.modelData)); }
                        }
                    }
                }
            }
            UiText {
                visible: root.hosts.length === 0
                Layout.fillWidth: true
                text: root.devices?.discovering ? "Buscando equipos en la red local…" : root.devices?.netStatus === "ok" ? "No se ha encontrado ningún equipo. Puedes conectar escribiendo su dirección." : ""
                size: Theme.files.body; color: Theme.textDim; wrapMode: Text.Wrap; maximumLineCount: 2
            }
            Caption { Layout.topMargin: Theme.files.smallGap; text: "Conectar a un servidor" }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.files.inset
                FilesInput { id: address; Layout.fillWidth: true; mono: true; placeholder: "smb://equipo/recurso"; onAccepted: root.connectTo(text.trim()) }
                FilesButton { label: root.devices?.netBusy?.[address.text.trim()] === "connect" ? "Conectando…" : "Conectar"; primary: true; enabled: address.text.trim().length > 0; onClicked: root.connectTo(address.text.trim()) }
            }
            // credentials, only when the server asked for them
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.needsAuth
                spacing: Theme.files.smallGap
                UiText { Layout.fillWidth: true; text: (root.authError?.message ?? "") + " · " + root.pendingUri; size: Theme.files.small; color: Theme.warn }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.files.inset
                    FilesInput { id: authUser; Layout.fillWidth: true; placeholder: "Usuario"; mono: true; onAccepted: authPassword.focusInput() }
                    FilesInput { id: authPassword; Layout.fillWidth: true; placeholder: "Contraseña"; password: true; mono: true
                                 onAccepted: root.connectTo(root.pendingUri, authUser.text, authPassword.text, saveCheck.checked) }
                }
                FilesCheck { id: saveCheck; label: "Guardar la contraseña en el llavero del sistema"; checked: true; onToggled: checked = !checked }
            }
            UiText {
                Layout.fillWidth: true
                visible: !root.needsAuth && !!root.authError
                text: root.authError?.message ?? ""
                size: Theme.files.small; color: Theme.danger; wrapMode: Text.Wrap; maximumLineCount: 2
            }
            UiText { Layout.fillWidth: true; text: "smb:// · sftp:// · nfs:// · ftp:// · webdav:// · davs:// · Las contraseñas las guarda el llavero del sistema."; mono: true; size: Theme.files.caption; color: Theme.textDim; elide: Text.ElideRight }
            Caption { Layout.topMargin: Theme.files.smallGap; text: "Marcadores"; visible: root.bookmarks.length > 0 }
            Flow {
                Layout.fillWidth: true
                spacing: Theme.files.inset
                Repeater {
                    model: root.bookmarks
                    delegate: FilesButton {
                        required property var modelData
                        label: modelData.name
                        onClicked: root.connectTo(modelData.uri)
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }

        // ---- detail of the chosen host ----
        Rectangle {
            Layout.preferredWidth: Theme.files.previewWidth
            Layout.fillHeight: true
            radius: Theme.files.radius - Theme.files.inset
            color: Theme.files.card
            border.width: Theme.files.border
            border.color: Theme.files.buttonBorder
            readonly property var host: root.selected
            readonly property var mount: host ? root.devices?.mountFor(host) ?? null : null
            UiText { anchors.centerIn: parent; visible: !parent.host; text: "Elige un equipo"; color: Theme.textDim; size: Theme.files.body }
            ColumnLayout {
                id: detail
                visible: !!parent.host
                anchors.fill: parent
                anchors.margins: Theme.files.padding - Theme.files.thinGap
                spacing: Theme.files.gap
                readonly property var host: parent.host
                readonly property var mount: parent.mount
                RowLayout {
                    spacing: Theme.files.inset
                    Rectangle { Layout.preferredWidth: Theme.files.navButton + Theme.files.smallGap; Layout.preferredHeight: Layout.preferredWidth; radius: Theme.files.buttonRadius; color: Theme.files.button
                        Glyph { anchors.centerIn: parent; icon: detail.host?.protocol === "ipp" ? Icons.printer : Icons.server; size: Theme.files.title + Theme.files.thinGap; color: Theme.ok } }
                    ColumnLayout {
                        spacing: 0
                        UiText { text: detail.host?.name ?? ""; size: Theme.files.title; weight: Theme.weightSemiBold }
                        UiText { text: (detail.host?.protocol ?? "").toUpperCase() + " · " + (detail.mount ? "MONTADO" : ({ saved: "GUARDADO", printer: "IMPRESORA" })[root.devices?.hostState(detail.host ?? {})] ?? "DISPONIBLE")
                                 mono: true; size: Theme.files.caption; color: detail.mount ? Theme.ok : Theme.textDim }
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Theme.files.gap
                    rowSpacing: Theme.files.smallGap
                    Meta { label: "Protocolo"; value: (detail.host?.protocol ?? "").toUpperCase() + (detail.mount?.version ? " " + detail.mount.version : "") }
                    Meta { label: "Dirección"; value: detail.host?.address ?? "—" }
                    Meta { label: "Usuario"; value: detail.mount?.user ?? "—" }
                    Meta { label: "Espacio libre"; value: detail.mount?.free ? F.formatSize(detail.mount.free) : "—" }
                }
                Caption { text: "Recursos compartidos"; visible: detail.host?.protocol === "smb" }
                UiText { Layout.fillWidth: true; visible: root.shareStatus.length > 0; text: root.shareStatus === "loading" ? "Preguntando al servidor…" : root.shareStatus
                         size: Theme.files.small; color: root.shareStatus === "loading" ? Theme.textDim : Theme.warn; wrapMode: Text.Wrap; maximumLineCount: 3 }
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: sharesColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: sharesColumn
                        width: parent.width
                        spacing: Theme.files.smallGap
                        Repeater {
                            model: root.shareList
                            delegate: Rectangle {
                                required property var modelData
                                width: sharesColumn.width
                                height: Theme.files.row + Theme.files.smallGap
                                radius: Theme.files.rowRadius
                                color: shareHit.containsMouse ? Theme.files.hover : Theme.files.rowAlt
                                Glyph { id: shareIcon; x: Theme.files.inset; anchors.verticalCenter: parent.verticalCenter; icon: Icons.folderOutline; size: Theme.files.icon; color: Theme.textSoft }
                                UiText { anchors.left: shareIcon.right; anchors.leftMargin: Theme.files.inset; anchors.right: shareSize.left; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; size: Theme.files.body }
                                UiText { id: shareSize; anchors.right: parent.right; anchors.rightMargin: Theme.files.inset; anchors.verticalCenter: parent.verticalCenter
                                         text: modelData.size ? F.formatSize(modelData.size) : (modelData.comment ?? ""); mono: true; size: Theme.files.caption; color: Theme.textDim }
                                MouseArea { id: shareHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.connectTo("smb://" + (detail.host.address || detail.host.name) + "/" + modelData.name) }
                            }
                        }
                    }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: Theme.files.inset
                    visible: detail.host?.protocol !== "ipp"
                    FilesButton { label: detail.mount ? "Abrir" : "Conectar"; primary: true
                                  onClicked: { if (detail.mount?.path) root.navigate(detail.mount.path); else root.connectTo(root.hostUri(detail.host)); } }
                    FilesButton { label: "Desmontar"; visible: !!detail.mount; onClicked: root.devices.unmountNet(detail.mount.uri) }
                    FilesButton { label: "Marcador"; onClicked: root.devices.saveServer(detail.mount?.uri ?? root.hostUri(detail.host), detail.host.name) }
                }
            }
        }
    }
    readonly property var bookmarks: (devices?.servers ?? []).map(s => ({ uri: s.uri, name: s.name || s.uri }))

    component Caption: UiText {
        mono: true
        size: Theme.files.caption
        color: Theme.textDim
        font.letterSpacing: Theme.files.captionTracking
        font.capitalization: Font.AllUppercase
    }
    component Meta: ColumnLayout {
        property string label
        property string value
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: 0
        UiText { Layout.fillWidth: true; text: parent.label; mono: true; size: Theme.files.caption; color: Theme.textDim; font.letterSpacing: Theme.files.captionTracking / 2; font.capitalization: Font.AllUppercase }
        UiText { Layout.fillWidth: true; text: parent.value; mono: true; size: Theme.files.mono; color: Theme.text }
    }
    component StateChip: Rectangle {
        property string state: "available"
        readonly property color tone: ({ connected: Theme.ok, available: Theme.cyan })[state] ?? Theme.textDim
        width: chipText.implicitWidth + Theme.files.inset * 2
        height: chipText.implicitHeight + Theme.files.smallGap
        radius: Theme.files.chipRadius
        color: Theme.alpha(tone, Theme.files.badgeTint / 2)
        border.width: Theme.files.border
        border.color: Theme.alpha(tone, Theme.files.selectedBorder.a / 2)
        UiText { id: chipText; anchors.centerIn: parent; mono: true; size: Theme.files.caption; color: parent.tone; font.letterSpacing: Theme.files.captionTracking / 2
                 text: ({ connected: "CONECTADO", available: "DISPONIBLE", saved: "GUARDADO", printer: "IMPRESORA" })[parent.state] ?? "" }
    }
}
