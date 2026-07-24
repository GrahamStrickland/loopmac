#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class PlaybackEngine;

/// Notified on the main thread when playback state or position changes.
@protocol PlaybackEngineDelegate <NSObject>
- (void)playbackEngineDidUpdate:(PlaybackEngine *)engine;
@end

/// AVAudioPlayer-backed audio playback, replacing Qt Multimedia's MediaPlayer.
@interface PlaybackEngine : NSObject

@property(nonatomic, weak, nullable) id<PlaybackEngineDelegate> delegate;

@property(nonatomic, readonly, getter=isPlaying) BOOL playing;
@property(nonatomic, readonly) BOOL hasMedia;
@property(nonatomic, readonly) NSTimeInterval position; // seconds
@property(nonatomic, readonly) NSTimeInterval duration; // seconds

/// Linear output volume in [0, 1]. Ignored while muted (restored on unmute).
@property(nonatomic) float volume;
@property(nonatomic, getter=isMuted) BOOL muted;

- (BOOL)openURL:(NSURL *)url error:(NSError *_Nullable *_Nullable)error;

- (BOOL)clearMedia;

- (void)play;
- (void)pause;
- (void)stop;
- (void)togglePlayPause;

/// Seeks to an absolute position (clamped to [0, duration]).
- (void)seekToPosition:(NSTimeInterval)seconds;

/// Skips relative to the current position by `delta` seconds (clamped).
- (void)skipBy:(NSTimeInterval)delta;

@end

NS_ASSUME_NONNULL_END
