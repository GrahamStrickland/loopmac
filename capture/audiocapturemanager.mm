#import "audiocapturemanager.h"
#import "logutil.h"
#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudio/CoreAudio.h>

#include <CoreAudio/AudioHardwareTapping.h>
#include <CoreAudio/CATapDescription.h>

// Constants for audio format
static const Float64 kTargetSampleRate = 22050.0;
static const UInt32 kTargetChannelCount = 1;
static const UInt32 kBitsPerChannel = 32;
static const UInt32 kPreferredBufferSize =
    4096; // Added preferred buffer size (samples)

// Constants for device monitoring
static const UInt32 kDeviceChangeScope = kAudioObjectPropertyScopeGlobal;
static const UInt32 kDeviceChangeElement = kAudioObjectPropertyElementMain;

@interface AudioCaptureManager () {
}
@end

@implementation AudioCaptureManager

#pragma mark - Singleton

static AudioCaptureManager *sharedInstance = nil;

+ (instancetype)sharedInstance {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    ScribeLog("AudioCaptureManager", "Creating singleton instance");
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
    _audioQueue = dispatch_queue_create("audio-capture-manager-queue",
                                        DISPATCH_QUEUE_SERIAL);
    _aggregateDeviceID = kAudioDeviceUnknown;
    _deviceProcID = NULL;

    // Set up target format
    _targetFormat.mSampleRate = kTargetSampleRate;
    _targetFormat.mFormatID = kAudioFormatLinearPCM;
    _targetFormat.mFormatFlags =
        kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    _targetFormat.mFramesPerPacket = 1;
    _targetFormat.mChannelsPerFrame = kTargetChannelCount;
    _targetFormat.mBitsPerChannel = kBitsPerChannel;
    _targetFormat.mBytesPerPacket =
        (_targetFormat.mBitsPerChannel / 8) * _targetFormat.mChannelsPerFrame;
    _targetFormat.mBytesPerFrame = _targetFormat.mBytesPerPacket;

    if ([self checkTCCPermission:@"kTCCServiceAudioCapture"] == 0) {
      NSError *error = nil;
      if (![self setupAudioTapIfNeeded:&error]) {
        ScribeLog("AudioCaptureManager",
                  std::string("Failed to setup audio tap: ") +
                      std::string([error.localizedDescription UTF8String]),
                  OS_LOG_TYPE_ERROR);
      }
      if (![self setupAggregateDeviceIfNeeded:&error]) {
        ScribeLog("AudioCaptureManager",
                  std::string("Failed to setup aggregate device: ") +
                      std::string([error.localizedDescription UTF8String]),
                  OS_LOG_TYPE_ERROR);
      }
      [self startDeviceMonitoring];
    }
  }

  return self;
}

- (void)dealloc {
  ScribeLog("AudioCaptureManager", "Deallocating");
  [self stopDeviceMonitoring];
  [self destroyAudioResources];
  [_audioDataCallback release];
  _audioDataCallback = nil;
  if (_tccHandle) {
    ScribeLog("AudioCaptureManager", "Closing TCC framework handle");
    dlclose(_tccHandle);
  }
  [super dealloc];
}

#pragma mark - Audio Control Methods

- (BOOL)startCapture:(NSError **)error {
  if (_isCapturing) {
    return YES;
  }

  ScribeLog("AudioCaptureManager", "Starting audio capture");

  auto permission = [self getPermission];
  if (permission != PermissionStatus::PermissionStatusAuthorized) {
    if (error) {
      *error = [NSError
          errorWithDomain:@"audio-capture-manager"
                     code:permission
                 userInfo:@{
                   NSLocalizedDescriptionKey :
                       @"Audio capture permission has not been granted",
                   @"ErrorLocation" : @"getPermission"
                 }];
    }
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
  ScribeLog("AudioCaptureManager",
            "Using aggregate device ID: " + std::to_string(_aggregateDeviceID));
  ScribeLog("AudioCaptureManager",
            "Tap object ID: " + std::to_string(_tapObjectID));

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
  ScribeLog("AudioCaptureManager", "Audio capture started successfully");
  return YES;
}

- (BOOL)stopCapture:(NSError **)error {
  if (!_isCapturing) {
    return YES;
  }

  ScribeLog("AudioCaptureManager", "Stopping audio capture");

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
  ScribeLog("AudioCaptureManager", "Audio capture stopped successfully");
  return YES;
}

#pragma mark - Audio Data Callback

- (void)setAudioDataCallback:(void (^)(NSData *audioData))callback {
  void (^previousCallback)(NSData *) = _audioDataCallback;
  _audioDataCallback = [callback copy];
  [previousCallback release];
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
      ScribeLog("AudioCaptureManager", "Invalid buffer list received",
                OS_LOG_TYPE_ERROR);
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
      ScribeLog("AudioCaptureManager", "Invalid frame count",
                OS_LOG_TYPE_ERROR);
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
      ScribeLog("AudioCaptureManager",
                std::string("Exception in handleAudioInput: ") +
                    std::string([exception.description UTF8String]),
                OS_LOG_TYPE_ERROR);
    }
  }
}

- (Float32 *)convertToMono:(const AudioBufferList *)bufferList
                 numFrames:(UInt32)numFrames {
  if (!bufferList || bufferList->mNumberBuffers == 0) {
    ScribeLog("AudioCaptureManager", "Invalid buffer list received",
              OS_LOG_TYPE_ERROR);
    return NULL;
  }

  const AudioBuffer *buffer = &bufferList->mBuffers[0];
  if (!buffer->mData || buffer->mDataByteSize == 0) {
    ScribeLog("AudioCaptureManager", "Invalid buffer data received",
              OS_LOG_TYPE_ERROR);
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
    ScribeLog("AudioCaptureManager",
              "Failed to allocate memory for mono buffer", OS_LOG_TYPE_ERROR);
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
    ScribeLog("AudioCaptureManager", "Invalid resampled frame length",
              OS_LOG_TYPE_ERROR);
    return NULL;
  }

  // Allocate buffer for resampled data
  Float32 *resampledBuffer = (Float32 *)calloc(newFrameLength, sizeof(Float32));
  if (!resampledBuffer) {
    ScribeLog("AudioCaptureManager",
              "Failed to allocate memory for resampled buffer",
              OS_LOG_TYPE_ERROR);
    return NULL;
  }

  // Perform sinc sampling
  const UInt32 windowSize = 16;
  const UInt32 halfWindow = windowSize / 2;
  const float M_2PI = 2.0f * M_PI;

  for (UInt32 newIndex = 0; newIndex < newFrameLength; newIndex++) {
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

  ScribeLog("AudioCaptureManager", "Setting up audio tap");

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

  ScribeLog("AudioCaptureManager", "Audio tap setup successfully");
  return YES;
}

#pragma mark - Aggregate Device Setup

- (BOOL)setupAggregateDeviceIfNeeded:(NSError **)error {
  if (_aggregateDeviceID != kAudioDeviceUnknown) {
    return YES;
  }

  ScribeLog("AudioCaptureManager", "Setting up aggregate device");

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

  ScribeLog("AudioCaptureManager",
            "Got input device ID: " + std::to_string(inputDeviceID));

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

  ScribeLog("AudioCaptureManager",
            "Got output device ID: " + std::to_string(outputDeviceID));

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

  ScribeLog("AudioCaptureManager",
            "Got input device UID: " +
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

  ScribeLog("AudioCaptureManager",
            "Got output device UID: " +
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

  ScribeLog("AudioCaptureManager",
            "Input device sample rate: " + std::to_string(inputSampleRate));

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

  ScribeLog("AudioCaptureManager",
            "Output device sample rate: " + std::to_string(outputSampleRate));

  // Choose master device based on lower sample rate
  NSString *masterDeviceUID = inputSampleRate <= outputSampleRate
                                  ? (__bridge NSString *)inputUID
                                  : (__bridge NSString *)outputUID;
  ScribeLog("AudioCaptureManager",
            "Selected master device UID: " +
                std::string([masterDeviceUID UTF8String]) +
                " (based on sample rate comparison: " +
                std::to_string(inputSampleRate) +
                " <= " + std::to_string(outputSampleRate) + ")");

  NSUUID *aggregateUID = [NSUUID UUID];
  ScribeLog("AudioCaptureManager",
            "Created aggregate device UUID: " +
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
    ScribeLog("AudioCaptureManager", "Set aggregate device buffer size to: " +
                                         std::to_string(bufferSize));
  } else {
    ScribeLog(
        "AudioCaptureManager",
        "Failed to set aggregate device buffer size, continuing with default",
        OS_LOG_TYPE_ERROR);
  }

  // Get and log aggregate device info
  Float64 aggregateSampleRate;
  status = AudioObjectGetPropertyData(aggregateDeviceID, &sampleRateAddress, 0,
                                      NULL, &dataSize, &aggregateSampleRate);

  if (status == noErr) {
    ScribeLog("AudioCaptureManager",
              "Created aggregate device with ID: " +
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
      ScribeLog("AudioCaptureManager", "Aggregate device format details:");
      ScribeLog("AudioCaptureManager",
                "- Sample rate: " + std::to_string(format.mSampleRate));
      ScribeLog("AudioCaptureManager",
                "- Format ID: " + std::to_string(format.mFormatID));
      ScribeLog("AudioCaptureManager",
                "- Format flags: " + std::to_string(format.mFormatFlags));
      ScribeLog("AudioCaptureManager",
                "- Bytes per packet: " +
                    std::to_string(format.mBytesPerPacket));
      ScribeLog("AudioCaptureManager",
                "- Frames per packet: " +
                    std::to_string(format.mFramesPerPacket));
      ScribeLog("AudioCaptureManager",
                "- Byes per frame: " + std::to_string(format.mBytesPerFrame));
      ScribeLog("AudioCaptureManager",
                "- Channels per frame: " +
                    std::to_string(format.mChannelsPerFrame));
      ScribeLog("AudioCaptureManager",
                "- Bits per channel: " +
                    std::to_string(format.mBitsPerChannel));
      bool isInterleaved =
          !(format.mFormatFlags & kAudioFormatFlagIsNonInterleaved);
      ScribeLog("AudioCaptureManager",
                "- Is interleaved: " +
                    std::string(isInterleaved ? "yes" : "no"));
    }
    _sourceFormat = format;
  }

  _aggregateDeviceID = aggregateDeviceID;
  ScribeLog("AudioCaptureManager", "Aggregate device setup successfully");
  return YES;
}

#pragma mark - Device Monitoring

- (void)startDeviceMonitoring {
  ScribeLog("AudioCaptureManager", "Starting device monitoring");

  // Set up device change listener for both input and output devices
  AudioObjectPropertyAddress propertyAddress = {
      .mSelector = kAudioHardwarePropertyDefaultInputDevice,
      .mScope = kDeviceChangeScope,
      .mElement = kDeviceChangeElement};

  // Create block for device changes.
  __block AudioCaptureManager *blockSelf = self;
  _deviceChangeListener = [^(UInt32 inNumberAddresses,
                             const AudioObjectPropertyAddress *inAddresses) {
    [blockSelf handleDeviceChange];
  } copy];

  // Add listener for input device changes
  OSStatus status = AudioObjectAddPropertyListenerBlock(
      kAudioObjectSystemObject, &propertyAddress, self->_audioQueue,
      self->_deviceChangeListener);

  if (status != noErr) {
    ScribeLog("AudioCaptureManager",
              "Failed to add input device change listener", OS_LOG_TYPE_ERROR);
    return;
  }

  // Add listener for output device changes
  propertyAddress.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
  status = AudioObjectAddPropertyListenerBlock(
      kAudioObjectSystemObject, &propertyAddress, self->_audioQueue,
      self->_deviceChangeListener);

  if (status != noErr) {
    ScribeLog("AudioCaptureManager",
              "Failed to add output device change listener", OS_LOG_TYPE_ERROR);
    return;
  }

  ScribeLog("AudioCaptureManager", "Device monitoring started successfully");
}

- (void)handleDeviceChange {
  ScribeLog("AudioCaptureManager", "Handling device change");

  // If we're currently capturing, we need to recreate the audio setup
  BOOL wasCapturing = _isCapturing;
  if (wasCapturing) {
    NSError *error = nil;
    [self stopCapture:&error];
    if (error) {
      ScribeLog("AudioCaptureManager",
                std::string("Failed to stop capture after device change: ") +
                    std::string([error.localizedDescription UTF8String]),
                OS_LOG_TYPE_ERROR);
      return;
    }
  }

  // Destroy and recreate audio resources
  [self destroyAudioResources];

  NSError *error = nil;
  if (![self setupAudioTapIfNeeded:&error]) {
    ScribeLog("AudioCaptureManager",
              std::string("Failed to setup audio tap after device change: ") +
                  std::string([error.localizedDescription UTF8String]),
              OS_LOG_TYPE_ERROR);
    return;
  }

  if (![self setupAggregateDeviceIfNeeded:&error]) {
    ScribeLog(
        "AudioCaptureManager",
        std::string("Failed to setup aggregate device after device change: ") +
            std::string([error.localizedDescription UTF8String]),
        OS_LOG_TYPE_ERROR);
    return;
  }

  // If we were capturing before, restart capture
  if (wasCapturing) {
    NSError *error = nil;
    [self startCapture:&error];
    if (error) {
      ScribeLog("AudioCaptureManager",
                std::string("Failed to start capture after device change: ") +
                    std::string([error.localizedDescription UTF8String]),
                OS_LOG_TYPE_ERROR);
      return;
    }
  }

  ScribeLog("AudioCaptureManager", "Device change handled successfully");
}

- (void)stopDeviceMonitoring {
  ScribeLog("AudioCaptureManager", "Stopping device monitoring");

  if (_deviceChangeListener) {
    // REmove input device listener
    AudioObjectPropertyAddress propertyAddress = {
        .mSelector = kAudioHardwarePropertyDefaultInputDevice,
        .mScope = kDeviceChangeScope,
        .mElement = kDeviceChangeElement};

    AudioObjectRemovePropertyListenerBlock(kAudioObjectSystemObject,
                                           &propertyAddress, _audioQueue,
                                           _deviceChangeListener);

    // Remove output device listener
    propertyAddress.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
    AudioObjectRemovePropertyListenerBlock(kAudioObjectSystemObject,
                                           &propertyAddress, _audioQueue,
                                           _deviceChangeListener);

    [_deviceChangeListener release];
    _deviceChangeListener = nil;
  }

  ScribeLog("AudioCaptureManager", "Device monitoring stopped");
}

- (void)destroyAudioResources {
  ScribeLog("AudioCaptureManager", "Destroying audio resources");

  if (_deviceProcID && _aggregateDeviceID != kAudioDeviceUnknown) {
    AudioDeviceDestroyIOProcID(_aggregateDeviceID, _deviceProcID);
    _deviceProcID = NULL;
  }

  if (_tapObjectID != 0) {
    AudioHardwareDestroyProcessTap(_tapObjectID);
    _tapObjectID = 0;
  }

  if (_tapUID) {
    _tapUID = NULL;
  }

  if (_aggregateDeviceID != kAudioDeviceUnknown) {
    AudioHardwareDestroyAggregateDevice(_aggregateDeviceID);
    _aggregateDeviceID = kAudioDeviceUnknown;
  }

  ScribeLog("AudioCaptureManager", "Audio resources destroyed");
}

#pragma mark - TCC Framework Methods

- (void)initializeTCCFramework {
  ScribeLog("AudioCaptureManager", "Initializing TCC framework");

  // Load TCC framework
  NSString *tccPath =
      @"/System/Library/PrivateFrameworks/TCC.framework/Versions/A/TCC";
  _tccHandle = dlopen([tccPath UTF8String], RTLD_NOW);
  if (!_tccHandle) {
    ScribeLog("AudioCaptureManager",
              std::string("Failed to load TCC framework: ") +
                  std::string(dlerror()),
              OS_LOG_TYPE_ERROR);
    return;
  }
  ScribeLog("AudioCaptureManager", "Successfully loaded TCC framework");

  // Get function pointers
  _preflightFunc =
      (TCCPreflightFuncType)dlsym(_tccHandle, "TCCAccessPreflight");
  _requestFunc = (TCCRequestFuncType)dlsym(_tccHandle, "TCCAccessRequest");

  if (!_preflightFunc || !_requestFunc) {
    ScribeLog("AudioCaptureManager",
              std::string("Failed to get TCC function pointers: ") +
                  std::string(dlerror()),
              OS_LOG_TYPE_ERROR);
    dlclose(_tccHandle);
    _tccHandle = NULL;
    return;
  }
  ScribeLog("AudioCaptureManager", "Successfully initialized TCC functions");
}

- (int)checkTCCPermission:(NSString *)service {
  ScribeLog("AudioCaptureManager", "Checking TCC permission for service: " +
                                       std::string([service UTF8String]));

  if (!_preflightFunc) {
    ScribeLog("AudioCaptureManager", "TCC preflight function not available",
              OS_LOG_TYPE_ERROR);
    return PermissionStatusNotDetermined; // Not determined
  }

  auto result = _preflightFunc((__bridge CFStringRef)service, NULL);

  ScribeLog("AudioCaptureManager",
            "TCC permission result: " + std::to_string(result));

  return result;
}

- (void)requestTCCPermission:(NSString *)service
                  completion:(void (^)(BOOL granted))completion {
  ScribeLog("AudioCaptureManager", "Requesting TCC permission for service: " +
                                       std::string([service UTF8String]));

  if (!_requestFunc) {
    ScribeLog("AudioCaptureManager", "TCC request function not available",
              OS_LOG_TYPE_ERROR);
    completion(NO);
    return;
  }

  _requestFunc((__bridge CFStringRef)service, NULL, ^(BOOL granted) {
    ScribeLog(
        "AudioCaptureManager",
        "TCC permission request for " + std::string([service UTF8String]) +
            " completed with result: " + (granted ? "granted" : "denied"));
    completion(granted);
  });
}

#pragma mark - Permission Methods

- (PermissionStatus)getPermission {
  ScribeLog("AudioCaptureManager", "Getting permission");

  // Check audio recording permission using TCC
  auto audioResult =
      (PermissionStatus)[self checkTCCPermission:@"kTCCServiceAudioCapture"];

  PermissionStatus audioPermissionStatus(audioResult);

  ScribeLog("AudioCaptureManager",
            "System audio permission status: " + std::to_string(audioResult));

  return audioPermissionStatus;
}

- (void)requestPermission:(void (^)(PermissionStatus))completion {
  ScribeLog("AudioCaptureManager", "Requesting permission");

  [self requestTCCPermission:@"kTCCServiceAudioCapture"
                  completion:^(BOOL granted) {
                    auto status =
                        granted ? PermissionStatus::PermissionStatusAuthorized
                                : PermissionStatus::PermissionStatusDenied;
                    ScribeLog("AudioCaptureManager",
                              "System audio permission request completed with "
                              "status: " +
                                  std::to_string(status));
                    completion(status);
                  }];
}

@end
