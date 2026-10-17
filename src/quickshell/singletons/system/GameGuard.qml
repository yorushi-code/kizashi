pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland

// Whether something owns a screen right now, so the shell keeps off it.
// covers(screen): the active window is fullscreen there, or (on niri) the
// focused window fills that output - how Wine/Proton games usually run
// under XWayland, where the fullscreen flag never reaches us.
// owns(screen): covers(), or a Steam/Proton game has the focus there.
// Both read reactive properties, so bindings that call them update.
Item {
    id: root

    readonly property var activeToplevel: ToplevelManager.activeToplevel
    readonly property bool niri: typeof NiriState !== "undefined" && NiriState.isNiri

    Component.onCompleted: { if (niri) NiriState.subscribe(); }
    Component.onDestruction: { if (niri) NiriState.unsubscribe(); }

    readonly property var focused: {
        let m = niri ? NiriState.windowsMap : null;
        if (!m) return null;
        for (let id in m) {
            if (m[id] && m[id].is_focused) return m[id];
        }
        return null;
    }

    function _onScreen(w, screen) {
        if (!w || !screen) return false;
        let ws = NiriState.workspacesMap ? NiriState.workspacesMap[w.workspace_id] : null;
        return !ws || !ws.output || ws.output === screen.name;
    }

    function _toplevelFullscreen(screen) {
        let t = activeToplevel;
        if (!t || !t.fullscreen) return false;
        return !t.screens || t.screens.length === 0 || t.screens.indexOf(screen) !== -1;
    }

    function covers(screen) {
        if (_toplevelFullscreen(screen)) return true;
        let w = focused;
        if (!w || !w.layout || !w.layout.window_size || !_onScreen(w, screen)) return false;
        let sz = w.layout.window_size;
        return sz[0] >= screen.width - 2 && sz[1] >= screen.height - 2;
    }

    function appId() {
        if (focused && focused.app_id) return String(focused.app_id);
        return (activeToplevel && activeToplevel.appId) ? String(activeToplevel.appId) : "";
    }

    function isGame() {
        return /^(steam_app_\d+|gamescope|steam_proton)$|\.exe$/i.test(appId());
    }

    function owns(screen) {
        return covers(screen) || ((!niri || _onScreen(focused, screen)) && isGame());
    }
}
