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

#include <future>
#include <memory>
#include <thread>

#import "audiocapturemanager.h"
#import <Foundation/Foundation.h>

#include "capture.h"
#include "logutil.h"

namespace capture {
struct audio_capture_manager::impl {
  AudioCaptureManager *audioCaptureManager;
  audio_data_callback audioDataCallback;
};

audio_capture_manager::audio_capture_manager() : pimpl(new impl) {
  pimpl->audioCaptureManager = [[AudioCaptureManager alloc] init];
}

audio_capture_manager::~audio_capture_manager() {
  [pimpl->audioCaptureManager release];
  delete pimpl;
}

permission_status audio_capture_manager::get_permission() {
  auto permissionStatus = [pimpl->audioCaptureManager getPermission];
  return (permission_status)permissionStatus;
}

void audio_capture_manager::request_permission(
    std::function<void(permission_status)> callback) {
  [pimpl->audioCaptureManager
      requestPermission:^(PermissionStatus permissionStatus) {
        callback((permission_status)permissionStatus);
      }];
}

void audio_capture_manager::set_audio_data_callback(
    audio_data_callback callback) {
  pimpl->audioDataCallback = std::move(callback);

  if (!pimpl->audioDataCallback) {
    [pimpl->audioCaptureManager setAudioDataCallback:nil];
    return;
  }

  // The block captures the impl rather than the std::function so that later
  // calls to this method replace the callback without reinstalling the block.
  impl *state = pimpl;
  [pimpl->audioCaptureManager setAudioDataCallback:^(NSData *audioData) {
    if (!state->audioDataCallback || audioData == nil) {
      return;
    }
    state->audioDataCallback(static_cast<const float *>([audioData bytes]),
                             [audioData length] / sizeof(float));
  }];
}

bool audio_capture_manager::start_capture() {
  NSError *error = nil;

  bool succeeded = [pimpl->audioCaptureManager startCapture:&error];

  if (!succeeded) {
    NSString *errorString = [error localizedDescription];
    LoopMacLog("Capture", std::string([errorString UTF8String]));
  }

  return succeeded;
}

bool audio_capture_manager::stop_capture() {
  NSError *error = nil;

  bool succeeded = [pimpl->audioCaptureManager stopCapture:&error];

  if (!succeeded) {
    NSString *errorString = [error localizedDescription];
    LoopMacLog("Capture", std::string([errorString UTF8String]));
  }

  return succeeded;
}
} // end namespace capture
