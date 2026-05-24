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

#import "AudioCaptureManager.h"
#import "LogUtil.h"
#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudio/CoreAudio.h>

#include <CoreAudio/AudioHardwareTapping.h>
#include <CoreAudio/CATapDescription.h>

@interface AudioCaptureManager () {
}
@end

@implementation AudioCaptureManager

#pragma mark - Singleton

static AudioCaptureManager *sharedInstance = nil;

+ (instancetype)sharedInstance {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    Log("Creating singleton instance");
    sharedInstance = [[self alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    Log("Intitalizing TCC framework");
    [self initializeTCCFramework];
  }

  if ([self checkTCCPermission:@"kTCCServiceAudioCapture"] == 0) {
  }

  return self;
}

- (void)dealloc {
  Log("Deallocating");
  if (_tccHandle) {
    Log("Closing TCC framework handle");
    dlclose(_tccHandle);
  }
  [super dealloc];
}

#pragma mark - Audio Setup Methods

- (BOOL)setupAudioTapIfNeeded:(NSError **)error {
  if (_tapUID != NULL) {
    return YES;
  }

  Log("Setting up audio tap");

  CATapDescription *desc =
      [[CATapDescription alloc] initMonoGlobalTapButExcludeProcesses:@[]];

  // Create a unique tap UID
  _tapUID = [NSUUID UUID];

  desc.name = [NSString stringWithFormat:@"audiorec-tap-%@", _tapUID];
  desc.UUID = _tapUID;
  desc.privateTap = true;
  desc.muteBehavior = CATapUnmuted;
  desc.exclusive = false;
  desc.mixdown = true;

  _tapObjectID = kAudioObjectUnknown;
  OSStatus ret = AudioHardwareCreateProcessTap(desc, &_tapObjectID);

  if (ret != kAudioHardwareNoError) {
    if (error) {
      *error = [NSError
          errorWithDomain:@"audio-manager"
                     code:ret
                 userInfo:@{
                   NSLocalizedDescriptionKey : @"Failed to create audio tap"
                 }];
    }
    return NO;
  }

  Log("Audio tap setup successfully");
  return YES;
}

#pragma mark - TCC Framework Methods

- (void)initializeTCCFramework {
  Log("Initializing TCC framework");

  // Load TCC framework
  NSString *tccPath =
      @"/System/Library/PrivateFrameworks/TCC.framework/Versions/A/TCC";
  _tccHandle = dlopen([tccPath UTF8String], RTLD_NOW);
  if (!_tccHandle) {
    Log(std::string("Failed to load TCC framework: ") + std::string(dlerror()),
        "error");
    return;
  }
  Log("Successfully loaded TCC framework");

  // Get function pointers
  _preflightFunc =
      (TCCPreflightFuncType)dlsym(_tccHandle, "TCCAccessPreflight");
  _requestFunc = (TCCRequestFuncType)dlsym(_tccHandle, "TCCAccessRequest");

  if (!_preflightFunc || !_requestFunc) {
    Log(std::string("Failed to get TCC function pointers: ") +
            std::string(dlerror()),
        "error");
    dlclose(_tccHandle);
    _tccHandle = NULL;
    return;
  }
  Log("Successfully initialized TCC functions");
}

- (PermissionStatus)checkTCCPermission:(NSString *)service {
  Log("Checking TCC permission for service: " +
      std::string([service UTF8String]));

  if (!_preflightFunc) {
    Log("TCC preflight function not available", "error");
    return PermissionStatusNotDetermined; // Not determined
  }

  auto result =
      (PermissionStatus)_preflightFunc((__bridge CFStringRef)service, NULL);

  Log("TCC permission result: " + std::to_string(result));

  return result;
}

- (void)requestTCCPermission:(NSString *)service
                  completion:(void (^)(BOOL granted))completion {
  Log("Requesting TCC permission for service: " +
      std::string([service UTF8String]));

  if (!_requestFunc) {
    Log("TCC request function not available", "error");
    completion(NO);
    return;
  }

  _requestFunc((__bridge CFStringRef)service, NULL, ^(BOOL granted) {
    Log("TCC permission request for " + std::string([service UTF8String]) +
        " completed with result: " + (granted ? "granted" : "denied"));
    completion(granted);
  });
}

#pragma mark - Permission Methods

- (PermissionStatus)getPermission {
  Log("Getting permission");

  // Check audio recording permission using TCC
  auto audioResult =
      (PermissionStatus)[self checkTCCPermission:@"kTCCServiceAudioCapture"];

  Log("System audio permission status: " + std::to_string(audioResult));

  return audioResult;
}

- (void)requestPermission:(void (^)(PermissionStatus))completion {
  Log("Requesting permission");

  [self requestTCCPermission:@"kTCCServiceAudioCapture"
                  completion:^(BOOL granted) {
                    auto status =
                        granted ? PermissionStatus::PermissionStatusAuthorized
                                : PermissionStatus::PermissionStatusDenied;
                    Log("System audio permission request completed with "
                        "status: " +
                        std::to_string(status));
                    completion(status);
                  }];
}
@end
