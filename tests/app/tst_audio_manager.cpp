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

#include <QSignalSpy>

#include "tst_audio_manager.h"
#include "audio_manager.h"
#include "capture.h"
#include "utils.h"

void TestAudioManager::getPermission() {
  AudioManager audioManager;
  auto result =
      static_cast<capture::permission_status>(audioManager.getPermission());

  QVERIFY(utils::is_valid_permission_status(result));
}

void TestAudioManager::requestPermission() {
  AudioManager audioManager;
  QSignalSpy spy(&audioManager, &AudioManager::permissionResult);

  audioManager.requestPermission();

  // permissionResult() is emitted from the capture callback, which only fires
  // once the user answers the interactive system prompt. spy.wait() spins the
  // event loop so the queued emission can be delivered.
  if (!spy.wait(5000)) {
    QSKIP("requestPermission() did not resolve within the timeout; this "
          "requires an interactive system permission prompt that cannot be "
          "answered in a non-interactive environment such as CI.");
  }

  QCOMPARE(spy.count(), 1);
  auto result =
      static_cast<capture::permission_status>(spy.at(0).at(0).toInt());
  QVERIFY(utils::is_request_result_status(result));
}

QTEST_MAIN(TestAudioManager)
