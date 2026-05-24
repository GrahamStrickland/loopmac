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

#include <chrono>
#include <future>
#include <memory>

#include "capture.h"
#include "utils.h"


TEST_CASE("Audio capture manager constructor", "[audio_capture_manager]") {
  auto capture_manager = capture::audio_capture_manager{};
  SUCCEED();
}

TEST_CASE("Audio capture manager get permission returns enum value",
          "[get_permission]") {
  auto capture_manager = capture::audio_capture_manager{};

  auto result = capture_manager.get_permission();

  REQUIRE(utils::is_valid_permission_status(result));
}

TEST_CASE("Audio capture manager request permission resolves via callback",
          "[request_permission]") {
  auto capture_manager = capture::audio_capture_manager{};

  // The callback runs on a background thread once the request resolves. Bridge
  // it back to this thread with a promise so we can wait with a timeout. Use a
  // shared_ptr so the promise outlives this scope: on timeout we SKIP and
  // return, but the callback may still fire later (writing to the promise).
  auto promise =
      std::make_shared<std::promise<capture::permission_status>>();
  auto result_future = promise->get_future();

  capture_manager.request_permission(
      [promise](capture::permission_status status) {
        promise->set_value(status);
      });

  // When the audio capture permission is undetermined, resolving the callback
  // requires answering an interactive system prompt. That cannot happen in a
  // non-interactive environment such as CI, so the callback never fires. Treat
  // a timeout as a skip rather than a failure; on a developer machine where the
  // permission state is already determined the callback runs immediately and
  // the result is asserted below.
  if (result_future.wait_for(std::chrono::seconds(5)) !=
      std::future_status::ready) {
    SKIP("request_permission() did not resolve within the timeout; this "
         "requires an interactive system permission prompt that cannot be "
         "answered in a non-interactive environment such as CI.");
  }

  auto result = result_future.get();
  REQUIRE(utils::is_request_result_status(result));
}
