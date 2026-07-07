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

#import "PlaybackEngine.h"

#import <AVFoundation/AVFoundation.h>

// Cadence at which position updates are pushed to the delegate while a clip is
// loaded.
static const NSTimeInterval kTickInterval = 0.05;

@interface PlaybackEngine () <AVAudioPlayerDelegate>
@end

@implementation PlaybackEngine {
  AVAudioPlayer *_player;
  NSTimer *_timer;
  float _volume; // desired volume, preserved across mute toggles
  BOOL _muted;
}

- (instancetype)init {
  if ((self = [super init])) {
    _volume = 1.0f;
    _muted = NO;

    __weak typeof(self) weakSelf = self;
    _timer = [NSTimer scheduledTimerWithTimeInterval:kTickInterval
                                             repeats:YES
                                               block:^(NSTimer *timer) {
                                                 [weakSelf tick];
                                               }];
  }
  return self;
}

- (void)dealloc {
  [_timer invalidate];
}

- (void)tick {
  if (self.hasMedia) {
    [self.delegate playbackEngineDidUpdate:self];
  }
}

#pragma mark - State

- (BOOL)hasMedia {
  return _player != nil;
}

- (BOOL)isPlaying {
  return _player.isPlaying;
}

- (NSTimeInterval)position {
  return _player ? _player.currentTime : 0.0;
}

- (NSTimeInterval)duration {
  return _player ? _player.duration : 0.0;
}

- (float)volume {
  return _volume;
}

- (void)setVolume:(float)volume {
  _volume = MIN(1.0f, MAX(0.0f, volume));
  if (!_muted) {
    _player.volume = _volume;
  }
}

- (BOOL)isMuted {
  return _muted;
}

- (void)setMuted:(BOOL)muted {
  _muted = muted;
  _player.volume = muted ? 0.0f : _volume;
}

#pragma mark - Transport

- (BOOL)openURL:(NSURL *)url error:(NSError *_Nullable *_Nullable)error {
  AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:url
                                                                 error:error];
  if (!player) {
    return NO;
  }

  player.delegate = self;
  player.volume = _muted ? 0.0f : _volume;
  [player prepareToPlay];

  _player = player;
  [_player play];

  [self.delegate playbackEngineDidUpdate:self];
  return YES;
}

- (BOOL)clearMedia {
  if (!_player) {
    return NO;
  }

  [_player stop];
  _player.delegate = nil;
  _player = nil;

  [self.delegate playbackEngineDidUpdate:self];
  return YES;
}

- (void)play {
  [_player play];
  [self.delegate playbackEngineDidUpdate:self];
}

- (void)pause {
  [_player pause];
  [self.delegate playbackEngineDidUpdate:self];
}

- (void)stop {
  [_player stop];
  [self.delegate playbackEngineDidUpdate:self];
}

- (void)togglePlayPause {
  if (self.isPlaying) {
    [self pause];
  } else {
    [self play];
  }
}

- (void)seekToPosition:(NSTimeInterval)seconds {
  if (!_player) {
    return;
  }
  _player.currentTime = MIN(_player.duration, MAX(0.0, seconds));
  [self.delegate playbackEngineDidUpdate:self];
}

- (void)skipBy:(NSTimeInterval)delta {
  [self seekToPosition:self.position + delta];
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player
                       successfully:(BOOL)flag {
  [self.delegate playbackEngineDidUpdate:self];
}

@end
