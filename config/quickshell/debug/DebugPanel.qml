// =============================================================================
// dragon-island — DebugPanel.qml
// Diagnostic plain-text window verifying all 13 Quickshell services.
// =============================================================================
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".." as Root
import "../services" as Svc

FloatingWindow {
    id: win
    title: "dragon-island — Service Diagnostics & Verification"
    width: 960
    height: 800
    color: Root.Theme.bg

    Flickable {
        anchors.fill: parent
        contentWidth: column.width
        contentHeight: column.implicitHeight + 40
        clip: true

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        ColumnLayout {
            id: column
            width: win.width - 40
            x: 20
            y: 20
            spacing: 16

            // Header banner
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                radius: Root.Theme.radiusCard
                color: Root.Theme.surface0
                border.color: Root.Theme.accent
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16

                    ColumnLayout {
                        Text {
                            text: "DRAGON-ISLAND — ESTADO DE SERVICIOS"
                            font.family: Root.Theme.fontUi
                            font.pixelSize: Root.Theme.sizeTitle
                            font.weight: Root.Theme.weightBold
                            color: Root.Theme.text
                        }
                        Text {
                            text: "Fase Base — Verificación de Singletons y APIs de Quickshell 0.3.1"
                            font.family: Root.Theme.fontUi
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textDim
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: Svc.Clock.timeWithSeconds
                        font.family: Root.Theme.fontMono
                        font.pixelSize: Root.Theme.sizeGreeting
                        font.weight: Root.Theme.weightBold
                        color: Root.Theme.cyan
                    }
                }
            }

            // Grid of service cards
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 12
                columnSpacing: 12

                // 1. Hypr Service
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    radius: Root.Theme.radiusCard
                    color: Root.Theme.surface1
                    border.color: Root.Theme.outline
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4

                        Text {
                            text: "1. Hypr (Compositor IPC)"
                            font.family: Root.Theme.fontUi
                            font.pixelSize: Root.Theme.sizeBody
                            font.weight: Root.Theme.weightBold
                            color: Root.Theme.accent
                        }
                        Text {
                            text: `Workspace activo: ${Svc.Hypr.focusedWorkspaceId} (${Svc.Hypr.focusedWorkspaceName}) | Modo Lua: ${Svc.Hypr.usingLua}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.text
                        }
                        Text {
                            text: `Ventana activa: [${Svc.Hypr.activeClass || "ninguna"}] ${Svc.Hypr.activeTitle || "vacío"}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textSoft
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: `Espacios (1-5): ${Svc.Hypr.workspaces.map(w => `${w.id}:${w.occupied ? "ocupado" : "vacío"}${w.active ? "(activo)" : ""}`).join(" | ")}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textDim
                        }
                    }
                }

                // 2. Audio Service
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    radius: Root.Theme.radiusCard
                    color: Root.Theme.surface1
                    border.color: Root.Theme.outline
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4

                        Text {
                            text: "2. Audio (PipeWire)"
                            font.family: Root.Theme.fontUi
                            font.pixelSize: Root.Theme.sizeBody
                            font.weight: Root.Theme.weightBold
                            color: Root.Theme.cyan
                        }
                        Text {
                            text: `Salida: ${Svc.Audio.sinkName}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.text
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: `Volumen: ${Svc.Audio.volumePct}% | Silenciado: ${Svc.Audio.muted ? "SÍ" : "NO"}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textSoft
                        }
                        Text {
                            text: `Micrófono: ${Svc.Audio.sourceName} (${Svc.Audio.micVolumePct}%, ${Svc.Audio.micMuted ? "Mute" : "Activo"})`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textDim
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                // 3. Media Service
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    radius: Root.Theme.radiusCard
                    color: Root.Theme.surface1
                    border.color: Root.Theme.outline
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4

                        Text {
                            text: "3. Media (MPRIS)"
                            font.family: Root.Theme.fontUi
                            font.pixelSize: Root.Theme.sizeBody
                            font.weight: Root.Theme.weightBold
                            color: Root.Theme.violet
                        }
                        Text {
                            text: `Reproductor: ${Svc.Media.identity || "Ninguno"} | Estado: ${Svc.Media.isPlaying ? "Reproduciendo" : "Pausado"}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.text
                        }
                        Text {
                            text: `Pista: ${Svc.Media.title || "Sin pista activa"}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textSoft
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: `Artista: ${Svc.Media.artist || "Desconocido"} | Álbum: ${Svc.Media.album || "Desconocido"}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textDim
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                // 4. Network Service
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    radius: Root.Theme.radiusCard
                    color: Root.Theme.surface1
                    border.color: Root.Theme.outline
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4

                        Text {
                            text: "4. Network (NetworkManager)"
                            font.family: Root.Theme.fontUi
                            font.pixelSize: Root.Theme.sizeBody
                            font.weight: Root.Theme.weightBold
                            color: Root.Theme.ok
                        }
                        Text {
                            text: `Wi-Fi Habilitado: ${Svc.Network.wifiEnabled ? "SÍ" : "NO"} | Conectado: ${Svc.Network.connected ? "SÍ" : "NO"}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.text
                        }
                        Text {
                            text: `Red actual: ${Svc.Network.ssid} (${Svc.Network.signalPct}%)`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textSoft
                        }
                        Text {
                            text: `Conectividad: ${Svc.Network.connectivityString} | Redes Wi-Fi detectadas: ${Svc.Network.wifiNetworks.length}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textDim
                        }
                    }
                }

                // 5. Bluetooth Service
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    radius: Root.Theme.radiusCard
                    color: Root.Theme.surface1
                    border.color: Root.Theme.outline
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4

                        Text {
                            text: "5. Bluetooth (BlueZ)"
                            font.family: Root.Theme.fontUi
                            font.pixelSize: Root.Theme.sizeBody
                            font.weight: Root.Theme.weightBold
                            color: Root.Theme.cyan
                        }
                        Text {
                            text: `Adaptador disponible: ${Svc.Bluetooth.adapterAvailable ? "SÍ" : "NO"} | Encendido: ${Svc.Bluetooth.enabled ? "SÍ" : "NO"}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.text
                        }
                        Text {
                            text: `Dispositivo conectado: ${Svc.Bluetooth.connectedDeviceName || "Ninguno"} ${Svc.Bluetooth.hasBattery ? `(Batería: ${Svc.Bluetooth.connectedBatteryPct}%)` : ""}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textSoft
                        }
                        Text {
                            text: `Dispositivos emparejados: ${Svc.Bluetooth.pairedDevices.length} | Conectados: ${Svc.Bluetooth.connectedDevices.length}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textDim
                        }
                    }
                }

                // 6. Power Service
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    radius: Root.Theme.radiusCard
                    color: Root.Theme.surface1
                    border.color: Root.Theme.outline
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4

                        Text {
                            text: "6. Power (UPower & Profiles)"
                            font.family: Root.Theme.fontUi
                            font.pixelSize: Root.Theme.sizeBody
                            font.weight: Root.Theme.weightBold
                            color: Root.Theme.warn
                        }
                        Text {
                            text: `Tiene batería: ${Svc.Power.hasBattery ? "SÍ" : "NO (Sobremesa)"} | Carga: ${Svc.Power.batteryPct}% (${Svc.Power.stateString})`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.text
                        }
                        Text {
                            text: `Perfil de energía: ${Svc.Power.currentProfileString}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textSoft
                        }
                        Text {
                            text: `Tiempo restante: ${Svc.Power.timeRemainingFormatted || "N/A"} | Salud: ${Svc.Power.healthPct}% | Consumo: ${Svc.Power.changeRateWatts}W`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textDim
                        }
                    }
                }

                // 7. Brightness Service
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    radius: Root.Theme.radiusCard
                    color: Root.Theme.surface1
                    border.color: Root.Theme.outline
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4

                        Text {
                            text: "7. Brightness (brightnessctl)"
                            font.family: Root.Theme.fontUi
                            font.pixelSize: Root.Theme.sizeBody
                            font.weight: Root.Theme.weightBold
                            color: Root.Theme.warn
                        }
                        Text {
                            text: `Nivel de brillo actual: ${Svc.Brightness.brightnessPct}% (${Svc.Brightness.brightnessReal.toFixed(2)})`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.text
                        }
                        Text {
                            text: "Controlado mediante llamadas no bloqueantes a brightnessctl."
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textDim
                        }
                    }
                }

                // 8. SysStats Service
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    radius: Root.Theme.radiusCard
                    color: Root.Theme.surface1
                    border.color: Root.Theme.outline
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4

                        Text {
                            text: "8. SysStats (CPU, RAM, Temp, Disco)"
                            font.family: Root.Theme.fontUi
                            font.pixelSize: Root.Theme.sizeBody
                            font.weight: Root.Theme.weightBold
                            color: Root.Theme.cyan
                        }
                        Text {
                            text: `CPU: ${Svc.SysStats.cpuPct}% | Temperatura: ${Svc.SysStats.tempC}°C`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.text
                        }
                        Text {
                            text: `RAM: ${Svc.SysStats.memPct}% (${Svc.SysStats.memUsedGb}G / ${Svc.SysStats.memTotalGb}G)`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textSoft
                        }
                        Text {
                            text: `Disco (/): ${Svc.SysStats.diskPct}% (${Svc.SysStats.diskUsedGb}G / ${Svc.SysStats.diskTotalGb}G)`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textDim
                        }
                    }
                }

                // 9. Notifs Service
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    radius: Root.Theme.radiusCard
                    color: Root.Theme.surface1
                    border.color: Root.Theme.outline
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4

                        Text {
                            text: "9. Notifs (NotificationServer)"
                            font.family: Root.Theme.fontUi
                            font.pixelSize: Root.Theme.sizeBody
                            font.weight: Root.Theme.weightBold
                            color: Root.Theme.accent
                        }
                        Text {
                            text: `Modo No Molestar (DND): ${Svc.Notifs.dnd ? "ACTIVO" : "INACTIVO"}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.text
                        }
                        Text {
                            text: `Notificaciones no leídas: ${Svc.Notifs.unreadCount}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textSoft
                        }
                        Text {
                            text: `Última: ${Svc.Notifs.latestNotification ? `[${Svc.Notifs.latestNotification.appName}] ${Svc.Notifs.latestNotification.summary}` : "Sin notificaciones recientes"}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textDim
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                // 10. Osd Service
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    radius: Root.Theme.radiusCard
                    color: Root.Theme.surface1
                    border.color: Root.Theme.outline
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4

                        Text {
                            text: "10. Osd (On-Screen Display)"
                            font.family: Root.Theme.fontUi
                            font.pixelSize: Root.Theme.sizeBody
                            font.weight: Root.Theme.weightBold
                            color: Root.Theme.warn
                        }
                        Text {
                            text: `Visible: ${Svc.Osd.visible ? "SÍ" : "NO"} | Icono: ${Svc.Osd.icon || "ninguno"}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.text
                        }
                        Text {
                            text: `Etiqueta: ${Svc.Osd.label || "N/A"} | Valor: ${(Svc.Osd.value * 100).toFixed(0)}%`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textSoft
                        }
                        Text {
                            text: `Silenciado: ${Svc.Osd.isMuted ? "SÍ" : "NO"}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textDim
                        }
                    }
                }

                // 11. Toggles Service
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    radius: Root.Theme.radiusCard
                    color: Root.Theme.surface1
                    border.color: Root.Theme.outline
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4

                        Text {
                            text: "11. Toggles (Conmutadores Rápidos)"
                            font.family: Root.Theme.fontUi
                            font.pixelSize: Root.Theme.sizeBody
                            font.weight: Root.Theme.weightBold
                            color: Root.Theme.ok
                        }
                        Text {
                            text: `Wi-Fi: ${Svc.Toggles.wifi ? "ON" : "OFF"} | Bluetooth: ${Svc.Toggles.bluetooth ? "ON" : "OFF"}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.text
                        }
                        Text {
                            text: `DND: ${Svc.Toggles.dnd ? "ON" : "OFF"} | Luz Nocturna: ${Svc.Toggles.nightLight ? "ON" : "OFF"}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textSoft
                        }
                        Text {
                            text: `Grabación de pantalla: ${Svc.Toggles.isRecording ? "GRABANDO" : "Inactiva"}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textDim
                        }
                    }
                }

                // 12. Apps Service
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    radius: Root.Theme.radiusCard
                    color: Root.Theme.surface1
                    border.color: Root.Theme.outline
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4

                        Text {
                            text: "12. Apps (Lanzador DesktopEntries)"
                            font.family: Root.Theme.fontUi
                            font.pixelSize: Root.Theme.sizeBody
                            font.weight: Root.Theme.weightBold
                            color: Root.Theme.violet
                        }
                        Text {
                            text: `Aplicaciones instaladas indexadas: ${Svc.Apps.count}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.text
                        }
                        Text {
                            text: `Primeras: ${Svc.Apps.list.slice(0, 3).map(a => a.name).join(", ")}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textDim
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                // 13. Clock & ShellState
                Rectangle {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Layout.preferredHeight: 110
                    radius: Root.Theme.radiusCard
                    color: Root.Theme.surface0
                    border.color: Root.Theme.outline
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 6

                        Text {
                            text: "13. Clock & ShellState (IPC)"
                            font.family: Root.Theme.fontUi
                            font.pixelSize: Root.Theme.sizeBody
                            font.weight: Root.Theme.weightBold
                            color: Root.Theme.accent
                        }
                        Text {
                            text: `Saludo: "${Svc.Clock.greeting}" | Fecha: ${Svc.Clock.fullDate} | Uptime: ${Svc.Clock.uptimeFormatted || "Calculando..."}`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.text
                        }
                        Text {
                            text: `ShellState.openPanel: "${Root.ShellState.openPanel}" (Target IPC: "shell", funciones: toggle, open, close, current)`
                            font.family: Root.Theme.fontMono
                            font.pixelSize: Root.Theme.sizeCaption
                            color: Root.Theme.textSoft
                        }
                    }
                }
            }
        }
    }
}
