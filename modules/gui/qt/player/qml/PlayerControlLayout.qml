/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

import QtQuick
import QtQuick.Layouts


import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.PlayerControls

FocusScope {
    id: playerControlLayout

    // Properties

    property real spacing: VLCStyle.margin_normal // spacing between controls

    property real layoutSpacing: VLCStyle.margin_xxlarge // spacing between layouts (left, center, and right)

    property int identifier: -1

    // Items (such as the time labels and the position slider) laid out on
    // the same row as the controls, between the center and right controls.
    // When it is not empty, the left and center controls are packed at the
    // beginning of the row instead of the center being centered.
    property var inlineItems: []

    readonly property bool _inline: inlineItems.length > 0

    // Item of the inline items that participates in the keyboard navigation
    // between the center and right controls.
    property Item inlineNavigationItem: null

    // Controls placed before and after the inline items, for navigating
    // from the inline items:
    readonly property Item inlineBeforeItem: loaderInline.item?.beforeItem ?? null
    readonly property Item inlineAfterItem: loaderInline.item?.afterItem ?? null

    readonly property PlayerControlbarModel model: {
        if (!!MainCtx.controlbarProfileModel.currentModel)
            return MainCtx.controlbarProfileModel.currentModel.getModel(identifier)
        else
            return null
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // Signals

    signal requestLockUnlockAutoHide(bool lock)
    signal menuOpened(var menu)
    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    // Settings

    implicitWidth: {
        if (loaderInline.active)
            return loaderInline.implicitWidth
        if (loaderLeftRight.active)
            return loaderLeftRight.implicitWidth
        return (loaderLeft.implicitWidth + loaderCenter.implicitWidth + loaderRight.implicitWidth)
    }

    implicitHeight: {
        if (loaderInline.active)
            return loaderInline.implicitHeight
        if (loaderLeftRight.active)
            return loaderLeftRight.implicitHeight
        return Math.max(loaderLeft.implicitHeight, loaderCenter.implicitHeight, loaderRight.implicitHeight)
    }

    // Events

    Component.onCompleted: console.assert(identifier >= 0)

    // Children

    Loader {
        id: loaderLeftRight

        anchors.fill: parent

        active: !playerControlLayout._inline &&
                !loaderCenter.active &&
                playerControlLayout.model &&
                ((playerControlLayout.model.left && (playerControlLayout.model.left.count > 0)) ||
                (playerControlLayout.model.right && (playerControlLayout.model.right.count > 0)))

        focus: active

        sourceComponent: RowLayout {
            spacing: playerControlLayout.spacing

            focus: true

            // TODO: Qt >= 5.13 Use QConcatenateTablesProxyModel
            //       instead of multiple repeaters

            ControlRepeater {
                id: leftRepeater
                model: ControlListFilter {
                    sourceModel: playerControlLayout.model.left

                    player: Player
                    ctx: MainCtx
                }

                Navigation.parentItem: playerControlLayout
                Navigation.rightAction: function() {
                    const item = rightRepeater.itemAt(0)
                    if (item)
                        item.forceActiveFocus(Qt.TabFocusReason)
                    else
                        return false
                }

                availableWidth: loaderLeftRight.width
                availableHeight: loaderLeftRight.height

                Component.onCompleted: {
                    requestLockUnlockAutoHide.connect(playerControlLayout.requestLockUnlockAutoHide)
                    menuOpened.connect(playerControlLayout.menuOpened)
                    playerControlLayout.forceUnlock.connect(leftRepeater.forceUnlock)
                }
            }

            Item {
                function containsVisibleItem(repeater) {
                    for (let i = 0; i < repeater.count; ++i) {
                        const item = repeater.itemAt(i)

                        if (item && item.visible)
                            return true
                    }

                    return false
                }

                Layout.minimumWidth: (containsVisibleItem(leftRepeater) && containsVisibleItem(rightRepeater)) ? playerControlLayout.layoutSpacing
                                                                                                               : 0

                Layout.fillWidth: true
                visible: true
            }

            ControlRepeater {
                id: rightRepeater
                model: ControlListFilter {
                    sourceModel: playerControlLayout.model.right

                    player: Player
                    ctx: MainCtx
                }

                Navigation.parentItem: playerControlLayout
                Navigation.leftAction: function() {
                    const item = leftRepeater.itemAt(leftRepeater.count - 1)
                    if (item)
                        item.forceActiveFocus(Qt.BacktabFocusReason)
                    else
                        return false
                }

                availableWidth: loaderLeftRight.width
                availableHeight: loaderLeftRight.height

                Component.onCompleted: {
                    requestLockUnlockAutoHide.connect(playerControlLayout.requestLockUnlockAutoHide)
                    menuOpened.connect(playerControlLayout.menuOpened)
                    playerControlLayout.forceUnlock.connect(rightRepeater.forceUnlock)
                }
            }

        }
    }


    Loader {
        id: loaderLeft

        anchors {
            right: loaderCenter.left
            left: parent.left
            top: parent.top
            bottom: parent.bottom

            // Spacing for the filler item acts as padding
            rightMargin: layoutSpacing - spacing
        }

        active: !playerControlLayout._inline &&
                !!playerControlLayout.model?.left && (playerControlLayout.model.left.count > 0) &&
                !loaderLeftRight.active

        focus: active

        sourceComponent: ControlLayout {
            id: leftControlLayout

            model: ControlListFilter {
                sourceModel: playerControlLayout.model.left

                player: Player
                ctx: MainCtx
            }

            alignment: (Qt.AlignVCenter | Qt.AlignLeft)

            spacing: playerControlLayout.spacing

            focus: true

            altFocusAction: () => Navigation.defaultNavigationRight()

            Navigation.parentItem: playerControlLayout
            Navigation.rightItem: loaderCenter.item

            Component.onCompleted: {
                requestLockUnlockAutoHide.connect(playerControlLayout.requestLockUnlockAutoHide)
                menuOpened.connect(playerControlLayout.menuOpened)
                playerControlLayout.forceUnlock.connect(leftControlLayout.forceUnlock)
            }
        }
    }

    Loader {
        id: loaderCenter

        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            bottom: parent.bottom
        }

        // TODO: "ControlListFilter"'s count......
        active: !playerControlLayout._inline &&
                !!playerControlLayout.model && !!playerControlLayout.model.center && (playerControlLayout.model.center.count > 0)

        Binding on width {
            delayed: true
            when: loaderCenter._componentCompleted
            value: {
                const item = loaderCenter.item

                const minimumWidth = (item && item.Layout.minimumWidth > 0) ? item.Layout.minimumWidth : implicitWidth
                const maximumWidth = (item && item.Layout.maximumWidth > 0) ? item.Layout.maximumWidth : implicitWidth

                if ((loaderLeft.active && (loaderLeft.width > 0)) || (loaderRight.active && (loaderRight.width > 0))) {
                    return minimumWidth
                } else {
                    return Math.min(loaderCenter.parent.width, maximumWidth)
                }
            }
        }

        property bool _componentCompleted: false

        Component.onCompleted: {
            _componentCompleted = true
        }

        sourceComponent: ControlLayout {
            id: centerControlLayout

            model: ControlListFilter {
                sourceModel: playerControlLayout.model.center

                player: Player
                ctx: MainCtx
            }

            focus: true

            spacing: playerControlLayout.spacing

            altFocusAction: () => Navigation.defaultNavigationUp()

            Navigation.parentItem: playerControlLayout
            Navigation.leftItem: loaderLeft.item
            Navigation.rightItem: loaderRight.item

            Component.onCompleted: {
                requestLockUnlockAutoHide.connect(playerControlLayout.requestLockUnlockAutoHide)
                menuOpened.connect(playerControlLayout.menuOpened)
                playerControlLayout.forceUnlock.connect(centerControlLayout.forceUnlock)
            }
        }
    }

    Loader {
        id: loaderRight

        anchors {
            left: loaderCenter.right
            right: parent.right
            top: parent.top
            bottom: parent.bottom

            // Spacing for the filler item acts as padding
            leftMargin: layoutSpacing - spacing
        }

        active: !playerControlLayout._inline &&
                !!playerControlLayout.model && !!playerControlLayout.model.right && (playerControlLayout.model.right.count > 0) &&
                !loaderLeftRight.active

        sourceComponent: ControlLayout {
            id: rightControlLayout

            model: ControlListFilter {
                sourceModel: playerControlLayout.model.right

                player: Player
                ctx: MainCtx
            }

            alignment: (Qt.AlignVCenter | Qt.AlignRight)

            spacing: playerControlLayout.spacing

            focus: true

            altFocusAction: () => Navigation.defaultNavigationLeft()

            Navigation.parentItem: playerControlLayout
            Navigation.leftItem: loaderCenter.item

            onRequestLockUnlockAutoHide: (lock) => playerControlLayout.requestLockUnlockAutoHide(lock)

            onMenuOpened: (menu) => playerControlLayout.menuOpened(menu)

            Component.onCompleted:{
                playerControlLayout.forceUnlock.connect(rightControlLayout.forceUnlock)
            }
        }
    }

    Loader {
        id: loaderInline

        anchors.fill: parent

        active: playerControlLayout._inline

        focus: active

        sourceComponent: RowLayout {
            id: inlineRow

            spacing: playerControlLayout.layoutSpacing

            focus: true

            readonly property bool _hasLeft: (playerControlLayout.model?.left?.count ?? 0) > 0
            readonly property bool _hasCenter: (playerControlLayout.model?.center?.count ?? 0) > 0
            readonly property bool _hasRight: (playerControlLayout.model?.right?.count ?? 0) > 0

            readonly property Item beforeItem: _hasCenter ? inlineCenter : (_hasLeft ? inlineLeft : null)
            readonly property Item afterItem: _hasRight ? inlineRight : null

            ControlLayout {
                id: inlineLeft

                Layout.fillHeight: true
                Layout.preferredWidth: implicitWidth

                visible: inlineRow._hasLeft

                model: ControlListFilter {
                    sourceModel: playerControlLayout.model?.left ?? null

                    player: Player
                    ctx: MainCtx
                }

                alignment: Qt.AlignVCenter

                spacing: playerControlLayout.spacing

                focus: inlineRow._hasLeft

                altFocusAction: () => Navigation.defaultNavigationRight()

                Navigation.parentItem: playerControlLayout
                Navigation.rightItem: {
                    if (inlineRow._hasCenter)
                        return inlineCenter
                    return playerControlLayout.inlineNavigationItem ?? (inlineRow._hasRight ? inlineRight : null)
                }

                Component.onCompleted: {
                    requestLockUnlockAutoHide.connect(playerControlLayout.requestLockUnlockAutoHide)
                    menuOpened.connect(playerControlLayout.menuOpened)
                    playerControlLayout.forceUnlock.connect(inlineLeft.forceUnlock)
                }
            }

            ControlLayout {
                id: inlineCenter

                Layout.fillHeight: true
                Layout.preferredWidth: implicitWidth

                visible: inlineRow._hasCenter

                model: ControlListFilter {
                    sourceModel: playerControlLayout.model?.center ?? null

                    player: Player
                    ctx: MainCtx
                }

                alignment: Qt.AlignVCenter

                spacing: playerControlLayout.spacing

                focus: !inlineRow._hasLeft && inlineRow._hasCenter

                altFocusAction: () => Navigation.defaultNavigationUp()

                Navigation.parentItem: playerControlLayout
                Navigation.leftItem: inlineRow._hasLeft ? inlineLeft : null
                Navigation.rightItem: playerControlLayout.inlineNavigationItem ?? (inlineRow._hasRight ? inlineRight : null)

                Component.onCompleted: {
                    requestLockUnlockAutoHide.connect(playerControlLayout.requestLockUnlockAutoHide)
                    menuOpened.connect(playerControlLayout.menuOpened)
                    playerControlLayout.forceUnlock.connect(inlineCenter.forceUnlock)
                }
            }

            RowLayout {
                id: inlineSlot

                Layout.fillWidth: true
                Layout.fillHeight: true

                spacing: VLCStyle.margin_xsmall

                children: playerControlLayout.inlineItems
            }

            ControlLayout {
                id: inlineRight

                Layout.fillHeight: true
                Layout.preferredWidth: implicitWidth

                visible: inlineRow._hasRight

                model: ControlListFilter {
                    sourceModel: playerControlLayout.model?.right ?? null

                    player: Player
                    ctx: MainCtx
                }

                alignment: Qt.AlignVCenter

                spacing: playerControlLayout.spacing

                focus: !inlineRow._hasLeft && !inlineRow._hasCenter && inlineRow._hasRight

                altFocusAction: () => Navigation.defaultNavigationLeft()

                Navigation.parentItem: playerControlLayout
                Navigation.leftItem: playerControlLayout.inlineNavigationItem ?? inlineRow.beforeItem

                Component.onCompleted: {
                    requestLockUnlockAutoHide.connect(playerControlLayout.requestLockUnlockAutoHide)
                    menuOpened.connect(playerControlLayout.menuOpened)
                    playerControlLayout.forceUnlock.connect(inlineRight.forceUnlock)
                }
            }
        }
    }
}
