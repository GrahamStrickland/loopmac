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

// Constants for audio format
static const UInt32 kPreferredBufferSize = 4096;  // Added preferred buffer size (samples)

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

    // Initialize audio properties
    _aggregateDeviceID = kAudioDeviceUnknown;
  }

  if ([self checkTCCPermission:@"kTCCServiceAudioCapture"] == 0) {
    NSError *error = nil;
    if (![self setupAudioTapIfNeeded:&error]) {
      Log(std::string("Failed to setup audio tap: ") +
              std::string([error.localizedDescription UTF8String]),
          "error");
    }
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
          errorWithDomain:@"audio-capture-manager"
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

#pragma mark - Aggregate Device Setup

- (BOOL)setupAggregateDeviceIfNeeded:(NSError **)error {
  if (_aggregateDeviceID != kAudioDeviceUnknown) {
    return YES;
  }

  Log("Setting up aggregate device");

  // Get default input and output devices
  AudioDeviceID inputDeviceID, outputDeviceID;
  UInt32 propertySize = sizeof(AudioDeviceID);
  AudioObjectPropertyAddress propertyAddress = {
      .mSelector = kAudioHardwarePropertyDefaultInputDevice,
      .mScope = kAudioObjectPropertyScopeGlobal,
      .mElement = kAudioObjectPropertyElementMain};

  // Get default input device
  OSStatus status =
      AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0,
                                 NULL, &propertySize, &inputDeviceID);

  if (status != noErr) {
    if (error) {
      *error = [NSError errorWithDomain:@"audio-capture-manager"
                                   code:status
                               userInfo:@{NSLocalizedDescriptionKey: @"Failed to get default input device"}];
    }
    return NO;
  }

  Log("Got input device ID: " + std::to_string(inputDeviceID));

  // Get default output device
  propertyAddress.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
  status = AudioObjectGetPropertyData(kAudioObjectSystemObject,
                                      &propertyAddress,
                                      0,
                                      NULL,
                                      &propertySize,
                                      &outputDeviceID);

  if (status != noErr) {
    if (error) {
      *error = [NSError errorWithDomain:@"audio-capture-manager"
                                  code:status
                              userInfo:@{NSLocalizedDescriptionKey: @"Failed to get default output device"}];
    }
    return NO;
  }

  // Get device UIDs
  CFStringRef inputUID, outputUID;
  AudioObjectPropertyAddress uidPropertyAddress = {
    .mSelector = kAudioDevicePropertyDeviceUID,
    .mScope = kAudioObjectPropertyScopeGlobal,
    .mElement = kAudioObjectPropertyElementMain
  };

  UInt32 dataSize = sizeof(CFStringRef);

  status = AudioObjectGetPropertyData(inputDeviceID,
                                      &uidPropertyAddress,
                                      0,
                                      NULL,
                                      &dataSize,
                                      &inputUID);

  if (status != noErr) {
    if (error) {
      *error = [NSError errorWithDomain:@"audio-capture-manager"
                                  code:status
                              userInfo:@{NSLocalizedDescriptionKey: @"Failed to get input device UID"}];
    }
    return NO;
  }

  Log("Got input device UID: " + std::string([(__bridge NSString *)inputUID UTF8String]));

  status = AudioObjectGetPropertyData(outputDeviceID,
                                      &uidPropertyAddress,
                                      0,
                                      NULL,
                                      &dataSize,
                                      &outputUID);

  if (status != noErr) {
    CFRelease(inputUID);
    if (error) {
      *error = [NSError errorWithDomain:@"audio-capture-manager"
                                  code:status
                              userInfo:@{NSLocalizedDescriptionKey: @"Failed to get output device UID"}];
    }
    return NO;
  }

  Log("Got output device UID: " + std::string([(__bridge NSString *)outputUID UTF8String]));

  // Get sample rates for both devices
  Float64 inputSampleRate, outputSampleRate;
  AudioObjectPropertyAddress sampleRateAddress = {
    .mSelector = kAudioDevicePropertyNominalSampleRate,
    .mScope = kAudioObjectPropertyScopeGlobal,
    .mElement = kAudioObjectPropertyElementMain
  };

  dataSize = sizeof(Float64);

  status = AudioObjectGetPropertyData(inputDeviceID,
                                      &sampleRateAddress,
                                      0,
                                      NULL,
                                      &dataSize,
                                      &inputSampleRate);

  if (status != noErr) {
    CFRelease(inputUID);
    CFRelease(outputUID);
    if (error) {
      *error = [NSError errorWithDomain:@"audio-capture-manager"
                                  code:status
                              userInfo:@{NSLocalizedDescriptionKey: @"Failed to get input device sample rate"}];
    }
    return NO;
  }

  Log("Input device sample rate: " + std::to_string(inputSampleRate));

  status = AudioObjectGetPropertyData(outputDeviceID,
                                      &sampleRateAddress,
                                      0,
                                      NULL,
                                      &dataSize,
                                      &outputSampleRate);

  if (status != noErr) {
    CFRelease(inputUID);
    CFRelease(outputUID);
    if (error) {
      *error = [NSError errorWithDomain:@"audio-capture-manager"
                                  code:status
                              userInfo:@{NSLocalizedDescriptionKey: @"Failed to get output device sample rate"}];
    }
    return NO;
  }

  Log("Output device sample rate: " + std::to_string(outputSampleRate));

  // Choose master device based on lower sample rate
  NSString *masterDeviceUID = inputSampleRate <= outputSampleRate ? (__bridge NSString *)inputUID : (__bridge NSString *)outputUID;
  Log("Selected master device UID: " + std::string([masterDeviceUID UTF8String]) +
          " (based on sample rate comparison: " + std::to_string(inputSampleRate) + " <= " + std::to_string(outputSampleRate) + ")");

  NSUUID *aggregateUID = [NSUUID UUID];
  Log("Created aggregate device UUID: " + std::string([[aggregateUID UUIDString] UTF8String]));

  NSDictionary *description = @{
    @(kAudioAggregateDeviceUIDKey): [aggregateUID UUIDString],
    @(kAudioAggregateDeviceIsPrivateKey): @(1),
    @(kAudioAggregateDeviceIsStackedKey): @(0),
    @(kAudioAggregateDeviceMasterSubDeviceKey): masterDeviceUID,
    @(kAudioAggregateDeviceSubDeviceListKey): @[
      @{
        @(kAudioSubDeviceUIDKey): (__bridge NSString *)inputUID,
        @(kAudioSubDeviceDriftCompensationKey): @(0),
        @(kAudioSubDeviceDriftCompensationQualityKey): @(kAudioSubDeviceDriftCompensationMaxQuality),
      },
      @{
        @(kAudioSubDeviceUIDKey): (__bridge NSString *)outputUID,
        @(kAudioSubDeviceDriftCompensationKey): @(1),
        @(kAudioSubDeviceDriftCompensationQualityKey): @(kAudioSubDeviceDriftCompensationMaxQuality),
      },
    ],
    @(kAudioAggregateDeviceTapListKey): @[
      @{
        @(kAudioSubTapDriftCompensationKey): @(1),
        @(kAudioSubTapUIDKey): [_tapUID UUIDString],
      },
    ],
  };

  // Create the aggregate device
  AudioDeviceID aggregateDeviceID;
  status = AudioHardwareCreateAggregateDevice((__bridge CFDictionaryRef)description, &aggregateDeviceID);

  CFRelease(inputUID);
  CFRelease(outputUID);

  if (status != noErr) {
    if (error) {
      *error = [NSError errorWithDomain:@"audio-capture-manager"
                                  code:status
                              userInfo:@{NSLocalizedDescriptionKey: @"Failed to create aggregate device"}];
    }
    return NO;
  }

  // Configure buffer size for aggregate device
  AudioObjectPropertyAddress bufferSizeAddress = {
    .mSelector = kAudioDevicePropertyBufferFrameSize,
    .mScope = kAudioDevicePropertyScopeInput,
    .mElement = kAudioObjectPropertyElementMain
  };

  UInt32 bufferSize = kPreferredBufferSize;
  status = AudioObjectSetPropertyData(aggregateDeviceID,
                                      &bufferSizeAddress,
                                      0,
                                      NULL,
                                      sizeof(UInt32),
                                      &bufferSize);

  if (status == noErr) {
    Log("Set aggregate device buffer size to: " + std::to_string(bufferSize));
  } else {
    Log("Failed to set aggregate device buffer size, continuing with default", "warning");
  }

  // Get and log aggregate device info
  Float64 aggregateSampleRate;
  status = AudioObjectGetPropertyData(aggregateDeviceID,
                                      &sampleRateAddress,
                                      0,
                                      NULL,
                                      &dataSize,
                                      &aggregateSampleRate);

  if (status == noErr) {
    Log("Created aggregate device with ID: " + std::to_string(aggregateDeviceID) +
            ", sample rate: " + std::to_string(aggregateSampleRate));

    // Get format description
    AudioStreamBasicDescription format;
    UInt32 formatSize = sizeof(AudioStreamBasicDescription);
    AudioObjectPropertyAddress formatAddress = {
      .mSelector = kAudioDevicePropertyStreamFormat,
      .mScope = kAudioDevicePropertyScopeInput,
      .mElement = kAudioObjectPropertyElementMain
    };

    status = AudioObjectGetPropertyData(aggregateDeviceID,
                                        &formatAddress,
                                        0,
                                        NULL,
                                        &formatSize,
                                        &format);

    if (status == noErr) {
      Log("Aggregate device format details:");
      Log("- Sample rate: " + std::to_string(format.mSampleRate));
      Log("- Format ID: " + std::to_string(format.mFormatID));
      Log("- Format flags: " + std::to_string(format.mFormatFlags));
      Log("- Bytes per packet: " + std::to_string(format.mBytesPerPacket));
      Log("- Frames per packet: " + std::to_string(format.mFramesPerPacket));
      Log("- Byes per frame: " + std::to_string(format.mBytesPerFrame));
      Log("- Channels per frame: " + std::to_string(format.mChannelsPerFrame));
      Log("- Bits per channel: " + std::to_string(format.mBitsPerChannel));
      bool isInterleaved = !(format.mFormatFlags & kAudioFormatFlagIsNonInterleaved);
      Log("- Is interleaved: " + std::string(isInterleaved ? "yes" : "no"));
    }
    _sourceFormat = format;
  }

  _aggregateDeviceID = aggregateDeviceID;
  Log("Aggregate device setup successfully");
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

- (int)checkTCCPermission:(NSString *)service {
  Log("Checking TCC permission for service: " +
      std::string([service UTF8String]));

  if (!_preflightFunc) {
    Log("TCC preflight function not available", "error");
    return PermissionStatusNotDetermined; // Not determined
  }

  auto result = _preflightFunc((__bridge CFStringRef)service, NULL);

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

  PermissionStatus audioPermissionStatus;
  switch (audioResult) {
  case 0:
    audioPermissionStatus = PermissionStatus::PermissionStatusAuthorized;
    break;
  case 1:
    audioPermissionStatus = PermissionStatus::PermissionStatusDenied;
    break;
  case 2:
    audioPermissionStatus = PermissionStatus::PermissionStatusNotDetermined;
    break;
  default:
    audioPermissionStatus = PermissionStatus::PermissionStatusNotDetermined;
    break;
  }

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
