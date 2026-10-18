// Tarjeta de frases en ruso para el escritorio (omarchy / Quickshell).
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick 6.11
import qs.Commons
import "phrases.js" as Phrases

Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string configPath: root.home + "/.config/omarchy/russian-phrases.json"
  // Inyectados por el shell (onLoaded): permiten avisar al shell cuando el
  // botón de cierre oculta la tarjeta, igual que hace omarchy.emojis.
  property var shell: null
  property var manifest: null

  // Configuración (sobreescribible en ~/.config/omarchy/russian-phrases.json)
  property int intervalSec: 30
  property string position: "bottom-right" // bottom-right | bottom-left | top-right | top-left
  property int margin: 24
  property int cardWidth: 380
  property real cardOpacity: 0.78
  property bool showHeader: true
  property real fontScale: 1.0
  // Visibilidad gestionada por el SHELL vía SUPER+H (`omarchy-shell shell
  // toggle madmasx.russian-phrases`). Patrón declarativo idéntico a omarchy.emojis:
  // el PanelWindow hace `visible: root.opened` y open()/close() SOLO cambian esta
  // propiedad. NO tocar `win.visible` directamente (causa "Property set multiple
  // times" y la superficie layershell no se re-mapea de forma fiable).
  property bool opened: true

  // Estado
  readonly property var phrases: Phrases.load()
  readonly property int totalCount: root.phrases.length
  property int currentIndex: -1
  property string curRu: ""
  property string curPron: ""
  property string curEs: ""
  property int elapsedSec: 0
  property int secLeft: root.intervalSec

  // Color del tema activo
  readonly property color fg: Color.foreground
  readonly property color accent: Color.accent
  readonly property color muted: Color.muted
  readonly property color bg: Color.background
  readonly property color cardBg: Util.alpha(Color.background, root.cardOpacity)
  readonly property color borderColor: Util.alpha(Color.foreground, 0.16)

  // Posición: esquina o libre (arrastre)
  property real freeX: -1
  property real freeY: -1
  readonly property bool posRight: root.position.indexOf("right") !== -1
  readonly property bool posBottom: root.position.indexOf("bottom") !== -1

  function loadConfig() {
    try {
      var c = JSON.parse(String(configFile.text() || "{}"))
      if (c && typeof c === "object") {
        if (c.intervalSec !== undefined) root.intervalSec = Math.max(5, Math.min(3600, Number(c.intervalSec)))
        if (c.position) root.position = String(c.position)
        if (c.freeX !== undefined) root.freeX = Number(c.freeX)
        if (c.freeY !== undefined) root.freeY = Number(c.freeY)
      }
    } catch (e) { console.warn("russian-phrases: config inválida", e) }
  }

  function saveConfig(payload) {
    try { configFile.setText(payload) }
    catch (e) { console.warn("russian-phrases: no se pudo guardar config", e) }
  }

  function applyPhrase() {
    if (root.totalCount === 0) return
    var ix = Math.floor(Math.random() * root.totalCount)
    while (ix === root.currentIndex && root.totalCount > 1) ix = Math.floor(Math.random() * root.totalCount)
    root.currentIndex = ix
    root.curRu = String(root.phrases[ix].ru || "")
    root.curPron = String(root.phrases[ix].pron || "")
    root.curEs = String(root.phrases[ix].es || "")
    root.elapsedSec = 0
    root.secLeft = root.intervalSec
    console.warn("russian-phrases: [rotación] frase " + (root.currentIndex + 1) + " / " + root.totalCount + " · " + root.curRu)
  }

  // ---- Alternar visibilidad con SUPER + H (omarchy-shell shell toggle
  // madmasx.russian-phrases). El shell oculta/muestra alternando open()/close()
  // sobre el ROOT (entryPoint overlay); patrón IDÉNTICO a omarchy.emojis:
  // open/close/toggle SOLO cambian la propiedad declarativa `root.opened` y el
  // PanelWindow escucha `visible: root.opened`. NUNCA setear win.visible a mano
  // (Quickshell da "Property set multiple times" y la superficie layershell deja
  // de re-mapearse al reabrir → "no abre").
  function open() { root.opened = true }
  function close() { root.opened = false }
  function toggle() { root.opened ? root.close() : root.open() }

  // Botón de cierre (y SUPER+SHIFT+H): oculta la tarjeta y sincroniza el
  // estado del shell para que `omarchy-shell shell summon` la vuelva a abrir.
  function closeCard() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "madmasx.russian-phrases")
  }

  Component.onCompleted: {
    root.loadConfig()
    root.applyPhrase()
  }

  PanelWindow {
    id: win
    visible: root.opened
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.namespace: "madmasx-russian-phrases"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Vidrio esmerilado: esta capa PIDE blur al compositor (Hyprland lo aplica
    // al difuminar lo que hay DETRÁS de la tarjeta — el fondo/escritorio). Como la
    // supercie es transparente salvo la tarjeta, el difuminado luce SOLO ahí.
    // (No toca el texto ni hace que la tarjeta se vuelva sólida: sigue semiopaca
    // y arrastrable.)

    exclusionMode: ExclusionMode.Ignore
    // SOLO la tarjeta es clicable; el resto de la superficie transparente deja
    // pasar los clics al escritorio / omarchy de detrás (cambiar fondo, tema, …).
    mask: clickMask

    Item {
      id: host
      anchors.fill: parent

      // Tarjeta (lo único visible)
      Rectangle {
        id: card
        width: root.cardWidth
        height: contentCol.implicitHeight + 44
        x: root.freeX >= 0 ? root.freeX : (root.posRight ? host.width - card.width - root.margin : root.margin)
        y: root.freeY >= 0 ? root.freeY : (root.posBottom ? host.height - card.height - root.margin : root.margin)
        color: root.cardBg
        radius: 12
        border { color: root.borderColor; width: 1 }
        z: 50

        Column {
          id: contentCol
          width: root.cardWidth - 34
          anchors.left: parent.left
          anchors.leftMargin: 15
          anchors.right: parent.right
          anchors.rightMargin: 15
          anchors.top: parent.top
          anchors.topMargin: 12
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 12
          spacing: 6

          Text {
            width: parent.width
            text: "РУССКИЙ · " + (root.currentIndex + 1) + " / " + root.totalCount
            color: Util.alpha(root.muted, 0.8)
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1.2
          }

          Text {
            width: parent.width
            text: root.curRu
            color: root.fg
            font.pixelSize: 26
            font.bold: true
            wrapMode: Text.Wrap
          }

          Text {
            width: parent.width
            text: root.curPron
            color: Util.alpha(root.muted, 0.7)
            font.pixelSize: 14
            font.italic: true
            wrapMode: Text.Wrap
          }

          Text {
            width: parent.width
            text: root.curEs
            color: root.accent
            font.pixelSize: 16
            wrapMode: Text.Wrap
          }

          Text {
            width: parent.width
            text: "próxima en " + root.secLeft + " s"
            color: Util.alpha(root.muted, 0.55)
            font.pixelSize: 11
          }
        }

        // Botón de cierre: parte de la tarjeta (z:50) para quedar POR DELANTE
        // de la MouseArea de arrastre (hermana, z:0) y recibir el clic.
        Rectangle {
          id: closeBtn
          anchors.top: card.top
          anchors.topMargin: 5
          anchors.right: card.right
          anchors.rightMargin: 5
          width: 24
          height: 24
          radius: 7
          color: closeBtnHover ? Util.alpha(Color.foreground, 0.12) : "transparent"
          property bool closeBtnHover: false

          Text {
            anchors.centerIn: parent
            text: "✕"
            color: Util.alpha(Color.foreground, closeBtn.closeBtnHover ? 0.95 : 0.55)
            font.pixelSize: 12
            font.bold: true
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: closeBtn.closeBtnHover = true
            onExited: closeBtn.closeBtnHover = false
            onClicked: root.closeCard()
          }
        }
      }

      // ARRASTRE FLUIDO 1:1 — la MouseArea es HERMANA de la tarjeta (no hija), anclada
      // al host FIJO. El cursor nunca sale del área durante el arrastre y las
      // coordenadas se miden contra una superficie estable: movimiento exacto 1:1,
      // sin tirones, sin "va detrás", sin retroalimentación.
      // Doble-clic = re-anclar a la posición configurada del JSON.
      MouseArea {
        id: dragArea
        anchors.fill: parent
        cursorShape: Qt.OpenHandCursor
        property point pressPoint
        property point pressCardPos
        property Item rootRef: root
        onPressed: {
          pressPoint = Qt.point(mouse.x, mouse.y)
          pressCardPos = Qt.point(card.x, card.y)
          cursorShape = Qt.ClosedHandCursor
        }
        onPositionChanged: {
          if (!pressed) return
          rootRef.freeX = Math.max(0, Math.min(host.width - card.width, pressCardPos.x + (mouse.x - pressPoint.x)))
          rootRef.freeY = Math.max(0, Math.min(host.height - card.height, pressCardPos.y + (mouse.y - pressPoint.y)))
        }
        onReleased: {
          cursorShape = Qt.OpenHandCursor
          rootRef.saveConfig(JSON.stringify({ freeX: rootRef.freeX, freeY: rootRef.freeY }))
        }
        onDoubleClicked: {
          rootRef.freeX = -1
          rootRef.freeY = -1
          rootRef.saveConfig(JSON.stringify({ freeX: -1, freeY: -1 }))
        }
      }

      // Región clicable = SOLO la tarjeta; el resto del fondo sigue pasando clics.
      Region {
        id: clickMask
        item: card
      }
    }
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadConfig()
    onLoadFailed: root.loadConfig()
  }

  Timer {
    id: cycle
    interval: root.intervalSec * 1000
    repeat: true
    running: root.totalCount > 0
    triggeredOnStart: true
    onTriggered: root.applyPhrase()
  }

  Timer {
    id: clock
    interval: 1000
    repeat: true
    running: root.totalCount > 0
    triggeredOnStart: true
    onTriggered: {
      root.elapsedSec++
      root.secLeft = Math.max(0, root.intervalSec - root.elapsedSec)
    }
  }
}
