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

import AudioManager 1.0

Item {
    id: playbackController

    required property MediaPlayer mediaPlayer

    property alias muted: audioControl.muted
    property alias volume: audioControl.volume

    property bool busy: fileDialog.visible || audioControl.busy || playbackSeekControl.busy

    implicitHeight: 168

    AudioManager {
        id: audioManager
        onPermissionResult: (status) => {
            if (status === AudioManager.Authorized) {
                // TODO: start recording
                console.log("Audio capture authorized — starting recording");
            } else {
                console.log(`Audio capture permission not granted: ${status}`);
            }
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

    FileDialog {
        id: fileDialog
        title: "Please choose a file"
        onAccepted: {
            playbackController.mediaPlayer.stop();
            playbackController.mediaPlayer.source = fileDialog.selectedFile;
            playbackController.mediaPlayer.play();
        }
    }

    Frame {
        id: controlsLayout
        anchors.fill: parent
        padding: 32
        topPadding: 28

        ColumnLayout {
            anchors.fill: parent
            spacing: 16

            PlaybackSeekControl {
                id: playbackSeekControl
                Layout.fillWidth: true
                mediaPlayer: playbackController.mediaPlayer
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: 40

                CustomButton {
                    id: fileDialogButton
                    icon.source: "../images/folder-open.svg"
                    flat: false
                    onClicked: fileDialog.open()

                    anchors.left: parent.left
                }

                CustomButton {
                    id: recordButton
                    icon.source: "../images/dot-circle.svg"
                    flat: false
                    onClicked: () => {
                        if (audioManager.getPermission() === AudioManager.Authorized) {
                            // TODO: start recording
                            console.log("Already authorized — starting recording");
                        } else {
                            // Returns immediately; result arrives via onPermissionResult.
                            audioManager.requestPermission();
                        }
                    }

                    anchors.left: fileDialogButton.right
                }

                RowLayout {
                    id: controlButtons
                    spacing: 16
                    anchors.horizontalCenter: parent.horizontalCenter

                    CustomRoundButton {
                        id: backward10Button
                        icon.source: "../images/angle-double-small-left.svg"
                        onClicked: {
                            const pos = Math.max(0, playbackController.mediaPlayer.position - 10000);
                            playbackController.mediaPlayer.setPosition(pos);
                        }
                    }

                    CustomRoundButton {
                        id: playButton
                        visible: playbackController.mediaPlayer.playbackState !== MediaPlayer.PlayingState
                        icon.source: "../images/play-circle.svg"
                        onClicked: playbackController.mediaPlayer.play()
                    }

                    CustomRoundButton {
                        id: pauseButton
                        visible: playbackController.mediaPlayer.playbackState === MediaPlayer.PlayingState
                        icon.source: "../images/pause-circle.svg"
                        onClicked: playbackController.mediaPlayer.pause()
                    }

                    CustomRoundButton {
                        id: forward10Button
                        icon.source: "../images/angle-double-small-right.svg"
                        onClicked: {
                            const pos = Math.max(0, playbackController.mediaPlayer.position + 10000);
                            playbackController.mediaPlayer.setPosition(pos);
                        }
                    }
                }

                AudioControl {
                    id: audioControl
                    showSlider: true
                    anchors.right: parent.right
                }
            }
        }
    }
}
