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
import QtMultimedia

import QtTest

import LoopMacUI

Item {
    width: 800
    height: 600

    MediaPlayer {
        id: mediaPlayer
    }

    PlaybackSeekControl {
        id: seekControl
        mediaPlayer: mediaPlayer
    }

    TestCase {
        name: "PlaybackSeekControl"

        function test_formatToMinutes() {
            compare(seekControl.formatToMinutes(0), "0:00.000");
            compare(seekControl.formatToMinutes(1), "0:00.001");
            compare(seekControl.formatToMinutes(1000), "0:01.000");
            compare(seekControl.formatToMinutes(61050), "1:01.050");
            compare(seekControl.formatToMinutes(601050), "10:01.050");
        }
    }
}
