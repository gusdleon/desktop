/*
 * Copyright (C) 2020 by Dominique Fuchs <32204802+DominiqueFuchs@users.noreply.github.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
 * for more details.
 */

import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Qt.labs.platform as NativeDialogs

import "../"
import "../filedetails/"

// Custom qml modules are in /theme (and included by resources.qrc)
import Style

import com.nextcloud.desktopclient

ApplicationWindow {
    id:         trayWindow

    title:      Systray.windowTitle
    // If the main dialog is displayed as a regular window we want it to be quadratic
    width:      Systray.useNormalWindow ? Style.trayWindowHeight : Style.trayWindowWidth
    height:     Style.trayWindowHeight
    flags:      Systray.useNormalWindow ? Qt.Window : Qt.Dialog | Qt.FramelessWindowHint
    color: 'transparent'

    readonly property int maxMenuHeight: Style.trayWindowHeight - Style.trayWindowHeaderHeight - 2 * Style.trayWindowBorderWidth

    Component.onCompleted: Systray.forceWindowInit(trayWindow)

    // Close tray window when focus is lost (e.g. click somewhere else on the screen)
    onActiveChanged: {
        if (!Systray.useNormalWindow && !active) {
            hide();
            Systray.isOpen = false;
        }
    }

    onClosing: Systray.isOpen = false

    onVisibleChanged: {
        // HACK: reload account Instantiator immediately by restting it - could be done better I guess
        // see also id:currentAccountHeaderButton.accountMenu below
        currentAccountHeaderButton.userLineInstantiator.active = false;
        currentAccountHeaderButton.userLineInstantiator.active = true;
        syncStatus.model.load();
    }

    background: Rectangle {
        radius: Systray.useNormalWindow ? 0.0 : Style.trayWindowRadius
        border.width: Style.trayWindowBorderWidth
        border.color: palette.dark
        color: palette.base
    }

    Connections {
        target: UserModel
        function onCurrentUserChanged() {
            currentAccountHeaderButton.accountMenu.close();
            syncStatus.model.load();
        }
    }

    Component {
        id: errorMessageDialog

        NativeDialogs.MessageDialog {
            id: dialog

            title: Systray.windowTitle

            onAccepted: destroy()
            onRejected: destroy()
        }
    }

    Connections {
        target: Systray

        function onIsOpenChanged() {
            userStatusDrawer.close()
            fileDetailsDrawer.close();

            if(Systray.isOpen) {
                currentAccountHeaderButton.accountMenu.close();
                appsMenu.close();
                openLocalFolderButton.closeMenu()
            }
        }

        function onShowErrorMessageDialog(error) {
            var newErrorDialog = errorMessageDialog.createObject(trayWindow)
            newErrorDialog.text = error
            newErrorDialog.open()
        }

        function onShowFileDetails(accountState, localPath, fileDetailsPage) {
            fileDetailsDrawer.openFileDetails(accountState, localPath, fileDetailsPage);
        }
    }

    OpacityMask {
        anchors.fill: parent
        anchors.margins: Style.trayWindowBorderWidth
        source: ShaderEffectSource {
            sourceItem: trayWindowMainItem
            hideSource: true
        }
        maskSource: Rectangle {
            width: trayWindow.width
            height: trayWindow.height
            radius: Systray.useNormalWindow ? 0.0 : Style.trayWindowRadius
        }
    }

    Drawer {
        id: userStatusDrawer
        width: parent.width
        height: parent.height - Style.trayDrawerMargin
        padding: 0
        edge: Qt.BottomEdge
        modal: true
        visible: false

        background: Rectangle {
            radius: Systray.useNormalWindow ? 0.0 : Style.trayWindowRadius
            border.width: Style.trayWindowBorderWidth
            border.color: palette.dark
            color: palette.base
        }

        property int userIndex: 0

        function openUserStatusDrawer(index) {
            console.log(`About to show dialog for user with index ${index}`);
            userIndex = index;
            open();
        }

        Loader {
            id: userStatusContents
            anchors.fill: parent
            active: userStatusDrawer.visible
            sourceComponent: UserStatusSelectorPage {
                anchors.fill: parent
                userIndex: userStatusDrawer.userIndex
                onFinished: userStatusDrawer.close()
            }
        }
    }

    Drawer {
        id: fileDetailsDrawer
        width: parent.width - Style.trayDrawerMargin
        height: parent.height
        padding: 0
        edge: Qt.RightEdge
        modal: true
        visible: false
        clip: true

        background: Rectangle {
            radius: Systray.useNormalWindow ? 0.0 : Style.trayWindowRadius
            border.width: Style.trayWindowBorderWidth
            border.color: palette.dark
            color: palette.base
        }

        property var folderAccountState: ({})
        property string fileLocalPath: ""
        property var pageToShow: Systray.FileDetailsPage.Activity

        function openFileDetails(accountState, localPath, fileDetailsPage) {
            console.log(`About to show file details view in tray for ${localPath}`);
            folderAccountState = accountState;
            fileLocalPath = localPath;
            pageToShow = fileDetailsPage;

            if(!opened) {
                open();
            }
        }

        Loader {
            id: fileDetailsContents
            anchors.fill: parent
            active: fileDetailsDrawer.visible
            onActiveChanged: {
                if (active) {
                    Systray.showFileDetailsPage(fileDetailsDrawer.fileLocalPath,
                                                fileDetailsDrawer.pageToShow);
                }
            }
            sourceComponent: FileDetailsView {
                id: fileDetails

                width: parent.width
                height: parent.height

                backgroundsVisible: false
                accentColor: Style.accentColor
                accountState: fileDetailsDrawer.folderAccountState
                localPath: fileDetailsDrawer.fileLocalPath
                showCloseButton: true

                onCloseButtonClicked: fileDetailsDrawer.close()
            }
        }
    }

    Item {
        id: trayWindowMainItem

        property bool isUnifiedSearchActive: unifiedSearchResultsListViewSkeletonLoader.active
                                             || unifiedSearchResultNothingFound.visible
                                             || unifiedSearchResultsErrorLabel.visible
                                             || unifiedSearchResultsListView.visible

        anchors.fill: parent
        anchors.margins: Style.trayWindowBorderWidth
        clip: true

        Accessible.role: Accessible.Grouping
        Accessible.name: qsTr("Nextcloud desktop main dialog")

        Rectangle {
            id: trayWindowHeaderBackground

            anchors.left:   trayWindowMainItem.left
            anchors.right:  trayWindowMainItem.right
            anchors.top:    trayWindowMainItem.top
            height:         Style.trayWindowHeaderHeight
            color:          Style.currentUserHeaderColor

            palette {
                text: Style.currentUserHeaderTextColor
                windowText: Style.currentUserHeaderTextColor
                buttonText: Style.currentUserHeaderTextColor
            }

            RowLayout {
                id: trayWindowHeaderLayout

                spacing:        0
                anchors.fill:   parent

                CurrentAccountHeaderButton {
                    id: currentAccountHeaderButton
                    Layout.preferredWidth:  Style.currentAccountButtonWidth
                    Layout.preferredHeight: Style.trayWindowHeaderHeight
                }

                // Add space between items
                Item {
                    Layout.fillWidth: true
                }

                TrayFoldersMenuButton {
                    id: openLocalFolderButton

                    visible: currentUser.hasLocalFolder
                    currentUser: UserModel.currentUser
                    parentBackgroundColor: trayWindowHeaderBackground.color

                    onClicked: openLocalFolderButton.userHasGroupFolders ? openLocalFolderButton.toggleMenuOpen() : UserModel.openCurrentAccountLocalFolder()

                    onFolderEntryTriggered: isGroupFolder ? UserModel.openCurrentAccountFolderFromTrayInfo(fullFolderPath) : UserModel.openCurrentAccountLocalFolder()

                    Accessible.role: Accessible.Graphic
                    Accessible.name: qsTr("Open local or group folders")
                    Accessible.onPressAction: openLocalFolderButton.userHasGroupFolders ? openLocalFolderButton.toggleMenuOpen() : UserModel.openCurrentAccountLocalFolder()

                    Layout.alignment: Qt.AlignRight
                    Layout.preferredWidth:  Style.trayWindowHeaderHeight
                    Layout.preferredHeight: Style.trayWindowHeaderHeight
                }

                HeaderButton {
                    id: trayWindowFeaturedAppButton
                    visible: UserModel.currentUser.isFeaturedAppEnabled
                    icon.source: UserModel.currentUser.featuredAppIcon + "/"
                    onClicked: UserModel.openCurrentAccountFeaturedApp()

                    Accessible.role: Accessible.Button
                    Accessible.name: UserModel.currentUser.featuredAppAccessibleName
                    Accessible.onPressAction: trayWindowFeaturedAppButton.clicked()

                    Layout.alignment: Qt.AlignRight
                    Layout.preferredWidth:  Style.trayWindowHeaderHeight
                    Layout.preferredHeight: Style.trayWindowHeaderHeight
                }

                HeaderButton {
                    id: trayWindowAppsButton
                    icon.source: "image://svgimage-custom-color/more-apps.svg/" + palette.windowText

                    onClicked: {
                        if(appsMenu.count <= 0) {
                            UserModel.openCurrentAccountServer()
                        } else if (appsMenu.visible) {
                            appsMenu.close()
                        } else {
                            appsMenu.open()
                        }
                    }

                    Accessible.role: Accessible.ButtonMenu
                    Accessible.name: qsTr("More apps")
                    Accessible.onPressAction: trayWindowAppsButton.clicked()

                    Menu {
                        id: appsMenu
                        x: Style.trayWindowMenuOffsetX
                        y: (trayWindowAppsButton.y + trayWindowAppsButton.height + Style.trayWindowMenuOffsetY)
                        width: Style.trayWindowWidth * Style.trayWindowMenuWidthFactor
                        height: implicitHeight + y > Style.trayWindowHeight ? Style.trayWindowHeight - y : implicitHeight
                        closePolicy: Menu.CloseOnPressOutsideParent | Menu.CloseOnEscape

                        Repeater { 
                            model: UserAppsModel
                            delegate: MenuItem {
                                id: appEntry
                                anchors.left: parent.left
                                anchors.right: parent.right
                                text: model.appName
                                font.pixelSize: Style.topLinePixelSize
                                icon.source: model.appIconUrl
                                icon.color: palette.windowText
                                onTriggered: UserAppsModel.openAppUrl(appUrl)
                                hoverEnabled: true
                                Accessible.role: Accessible.MenuItem
                                Accessible.name: qsTr("Open %1 in browser").arg(model.appName)
                                Accessible.onPressAction: appEntry.triggered()
                            }
                        }
                    }
                }
            }
        }   // Rectangle trayWindowHeaderBackground

        UnifiedSearchInputContainer {
            id: trayWindowUnifiedSearchInputContainer

            anchors.top: trayWindowHeaderBackground.bottom
            anchors.left: trayWindowMainItem.left
            anchors.right: trayWindowMainItem.right
            anchors.topMargin: Style.trayHorizontalMargin
            anchors.leftMargin: Style.trayHorizontalMargin
            anchors.rightMargin: Style.trayHorizontalMargin

            text: UserModel.currentUser.unifiedSearchResultsListModel.searchTerm
            readOnly: !UserModel.currentUser.isConnected || UserModel.currentUser.unifiedSearchResultsListModel.currentFetchMoreInProgressProviderId
            isSearchInProgress: UserModel.currentUser.unifiedSearchResultsListModel.isSearchInProgress
            onTextEdited: { UserModel.currentUser.unifiedSearchResultsListModel.searchTerm = trayWindowUnifiedSearchInputContainer.text }
            onClearText: { UserModel.currentUser.unifiedSearchResultsListModel.searchTerm = "" }
        }

        Rectangle {
            id: bottomUnifiedSearchInputSeparator

            anchors.top: trayWindowUnifiedSearchInputContainer.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Style.trayHorizontalMargin

            height: 1
            color: palette.dark
            visible: trayWindowMainItem.isUnifiedSearchActive
        }

        ErrorBox {
            id: unifiedSearchResultsErrorLabel
            visible:  UserModel.currentUser.unifiedSearchResultsListModel.errorString && !unifiedSearchResultsListView.visible && ! UserModel.currentUser.unifiedSearchResultsListModel.isSearchInProgress && ! UserModel.currentUser.unifiedSearchResultsListModel.currentFetchMoreInProgressProviderId
            text:  UserModel.currentUser.unifiedSearchResultsListModel.errorString
            anchors.top: bottomUnifiedSearchInputSeparator.bottom
            anchors.left: trayWindowMainItem.left
            anchors.right: trayWindowMainItem.right
            anchors.margins: Style.trayHorizontalMargin
        }

        UnifiedSearchResultNothingFound {
            id: unifiedSearchResultNothingFound

            anchors.top: bottomUnifiedSearchInputSeparator.bottom
            anchors.left: trayWindowMainItem.left
            anchors.right: trayWindowMainItem.right
            anchors.topMargin: Style.trayHorizontalMargin

            text: UserModel.currentUser.unifiedSearchResultsListModel.searchTerm

            property bool isSearchRunning: UserModel.currentUser.unifiedSearchResultsListModel.isSearchInProgress
            property bool waitingForSearchTermEditEnd: UserModel.currentUser.unifiedSearchResultsListModel.waitingForSearchTermEditEnd
            property bool isSearchResultsEmpty: unifiedSearchResultsListView.count === 0
            property bool nothingFound: text && isSearchResultsEmpty && !UserModel.currentUser.unifiedSearchResultsListModel.errorString

            visible: !isSearchRunning && !waitingForSearchTermEditEnd && nothingFound
        }

        Loader {
            id: unifiedSearchResultsListViewSkeletonLoader

            anchors.top: bottomUnifiedSearchInputSeparator.bottom
            anchors.left: trayWindowMainItem.left
            anchors.right: trayWindowMainItem.right
            anchors.bottom: trayWindowMainItem.bottom
            anchors.margins: controlRoot.padding

            active: !unifiedSearchResultNothingFound.visible &&
                    !unifiedSearchResultsListView.visible &&
                    !UserModel.currentUser.unifiedSearchResultsListModel.errorString &&
                    UserModel.currentUser.unifiedSearchResultsListModel.searchTerm

            sourceComponent: UnifiedSearchResultItemSkeletonContainer {
                anchors.fill: parent
                spacing: unifiedSearchResultsListView.spacing
                animationRectangleWidth: trayWindow.width
            }
        }

        ScrollView {
            id: controlRoot
            contentWidth: availableWidth

            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            data: WheelHandler {
                target: controlRoot.contentItem
            }
            visible: unifiedSearchResultsListView.count > 0

            anchors.top: bottomUnifiedSearchInputSeparator.bottom
            anchors.left: trayWindowMainItem.left
            anchors.right: trayWindowMainItem.right
            anchors.bottom: trayWindowMainItem.bottom

            ListView {
                id: unifiedSearchResultsListView
                spacing: 4
                clip: true

                keyNavigationEnabled: true

                reuseItems: true

                Accessible.role: Accessible.List
                Accessible.name: qsTr("Unified search results list")

                model: UserModel.currentUser.unifiedSearchResultsListModel

                delegate: UnifiedSearchResultListItem {
                    width: unifiedSearchResultsListView.width
                    isSearchInProgress:  unifiedSearchResultsListView.model.isSearchInProgress
                    currentFetchMoreInProgressProviderId: unifiedSearchResultsListView.model.currentFetchMoreInProgressProviderId
                    fetchMoreTriggerClicked: unifiedSearchResultsListView.model.fetchMoreTriggerClicked
                    resultClicked: unifiedSearchResultsListView.model.resultClicked
                    ListView.onPooled: isPooled = true
                    ListView.onReused: isPooled = false
                }

                section.property: "providerName"
                section.criteria: ViewSection.FullString
                section.delegate: UnifiedSearchResultSectionItem {
                    width: unifiedSearchResultsListView.width
                }
            }
        }

        SyncStatus {
            id: syncStatus

            accentColor: Style.accentColor
            visible: !trayWindowMainItem.isUnifiedSearchActive

            anchors.top: trayWindowUnifiedSearchInputContainer.bottom
            anchors.left: trayWindowMainItem.left
            anchors.right: trayWindowMainItem.right
        }

        Rectangle {
            id: syncStatusSeparator
            anchors.left: syncStatus.left
            anchors.right: syncStatus.right
            anchors.bottom: syncStatus.bottom
            height: 1
            color: palette.dark
            visible: !trayWindowMainItem.isUnifiedSearchActive
        }

        Loader {
            id: newActivitiesButtonLoader

            anchors.top: activityList.top
            anchors.topMargin: 5
            anchors.horizontalCenter: activityList.horizontalCenter

            width: Style.newActivitiesButtonWidth
            height: Style.newActivitiesButtonHeight

            z: 1

            active: false

            sourceComponent: Button {
                id: newActivitiesButton
                hoverEnabled: true
                padding: Style.smallSpacing

                anchors.fill: parent

                text: qsTr("New activities")

                icon.source: "image://svgimage-custom-color/expand-less-black.svg" + "/" + Style.currentUserHeaderTextColor
                icon.width: Style.activityLabelBaseWidth
                icon.height: Style.activityLabelBaseWidth

                onClicked: {
                    activityList.scrollToTop();
                    newActivitiesButtonLoader.active = false
                }

                Timer {
                    id: newActivitiesButtonDisappearTimer
                    interval: Style.newActivityButtonDisappearTimeout
                    running: newActivitiesButtonLoader.active && !newActivitiesButton.hovered
                    repeat: false
                    onTriggered: fadeoutActivitiesButtonDisappear.running = true
                }

                OpacityAnimator {
                    id: fadeoutActivitiesButtonDisappear
                    target: newActivitiesButton
                    from: 1
                    to: 0
                    duration: Style.newActivityButtonDisappearFadeTimeout
                    loops: 1
                    running: false
                    onFinished: newActivitiesButtonLoader.active = false
                }
            }
        }

        ActivityList {
            id: activityList
            visible: !trayWindowMainItem.isUnifiedSearchActive
            anchors.top: syncStatus.bottom
            anchors.left: trayWindowMainItem.left
            anchors.right: trayWindowMainItem.right
            anchors.bottom: trayWindowMainItem.bottom

            activeFocusOnTab: true
            model: activityModel
            onOpenFile: Qt.openUrlExternally(filePath);
            onActivityItemClicked: {
                model.slotTriggerDefaultAction(index)
            }
            Connections {
                target: activityModel
                function onInteractiveActivityReceived() {
                    if (!activityList.atYBeginning) {
                        newActivitiesButtonLoader.active = true;
                    }
                }
            }
        }
    } // Item trayWindowMainItem
}
