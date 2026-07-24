#include "audiomanager.h"

#include <dispatch/dispatch.h>

AudioManager::AudioManager() = default;

AudioManager::~AudioManager() = default;

AudioManager::PermissionStatus AudioManager::getPermission() {
  return static_cast<PermissionStatus>(captureManager.get_permission());
}

void AudioManager::requestPermission(
    std::function<void(PermissionStatus)> callback) {
  captureManager.request_permission(
      [callback = std::move(callback)](capture::permission_status status) {
        // The capture callback runs on a background thread; hop back onto the
        // main queue before invoking the UI-facing callback.
        const PermissionStatus mapped = static_cast<PermissionStatus>(status);
        dispatch_async(dispatch_get_main_queue(), ^{
          callback(mapped);
        });
      });
}

bool AudioManager::startCapture() {
  return captureManager.start_capture();
}

bool AudioManager::stopCapture() {
  return captureManager.stop_capture();
}
