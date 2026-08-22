#include <filesystem>
#include <fstream>

#include <catch2/catch_test_macros.hpp>

#include "audiomanager.h"

namespace fs = std::filesystem;
namespace {
bool is_valid_permission_status(AudioManager::PermissionStatus status) {
  switch (status) {
  case AudioManager::NotDetermined:
  case AudioManager::Denied:
  case AudioManager::Authorized:
  case AudioManager::Restricted:
    return true;
  default:
    return false;
  }
}

struct temp_file_guard {
  fs::path path;

  temp_file_guard(const std::string &filename) {
    path = fs::temp_directory_path() / filename;
  }

  ~temp_file_guard() {
    if (fs::exists(path)) {
      fs::remove(path);
    }
  }
};
} // namespace

// requestPermission() is intentionally not covered: it only resolves once the
// user answers the interactive system prompt, which cannot be automated.
TEST_CASE("getPermission returns a valid status", "[audio_manager]") {
  AudioManager audioManager;

  REQUIRE(is_valid_permission_status(audioManager.getPermission()));
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

TEST_CASE("writeCapturedAudio succeeds without errors", "[audio_manager]") {
  temp_file_guard temp("test_file.wav");
  std::string errorMessage;
  AudioManager audioManager;

  if (audioManager.getPermission() != AudioManager::Authorized) {
    SKIP("startCapture() requires audio capture permission, which cannot be "
         "granted in a non-interactive environment such as CI.");
  }
  REQUIRE(audioManager.startCapture());
  REQUIRE(audioManager.stopCapture());
  REQUIRE(audioManager.writeCapturedAudio(temp.path.string(), errorMessage));

  REQUIRE(fs::exists(temp.path));
  std::ifstream in(temp.path);
  std::string content;
  std::getline(in, content);
  REQUIRE(content.length() > 0);
}
