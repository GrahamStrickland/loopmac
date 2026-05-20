// Copyright (C) 2026 Graham Strickland
//
// This file is part of LoopMac.
//
// LoopMac is free software: you can redistribute it and/or modify it under the
// terms of the GNU Lesser General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option) any
// later version.
//
// LoopMac is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
// details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with LoopMac. If not, see <https://www.gnu.org/licenses/>.

import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Dialogs
import QtMultimedia

import "controls"

ApplicationWindow {
    id: root
    height: 720
    width: 1280
    minimumHeight: 540
    minimumWidth: 960
    visible: true
    title: qsTr("LoopMac")

    property bool fullScreen: false

    MessageDialog {
        id: mediaError
        buttons: MessageDialog.Ok
    }

    MouseArea {
        id: activityListener
        anchors.fill: parent
        z: 1
        propagateComposedEvents: true
        hoverEnabled: true

        property bool inactiveMouse: false

        Timer {
            id: timer
            interval: 1500 // milliseconds
            onTriggered: activityListener.inactiveMouse = true
        }

        function activityHandler(mouse) {
            if (activityListener.inactiveMouse)
                activityListener.inactiveMouse = false;
            timer.restart();
            timer.start();
            mouse.accepted = false;
        }

        onPositionChanged: mouse => activityHandler(mouse)
        onPressed: mouse => activityHandler(mouse)
        onDoubleClicked: mouse => mouse.accepted = false
    }

    MediaPlayer {
        id: mediaPlayer

        audioOutput: AudioOutput {
            id: audio
            muted: playbackController.muted
            volume: playbackController.volume
        }

        onErrorOccurred: {
            mediaError.text = mediaPlayer.errorString;
            mediaError.open();
        }

        source: ""
    }

    Rectangle {
        anchors.fill: parent
        visible: mediaPlayer.mediaStatus === 0
        color: "black"

        TapHandler {
            onDoubleTapped: {
                root.fullScreen ? root.showNormal() : root.showFullScreen();
                root.fullScreen = !root.fullScreen;
            }
        }
    }

    PlaybackControl {
        id: playbackController

        property bool showControls: !activityListener.inactiveMouse || busy
        opacity: showControls
        onShowControlsChanged: activityListener.cursorShape = showControls ? Qt.ArrowCursor : Qt.BlankCursor

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        mediaPlayer: mediaPlayer
    }
}
