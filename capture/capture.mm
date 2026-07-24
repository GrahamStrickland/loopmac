#include <future>
#include <memory>
#include <string>
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

namespace {
// -localizedDescription and -UTF8String both return nil/NULL when the error is
// nil, and constructing a std::string from NULL is undefined behaviour.
std::string describe_error(NSError *error) {
  const char *description = [[error localizedDescription] UTF8String];
  return description ? std::string(description) : std::string("unknown error");
}
} // namespace

bool audio_capture_manager::start_capture() {
  @autoreleasepool {
    NSError *error = nil;

    bool succeeded = [pimpl->audioCaptureManager startCapture:&error];

    if (!succeeded) {
      ScribeLog("Capture", describe_error(error), OS_LOG_TYPE_ERROR);
    }

    return succeeded;
  }
}

bool audio_capture_manager::stop_capture() {
  @autoreleasepool {
    NSError *error = nil;

    bool succeeded = [pimpl->audioCaptureManager stopCapture:&error];

    if (!succeeded) {
      ScribeLog("Capture", describe_error(error), OS_LOG_TYPE_ERROR);
    }

    return succeeded;
  }
}
} // end namespace capture
