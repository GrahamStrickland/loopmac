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

Item {
    id: audioController

    property alias busy: slider.pressed
    property alias muted: muteButton.checked
    property real volume: slider.value
    property alias showSlider: slider.visible
    property int iconDimension: 24

    implicitHeight: 46
    implicitWidth: mainLayout.width

    RowLayout {
        id: mainLayout
        spacing: 10
        anchors.verticalCenter: parent.verticalCenter

        RoundButton {
            id: muteButton
            implicitHeight: 40
            implicitWidth: 40
            radius: 4
            icon.source: audioController.muted ? "../../images/volume-slash.svg" : "../../images/volume.svg"
            icon.width: audioController.iconDimension
            icon.height: audioController.iconDimension
            icon.color: palette.buttonText
            flat: true
            checkable: true
        }

        Slider {
            id: slider
            implicitWidth: 136
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            enabled: true
            value: 1
        }
    }
}
