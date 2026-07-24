#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PlaybackEngine;

/// Native transport containing seek slider with time labels, transport buttons,
/// file open, record, and volume/mute controls.
@interface PlaybackControlView : NSView

- (instancetype)initWithEngine:(PlaybackEngine *)engine;

/// Presents an open panel and loads the chosen file (also the File -> Open...
/// target via the responder chain).
- (void)openDocument:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
