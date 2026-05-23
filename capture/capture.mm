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

#import "AudioCaptureManager.h"
#import <Foundation/Foundation.h>

#include "capture.h"

namespace capture {
struct audio_capture_manager::impl {
  AudioCaptureManager *audioCaptureManager;
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

std::future<permission_status> audio_capture_manager::request_permission() {
  auto promise = std::make_shared<std::promise<permission_status>>();
  std::future<permission_status> future = promise->get_future();

  [pimpl->audioCaptureManager
      requestPermission:^(PermissionStatus permissionStatus) {
        promise->set_value((permission_status)permissionStatus);
      }];

  return future;
}
} // end namespace capture
