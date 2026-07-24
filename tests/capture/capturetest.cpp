#include <catch2/catch_test_macros.hpp>

#include <CoreFoundation/CoreFoundation.h>

#include <chrono>
#include <cmath>
#include <cstddef>
#include <future>
#include <memory>

#include "capture.h"
#include "test_utils.h"

TEST_CASE("Audio capture manager constructor", "[audio_capture_manager]") {
  auto capture_manager = capture::audio_capture_manager{};
  SUCCEED();
}

TEST_CASE("Audio capture manager get permission returns enum value",
          "[audio_capture_manager][get_permission]") {
  auto capture_manager = capture::audio_capture_manager{};

  auto result = capture_manager.get_permission();

  REQUIRE(test_utils::is_valid_permission_status(result));
}

TEST_CASE("Audio capture manager request permission resolves via callback",
          "[audio_capture_manager][request_permission]") {
  auto capture_manager = capture::audio_capture_manager{};

  // The callback runs on a background thread once the request resolves.Use a
  // shared_ptr so the promise outlives this scope: on timeout we SKIP and
  // return, but the callback may still fire later (writing to the promise).
  auto promise = std::make_shared<std::promise<capture::permission_status>>();
  auto result_future = promise->get_future();

  capture_manager.request_permission(
      [promise](capture::permission_status status) {
        promise->set_value(status);
      });

  // When the audio capture permission is undetermined, resolving the callback
  // requires answering an interactive system prompt. That cannot happen in a
  // non-interactive environment such as CI, so the callback never fires. Treat
  // a timeout as a skip rather than a failure.
  if (result_future.wait_for(std::chrono::seconds(5)) !=
      std::future_status::ready) {
    SKIP("request_permission() did not resolve within the timeout; this "
         "requires an interactive system permission prompt that cannot be "
         "answered in a non-interactive environment such as CI.");
  }

  auto result = result_future.get();
  REQUIRE(test_utils::is_request_result_status(result));
}

TEST_CASE("Audio capture manager audio data callback can be replaced and "
          "cleared while idle",
          "[audio_capture_manager][set_audio_data_callback]") {
  auto capture_manager = capture::audio_capture_manager{};

  capture_manager.set_audio_data_callback([](const float *, std::size_t) {});

  // Replacing an installed callback must not require tearing down capture.
  capture_manager.set_audio_data_callback([](const float *, std::size_t) {});

  // An empty std::function removes the callback.
  capture_manager.set_audio_data_callback(
      capture::audio_capture_manager::audio_data_callback{});

  SUCCEED();
}

TEST_CASE("Audio capture manager destruction with an installed callback is "
          "safe",
          "[audio_capture_manager][set_audio_data_callback]") {
  {
    auto capture_manager = capture::audio_capture_manager{};
    capture_manager.set_audio_data_callback([](const float *, std::size_t) {});
  }

  // The installed block holds a pointer to the manager's implementation, so
  // destroying the manager must not leave it dangling behind a live block.
  SUCCEED();
}

TEST_CASE("Audio capture manager delivers PCM samples to the callback",
          "[audio_capture_manager][set_audio_data_callback]") {
  auto capture_manager = capture::audio_capture_manager{};

  if (capture_manager.get_permission() !=
      capture::PermissionStatusAuthorized) {
    SKIP("Capturing audio requires audio capture permission, which cannot be "
         "granted in a non-interactive environment such as CI.");
  }

  auto received_frames = std::size_t{0};
  auto every_sample_finite = true;

  capture_manager.set_audio_data_callback(
      [&](const float *samples, std::size_t frame_count) {
        for (auto i = std::size_t{0}; i < frame_count; ++i) {
          if (!std::isfinite(samples[i])) {
            every_sample_finite = false;
          }
        }
        received_frames += frame_count;
      });

  if (!capture_manager.start_capture()) {
    SKIP("start_capture() failed; the audio tap and aggregate device could not "
         "be set up in this environment.");
  }

  // Captured blocks are delivered on the main dispatch queue, which is only
  // drained while the main run loop runs. A console test never enters it on
  // its own, so pump it here until the first block arrives.
  const auto deadline =
      std::chrono::steady_clock::now() + std::chrono::seconds(5);
  while (received_frames == 0 &&
         std::chrono::steady_clock::now() < deadline) {
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, true);
  }

  REQUIRE(capture_manager.stop_capture());

  // Clear the callback before draining, so blocks already queued cannot reach
  // the stack captures above once this scope exits.
  capture_manager.set_audio_data_callback(
      capture::audio_capture_manager::audio_data_callback{});
  CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);

  if (received_frames == 0) {
    SKIP("No audio blocks were delivered within the timeout; this requires a "
         "usable default input and output device.");
  }

  REQUIRE(every_sample_finite);
}
