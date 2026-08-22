#include "audiomanager.h"

#import "audiocapturemanager.h"
#import "audioengine.h"
#import "logutil.h"

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

#include <string>

// This translation unit is compiled with ARC (see app/CMakeLists.txt), so the
// strong Objective-C member below is retained/released automatically, including
// when `impl` is destroyed via `delete pimpl`.
struct AudioManager::impl {
  AudioCaptureManager *captureManager;
};

namespace {
// -localizedDescription and -UTF8String both return nil/NULL when the error is
// nil, and constructing a std::string from NULL is undefined behaviour.
std::string describe_error(NSError *error) {
  const char *description = [[error localizedDescription] UTF8String];
  return description ? std::string(description) : std::string("unknown error");
}
} // namespace

AudioManager::AudioManager() : pimpl(new impl) {
  _audioEngine = new audio::audio_engine();
  pimpl->captureManager = [[AudioCaptureManager alloc] init];
  [pimpl->captureManager setAudioDataCallback:^(NSData *audioData) {
    if (!audioData)
      return;

    const void *rawBytes = [audioData bytes];
    std::size_t byteLength = [audioData length];

    _audioEngine->write_audio_data(rawBytes, byteLength);
  }];
}

AudioManager::~AudioManager() {
  delete pimpl;
  delete _audioEngine;
}

AudioManager::PermissionStatus AudioManager::getPermission() {
  return static_cast<AudioManager::PermissionStatus>(
      [pimpl->captureManager getPermission]);
}

void AudioManager::requestPermission(
    std::function<void(PermissionStatus)> callback) {
  // `::PermissionStatus` is the Objective-C enum from audiocapturemanager.h;
  // inside this member the unqualified name would resolve to the nested C++
  // enum instead, so the block parameter is spelled with the global scope.
  [pimpl->captureManager requestPermission:^(::PermissionStatus status) {
    const auto mapped = static_cast<AudioManager::PermissionStatus>(status);
    // The capture backend resolves this on a TCC-internal background thread;
    // hop onto the main queue so AppKit callers can update views directly.
    dispatch_async(dispatch_get_main_queue(), ^{
      if (callback) {
        callback(mapped);
      }
    });
  }];
}

bool AudioManager::startCapture() {
  @autoreleasepool {
    NSError *error = nil;
    const bool succeeded = [pimpl->captureManager startCapture:&error];
    if (!succeeded) {
      ScribeLog("AudioManager", describe_error(error), OS_LOG_TYPE_ERROR);
    }
    return succeeded;
  }
}

bool AudioManager::stopCapture() {
  @autoreleasepool {
    NSError *error = nil;
    const bool succeeded = [pimpl->captureManager stopCapture:&error];
    if (!succeeded) {
      ScribeLog("AudioManager", describe_error(error), OS_LOG_TYPE_ERROR);
    }
    return succeeded;
  }
}

bool AudioManager::writeCapturedAudio(std::string filename, std::string &uiError) {
  std::string errorMessage;
  const bool succeeded =
      _audioEngine->export_audio_data_to_wav(filename, errorMessage);
  uiError = errorMessage;
  if (!succeeded) {
    ScribeLog("AudioManager", errorMessage, OS_LOG_TYPE_ERROR);
  }
  return succeeded;
}
