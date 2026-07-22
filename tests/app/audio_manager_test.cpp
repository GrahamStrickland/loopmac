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

#include <catch2/catch_test_macros.hpp>

#include "audio_manager.h"
#include "capture.h"
#include "test_utils.h"

// requestPermission() is intentionally not covered: it only resolves once the
// user answers the interactive system prompt, which cannot be automated.
TEST_CASE("getPermission returns a valid status", "[audio_manager]") {
  AudioManager audioManager;
  auto result =
      static_cast<capture::permission_status>(audioManager.getPermission());

  REQUIRE(test_utils::is_valid_permission_status(result));
}

TEST_CASE("stopCapture on an idle manager succeeds", "[audio_manager]") {
  AudioManager audioManager;

  // Stopping when nothing is capturing is a no-op, so this holds regardless of
  // whether audio capture permission has been granted.
  REQUIRE(audioManager.stopCapture());
}

TEST_CASE("startCapture fails without audio capture permission",
          "[audio_manager]") {
  AudioManager audioManager;

  if (audioManager.getPermission() == AudioManager::Authorized) {
    SKIP("Permission is granted, so startCapture() is expected to succeed; "
         "that path is covered by the round-trip test.");
  }

  REQUIRE_FALSE(audioManager.startCapture());
}

TEST_CASE("startCapture and stopCapture round-trip and are idempotent",
          "[audio_manager]") {
  AudioManager audioManager;

  if (audioManager.getPermission() != AudioManager::Authorized) {
    SKIP("startCapture() requires audio capture permission, which cannot be "
         "granted in a non-interactive environment such as CI.");
  }

  REQUIRE(audioManager.startCapture());
  REQUIRE(audioManager.startCapture());

  REQUIRE(audioManager.stopCapture());
  REQUIRE(audioManager.stopCapture());
}
