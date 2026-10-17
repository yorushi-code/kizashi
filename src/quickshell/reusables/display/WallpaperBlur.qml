import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../"
import "../"
import "glassNesting.js" as Nesting

Item {
    id: root

    property real radius: ThemeBackend.borderRadius
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomLeftRadius: radius
    property real bottomRightRadius: radius
    property real blurStrength: 1.0
    property real tint: 0.0
    property real rim: 0.45

    readonly property bool liquid: ThemeBackend.liquidGlass
    readonly property bool isGlassBackdrop: true
    property alias texture: glassTexture
    property int consumers: 0
    property int nestLevel: 0
    readonly property real nest: Math.min(1, nestLevel * 0.5)

    property bool standalone: false
    property bool surfaceEnabled: true

    Component.onCompleted: nestLevel = standalone ? 0 : Nesting.nestLevel(root, null, true)
    readonly property bool transitioning: engine ? (engine.transitionProgress > 0.0 && engine.transitionProgress < 1.0) : false
    property int frame: 0
    property int tick: 0

    property var screenOverride: null
    property bool useSnapshot: false

    readonly property var hostWindow: QsWindow.window
    readonly property var hostScreen: screenOverride ? screenOverride : (hostWindow ? hostWindow.screen : null)
    readonly property string screenName: hostScreen && hostScreen.name ? hostScreen.name : ""
    readonly property bool active: surfaceEnabled && ThemeBackend.blurBackground && ThemeBackend.elementOpacity < 0.999 && width > 0 && height > 0 && hostScreen !== null && (hostWindow ? hostWindow.visible : true)

    readonly property var engine: useSnapshot ? null : (Wallpaper.engines[screenName] || null)

    property real imageX: 0
    property real imageY: 0
    property real imageScale: 1
    property real imageRotation: 0
    property int revision: 0

    readonly property string snapshotDir: Caching.getCacheDir("wallpaper")
    readonly property string snapshotPath: snapshotDir + (screenName !== "" ? "/current_wallpaper_" + screenName + ".png" : "/current_wallpaper.png")
    readonly property string snapshotUrl: "file://" + snapshotPath + "?rev=" + revision

    function layerSource(slot) {
        if (!root.active) return "";
        if (!root.engine) return slot === 0 ? root.snapshotUrl : "";
        const e = root.engine;
        if (slot === 0) {
            if (e.isVideoA) return e.snapReadyA ? "file://" + e.layerSnapshotPathA + "?rev=" + e.snapRevA : "";
            return e.pathA !== "" ? "file://" + e.pathA : "";
        }
        if (e.isVideoB) return e.snapReadyB ? "file://" + e.layerSnapshotPathB + "?rev=" + e.snapRevB : "";
        return e.pathB !== "" ? "file://" + e.pathB : "";
    }

    readonly property int incomingSlot: engine ? engine.activeLayer : 0
    readonly property string newSource: layerSource(incomingSlot)
    readonly property string oldSource: engine ? layerSource(incomingSlot === 0 ? 1 : 0) : ""
    readonly property real screenWidth: hostScreen ? hostScreen.width : 1
    readonly property real screenHeight: hostScreen ? hostScreen.height : 1
    readonly property size textureSize: Qt.size(Math.max(1, Math.round(screenWidth / (liquid ? 2 : 4))), Math.max(1, Math.round(screenHeight / (liquid ? 2 : 4))))

    visible: active
    clip: false

    function refreshTexture() {
        if (root.liquid && root.consumers > 0) glassTexture.scheduleUpdate();
    }

    onImageXChanged: refreshTexture()
    onImageYChanged: refreshTexture()
    onImageScaleChanged: refreshTexture()
    onImageRotationChanged: refreshTexture()
    onWidthChanged: refreshTexture()
    onHeightChanged: refreshTexture()
    onNewSourceChanged: refreshTexture()
    onOldSourceChanged: refreshTexture()
    onRevisionChanged: refreshTexture()
    onConsumersChanged: refreshTexture()
    onLiquidChanged: refreshTexture()
    onTintChanged: refreshTexture()
    onBlurStrengthChanged: refreshTexture()

    function refreshGeometry() {
        const w = root.hostWindow;
        const scr = root.hostScreen;
        if (!scr) return;
        let wx = 0;
        let wy = 0;
        if (w && w.anchors && !root.screenOverride) {
            const a = w.anchors;
            const m = w.margins;
            if (a.left) wx = m.left;
            else if (a.right) wx = scr.width - w.width - m.right;
            else wx = (scr.width - w.width) / 2;
            if (a.top) wy = m.top;
            else if (a.bottom) wy = scr.height - w.height - m.bottom;
            else wy = (scr.height - w.height) / 2;
        }
        const p0 = root.mapFromItem(null, -wx, -wy);
        const px = root.mapFromItem(null, 1 - wx, -wy);
        const dx = px.x - p0.x;
        const dy = px.y - p0.y;
        const len = Math.sqrt(dx * dx + dy * dy);
        if (!isFinite(len) || len <= 0) return;
        root.imageX = p0.x;
        root.imageY = p0.y;
        root.imageScale = len;
        root.imageRotation = Math.atan2(dy, dx) * 180 / Math.PI;
    }

    FrameAnimation {
        running: root.active
        onTriggered: {
            root.refreshGeometry();
            if (root.consumers > 0 && (++root.tick % 2) === 0) root.frame++;
        }
    }

    onActiveChanged: {
        if (active) refreshGeometry();
    }

    FileView {
        path: root.active ? root.snapshotPath : ""
        watchChanges: true
        onFileChanged: root.revision++
    }

    Item {
        id: oldLayer
        width: root.screenWidth
        height: root.screenHeight
        visible: false
        layer.enabled: true
        layer.textureSize: root.textureSize
        layer.smooth: true

        Image {
            anchors.fill: parent
            source: root.oldSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            sourceSize: root.textureSize
            onStatusChanged: root.refreshTexture()
        }
    }

    Item {
        id: newLayer
        width: root.screenWidth
        height: root.screenHeight
        visible: false
        layer.enabled: true
        layer.textureSize: root.textureSize
        layer.smooth: true

        Image {
            anchors.fill: parent
            source: root.newSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            sourceSize: root.textureSize
            onStatusChanged: root.refreshTexture()
        }
    }

    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            topLeftRadius: root.topLeftRadius
            topRightRadius: root.topRightRadius
            bottomLeftRadius: root.bottomLeftRadius
            bottomRightRadius: root.bottomRightRadius
            color: "black"
        }
    }

    Item {
        id: content
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.mipmap: root.liquid
        layer.smooth: true

        ShaderEffect {
            id: blend
            x: root.imageX
            y: root.imageY
            width: root.screenWidth
            height: root.screenHeight
            scale: root.imageScale
            transformOrigin: Item.TopLeft
            rotation: root.imageRotation

            property variant oldTex: oldLayer
            property variant newTex: newLayer
            property vector2d itemSize: Qt.vector2d(width, height)
            property real progress: root.engine ? (root.engine.isPreloading ? -1.0 : root.engine.transitionProgress) : 1.0
            property real transitionType: root.engine ? root.engine.activeTransitionType : 0
            property vector2d origin: Qt.vector2d(root.engine ? root.engine.transitionOriginX : 0.5, root.engine ? root.engine.transitionOriginY : 0.5)
            property vector4d params: Qt.vector4d(root.engine && root.engine.wipeIsVertical ? 1.0 : 0.0, root.engine ? root.engine.swipeDirection : 0, 0.0, 0.0)

            fragmentShader: "file://" + Caching.kizashiDir + "/assets/shaders/transitions/wallpaper_blend.frag.qsb"
        }

        Rectangle {
            anchors.fill: parent
            visible: root.tint > 0
            color: Qt.alpha(ThemeBackend.base, root.tint)
        }
    }

    Item {
        id: rendered
        anchors.fill: parent

        MultiEffect {
            anchors.fill: parent
            visible: !root.liquid
            source: content
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: Math.min(1.0, root.blurStrength)
            maskEnabled: true
            maskSource: mask
        }

        LiquidGlass {
            id: glassEffect
            anchors.fill: parent
            visible: root.liquid
            src: content
            topLeftRadius: root.topLeftRadius
            topRightRadius: root.topRightRadius
            bottomLeftRadius: root.bottomLeftRadius
            bottomRightRadius: root.bottomRightRadius
            tintColor: ThemeBackend.base
            tintAmount: Math.max(root.tint, 0.12) * (1 - 0.5 * root.nest)
            frost: Math.max(0.5, root.blurStrength * 2.5) * 1.08 * (1 - 0.5 * root.nest)
            rim: root.rim * (1 - 0.35 * root.nest)
            nest: root.nest
            clear: root.nestLevel >= 1 ? 1 : 0
            cursorPos: Qt.point(root.cursorX, root.cursorY)
            hover: root.hoverAmount
        }
    }

    ShaderEffectSource {
        id: glassTexture
        anchors.fill: parent
        sourceItem: rendered
        live: root.liquid && root.consumers > 0 && root.transitioning
        mipmap: true
        visible: false
        smooth: true
        format: ShaderEffectSource.RGBA8
    }

    HoverHandler {
        id: pointer
        enabled: root.liquid
    }

    property real hoverAmount: pointer.hovered ? 1.0 : 0.0
    Behavior on hoverAmount { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    property real cursorX: width / 2
    property real cursorY: height / 2
    Behavior on cursorX { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on cursorY { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Connections {
        target: pointer
        function onPointChanged() {
            if (pointer.hovered) {
                root.cursorX = pointer.point.position.x;
                root.cursorY = pointer.point.position.y;
            }
        }
    }
}
