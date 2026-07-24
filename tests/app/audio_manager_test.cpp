#include <catch2/catch_test_macros.hpp>

#include "audiomanager.h"
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
