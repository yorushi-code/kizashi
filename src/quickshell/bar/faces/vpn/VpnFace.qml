import QtQuick

// С 2.2.12 апстрим держит в реестре один файл на модуль (ключ face) и сам
// файл решает, как рисоваться сверху и сбоку. У нас два готовых варианта,
// поэтому здесь только развилка по ориентации; BarModule видит наружу то же,
// что видел раньше: vpnPill, isFaceVisible и размер по оси бара.
Item {
    id: root

    property var module: null
    readonly property bool isVertical: module ? module.orientation === "vertical" : false

    readonly property var vpnPill: inner.item ? inner.item.vpnPill : null
    readonly property bool isFaceVisible: inner.item ? inner.item.isFaceVisible : false
    // BarModule берёт длину по оси отсюда в первую очередь; без неё он
    // читает implicit-размер, а тот замыкается через Loader на ширину модуля.
    readonly property real targetLength: inner.item
        ? (isVertical ? inner.item.targetHeight : inner.item.targetWidth) : 0

    // По оси бара -- размер варианта, поперёк -- размер родителя, как и было
    // у самих вариантов (они меряют поперёк по parent, то есть по этой обёртке).
    implicitWidth: isVertical ? (parent ? parent.width : 0) : (inner.item ? inner.item.implicitWidth : 0)
    implicitHeight: isVertical ? (inner.item ? inner.item.implicitHeight : 0) : (parent ? parent.height : 0)

    Loader {
        id: inner
        anchors.fill: parent
        Component.onCompleted: root.load()
    }

    function load() {
        inner.setSource(root.isVertical ? "SideVpnFace.qml" : "TopVpnFace.qml", { "module": root.module });
    }

    onIsVerticalChanged: load()
}
