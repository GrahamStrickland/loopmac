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
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtMultimedia

Item {
    id: playbackController

    required property MediaPlayer mediaPlayer

    property alias muted: audioControl.muted
    property alias volume: audioControl.volume

    property bool landscapePlaybackControls: root.width >= 668
    property bool busy: fileDialog.visible || audioControl.busy || playbackSeekControl.busy

    implicitHeight: landscapePlaybackControls ? 168 : 208

    FileDialog {
        id: fileDialog
        title: "Please choose a file"
        onAccepted: {
            playbackController.mediaPlayer.stop();
            playbackController.mediaPlayer.source = fileDialog.selectedFile;
            playbackController.mediaPlayer.play();
        }
    }

    component CustomButton: RoundButton {
        property int diameter: 40
        Layout.preferredWidth: diameter
        Layout.preferredHeight: diameter
        radius: diameter / 2
        icon.width: 24
        icon.height: 24
    }

    component CustomRoundButton: RoundButton {
        property int diameter: 40
        Layout.preferredWidth: diameter
        Layout.preferredHeight: diameter
        radius: diameter / 2
        icon.width: 24
        icon.height: 24
    }

    CustomButton {
        id: fileDialogButton
        icon.source: "../../images/folder-open.svg"
        flat: false
        onClicked: fileDialog.open();
    }

    RowLayout {
        id: controlButtons
        spacing: 16

        CustomRoundButton {
            id: backward10Button
            icon.source: "../../images/angle-double-small-left.svg"
            onClicked: {
                const pos = Math.max(0, playbackController.mediaPlayer.position - 10000);
                playbackController.mediaPlayer.setPosition(pos);
            }
        }

        CustomRoundButton {
            id: playButton
            visible: playbackController.mediaPlayer.playbackState !== MediaPlayer.PlayingState
            icon.source: "../../images/play-circle.svg"
            onClicked: playbackController.mediaPlayer.play()
        }

        CustomRoundButton {
            id: pauseButton
            visible: playbackController.mediaPlayer.playbackState === MediaPlayer.PlayingState
            icon.source: "../../images/pause-circle.svg"
            onClicked: playbackController.mediaPlayer.pause()
        }

        CustomRoundButton {
            id: forward10Button
            icon.source: "../../images/angle-double-small-right.svg"
            onClicked: {
                const pos = Math.max(0, playbackController.mediaPlayer.position + 10000);
                playbackController.mediaPlayer.setPosition(pos);
            }
        }
    }

    AudioControl {
        id: audioControl
        showSlider: root.width >= 960
    }

    PlaybackSeekControl {
        id: playbackSeekControl
        Layout.fillWidth: true
        mediaPlayer: playbackController.mediaPlayer
    }

    Frame {
        id: landscapeLayout
        anchors.fill: parent
        padding: 32
        topPadding: 28
        visible: landscapePlaybackControls

        ColumnLayout {
            anchors.fill: parent
            spacing: 16

            Item {
                Layout.fillWidth: true
                implicitHeight: 40

                LayoutItemProxy {
                    id: fdbProxy
                    target: fileDialogButton
                    anchors.left: parent.left
                }

                LayoutItemProxy {
                    id: cbProxy
                    target: controlButtons
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                LayoutItemProxy {
                    target: audioControl
                    anchors.left: cbProxy.right
                    anchors.leftMargin: 30
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            LayoutItemProxy {
                target: playbackSeekControl
                Layout.topMargin: 16
                Layout.bottomMargin: 16
            }
        }
    }

    Frame {
        id: portraitLayout
        anchors.fill: parent
        padding: 32
        topPadding: 28
        visible: !landscapePlaybackControls

        ColumnLayout {
            anchors.fill: parent
            spacing: 16

            Item {
                Layout.fillWidth: true
                implicitHeight: 40

                LayoutItemProxy {
                    id: fdbProxy_
                    target: fileDialogButton
                    anchors.left: parent.left
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 16

            Item {
                Layout.fillWidth: true
                implicitHeight: 40

                LayoutItemProxy {
                    id: cbProxy_
                    target: controlButtons
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                LayoutItemProxy {
                    target: audioControl
                    anchors.left: cbProxy_.right
                    anchors.leftMargin: 16
                }
            }

            LayoutItemProxy {
                target: playbackSeekControl
                Layout.topMargin: 8
                Layout.bottomMargin: 8
            }
        }
    }
}
