# loopmac

LoopMac is a native macOS audio loopback and replay application. It is designed purely for personal use and makes use of the [macOS Core Audio framework](https://developer.apple.com/documentation/coreaudio) to capture system audio with Core Audio taps. The user interface is built with native [AppKit](https://developer.apple.com/documentation/appkit) (Objective-C++) and audio file playback uses [AVFoundation](https://developer.apple.com/documentation/avfoundation); icons are macOS [SF Symbols](https://developer.apple.com/sf-symbols/).

LoopMac has been designed and tested on macOS Tahoe version 26.5 using AppleClang 21.0.0 and CMake 4.3.2. No attempt is currently being made for backwards compatibility.

Guidance on using `CATapDescription` for Core Audio capture provided by [Yingzhong Xu](https://dev.to/yingzhong_xu_20d6f4c5d4ce/from-core-audio-to-llms-native-macos-audio-capture-for-ai-powered-tools-dkg). 
