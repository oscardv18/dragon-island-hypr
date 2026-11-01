// Share a folder on the local network (33-archivos-compartir.png): name, read-only or read-write, guests (off by
// default), copyable addresses for Linux/Mac and Windows, an amber reminder and «Dejar de compartir». The tool
// validates the folder (no $HOME, /, ~/.ssh, ~/.gnupg, ~/.config, system paths) and explains the firewall command
// instead of running it; this view shows what it answers.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "files.js" as F

Item {
    id: root
    property var files: null
    property string path: ""
    property var status: null
    property bool enabledShare: true
    property bool rw: false
    property bool guest: false
    property string error: ""
    property string errorHint: ""
    property bool busy: false
    property string copied: ""
    readonly property string host: status?.host ?? ""
    readonly property string shareName: nameInput.text.trim()
    readonly property string smbAddress: status?.shared && status.addresses?.smb ? status.addresses.smb : (host ? "smb://" + host + "/" + shareName : "")
    readonly property string uncAddress: status?.shared && status.addresses?.unc ? status.addresses.unc : (host ? "\\\\" + host + "\\" + shareName : "")
    signal closed()
    visible: false
    anchors.fill: parent

    function open(p): void {
        path = p; status = null; error = ""; errorHint = ""; copied = ""; busy = true;
        enabledShare = true; rw = false; guest = false;
        nameInput.text = F.basename(p).replace(/[^A-Za-z0-9._-]+/g, "-");
        visible = true;
        files?.refreshShares();
        files?.shareStatus(p, r => {
            root.busy = false;
            if (!r.ok) { root.error = r.error?.message ?? "No se pudo consultar Samba"; root.errorHint = r.error?.hint ?? ""; return; }
            root.status = r;
            if (r.shared) { nameInput.text = r.name; root.rw = !!r.rw; root.guest = !!r.guest; }
        });
        Qt.callLater(() => nameInput.focusInput());
    }
    function close(): void { visible = false; closed(); }
    function apply(): void {
        if (busy || !files) return;
        if (!enabledShare) { stop(); return; }
        if (!shareName) { error = "Escribe un nombre para la red"; return; }
        busy = true; error = ""; errorHint = "";
        files.shareEnable(path, shareName, rw, guest, r => {
            root.busy = false;
            if (!r.ok) { root.error = r.error?.message ?? "No se pudo compartir"; root.errorHint = r.error?.hint ?? ""; return; }
            root.status = Object.assign({ shared: true, host: root.host }, r, { shared: true, name: root.shareName, rw: root.rw, guest: root.guest });
        });
    }
    function stop(): void {
        if (!status?.shared) { close(); return; }
        busy = true;
        files.shareDisable(path, status.name, r => {
            root.busy = false;
            if (!r.ok) { root.error = r.error?.message ?? "No se pudo dejar de compartir"; return; }
            root.close();
        });
    }

    Rectangle { anchors.fill: parent; radius: Theme.files.radius; color: Theme.files.scrim; MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons } }
    Rectangle {
        id: box
        anchors.centerIn: parent
        width: Math.min(Theme.files.dialogWidth, parent.width - Theme.files.padding * 2)
        height: Math.min(layout.implicitHeight + Theme.files.padding * 2 + Theme.files.thinGap, parent.height - Theme.files.padding * 2)
        radius: Theme.files.radius - Theme.files.smallGap
        color: Theme.files.dialog
        border.width: Theme.files.border
        border.color: Theme.files.buttonBorder
        Keys.onEscapePressed: root.close()
        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: Theme.files.padding + Theme.files.thinGap
            spacing: Theme.files.inset
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.files.inset
                Caption { text: "Compartir en la red" }
                Rectangle { Layout.fillWidth: true; height: Theme.files.border; color: Theme.files.divider }
                Caption { text: "Samba · red local" }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.files.inset
                Rectangle {
                    Layout.preferredWidth: Theme.files.navButton; Layout.preferredHeight: Theme.files.navButton
                    radius: Theme.files.chipRadius; color: Theme.files.button
                    Glyph { anchors.centerIn: parent; icon: Icons.folderOutline; size: Theme.files.icon; color: Theme.textSoft }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    UiText { Layout.fillWidth: true; text: F.basename(root.path); size: Theme.files.title + 1; weight: Theme.weightSemiBold }
                    Caption { Layout.fillWidth: true; text: F.displayPath(root.path, root.files?.home ?? "") + (root.status?.size ? " · " + F.formatSize(root.status.size) : ""); font.letterSpacing: Theme.files.captionTracking / 2 }
                }
                ToggleSwitch { checked: root.enabledShare; onToggled: root.enabledShare = !root.enabledShare }
            }
            Caption { text: "Nombre en la red" }
            FilesInput { id: nameInput; Layout.fillWidth: true; mono: true; enabled: root.enabledShare; onAccepted: root.apply(); onEscaped: root.close() }
            Caption { text: "Permisos" }
            FilesSegmented {
                Layout.fillWidth: true
                enabled: root.enabledShare
                value: root.rw ? "rw" : "ro"
                options: [{ value: "ro", label: "Solo lectura" }, { value: "rw", label: "Lectura y escritura" }]
                onChosen: v => root.rw = v === "rw"
            }
            FilesCheck { label: "Permitir el acceso a invitados, sin contraseña"; checked: root.guest; enabled: root.enabledShare; onToggled: root.guest = !root.guest }
            Caption { text: "Direcciones" }
            Repeater {
                model: [{ text: root.smbAddress, os: "Linux · Mac" }, { text: root.uncAddress, os: "Windows" }]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: Theme.files.row + Theme.files.inset - Theme.files.thinGap
                    radius: Theme.files.rowRadius
                    color: Theme.files.card
                    opacity: root.status?.shared ? 1 : Theme.files.disabledOpacity + Theme.files.badgeTint
                    UiText { anchors.left: parent.left; anchors.leftMargin: Theme.files.inset; anchors.right: os.left; anchors.verticalCenter: parent.verticalCenter
                             text: modelData.text || "—"; mono: true; size: Theme.files.small }
                    Caption { id: os; anchors.right: copy.left; anchors.rightMargin: Theme.files.inset; anchors.verticalCenter: parent.verticalCenter; text: modelData.os; font.letterSpacing: Theme.files.captionTracking / 2 }
                    FilesButton {
                        id: copy
                        anchors.right: parent.right; anchors.rightMargin: Theme.files.smallGap; anchors.verticalCenter: parent.verticalCenter
                        implicitHeight: Theme.files.tabsHeight
                        label: root.copied !== "" && root.copied === modelData.text ? "Copiada" : "Copiar"
                        enabled: !!root.status?.shared && !!modelData.text
                        onClicked: { root.files.copyText(modelData.text); root.copied = modelData.text; }
                    }
                }
            }
            // reminder (amber) and whatever the tool reports: forbidden folder, Samba not prepared, firewall
            Notice { text: "Solo se comparte esta carpeta y solo en tu red local. Se puede dejar de compartir con un clic."; tone: Theme.warn }
            Notice { visible: root.error.length > 0; text: root.error + (root.errorHint ? ". " + root.errorHint : ""); tone: Theme.danger }
            Notice {
                visible: !!root.status?.firewall?.needed
                text: (root.status?.firewall?.message ?? "El cortafuegos bloquea Samba. Para abrirlo, ejecuta tú:") + "\n" + (root.status?.firewall?.command ?? "")
                tone: Theme.warn
                mono: true
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.files.inset
                Caption { text: "Carpetas compartidas ahora · " + (root.files?.shares?.length ?? 0) }
                Item { Layout.fillWidth: true }
                FilesButton { label: "Dejar de compartir"; visible: !!root.status?.shared; enabled: !root.busy; onClicked: root.stop() }
                FilesButton { label: root.busy ? "…" : "Aplicar"; primary: true; enabled: !root.busy; onClicked: root.apply() }
            }
        }
    }
    component Caption: UiText {
        mono: true
        size: Theme.files.caption
        color: Theme.textDim
        font.letterSpacing: Theme.files.captionTracking
        font.capitalization: Font.AllUppercase
    }
    component Notice: Rectangle {
        property alias text: noticeText.text
        property color tone: Theme.warn
        property bool mono: false
        Layout.fillWidth: true
        implicitHeight: noticeText.implicitHeight + Theme.files.inset * 1.6
        radius: Theme.files.rowRadius
        color: Theme.alpha(tone, Theme.files.badgeTint / 2)
        border.width: Theme.files.border
        border.color: Theme.alpha(tone, Theme.files.selectedBorder.a)
        UiText {
            id: noticeText
            x: Theme.files.inset; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Theme.files.inset * 2
            size: Theme.files.small
            color: parent.tone
            mono: parent.mono
            wrapMode: Text.Wrap
            maximumLineCount: 4
            leftPadding: Theme.files.inset + Theme.files.thinGap
            Text { text: "!"; color: parent.color; font.pixelSize: parent.font.pixelSize; font.family: Theme.fontUi; font.weight: Font.Bold }
        }
    }
}
