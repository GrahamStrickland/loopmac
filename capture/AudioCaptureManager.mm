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
static const Float64 kTargetSampleRate = 22050.0;
static const UInt32 kPreferredBufferSize =
    4096; // Added preferred buffer size (samples)

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
    [self initializeTCCFramework];

    // Initialize audio properties
    _isCapturing = NO;
    _aggregateDeviceID = kAudioDeviceUnknown;
    _deviceProcID = NULL;

    if ([self checkTCCPermission:@"kTCCServiceAudioCapture"] == 0) {
      NSError *error = nil;
      if (![self setupAudioTapIfNeeded:&error]) {
        Log(std::string("Failed to setup audio tap: ") +
                std::string([error.localizedDescription UTF8String]),
            "error");
      }
      if (![self setupAggregateDeviceIfNeeded:&error]) {
        Log(std::string("Failed to setup aggregate device: ") +
                std::string([error.localizedDescription UTF8String]),
            "error");
      }
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

#pragma mark - Audio Control Methods

- (BOOL)startCapture:(NSError **)error {
  if (_isCapturing) {
    return YES;
  }

  Log("Starting audio capture");

  auto permission = [self getPermission];
  if (permission != PermissionStatus::PermissionStatusAuthorized) {
    return NO;
  }

  // Set up audio tap and aggregate device if needed
  if (![self setupAudioTapIfNeeded:error]) {
    return NO;
  }

  if (![self setupAggregateDeviceIfNeeded:error]) {
    return NO;
  }

  // Log device IDs for debugging
  Log("Using aggregate device ID: " + std::to_string(_aggregateDeviceID));
  Log("Tap object ID: " + std::to_string(_tapObjectID));

  // Set up IO proc for the aggregate device instead of tap
  OSStatus status =
      AudioDeviceCreateIOProcID(_aggregateDeviceID, HandleAudioDeviceIOProc,
                                (__bridge void *)self, &_deviceProcID);

  if (status != noErr) {
    if (error) {
      NSString *errorDescription = [NSString
          stringWithFormat:
              @"Failed to create IO proc for aggregate device. Status code: "
              @"%d. This typically means there was an issue setting up the "
              @"audio process callback for the device.",
              (int)status];

      *error = [NSError errorWithDomain:@"audio-capture-manager"
                                   code:status
                               userInfo:@{
                                 NSLocalizedDescriptionKey : errorDescription,
                                 @"OSStatus" : @(status),
                                 @"ErrorLocation" : @"AudioDeviceCreateIOProcID"
                               }];
    }
    return NO;
  }

  // Start the IO proc on the aggregate device
  status = AudioDeviceStart(_aggregateDeviceID, _deviceProcID);
  if (status != noErr) {
    AudioDeviceDestroyIOProcID(_aggregateDeviceID, _deviceProcID);
    _deviceProcID = NULL;
    if (error) {
      *error = [NSError
          errorWithDomain:@"audio-capture-manager"
                     code:status
                 userInfo:@{
                   NSLocalizedDescriptionKey : @"Failed to start audio capture"
                 }];
    }
    return NO;
  }

  _isCapturing = YES;
  Log("Audio capture started successfully");
  return YES;
}

- (BOOL)stopCapture:(NSError **)error {
  if (!_isCapturing) {
    return YES;
  }

  Log("Stopping audio capture");

  // Stop and destroy the IO proc on the aggregate device
  if (_deviceProcID != NULL) {
    OSStatus status = AudioDeviceStop(_aggregateDeviceID, _deviceProcID);
    if (status != noErr) {
      if (error) {
        *error = [NSError
            errorWithDomain:@"audio-capture-manager"
                       code:status
                   userInfo:@{
                     NSLocalizedDescriptionKey : @"Failed to stop audio capture"
                   }];
      }
      return NO;
    }

    status = AudioDeviceDestroyIOProcID(_aggregateDeviceID, _deviceProcID);
    if (status != noErr) {
      if (error) {
        *error = [NSError
            errorWithDomain:@"audio-capture-manager"
                       code:status
                   userInfo:@{
                     NSLocalizedDescriptionKey : @"Failed to destroy IO proc"
                   }];
      }
      return NO;
    }

    _deviceProcID = NULL;
  }

  _isCapturing = NO;
  Log("Audio capture stopped successfully");
  return YES;
}

#pragma mark - Audio Data Callback

- (void)setAudioDataCallback:(void (^)(NSData *audioData))callback {
  _audioDataCallback = [callback copy];
}

static OSStatus HandleAudioDeviceIOProc(AudioDeviceID inDevice,
                                        const AudioTimeStamp *inNow,
                                        const AudioBufferList *inInputData,
                                        const AudioTimeStamp *inInputTime,
                                        AudioBufferList *outOutputData,
                                        const AudioTimeStamp *inOutputTime,
                                        void *inClientData) {
  AudioCaptureManager *audioManager =
      (__bridge AudioCaptureManager *)inClientData;
  [audioManager handleAudioInput:inInputData];
  return noErr;
}

- (void)handleAudioInput:(const AudioBufferList *)bufferList {
  if (!_isCapturing || !_audioDataCallback) {
    return;
  }

  @autoreleasepool {
    // Validate input data
    if (!bufferList || bufferList->mNumberBuffers == 0) {
      Log("Invalid buffer list received"
          "error");
      return;
    }

    const AudioBuffer *buffer = &bufferList->mBuffers[0];
    UInt32 numFrames = buffer->mDataByteSize / sizeof(Float32);

    // Determine channel count based on source format
    BOOL isInterleaved =
        !(_sourceFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved);
    UInt32 numChannels = _sourceFormat.mChannelsPerFrame;
    if (numChannels == 0) {
      numChannels = bufferList->mNumberBuffers;
    }

    // For interleaved data, adjust numFrames
    if (isInterleaved) {
      numFrames = numFrames / numChannels;
    }

    // Validate frame count
    if (numFrames == 0) {
      Log("Invalid frame count", "error");
      return;
    }

    @try {
      // Convert to mono
      Float32 *monoBuffer = [self convertToMono:bufferList numFrames:numFrames];
      if (!monoBuffer) {
        return;
      }

      // Resample
      UInt32 resampledFrameLength = 0;
      Float32 *resampledBuffer = [self resampleBuffer:monoBuffer
                                          inputFrames:numFrames
                                         outputFrames:&resampledFrameLength];
      free(monoBuffer);

      if (!resampledBuffer) {
        return;
      }

      // Create NSData safely
      NSData *audioData =
          [[NSData alloc] initWithBytes:resampledBuffer
                                 length:resampledFrameLength * sizeof(Float32)];
      free(resampledBuffer);

      // Send to callback on main thread
      if (audioData) {
        dispatch_async(dispatch_get_main_queue(), ^{
          if (self->_audioDataCallback) {
            self->_audioDataCallback(audioData);
          }
        });
      }
    } @catch (NSException *exception) {
      Log(std::string("Exception in handleAudioInput: ") +
              std::string([exception.description UTF8String]),
          "error");
    }
  }
}

- (Float32 *)convertToMono:(const AudioBufferList *)bufferList
                 numFrames:(UInt32)numFrames {
  if (!bufferList || bufferList->mNumberBuffers == 0) {
    Log("Invalid buffer list received", "error");
    return NULL;
  }

  const AudioBuffer *buffer = &bufferList->mBuffers[0];
  if (!buffer->mData || buffer->mDataByteSize == 0) {
    Log("Invalid buffer data received", "error");
    return NULL;
  }

  Float32 *samples = (Float32 *)buffer->mData;

  // Determine channel count and format based on source format
  BOOL isInterleaved =
      !(_sourceFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved);
  UInt32 numChannels = _sourceFormat.mChannelsPerFrame;
  if (numChannels == 0) {
    numChannels = bufferList->mNumberBuffers;
  }

  // Allocate mono buffer
  Float32 *monoBuffer = (Float32 *)calloc(numFrames, sizeof(Float32));
  if (!monoBuffer) {
    Log("Failed to allocate memory for mono buffer", "error");
    return NULL;
  }

  // Merge channels to mono based on format
  if (isInterleaved) {
    // Handle interleave d format (all channels in one buffer)
    for (UInt32 frame = 0; frame < numFrames; frame++) {
      float sum = 0.0f;
      for (UInt32 channel = 0; channel < numChannels; channel++) {
        sum += samples[frame * numChannels + channel];
      }
      monoBuffer[frame] = sum / numChannels;
    }
  } else {
    // Handle non-interleaved format (separate buffers for each channel)
    for (UInt32 frame = 0; frame < numFrames; frame++) {
      float sum = 0.0f;
      for (UInt32 channel = 0; channel < numChannels; channel++) {
        const AudioBuffer *channelBuffer = &bufferList->mBuffers[channel];
        Float32 *channelData = (Float32 *)channelBuffer->mData;
        sum += channelData[frame];
      }
      monoBuffer[frame] = sum / numChannels;
    }
  }

  return monoBuffer;
}

- (Float32 *)resampleBuffer:(Float32 *)inputBuffer
                inputFrames:(UInt32)inputFrames
               outputFrames:(UInt32 *)outputFrames {
  Float64 sourceRate = _sourceFormat.mSampleRate;
  Float64 ratio = sourceRate / kTargetSampleRate;
  UInt32 newFrameLength = (UInt32)(inputFrames / ratio);

  if (newFrameLength == 0) {
    Log("Invalid resampled frame length", "error");
    return NULL;
  }

  // Allocate buffer for resampled data
  Float32 *resampledBuffer = (Float32 *)calloc(newFrameLength, sizeof(Float32));
  if (!resampledBuffer) {
    Log("Failed to allocate memory for resampled buffer", "error");
    return NULL;
  }

  // Perform sinc sampling
  const UInt32 windowSize = 16;
  const UInt32 halfWindow = windowSize / 2;
  const float M_2PI = 2.0f * M_PI;

  for (UInt32 newIndex = 0; newIndex <= newFrameLength; newIndex++) {
    float position = newIndex * ratio;
    int32_t centerIndex = (int32_t)floorf(position);
    float fracOffset = position - centerIndex;
    float sum = 0.0f;
    float weightSum = 0.0f;

    for (int32_t i = -(int32_t)halfWindow; i <= (int32_t)halfWindow; i++) {
      int32_t sampleIndex = centerIndex + i;

      if (sampleIndex < 0 || (UInt32)sampleIndex >= inputFrames) {
        continue;
      }

      float x = fracOffset - i;
      // Use normalized sinc function
      float sincValue = (x == 0.0f) ? 1.0f : sinf(M_PI * x) / (M_PI * x);
      // Blackman window for better frequency response
      float windowValue = 0.42f -
                          0.5f * cosf(M_PI * (i + halfWindow) / halfWindow) +
                          0.08f * cosf(M_2PI * (i + halfWindow) / halfWindow);
      float weight = sincValue * windowValue;

      sum += inputBuffer[sampleIndex] * weight;
      weightSum += weight;
    }

    // Normalize by total weight
    resampledBuffer[newIndex] = weightSum > 0.0f ? sum / weightSum : 0.0f;
  }

  *outputFrames = newFrameLength;
  return resampledBuffer;
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
                               userInfo:@{
                                 NSLocalizedDescriptionKey :
                                     @"Failed to get default input device"
                               }];
    }
    return NO;
  }

  Log("Got input device ID: " + std::to_string(inputDeviceID));

  // Get default output device
  propertyAddress.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
  status =
      AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0,
                                 NULL, &propertySize, &outputDeviceID);

  if (status != noErr) {
    if (error) {
      *error = [NSError errorWithDomain:@"audio-capture-manager"
                                   code:status
                               userInfo:@{
                                 NSLocalizedDescriptionKey :
                                     @"Failed to get default output device"
                               }];
    }
    return NO;
  }

  Log("Got output device ID: " + std::to_string(outputDeviceID));

  // Get device UIDs
  CFStringRef inputUID, outputUID;
  AudioObjectPropertyAddress uidPropertyAddress = {
      .mSelector = kAudioDevicePropertyDeviceUID,
      .mScope = kAudioObjectPropertyScopeGlobal,
      .mElement = kAudioObjectPropertyElementMain};

  UInt32 dataSize = sizeof(CFStringRef);

  status = AudioObjectGetPropertyData(inputDeviceID, &uidPropertyAddress, 0,
                                      NULL, &dataSize, &inputUID);

  if (status != noErr) {
    if (error) {
      *error = [NSError
          errorWithDomain:@"audio-capture-manager"
                     code:status
                 userInfo:@{
                   NSLocalizedDescriptionKey : @"Failed to get input device UID"
                 }];
    }
    return NO;
  }

  Log("Got input device UID: " +
      std::string([(__bridge NSString *)inputUID UTF8String]));

  status = AudioObjectGetPropertyData(outputDeviceID, &uidPropertyAddress, 0,
                                      NULL, &dataSize, &outputUID);

  if (status != noErr) {
    CFRelease(inputUID);
    if (error) {
      *error = [NSError errorWithDomain:@"audio-capture-manager"
                                   code:status
                               userInfo:@{
                                 NSLocalizedDescriptionKey :
                                     @"Failed to get output device UID"
                               }];
    }
    return NO;
  }

  Log("Got output device UID: " +
      std::string([(__bridge NSString *)outputUID UTF8String]));

  // Get sample rates for both devices
  Float64 inputSampleRate, outputSampleRate;
  AudioObjectPropertyAddress sampleRateAddress = {
      .mSelector = kAudioDevicePropertyNominalSampleRate,
      .mScope = kAudioObjectPropertyScopeGlobal,
      .mElement = kAudioObjectPropertyElementMain};

  dataSize = sizeof(Float64);

  status = AudioObjectGetPropertyData(inputDeviceID, &sampleRateAddress, 0,
                                      NULL, &dataSize, &inputSampleRate);

  if (status != noErr) {
    CFRelease(inputUID);
    CFRelease(outputUID);
    if (error) {
      *error = [NSError errorWithDomain:@"audio-capture-manager"
                                   code:status
                               userInfo:@{
                                 NSLocalizedDescriptionKey :
                                     @"Failed to get input device sample rate"
                               }];
    }
    return NO;
  }

  Log("Input device sample rate: " + std::to_string(inputSampleRate));

  status = AudioObjectGetPropertyData(outputDeviceID, &sampleRateAddress, 0,
                                      NULL, &dataSize, &outputSampleRate);

  if (status != noErr) {
    CFRelease(inputUID);
    CFRelease(outputUID);
    if (error) {
      *error = [NSError errorWithDomain:@"audio-capture-manager"
                                   code:status
                               userInfo:@{
                                 NSLocalizedDescriptionKey :
                                     @"Failed to get output device sample rate"
                               }];
    }
    return NO;
  }

  Log("Output device sample rate: " + std::to_string(outputSampleRate));

  // Choose master device based on lower sample rate
  NSString *masterDeviceUID = inputSampleRate <= outputSampleRate
                                  ? (__bridge NSString *)inputUID
                                  : (__bridge NSString *)outputUID;
  Log("Selected master device UID: " +
      std::string([masterDeviceUID UTF8String]) +
      " (based on sample rate comparison: " + std::to_string(inputSampleRate) +
      " <= " + std::to_string(outputSampleRate) + ")");

  NSUUID *aggregateUID = [NSUUID UUID];
  Log("Created aggregate device UUID: " +
      std::string([[aggregateUID UUIDString] UTF8String]));

  NSDictionary *description = @{
    @(kAudioAggregateDeviceUIDKey) : [aggregateUID UUIDString],
    @(kAudioAggregateDeviceIsPrivateKey) : @(1),
    @(kAudioAggregateDeviceIsStackedKey) : @(0),
    @(kAudioAggregateDeviceMasterSubDeviceKey) : masterDeviceUID,
    @(kAudioAggregateDeviceSubDeviceListKey) : @[
      @{
        @(kAudioSubDeviceUIDKey) : (__bridge NSString *)inputUID,
        @(kAudioSubDeviceDriftCompensationKey) : @(0),
        @(kAudioSubDeviceDriftCompensationQualityKey) :
            @(kAudioSubDeviceDriftCompensationMaxQuality),
      },
      @{
        @(kAudioSubDeviceUIDKey) : (__bridge NSString *)outputUID,
        @(kAudioSubDeviceDriftCompensationKey) : @(1),
        @(kAudioSubDeviceDriftCompensationQualityKey) :
            @(kAudioSubDeviceDriftCompensationMaxQuality),
      },
    ],
    @(kAudioAggregateDeviceTapListKey) : @[
      @{
        @(kAudioSubTapDriftCompensationKey) : @(1),
        @(kAudioSubTapUIDKey) : [_tapUID UUIDString],
      },
    ],
  };

  // Create the aggregate device
  AudioDeviceID aggregateDeviceID;
  status = AudioHardwareCreateAggregateDevice(
      (__bridge CFDictionaryRef)description, &aggregateDeviceID);

  CFRelease(inputUID);
  CFRelease(outputUID);

  if (status != noErr) {
    if (error) {
      *error = [NSError errorWithDomain:@"audio-capture-manager"
                                   code:status
                               userInfo:@{
                                 NSLocalizedDescriptionKey :
                                     @"Failed to create aggregate device"
                               }];
    }
    return NO;
  }

  // Configure buffer size for aggregate device
  AudioObjectPropertyAddress bufferSizeAddress = {
      .mSelector = kAudioDevicePropertyBufferFrameSize,
      .mScope = kAudioDevicePropertyScopeInput,
      .mElement = kAudioObjectPropertyElementMain};

  UInt32 bufferSize = kPreferredBufferSize;
  status = AudioObjectSetPropertyData(aggregateDeviceID, &bufferSizeAddress, 0,
                                      NULL, sizeof(UInt32), &bufferSize);

  if (status == noErr) {
    Log("Set aggregate device buffer size to: " + std::to_string(bufferSize));
  } else {
    Log("Failed to set aggregate device buffer size, continuing with default",
        "warning");
  }

  // Get and log aggregate device info
  Float64 aggregateSampleRate;
  status = AudioObjectGetPropertyData(aggregateDeviceID, &sampleRateAddress, 0,
                                      NULL, &dataSize, &aggregateSampleRate);

  if (status == noErr) {
    Log("Created aggregate device with ID: " +
        std::to_string(aggregateDeviceID) +
        ", sample rate: " + std::to_string(aggregateSampleRate));

    // Get format description
    AudioStreamBasicDescription format;
    UInt32 formatSize = sizeof(AudioStreamBasicDescription);
    AudioObjectPropertyAddress formatAddress = {
        .mSelector = kAudioDevicePropertyStreamFormat,
        .mScope = kAudioDevicePropertyScopeInput,
        .mElement = kAudioObjectPropertyElementMain};

    status = AudioObjectGetPropertyData(aggregateDeviceID, &formatAddress, 0,
                                        NULL, &formatSize, &format);

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
      bool isInterleaved =
          !(format.mFormatFlags & kAudioFormatFlagIsNonInterleaved);
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

  return audioPermissionStatus;
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
