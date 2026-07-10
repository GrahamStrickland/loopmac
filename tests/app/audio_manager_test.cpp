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
