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

#include "audio_manager.h"

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
