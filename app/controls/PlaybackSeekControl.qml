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
import QtMultimedia

Item {
    id: seekController
    required property MediaPlayer mediaPlayer
    property alias busy: slider.pressed

    implicitHeight: 20

    function formatToMinutes(milliseconds) {
        const min = Math.floor(milliseconds / 60000);
        const sec = ((milliseconds - min * 60000) / 1000).toFixed(1);
        return `${min}:${sec.padStart(4, 0)}`;
    }

    RowLayout {
        anchors.fill: parent
        spacing: 22

        Label {
            id: currentTime
            Layout.preferredWidth: 45
            text: seekController.formatToMinutes(seekController.mediaPlayer.position)
            horizontalAlignment: Text.AlignLeft
            font.pixelSize: 11
        }

        Slider {
            id: slider
            Layout.fillWidth: true
            enabled: seekController.mediaPlayer.seekable
            value: seekController.mediaPlayer.position / seekController.mediaPlayer.duration
            onMoved: seekController.mediaPlayer.setPosition(value * seekController.mediaPlayer.duration);
        }

        Label {
            id: remainingTime
            Layout.preferredWidth: 45
            text: seekController.formatToMinutes(seekController.mediaPlayer.duration - seekController.mediaPlayer.position)
            horizontalAlignment: Text.AlignRight
            font.pixelSize: 11
        }
    }
}
